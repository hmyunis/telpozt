import json
import logging
import os
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

from apscheduler.jobstores.sqlalchemy import SQLAlchemyJobStore
from apscheduler.schedulers.background import BackgroundScheduler

from app.config import Config
from app.models.db import get_db_connection
from app.services.deduplication import calculate_cosine_similarity, calculate_sha256_hash, parse_blob_to_vector
from app.services.ollama import OllamaServiceError, generate_rewrite, generate_topic_summary, get_text_embedding
from app.services.prompt_builder import build_system_prompt
from app.services.telethon_client import scrape_channel_messages
from app.services.telegram_bot import dispatch_manual_review_prompt, send_admin_notification, send_telegram_message
from app.utils.timezone import get_current_utc_iso

logger = logging.getLogger(__name__)
scheduler = BackgroundScheduler()
DEFAULT_SOURCE_SCRAPE_LIMIT = 20


def _compose_generation_input(raw_source_text: str, instruction: str | None = None) -> str:
    if not instruction:
        return raw_source_text
    cleaned = instruction.strip()
    if not cleaned:
        return raw_source_text
    return (
        "Source material:\n"
        f"{raw_source_text}\n\n"
        "Refinement instructions from the editor:\n"
        f"{cleaned}\n\n"
        "You must apply the refinement instructions while preserving factual accuracy from the source material."
    )


def _compose_regeneration_input(
    raw_source_text: str,
    current_generated_text: str | None,
    instruction: str | None = None,
) -> str:
    cleaned = (instruction or "").strip()
    current_text = (current_generated_text or "").strip()
    sections = [f"Source material:\n{raw_source_text}"]

    if current_text:
        sections.append(
            "Current draft version to revise:\n"
            f"{current_text}"
        )

    if cleaned:
        sections.append(
            "Refinement instructions from the editor:\n"
            f"{cleaned}\n\n"
            "Revise the current draft using these instructions. Follow them directly, not optionally."
        )
    else:
        sections.append(
            "Create a fresh alternative version using the same source material."
        )

    return "\n\n".join(sections)


def _get_queue_source_names(conn, queue_id: int) -> list[str]:
    rows = conn.execute(
        """SELECT DISTINCT sc.channel_id
           FROM queue_source_posts qsp
           JOIN scraped_posts sp ON qsp.scraped_post_id = sp.id
           JOIN source_channels sc ON sp.source_channel_id = sc.id
           WHERE qsp.queue_id = ?
           ORDER BY qsp.position, sc.channel_id""",
        (queue_id,),
    ).fetchall()
    names = [row["channel_id"] for row in rows if row["channel_id"]]
    if names:
        return names

    fallback = conn.execute(
        """SELECT sc.channel_id
           FROM queue q
           LEFT JOIN scraped_posts sp ON q.scraped_post_id = sp.id
           LEFT JOIN source_channels sc ON sp.source_channel_id = sc.id
           WHERE q.id = ?""",
        (queue_id,),
    ).fetchone()
    return [fallback["channel_id"]] if fallback and fallback["channel_id"] else []


def _publish_queue_item(conn, item, *, reschedule_on_failure: bool) -> None:
    now_utc = get_current_utc_iso()
    source_names = _get_queue_source_names(conn, item["id"])
    source_label = ", ".join(source_names) if source_names else "manual"
    try:
        response = send_telegram_message(
            item["bot_token"],
            item["target_channel_id"],
            item["generated_text"],
        )
        tg_msg_id = response.get("result", {}).get("message_id")
        conn.execute(
            "UPDATE queue SET state = 'posted', posted_at_utc = ?, updated_at = ?, failure_reason = NULL WHERE id = ?",
            (now_utc, now_utc, item["id"]),
        )
        conn.execute(
            """INSERT INTO post_history (queue_id, workspace_id, final_text, source_channel, telegram_message_id, posted_at_utc)
               VALUES (?, ?, ?, ?, ?, ?)""",
            (
                item["id"],
                item["workspace_id"],
                item["generated_text"],
                source_label,
                str(tg_msg_id) if tg_msg_id is not None else None,
                now_utc,
            ),
        )
        posted_vector = get_text_embedding(item["generated_text"])
        vector_blob = json.dumps(posted_vector).encode("utf-8")
        topic_summary = generate_topic_summary(item["generated_text"])
        conn.execute(
            """INSERT INTO posted_content (workspace_id, content_hash, embedding, summary_topic, posted_at)
               VALUES (?, ?, ?, ?, ?)""",
            (
                item["workspace_id"],
                calculate_sha256_hash(item["generated_text"]),
                vector_blob,
                topic_summary,
                now_utc,
            ),
        )
        conn.commit()
    except Exception as e:
        retries = item["retry_count"] + 1
        if reschedule_on_failure and retries < 3:
            next_attempt = (datetime.now(ZoneInfo("UTC")) + timedelta(minutes=5)).isoformat()
            conn.execute(
                """UPDATE queue SET state = 'scheduled', retry_count = ?,
                   scheduled_at_utc = ?, failure_reason = ?, updated_at = ? WHERE id = ?""",
                (retries, next_attempt, str(e), now_utc, item["id"]),
            )
            send_admin_notification(
                f"⚠️ Publication failed for item #{item['id']}. Rescheduling (Attempt {retries}/3). Error: {str(e)}"
            )
        else:
            conn.execute(
                "UPDATE queue SET state = 'failed', retry_count = ?, failure_reason = ?, updated_at = ? WHERE id = ?",
                (retries, str(e), now_utc, item["id"]),
            )
            if reschedule_on_failure:
                send_admin_notification(
                    f"🚨 Publication failed for item #{item['id']} after 3 attempts. Error: {str(e)}"
                )
        conn.commit()
        raise


def start_scheduler():
    jobstore_path = os.path.join(os.path.dirname(Config.DATABASE_PATH), "jobs.db")
    scheduler.configure(
        jobstores={"default": SQLAlchemyJobStore(url=f"sqlite:///{jobstore_path}")},
        coalesce=True,
        max_instances=3,
    )
    scheduler.add_job(run_scraper_pipeline, "interval", minutes=Config.SCRAPE_INTERVAL_MINUTES, id="scraper_daemon", replace_existing=True)
    scheduler.add_job(generate_pending_embeddings, "interval", minutes=5, id="embedding_daemon", replace_existing=True)
    scheduler.add_job(process_semantic_deduplication, "interval", minutes=5, id="dedup_daemon", replace_existing=True)
    scheduler.add_job(process_pending_generation_queue, "interval", minutes=1, id="generation_daemon", replace_existing=True)
    scheduler.add_job(publish_scheduled_posts, "interval", minutes=1, id="queue_daemon", replace_existing=True)
    scheduler.add_job(run_watchdog_pipeline, "interval", minutes=5, id="watchdog_daemon", replace_existing=True)
    scheduler.start()
    logger.info("Background scheduling services initialized successfully.")


def _resolve_scrape_limit(source_row, override_message_count: int | None) -> int:
    if override_message_count is not None:
        return max(1, override_message_count)
    if source_row["default_scrape_message_count"]:
        return max(1, int(source_row["default_scrape_message_count"]))
    return DEFAULT_SOURCE_SCRAPE_LIMIT


def _resolve_source_date_window(
    source_row,
    override_from_date: datetime | None,
    override_to_date: datetime | None,
) -> tuple[datetime | None, datetime | None]:
    if override_from_date is not None or override_to_date is not None:
        return override_from_date, override_to_date
    lookback_days = source_row["default_lookback_days"]
    if lookback_days:
        now = datetime.now(ZoneInfo("UTC"))
        return now - timedelta(days=int(lookback_days)), now
    return None, None


def run_scraper_pipeline(
    workspace_id: int | None = None,
    *,
    override_message_count: int | None = None,
    override_from_date: datetime | None = None,
    override_to_date: datetime | None = None,
):
    logger.info("Starting background scraper pipeline...")
    with get_db_connection() as conn:
        if workspace_id is None:
            active_sources = conn.execute("SELECT * FROM source_channels WHERE is_active = 1").fetchall()
        else:
            active_sources = conn.execute(
                "SELECT * FROM source_channels WHERE is_active = 1 AND workspace_id = ?",
                (workspace_id,),
            ).fetchall()
        for src in active_sources:
            effective_limit = _resolve_scrape_limit(src, override_message_count)
            effective_from_date, effective_to_date = _resolve_source_date_window(
                src,
                override_from_date,
                override_to_date,
            )
            posts = scrape_channel_messages(
                src["channel_id"],
                src["last_message_id"],
                limit=effective_limit,
                from_date=effective_from_date,
                to_date=effective_to_date,
            )
            for post in posts:
                raw_text = post["text"]
                msg_id = post["id"]
                c_hash = calculate_sha256_hash(raw_text)
                existing_scraped = conn.execute(
                    "SELECT id FROM scraped_posts WHERE content_hash = ? AND source_channel_id = ?",
                    (c_hash, src["id"]),
                ).fetchone()
                existing_posted = conn.execute(
                    "SELECT id FROM posted_content WHERE content_hash = ? AND workspace_id = ?",
                    (c_hash, src["workspace_id"]),
                ).fetchone()
                dedup_status = "duplicate" if (existing_scraped or existing_posted) else "pending"
                try:
                    conn.execute(
                        """INSERT INTO scraped_posts (
                            source_channel_id, telegram_message_id, raw_text, content_hash,
                            original_posted_at_utc, view_count,
                            embedding, embedding_status, dedup_status, duplicate_of_id,
                            similarity_score, scraped_at
                           ) VALUES (?, ?, ?, ?, ?, ?, NULL, 'pending', ?, ?, NULL, ?)""",
                        (
                            src["id"],
                            msg_id,
                            raw_text,
                            c_hash,
                            post.get("date") or None,
                            post.get("views"),
                            dedup_status,
                            existing_scraped["id"] if existing_scraped else None,
                            get_current_utc_iso(),
                        ),
                    )
                except Exception as e:
                    logger.warning(f"Failed to save scraped post {msg_id}: {e}")
            if posts:
                max_msg_id = max(post["id"] for post in posts)
                conn.execute(
                    "UPDATE source_channels SET last_message_id = ?, last_scraped_at = ? WHERE id = ?",
                    (max_msg_id, get_current_utc_iso(), src["id"]),
                )
                conn.commit()


def generate_pending_embeddings():
    with get_db_connection() as conn:
        pending_posts = conn.execute(
            """SELECT id, raw_text FROM scraped_posts
               WHERE embedding_status IN ('pending', 'failed')
               AND dedup_status = 'pending'
               LIMIT 20"""
        ).fetchall()
        for post in pending_posts:
            try:
                vector = get_text_embedding(post["raw_text"])
                vector_blob = json.dumps(vector).encode("utf-8")
                conn.execute("UPDATE scraped_posts SET embedding = ?, embedding_status = 'done' WHERE id = ?", (vector_blob, post["id"]))
                conn.commit()
            except Exception as e:
                logger.error(f"Embedding calculation failure on post {post['id']}: {e}")
                conn.execute("UPDATE scraped_posts SET embedding_status = 'failed' WHERE id = ?", (post["id"],))
                conn.commit()


def process_semantic_deduplication():
    threshold = Config.DEDUP_SIMILARITY_THRESHOLD
    cutoff_date = (datetime.now(ZoneInfo("UTC")) - timedelta(days=Config.DEDUP_LOOKBACK_DAYS)).isoformat()
    with get_db_connection() as conn:
        candidates = conn.execute(
            """SELECT sp.id, sp.raw_text, sp.embedding, sc.workspace_id 
               FROM scraped_posts sp
               JOIN source_channels sc ON sp.source_channel_id = sc.id
               WHERE sp.embedding_status = 'done' AND sp.dedup_status = 'pending'"""
        ).fetchall()
        for cand in candidates:
            cand_vector = parse_blob_to_vector(cand["embedding"])
            if not cand_vector:
                continue
            reference_posts = conn.execute(
                """SELECT id, embedding, summary_topic FROM posted_content 
                   WHERE workspace_id = ? AND posted_at >= ?""",
                (cand["workspace_id"], cutoff_date),
            ).fetchall()
            max_sim = 0.0
            best_match = None
            for ref in reference_posts:
                ref_vector = parse_blob_to_vector(ref["embedding"])
                sim = calculate_cosine_similarity(cand_vector, ref_vector)
                if sim > max_sim:
                    max_sim = sim
                    best_match = ref
            if max_sim >= threshold:
                conn.execute(
                    """UPDATE scraped_posts SET dedup_status = 'duplicate', 
                       similarity_score = ?, duplicate_of_id = ? WHERE id = ?""",
                    (max_sim, best_match["id"] if best_match else None, cand["id"]),
                )
            elif max_sim >= 0.75:
                conn.execute(
                    "UPDATE scraped_posts SET dedup_status = 'manual_review', similarity_score = ? WHERE id = ?",
                    (max_sim, cand["id"]),
                )
                dispatch_manual_review_prompt(
                    cand["id"], cand["raw_text"],
                    best_match["summary_topic"] if best_match else "Prior post matching criteria",
                    max_sim, cand["workspace_id"],
                )
            else:
                conn.execute("UPDATE scraped_posts SET dedup_status = 'unique' WHERE id = ?", (cand["id"],))
            conn.commit()


def enqueue_generation(queue_id: int):
    scheduler.add_job(generate_rewrite_task, args=[queue_id], id=f"gen_job_{queue_id}", replace_existing=True)


def process_pending_generation_queue():
    with get_db_connection() as conn:
        pending_items = conn.execute(
            """SELECT id FROM queue
               WHERE generation_status = 'pending'
               AND state = 'draft'
               ORDER BY id
               LIMIT 5"""
        ).fetchall()
    for item in pending_items:
        generate_rewrite_task(item["id"])


def _is_retryable_generation_error(error: Exception) -> bool:
    if isinstance(error, OllamaServiceError):
        return error.retryable
    message = str(error).lower()
    return "429" in message or "quota" in message or "rate limit" in message or "retry" in message


def generate_rewrite_task(queue_id: int):
    _generate_rewrite(queue_id)


def _generate_rewrite(
    queue_id: int,
    *,
    instruction_override: str | None = None,
    preserve_existing_text: bool = False,
    retry_on_failure: bool = True,
    use_saved_instruction: bool = True,
):
    with get_db_connection() as conn:
        item = conn.execute("SELECT * FROM queue WHERE id = ?", (queue_id,)).fetchone()
        if not item or item["generation_status"] == "generating":
            return
        previous_generated_text = item["generated_text"]
        effective_instruction = (
            instruction_override
            if instruction_override is not None
            else item["last_generation_instruction"] if use_saved_instruction else None
        )
        conn.execute(
            "UPDATE queue SET generation_status = 'generating', failure_reason = NULL, updated_at = ? WHERE id = ?",
            (get_current_utc_iso(), queue_id),
        )
        conn.commit()
        ws = conn.execute("SELECT style_profile_id FROM workspaces WHERE id = ?", (item["workspace_id"],)).fetchone()
        if not ws or not ws["style_profile_id"]:
            conn.execute(
                "UPDATE queue SET generation_status = 'failed', failure_reason = 'Workspace style profile missing' WHERE id = ?",
                (queue_id,),
            )
            conn.commit()
            return
        profile = conn.execute("SELECT * FROM style_profiles WHERE id = ?", (ws["style_profile_id"],)).fetchone()
        topics = conn.execute("SELECT summary_topic FROM posted_content WHERE workspace_id = ? ORDER BY id DESC LIMIT 10", (item["workspace_id"],)).fetchall()
        recent_topics = [t["summary_topic"] for t in topics if t["summary_topic"]]
        prompt = build_system_prompt(dict(profile), dict(ws), recent_topics)
        try:
            generation_input = (
                _compose_regeneration_input(
                    item["raw_source_text"],
                    previous_generated_text,
                    effective_instruction,
                )
                if preserve_existing_text
                else _compose_generation_input(item["raw_source_text"], effective_instruction)
            )
            rewrite = generate_rewrite(prompt, generation_input)
            conn.execute(
                """UPDATE queue
                   SET generated_text = ?, last_generation_instruction = ?, generation_status = 'done',
                       failure_reason = NULL, updated_at = ?
                   WHERE id = ?""",
                (rewrite, effective_instruction, get_current_utc_iso(), queue_id),
            )
            conn.commit()
        except Exception as e:
            if preserve_existing_text and previous_generated_text:
                next_status = "done"
            else:
                next_status = "pending" if retry_on_failure and _is_retryable_generation_error(e) else "failed"
            conn.execute(
                """UPDATE queue SET generation_status = ?,
                   generated_text = ?, failure_reason = ?, updated_at = ? WHERE id = ?""",
                (next_status, previous_generated_text, str(e), get_current_utc_iso(), queue_id),
            )
            conn.commit()
            raise


def regenerate_draft(queue_id: int, instruction: str | None = None):
    _generate_rewrite(
        queue_id,
        instruction_override=instruction,
        preserve_existing_text=True,
        retry_on_failure=False,
        use_saved_instruction=False,
    )


def publish_queue_item_now(queue_id: int):
    with get_db_connection() as conn:
        item = conn.execute(
            """SELECT q.*, w.bot_token, w.target_channel_id
               FROM queue q
               JOIN workspaces w ON q.workspace_id = w.id
               WHERE q.id = ?""",
            (queue_id,),
        ).fetchone()
        if not item:
            raise ValueError(f"Queue item {queue_id} was not found.")
        if item["generation_status"] != "done" or not item["generated_text"]:
            raise ValueError("Draft content is not ready to publish.")
        if item["state"] == "posted":
            return
        now_utc = get_current_utc_iso()
        conn.execute(
            "UPDATE queue SET state = 'posting', updated_at = ? WHERE id = ?",
            (now_utc, queue_id),
        )
        conn.commit()
        _publish_queue_item(conn, item, reschedule_on_failure=False)


def publish_scheduled_posts():
    now_utc = get_current_utc_iso()
    with get_db_connection() as conn:
        target = conn.execute(
            """SELECT id FROM queue 
               WHERE state = 'scheduled' 
               AND scheduled_at_utc <= ? 
               LIMIT 1""",
            (now_utc,),
        ).fetchone()
        if not target:
            return
        cursor = conn.cursor()
        cursor.execute("UPDATE queue SET state = 'posting', updated_at = ? WHERE id = ? AND state = 'scheduled'", (now_utc, target["id"]))
        conn.commit()
        if cursor.rowcount == 0:
            return
        item = conn.execute(
            """SELECT q.*, w.bot_token, w.target_channel_id
               FROM queue q
               JOIN workspaces w ON q.workspace_id = w.id
               WHERE q.id = ?""",
            (target["id"],),
        ).fetchone()
        try:
            _publish_queue_item(conn, item, reschedule_on_failure=True)
        except Exception as e:
            logger.error("Scheduled publication failed for queue item %s: %s", item["id"], e)


def run_watchdog_pipeline():
    cutoff = (datetime.now(ZoneInfo("UTC")) - timedelta(minutes=5)).isoformat()
    with get_db_connection() as conn:
        stuck_items = conn.execute("SELECT id, retry_count FROM queue WHERE state = 'posting' AND updated_at <= ?", (cutoff,)).fetchall()
        for item in stuck_items:
            retries = item["retry_count"] + 1
            next_attempt = (datetime.now(ZoneInfo("UTC")) + timedelta(minutes=2)).isoformat()
            conn.execute(
                """UPDATE queue SET state = 'scheduled', retry_count = ?, 
                   scheduled_at_utc = ?, failure_reason = 'Stuck in posting state', updated_at = ? 
                   WHERE id = ?""",
                (retries, next_attempt, get_current_utc_iso(), item["id"]),
            )
            conn.commit()

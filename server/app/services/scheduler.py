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
from app.services.gemini import generate_rewrite, generate_topic_summary, get_text_embedding
from app.services.prompt_builder import build_system_prompt
from app.services.telethon_client import scrape_channel_messages
from app.services.telegram_bot import dispatch_manual_review_prompt, send_admin_notification, send_telegram_message
from app.utils.timezone import get_current_utc_iso

logger = logging.getLogger(__name__)
scheduler = BackgroundScheduler()


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
    scheduler.add_job(publish_scheduled_posts, "interval", minutes=1, id="queue_daemon", replace_existing=True)
    scheduler.add_job(run_watchdog_pipeline, "interval", minutes=5, id="watchdog_daemon", replace_existing=True)
    scheduler.start()
    logger.info("Background scheduling services initialized successfully.")


def run_scraper_pipeline(workspace_id: int | None = None):
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
            posts = scrape_channel_messages(src["channel_id"], src["last_message_id"])
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
                            embedding, embedding_status, dedup_status, duplicate_of_id,
                            similarity_score, scraped_at
                           ) VALUES (?, ?, ?, ?, NULL, 'pending', ?, ?, NULL, ?)""",
                        (
                            src["id"], msg_id, raw_text, c_hash, dedup_status,
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
            "SELECT id, raw_text FROM scraped_posts WHERE embedding_status = 'pending' AND dedup_status = 'pending' LIMIT 20"
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
                cursor = conn.cursor()
                cursor.execute(
                    """INSERT INTO queue (
                        workspace_id, scraped_post_id, raw_source_text, generated_text,
                        generation_status, state, scheduled_at_utc, posted_at_utc,
                        failure_reason, retry_count, created_at, updated_at
                       ) VALUES (?, ?, ?, NULL, 'pending', 'draft', NULL, NULL, NULL, 0, ?, ?)""",
                    (cand["workspace_id"], cand["id"], cand["raw_text"], get_current_utc_iso(), get_current_utc_iso()),
                )
                conn.commit()
                enqueue_generation(cursor.lastrowid)
            conn.commit()


def enqueue_generation(queue_id: int):
    scheduler.add_job(generate_rewrite_task, args=[queue_id], id=f"gen_job_{queue_id}", replace_existing=True)


def generate_rewrite_task(queue_id: int):
    with get_db_connection() as conn:
        item = conn.execute("SELECT * FROM queue WHERE id = ?", (queue_id,)).fetchone()
        if not item or item["generation_status"] == "generating":
            return
        conn.execute("UPDATE queue SET generation_status = 'generating' WHERE id = ?", (queue_id,))
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
            rewrite = generate_rewrite(prompt, item["raw_source_text"])
            conn.execute("UPDATE queue SET generated_text = ?, generation_status = 'done', updated_at = ? WHERE id = ?", (rewrite, get_current_utc_iso(), queue_id))
            conn.commit()
        except Exception as e:
            conn.execute(
                """UPDATE queue SET generation_status = 'failed', 
                   failure_reason = ?, updated_at = ? WHERE id = ?""",
                (str(e), get_current_utc_iso(), queue_id),
            )
            conn.commit()


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
            """SELECT q.*, w.bot_token, w.target_channel_id, sc.channel_id as source_name 
               FROM queue q
               JOIN workspaces w ON q.workspace_id = w.id
               LEFT JOIN scraped_posts sp ON q.scraped_post_id = sp.id
               LEFT JOIN source_channels sc ON sp.source_channel_id = sc.id
               WHERE q.id = ?""",
            (target["id"],),
        ).fetchone()
        try:
            response = send_telegram_message(item["bot_token"], item["target_channel_id"], item["generated_text"])
            tg_msg_id = response.get("result", {}).get("message_id")
            conn.execute("UPDATE queue SET state = 'posted', posted_at_utc = ?, updated_at = ? WHERE id = ?", (now_utc, now_utc, item["id"]))
            conn.execute(
                """INSERT INTO post_history (queue_id, workspace_id, final_text, source_channel, telegram_message_id, posted_at_utc)
                   VALUES (?, ?, ?, ?, ?, ?)""",
                (item["id"], item["workspace_id"], item["generated_text"], item["source_name"] or "manual", str(tg_msg_id), now_utc),
            )
            posted_vector = get_text_embedding(item["generated_text"])
            vector_blob = json.dumps(posted_vector).encode("utf-8")
            topic_summary = generate_topic_summary(item["generated_text"])
            conn.execute(
                """INSERT INTO posted_content (workspace_id, content_hash, embedding, summary_topic, posted_at)
                   VALUES (?, ?, ?, ?, ?)""",
                (item["workspace_id"], calculate_sha256_hash(item["generated_text"]), vector_blob, topic_summary, now_utc),
            )
            conn.commit()
        except Exception as e:
            retries = item["retry_count"] + 1
            if retries < 3:
                next_attempt = (datetime.now(ZoneInfo("UTC")) + timedelta(minutes=5)).isoformat()
                conn.execute(
                    """UPDATE queue SET state = 'scheduled', retry_count = ?, 
                       scheduled_at_utc = ?, failure_reason = ?, updated_at = ? WHERE id = ?""",
                    (retries, next_attempt, str(e), now_utc, item["id"]),
                )
                send_admin_notification(f"⚠️ Publication failed for item #{item['id']}. Rescheduling (Attempt {retries}/3). Error: {str(e)}")
            else:
                conn.execute(
                    "UPDATE queue SET state = 'failed', retry_count = ?, failure_reason = ?, updated_at = ? WHERE id = ?",
                    (retries, str(e), now_utc, item["id"]),
                )
                send_admin_notification(f"🚨 Publication failed for item #{item['id']} after 3 attempts. Error: {str(e)}")
            conn.commit()


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

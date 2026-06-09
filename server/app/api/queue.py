from datetime import datetime
from zoneinfo import ZoneInfo

from flask import Blueprint, g, request

from app.api.utils import APIError, api_success, token_required, verify_queue_owner, verify_workspace_owner
from app.models.db import get_db_connection
from app.services.prompt_builder import build_system_prompt
from app.services.scheduler import generate_rewrite_task, publish_queue_item_now, regenerate_draft
from app.services.telegram_bot import send_post_preview
from app.utils.timezone import get_current_utc_iso

queue_bp = Blueprint("queue", __name__)

VALID_TRANSITIONS = {
    "approve": {"allowed_from": ["draft"], "target_state": "approved"},
    "cancel": {"allowed_from": ["draft", "approved", "scheduled"], "target_state": "cancelled"},
    "requeue": {"allowed_from": ["failed", "cancelled"], "target_state": "draft"},
}


def _parse_optional_iso_datetime(value, field_name: str) -> datetime | None:
    if value in (None, ""):
        return None
    try:
        parsed = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError as err:
        raise APIError("VALIDATION_ERROR", f"{field_name} must be a valid ISO-8601 datetime.", 400) from err
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=ZoneInfo("UTC"))
    return parsed.astimezone(ZoneInfo("UTC"))


def _parse_int_list_param(raw_value: str | None, field_name: str) -> list[int]:
    if raw_value in (None, ""):
        return []
    values: list[int] = []
    for part in str(raw_value).split(","):
        cleaned = part.strip()
        if not cleaned:
            continue
        try:
            parsed = int(cleaned)
        except ValueError as err:
            raise APIError("VALIDATION_ERROR", f"{field_name} must contain only integers.", 400) from err
        if parsed not in values:
            values.append(parsed)
    return values


def _draft_status(item: dict) -> str:
    if item["state"] == "posted":
        return "published"
    if item["state"] == "scheduled":
        return "scheduled"
    if item["state"] == "failed" or item["generation_status"] == "failed":
        return "failed"
    if item["generation_status"] in {"pending", "generating"}:
        return "generating"
    return "ready"


def _fetch_source_rows(conn, queue_id: int) -> list[dict]:
    rows = conn.execute(
        """SELECT qsp.scraped_post_id,
                  qsp.position,
                  sp.raw_text,
                  sp.dedup_status,
                  sp.original_posted_at_utc,
                  sp.view_count,
                  sc.channel_id AS source_channel_id,
                  COALESCE(sc.display_name, sc.channel_id) AS source_label
           FROM queue_source_posts qsp
           JOIN scraped_posts sp ON qsp.scraped_post_id = sp.id
           JOIN source_channels sc ON sp.source_channel_id = sc.id
           WHERE qsp.queue_id = ?
           ORDER BY qsp.position, qsp.scraped_post_id""",
        (queue_id,),
    ).fetchall()
    if rows:
        return [dict(row) for row in rows]

    fallback = conn.execute(
        """SELECT q.scraped_post_id AS scraped_post_id,
                  0 AS position,
                  sp.raw_text,
                  sp.dedup_status,
                  sp.original_posted_at_utc,
                  sp.view_count,
                  sc.channel_id AS source_channel_id,
                  COALESCE(sc.display_name, sc.channel_id) AS source_label
           FROM queue q
           LEFT JOIN scraped_posts sp ON q.scraped_post_id = sp.id
           LEFT JOIN source_channels sc ON sp.source_channel_id = sc.id
           WHERE q.id = ?""",
        (queue_id,),
    ).fetchone()
    if fallback and fallback["scraped_post_id"]:
        return [dict(fallback)]
    return []


def _serialize_draft(conn, row) -> dict:
    item = dict(row)
    sources = _fetch_source_rows(conn, item["id"])
    item["status"] = _draft_status(item)
    item["selected_source_ids"] = [src["scraped_post_id"] for src in sources]
    item["selected_sources"] = sources
    item["source_count"] = len(sources)
    return item


def _merge_sources_for_generation(source_rows: list[dict]) -> str:
    sections = []
    for index, row in enumerate(source_rows, start=1):
        label = row["source_label"] or row["source_channel_id"] or f"Source {index}"
        text = (row["raw_text"] or "").strip()
        sections.append(f"Source {index} - {label}:\n{text}")
    return "\n\n".join(sections)


def _load_workspace_sources(conn, workspace_id: int, source_post_ids: list[int]) -> list[dict]:
    placeholders = ",".join("?" for _ in source_post_ids)
    rows = conn.execute(
        f"""SELECT sp.id AS scraped_post_id,
                   sp.raw_text,
                   sp.dedup_status,
                   sp.original_posted_at_utc,
                   sp.view_count,
                   sc.channel_id AS source_channel_id,
                   COALESCE(sc.display_name, sc.channel_id) AS source_label
            FROM scraped_posts sp
            JOIN source_channels sc ON sp.source_channel_id = sc.id
            WHERE sc.workspace_id = ?
              AND sp.id IN ({placeholders})
            ORDER BY sp.id DESC""",
        [workspace_id, *source_post_ids],
    ).fetchall()
    by_id = {row["scraped_post_id"]: dict(row) for row in rows}
    ordered = [by_id[source_id] for source_id in source_post_ids if source_id in by_id]
    if len(ordered) != len(source_post_ids):
        raise APIError("NOT_FOUND", "One or more selected source items were not found in this workspace.", 404)
    return ordered


def _create_queue_record(conn, workspace_id: int, source_rows: list[dict]) -> int:
    now = get_current_utc_iso()
    merged_text = _merge_sources_for_generation(source_rows)
    cursor = conn.cursor()
    cursor.execute(
        """INSERT INTO queue (
            workspace_id, scraped_post_id, raw_source_text, generated_text, last_generation_instruction,
            generation_status, state, scheduled_at_utc, posted_at_utc, failure_reason,
            retry_count, created_at, updated_at
        ) VALUES (?, ?, ?, NULL, NULL, 'pending', 'draft', NULL, NULL, NULL, 0, ?, ?)""",
        (workspace_id, source_rows[0]["scraped_post_id"], merged_text, now, now),
    )
    queue_id = cursor.lastrowid
    for index, row in enumerate(source_rows):
        conn.execute(
            "INSERT INTO queue_source_posts (queue_id, scraped_post_id, position) VALUES (?, ?, ?)",
            (queue_id, row["scraped_post_id"], index),
        )
    conn.commit()
    return queue_id


@queue_bp.route("/<int:id>/drafts", methods=["GET"])
@token_required
def list_workspace_drafts(id):
    status_filter = request.args.get("status", "").strip().lower()
    search_query = request.args.get("q", "").strip().lower()
    source_channel_ids = _parse_int_list_param(
        request.args.get("source_channel_ids"),
        "source_channel_ids",
    )
    scraped_from = _parse_optional_iso_datetime(
        request.args.get("scraped_from_utc"),
        "scraped_from_utc",
    )
    scraped_to = _parse_optional_iso_datetime(
        request.args.get("scraped_to_utc"),
        "scraped_to_utc",
    )
    if scraped_from and scraped_to and scraped_from > scraped_to:
        raise APIError("VALIDATION_ERROR", "scraped_from_utc must be earlier than scraped_to_utc.", 400)

    page = max(1, int(request.args.get("page", 1)))
    per_page = max(1, min(100, int(request.args.get("per_page", 20))))
    offset = (page - 1) * per_page
    with get_db_connection() as conn:
        verify_workspace_owner(id, g.current_user["id"], conn)
        where_clauses = ["workspace_id = ?", "state != 'cancelled'"]
        params = [id]
        count_params = [id]
        if status_filter == "published":
            where_clauses.append("state = 'posted'")
        else:
            where_clauses.append("state != 'posted'")
        if status_filter == "scheduled":
            where_clauses.append("state = 'scheduled'")
        elif status_filter == "failed":
            where_clauses.append("(state = 'failed' OR generation_status = 'failed')")
        elif status_filter == "generating":
            where_clauses.append("generation_status IN ('pending', 'generating')")
        elif status_filter == "ready":
            where_clauses.append(
                "state NOT IN ('posted', 'scheduled', 'failed') AND generation_status = 'done'"
            )
        if search_query:
            like_value = f"%{search_query}%"
            where_clauses.append(
                """(
                    lower(coalesce(generated_text, '')) LIKE ?
                    OR lower(coalesce(raw_source_text, '')) LIKE ?
                    OR EXISTS (
                        SELECT 1
                        FROM queue_source_posts qsp
                        JOIN scraped_posts sp ON qsp.scraped_post_id = sp.id
                        JOIN source_channels sc ON sp.source_channel_id = sc.id
                        WHERE qsp.queue_id = queue.id
                          AND (
                            lower(coalesce(sp.raw_text, '')) LIKE ?
                            OR lower(coalesce(sc.channel_id, '')) LIKE ?
                            OR lower(coalesce(sc.display_name, '')) LIKE ?
                          )
                    )
                )"""
            )
            params.extend([like_value, like_value, like_value, like_value, like_value])
            count_params.extend([like_value, like_value, like_value, like_value, like_value])
        if source_channel_ids:
            placeholders = ",".join("?" for _ in source_channel_ids)
            exists_clause = (
                "EXISTS ("
                "SELECT 1 FROM queue_source_posts qsp "
                "JOIN scraped_posts sp ON qsp.scraped_post_id = sp.id "
                "WHERE qsp.queue_id = queue.id "
                f"AND sp.source_channel_id IN ({placeholders})"
                ")"
            )
            where_clauses.append(exists_clause)
            params.extend(source_channel_ids)
            count_params.extend(source_channel_ids)
        if scraped_from:
            where_clauses.append(
                """EXISTS (
                    SELECT 1 FROM queue_source_posts qsp
                    JOIN scraped_posts sp ON qsp.scraped_post_id = sp.id
                    WHERE qsp.queue_id = queue.id
                      AND sp.original_posted_at_utc IS NOT NULL
                      AND sp.original_posted_at_utc >= ?
                )"""
            )
            iso_value = scraped_from.isoformat()
            params.append(iso_value)
            count_params.append(iso_value)
        if scraped_to:
            where_clauses.append(
                """EXISTS (
                    SELECT 1 FROM queue_source_posts qsp
                    JOIN scraped_posts sp ON qsp.scraped_post_id = sp.id
                    WHERE qsp.queue_id = queue.id
                      AND sp.original_posted_at_utc IS NOT NULL
                      AND sp.original_posted_at_utc <= ?
                )"""
            )
            iso_value = scraped_to.isoformat()
            params.append(iso_value)
            count_params.append(iso_value)
        where_sql = " AND ".join(where_clauses)
        rows = conn.execute(
            f"""SELECT * FROM queue
               WHERE {where_sql}
               ORDER BY
                 CASE
                   WHEN state = 'scheduled' THEN 0
                   WHEN generation_status IN ('pending', 'generating') THEN 1
                   WHEN generation_status = 'failed' OR state = 'failed' THEN 3
                   WHEN state = 'posted' THEN 4
                   ELSE 2
                 END,
                 id DESC
               LIMIT ? OFFSET ?""",
            [*params, per_page, offset],
        ).fetchall()
        serialized = [_serialize_draft(conn, row) for row in rows]
        total = conn.execute(
            f"SELECT COUNT(*) AS total FROM queue WHERE {where_sql}",
            count_params,
        ).fetchone()["total"]
    return api_success(
        {
            "items": serialized,
            "meta": {
                "page": page,
                "per_page": per_page,
                "total_items": total,
                "total_pages": (total + per_page - 1) // per_page,
            },
        }
    )


@queue_bp.route("/<int:id>/drafts", methods=["POST"])
@token_required
def create_draft(id):
    data = request.get_json() or {}
    raw_ids = data.get("source_post_ids", [])
    if not isinstance(raw_ids, list) or not raw_ids:
        raise APIError("VALIDATION_ERROR", "source_post_ids must be a non-empty array.", 400)

    source_post_ids: list[int] = []
    for value in raw_ids:
        try:
            parsed = int(value)
        except (TypeError, ValueError) as err:
            raise APIError("VALIDATION_ERROR", "source_post_ids must only contain integers.", 400) from err
        if parsed not in source_post_ids:
            source_post_ids.append(parsed)

    with get_db_connection() as conn:
        verify_workspace_owner(id, g.current_user["id"], conn)
        source_rows = _load_workspace_sources(conn, id, source_post_ids)
        if any(row["dedup_status"] == "duplicate" for row in source_rows):
            raise APIError("VALIDATION_ERROR", "Duplicate candidates cannot be used to create a draft.", 400)
        queue_id = _create_queue_record(conn, id, source_rows)

    try:
        generate_rewrite_task(queue_id)
    except Exception:
        pass

    with get_db_connection() as conn:
        created = conn.execute("SELECT * FROM queue WHERE id = ?", (queue_id,)).fetchone()
        return api_success(_serialize_draft(conn, created), 201)


@queue_bp.route("/<int:id>/drafts/<int:draft_id>", methods=["GET"])
@token_required
def get_draft(id, draft_id):
    with get_db_connection() as conn:
        verify_workspace_owner(id, g.current_user["id"], conn)
        item = verify_queue_owner(id, draft_id, conn)
        return api_success(_serialize_draft(conn, item))


@queue_bp.route("/<int:id>/drafts/<int:draft_id>/regenerate", methods=["POST"])
@token_required
def regenerate_workspace_draft(id, draft_id):
    data = request.get_json() or {}
    instruction = data.get("instruction")
    if instruction is not None:
        instruction = str(instruction).strip()
    with get_db_connection() as conn:
        verify_workspace_owner(id, g.current_user["id"], conn)
        verify_queue_owner(id, draft_id, conn)

    try:
        regenerate_draft(draft_id, instruction or None)
    except Exception as err:
        raise APIError("DRAFT_REGENERATION_FAILED", str(err), 400) from err

    with get_db_connection() as conn:
        updated = conn.execute("SELECT * FROM queue WHERE id = ?", (draft_id,)).fetchone()
        return api_success(_serialize_draft(conn, updated))


@queue_bp.route("/<int:id>/drafts/<int:draft_id>/text", methods=["PATCH"])
@token_required
def save_draft_text(id, draft_id):
    data = request.get_json() or {}
    text = data.get("generated_text", "").strip()
    if not text:
        raise APIError("VALIDATION_ERROR", "The generated_text field cannot be empty.", 400)
    now = get_current_utc_iso()
    with get_db_connection() as conn:
        verify_workspace_owner(id, g.current_user["id"], conn)
        verify_queue_owner(id, draft_id, conn)
        conn.execute(
            """UPDATE queue
               SET generated_text = ?, generation_status = 'done', failure_reason = NULL, updated_at = ?
               WHERE id = ?""",
            (text, now, draft_id),
        )
        conn.commit()
        updated = conn.execute("SELECT * FROM queue WHERE id = ?", (draft_id,)).fetchone()
        return api_success(_serialize_draft(conn, updated))


@queue_bp.route("/<int:id>/drafts/<int:draft_id>/publish", methods=["POST"])
@token_required
def publish_draft(id, draft_id):
    with get_db_connection() as conn:
        verify_workspace_owner(id, g.current_user["id"], conn)
        item = verify_queue_owner(id, draft_id, conn)
        if item["generation_status"] != "done" or not item["generated_text"]:
            raise APIError("GENERATION_NOT_READY", "Draft content must be ready before publishing.", 400)

    try:
        publish_queue_item_now(draft_id)
    except Exception as err:
        raise APIError("PUBLISH_FAILED", str(err), 400) from err

    with get_db_connection() as conn:
        updated = conn.execute("SELECT * FROM queue WHERE id = ?", (draft_id,)).fetchone()
        return api_success(_serialize_draft(conn, updated))


@queue_bp.route("/<int:id>/drafts/<int:draft_id>/schedule", methods=["POST"])
@token_required
def schedule_draft(id, draft_id):
    data = request.get_json() or {}
    scheduled_at = str(data.get("scheduled_at", "")).strip()
    if not scheduled_at:
        raise APIError("VALIDATION_ERROR", "scheduled_at is required.", 400)
    now = get_current_utc_iso()
    with get_db_connection() as conn:
        verify_workspace_owner(id, g.current_user["id"], conn)
        item = verify_queue_owner(id, draft_id, conn)
        if item["generation_status"] != "done":
            raise APIError("GENERATION_NOT_READY", "Draft content must be ready before scheduling.", 400)
        conn.execute(
            """UPDATE queue
               SET state = 'scheduled', scheduled_at_utc = ?, failure_reason = NULL, updated_at = ?
               WHERE id = ?""",
            (scheduled_at, now, draft_id),
        )
        conn.commit()
        updated = conn.execute("SELECT * FROM queue WHERE id = ?", (draft_id,)).fetchone()
        return api_success(_serialize_draft(conn, updated))


@queue_bp.route("/<int:id>/drafts/<int:draft_id>", methods=["DELETE"])
@token_required
def delete_draft(id, draft_id):
    with get_db_connection() as conn:
        verify_workspace_owner(id, g.current_user["id"], conn)
        item = verify_queue_owner(id, draft_id, conn)
        if item["state"] == "posted":
            raise APIError("INVALID_STATE_TRANSITION", "Published posts cannot be deleted as drafts.", 400)
        conn.execute("DELETE FROM queue WHERE id = ?", (draft_id,))
        conn.commit()
    return api_success({"deleted": True})


@queue_bp.route("/<int:id>/queue", methods=["GET"])
@token_required
def list_workspace_queue(id):
    state_filter = request.args.get("state", "").strip()
    page = max(1, int(request.args.get("page", 1)))
    per_page = max(1, min(100, int(request.args.get("per_page", 20))))
    offset = (page - 1) * per_page
    states = [s.strip() for s in state_filter.split(",") if s.strip()]
    with get_db_connection() as conn:
        verify_workspace_owner(id, g.current_user["id"], conn)
        query = "SELECT * FROM queue WHERE workspace_id = ?"
        params = [id]
        if states:
            query += f" AND state IN ({','.join(['?' for _ in states])})"
            params.extend(states)
        query += " ORDER BY id DESC LIMIT ? OFFSET ?"
        params.extend([per_page, offset])
        rows = conn.execute(query, params).fetchall()
        count_query = "SELECT COUNT(*) as total FROM queue WHERE workspace_id = ?"
        count_params = [id]
        if states:
            count_query += f" AND state IN ({','.join(['?' for _ in states])})"
            count_params.extend(states)
        total = conn.execute(count_query, count_params).fetchone()["total"]
    return api_success({"items": [dict(row) for row in rows], "meta": {"page": page, "per_page": per_page, "total_items": total, "total_pages": (total + per_page - 1) // per_page}})


@queue_bp.route("/<int:id>/queue/<int:queue_id>", methods=["GET"])
@token_required
def get_queue_item(id, queue_id):
    with get_db_connection() as conn:
        verify_workspace_owner(id, g.current_user["id"], conn)
        item = verify_queue_owner(id, queue_id, conn)
    return api_success(item)


@queue_bp.route("/<int:id>/queue", methods=["POST"])
@token_required
def create_queue_item(id):
    data = request.get_json() or {}
    raw_text = data.get("raw_text", "").strip()
    if not raw_text:
        raise APIError("VALIDATION_ERROR", "The raw_text field is required.", 400)
    now = get_current_utc_iso()
    with get_db_connection() as conn:
        verify_workspace_owner(id, g.current_user["id"], conn)
        cursor = conn.cursor()
        cursor.execute(
            """INSERT INTO queue (
                workspace_id, scraped_post_id, raw_source_text, generated_text, last_generation_instruction,
                generation_status, state, scheduled_at_utc, posted_at_utc,
                failure_reason, retry_count, created_at, updated_at
               ) VALUES (?, NULL, ?, NULL, NULL, 'pending', 'draft', NULL, NULL, NULL, 0, ?, ?)""",
            (id, raw_text, now, now),
        )
        conn.commit()
        queue_id = cursor.lastrowid
        saved_item = conn.execute("SELECT * FROM queue WHERE id = ?", (queue_id,)).fetchone()
    return api_success(dict(saved_item), 201)


@queue_bp.route("/<int:id>/queue/<int:queue_id>", methods=["PATCH"])
@token_required
def update_queue_item_state(id, queue_id):
    data = request.get_json() or {}
    action = data.get("action", "").strip().lower()
    scheduled_at = data.get("scheduled_at", "").strip()
    now = get_current_utc_iso()
    with get_db_connection() as conn:
        verify_workspace_owner(id, g.current_user["id"], conn)
        item = verify_queue_owner(id, queue_id, conn)
        if action == "set_schedule":
            if not scheduled_at:
                raise APIError("VALIDATION_ERROR", "scheduled_at parameter is required for scheduling.", 400)
            if item["state"] not in ["approved", "scheduled", "draft"]:
                raise APIError("INVALID_STATE_TRANSITION", f"Cannot schedule from: {item['state']}", 400)
            if item["generation_status"] != "done":
                raise APIError("GENERATION_NOT_READY", "Content must be generated before scheduling.", 400)
            conn.execute(
                "UPDATE queue SET state = 'scheduled', scheduled_at_utc = ?, updated_at = ? WHERE id = ?",
                (scheduled_at, now, queue_id),
            )
            conn.commit()
        elif action == "post_now":
            if item["generation_status"] != "done":
                raise APIError("GENERATION_NOT_READY", "Content must be generated before publishing.", 400)
        elif action in VALID_TRANSITIONS:
            rule = VALID_TRANSITIONS[action]
            if item["state"] not in rule["allowed_from"]:
                raise APIError("INVALID_STATE_TRANSITION", f"Action '{action}' is invalid from state '{item['state']}'", 400)
            if action == "approve" and item["generation_status"] != "done":
                raise APIError("GENERATION_NOT_READY", "Cannot approve an item with incomplete rewrite.", 400)
            conn.execute("UPDATE queue SET state = ?, updated_at = ? WHERE id = ?", (rule["target_state"], now, queue_id))
            conn.commit()
        else:
            raise APIError("VALIDATION_ERROR", f"Unsupported action option: {action}", 400)

    if action == "post_now":
        try:
            publish_queue_item_now(queue_id)
        except Exception as err:
            raise APIError("PUBLISH_FAILED", str(err), 400) from err

    with get_db_connection() as conn:
        updated = conn.execute("SELECT * FROM queue WHERE id = ?", (queue_id,)).fetchone()
    return api_success(dict(updated))


@queue_bp.route("/<int:id>/queue/<int:queue_id>", methods=["DELETE"])
@token_required
def delete_queue_item(id, queue_id):
    with get_db_connection() as conn:
        verify_workspace_owner(id, g.current_user["id"], conn)
        item = verify_queue_owner(id, queue_id, conn)
        if item["state"] not in ["cancelled", "failed"]:
            raise APIError("INVALID_STATE_TRANSITION", "Only items in 'cancelled' or 'failed' states can be deleted.", 400)
        conn.execute("DELETE FROM queue WHERE id = ?", (queue_id,))
        conn.commit()
    return api_success({"message": "Queue record removed."})


@queue_bp.route("/<int:id>/queue/<int:queue_id>/prompt", methods=["GET"])
@token_required
def get_queue_item_prompt(id, queue_id):
    with get_db_connection() as conn:
        verify_workspace_owner(id, g.current_user["id"], conn)
        item = verify_queue_owner(id, queue_id, conn)
        workspace = conn.execute("SELECT style_profile_id FROM workspaces WHERE id = ?", (id,)).fetchone()
        if not workspace["style_profile_id"]:
            raise APIError("VALIDATION_ERROR", "The workspace must have an assigned style profile to generate the prompt.", 400)
        profile = conn.execute("SELECT * FROM style_profiles WHERE id = ?", (workspace["style_profile_id"],)).fetchone()
        topics = conn.execute("SELECT summary_topic FROM posted_content WHERE workspace_id = ? ORDER BY id DESC LIMIT 10", (id,)).fetchall()
        recent_topics = [t["summary_topic"] for t in topics if t["summary_topic"]]
    system_prompt = build_system_prompt(dict(profile), dict(workspace), recent_topics)
    return api_success({"prompt": system_prompt, "raw_text": item["raw_source_text"]})


@queue_bp.route("/<int:id>/queue/<int:queue_id>/text", methods=["PATCH"])
@token_required
def save_manual_queue_text(id, queue_id):
    data = request.get_json() or {}
    text = data.get("generated_text", "").strip()
    if not text:
        raise APIError("VALIDATION_ERROR", "The generated_text field cannot be empty.", 400)
    now = get_current_utc_iso()
    with get_db_connection() as conn:
        verify_workspace_owner(id, g.current_user["id"], conn)
        verify_queue_owner(id, queue_id, conn)
        conn.execute(
            """UPDATE queue SET generated_text = ?, generation_status = 'done', failure_reason = NULL, updated_at = ?
               WHERE id = ?""",
            (text, now, queue_id),
        )
        conn.commit()
        updated = conn.execute("SELECT * FROM queue WHERE id = ?", (queue_id,)).fetchone()
    return api_success(dict(updated))


@queue_bp.route("/<int:id>/queue/<int:queue_id>/preview", methods=["POST"])
@token_required
def trigger_preview_dm(id, queue_id):
    with get_db_connection() as conn:
        verify_workspace_owner(id, g.current_user["id"], conn)
        item = verify_queue_owner(id, queue_id, conn)
    if item["generation_status"] != "done" or not item["generated_text"]:
        raise APIError("GENERATION_NOT_READY", "Cannot trigger a preview because the content rewrite is incomplete.", 400)
    send_post_preview(id, item["generated_text"])
    return api_success({"sent": True})

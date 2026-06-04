from flask import Blueprint, g, request

from app.api.utils import APIError, api_success, token_required, verify_queue_owner, verify_workspace_owner
from app.models.db import get_db_connection
from app.services.prompt_builder import build_system_prompt
from app.utils.timezone import get_current_utc_iso

queue_bp = Blueprint("queue", __name__)

VALID_TRANSITIONS = {
    "approve": {"allowed_from": ["draft"], "target_state": "approved"},
    "cancel": {"allowed_from": ["draft", "approved", "scheduled"], "target_state": "cancelled"},
    "requeue": {"allowed_from": ["failed", "cancelled"], "target_state": "draft"},
}


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
                workspace_id, scraped_post_id, raw_source_text, generated_text,
                generation_status, state, scheduled_at_utc, posted_at_utc,
                failure_reason, retry_count, created_at, updated_at
               ) VALUES (?, NULL, ?, NULL, 'pending', 'draft', NULL, NULL, NULL, 0, ?, ?)""",
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
            if item["state"] not in ["approved", "scheduled"]:
                raise APIError("INVALID_STATE_TRANSITION", f"Cannot schedule from: {item['state']}", 400)
            if item["generation_status"] != "done":
                raise APIError("GENERATION_NOT_READY", "Content must be generated before scheduling.", 400)
            conn.execute(
                "UPDATE queue SET state = 'scheduled', scheduled_at_utc = ?, updated_at = ? WHERE id = ?",
                (scheduled_at, now, queue_id),
            )
            conn.commit()
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
            """UPDATE queue SET generated_text = ?, generation_status = 'done', updated_at = ?
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
    return api_success({"sent": True})

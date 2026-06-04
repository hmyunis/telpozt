from flask import Blueprint, g, request

from app.api.utils import APIError, api_success, token_required, verify_workspace_owner
from app.models.db import get_db_connection

history_bp = Blueprint("history", __name__)


@history_bp.route("/<int:id>/history", methods=["GET"])
@token_required
def get_workspace_history(id):
    page = max(1, int(request.args.get("page", 1)))
    per_page = max(1, min(100, int(request.args.get("per_page", 20))))
    from_date = request.args.get("from_date", "").strip()
    to_date = request.args.get("to_date", "").strip()
    offset = (page - 1) * per_page
    with get_db_connection() as conn:
        verify_workspace_owner(id, g.current_user["id"], conn)
        query = "SELECT * FROM post_history WHERE workspace_id = ?"
        params = [id]
        if from_date:
            query += " AND posted_at_utc >= ?"
            params.append(from_date)
        if to_date:
            query += " AND posted_at_utc <= ?"
            params.append(to_date)
        query += " ORDER BY id DESC LIMIT ? OFFSET ?"
        params.extend([per_page, offset])
        rows = conn.execute(query, params).fetchall()
        count_query = "SELECT COUNT(*) as total FROM post_history WHERE workspace_id = ?"
        count_params = [id]
        if from_date:
            count_query += " AND posted_at_utc >= ?"
            count_params.append(from_date)
        if to_date:
            count_query += " AND posted_at_utc <= ?"
            count_params.append(to_date)
        total = conn.execute(count_query, count_params).fetchone()["total"]
    return api_success({"items": [dict(row) for row in rows], "meta": {"page": page, "per_page": per_page, "total_items": total, "total_pages": (total + per_page - 1) // per_page}})


@history_bp.route("/<int:id>/history/<int:history_id>", methods=["GET"])
@token_required
def get_history_detail(id, history_id):
    with get_db_connection() as conn:
        verify_workspace_owner(id, g.current_user["id"], conn)
        history = conn.execute("SELECT * FROM post_history WHERE id = ? AND workspace_id = ?", (history_id, id)).fetchone()
        if not history:
            raise APIError("NOT_FOUND", "No log record found matching that key.", 404)
        item = conn.execute("SELECT * FROM queue WHERE id = ?", (history["queue_id"],)).fetchone()
    res = dict(history)
    res["queue_detail"] = dict(item) if item else None
    return api_success(res)

from flask import Blueprint, g, request
from app.api.utils import APIError, api_success, token_required, verify_queue_owner, verify_workspace_owner
from app.models.db import get_db_connection

queue_bp = Blueprint("queue", __name__)

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
        
    return api_success({
        "items": [dict(row) for row in rows], 
        "meta": {"page": page, "per_page": per_page, "total_items": total, "total_pages": (total + per_page - 1) // per_page}
    })

@queue_bp.route("/<int:id>/queue/<int:queue_id>", methods=["DELETE"])
@token_required
def delete_queue_item(id, queue_id):
    with get_db_connection() as conn:
        verify_workspace_owner(id, g.current_user["id"], conn)
        verify_queue_owner(id, queue_id, conn)
        conn.execute("DELETE FROM queue WHERE id = ?", (queue_id,))
        conn.commit()
    return api_success({"deleted": True})

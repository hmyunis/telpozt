from flask import Blueprint, g, request
from app.api.utils import api_success, token_required, verify_workspace_owner
from app.models.db import get_db_connection

candidates_bp = Blueprint("candidates", __name__)

@candidates_bp.route("/<int:id>/candidates", methods=["GET"])
@token_required
def get_candidates(id):
    with get_db_connection() as conn:
        verify_workspace_owner(id, g.current_user["id"], conn)
        rows = conn.execute("""
            SELECT sp.id, sp.raw_text, sc.channel_id as source_channel, sp.original_posted_at_utc, sp.view_count
            FROM scraped_posts sp
            JOIN source_channels sc ON sp.source_channel_id = sc.id
            WHERE sc.workspace_id = ? AND sp.dedup_status = 'unique'
            ORDER BY sp.id DESC LIMIT 50
        """, (id,)).fetchall()
    return api_success([dict(r) for r in rows])

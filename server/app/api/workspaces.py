from flask import Blueprint, g, request
from app.api.utils import APIError, api_success, token_required, validate_telegram_bot_token, verify_source_owner, verify_workspace_owner
from app.models.db import get_db_connection
from app.utils.timezone import get_current_utc_iso
from app.utils.validators import validate_channel_priority
from app.services.cron import _scrape_channels
from app.services.prompt_builder import build_system_prompt

workspaces_bp = Blueprint("workspaces", __name__)

@workspaces_bp.route("", methods=["GET"])
@token_required
def list_workspaces():
    with get_db_connection() as conn:
        rows = conn.execute("SELECT * FROM workspaces WHERE user_id = ?", (g.current_user["id"],)).fetchall()
    return api_success([dict(row) for row in rows])

@workspaces_bp.route("", methods=["POST"])
@token_required
def create_workspace():
    data = request.get_json() or {}
    name, target_channel, bot_token = data.get("name", "").strip(), data.get("target_channel_id", "").strip(), data.get("bot_token", "").strip()
    if not all([name, target_channel, bot_token]):
        raise APIError("VALIDATION_ERROR", "Name, target channel, and bot token are required.", 400)
    
    if not validate_telegram_bot_token(bot_token):
        raise APIError("BOT_TOKEN_INVALID", "Invalid Telegram Bot Token.", 400)

    now = get_current_utc_iso()
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            "INSERT INTO workspaces (user_id, name, target_channel_id, bot_token, style_profile_id, is_active, created_at, updated_at) VALUES (?, ?, ?, ?, ?, 1, ?, ?)",
            (g.current_user["id"], name, target_channel, bot_token, data.get("style_profile_id"), now, now)
        )
        conn.commit()
        saved = conn.execute("SELECT * FROM workspaces WHERE id = ?", (cursor.lastrowid,)).fetchone()
    return api_success(dict(saved), 201)

@workspaces_bp.route("/<int:id>", methods=["PUT", "GET", "DELETE"])
@token_required
def manage_workspace(id):
    with get_db_connection() as conn:
        workspace = verify_workspace_owner(id, g.current_user["id"], conn)
        
        if request.method == "GET":
            return api_success(workspace)
            
        elif request.method == "DELETE":
            conn.execute("DELETE FROM workspaces WHERE id = ?", (id,))
            conn.commit()
            return api_success({"deleted": True})
            
        elif request.method == "PUT":
            data = request.get_json() or {}
            updates, params = [], []
            for field in ["name", "target_channel_id", "bot_token", "style_profile_id", "is_active"]:
                if field in data:
                    updates.append(f"{field} = ?")
                    params.append(data[field])
            
            if updates:
                params.extend([get_current_utc_iso(), id])
                conn.execute(f"UPDATE workspaces SET {', '.join(updates)}, updated_at = ? WHERE id = ?", params)
                conn.commit()
            return api_success(dict(conn.execute("SELECT * FROM workspaces WHERE id = ?", (id,)).fetchone()))

@workspaces_bp.route("/<int:id>/source-channels", methods=["GET", "POST"])
@token_required
def manage_source_channels(id):
    with get_db_connection() as conn:
        verify_workspace_owner(id, g.current_user["id"], conn)
        if request.method == "GET":
            rows = conn.execute("SELECT * FROM source_channels WHERE workspace_id = ? ORDER BY id DESC", (id,)).fetchall()
            return api_success([dict(row) for row in rows])
        
        data = request.get_json() or {}
        channel_id, priority = data.get("channel_id", "").strip(), data.get("priority", "normal").strip()
        validate_channel_priority(priority)
        
        cursor = conn.cursor()
        cursor.execute(
            "INSERT INTO source_channels (workspace_id, channel_id, display_name, priority, is_active, created_at) VALUES (?, ?, ?, ?, 1, ?)",
            (id, channel_id, data.get("display_name"), priority, get_current_utc_iso())
        )
        conn.commit()
        return api_success(dict(conn.execute("SELECT * FROM source_channels WHERE id = ?", (cursor.lastrowid,)).fetchone()), 201)

@workspaces_bp.route("/<int:id>/source-channels/<int:source_id>", methods=["PUT", "DELETE"])
@token_required
def manage_single_source_channel(id, source_id):
    with get_db_connection() as conn:
        verify_workspace_owner(id, g.current_user["id"], conn)
        verify_source_owner(id, source_id, conn)
        
        if request.method == "DELETE":
            conn.execute("DELETE FROM source_channels WHERE id = ?", (source_id,))
            conn.commit()
            return api_success({"deleted": True})
            
        data = request.get_json() or {}
        updates, params = [], []
        for field in ["channel_id", "display_name", "priority", "is_active"]:
            if field in data:
                if field == "priority": validate_channel_priority(data[field])
                updates.append(f"{field} = ?")
                params.append(data[field])
                
        if updates:
            params.append(source_id)
            conn.execute(f"UPDATE source_channels SET {', '.join(updates)} WHERE id = ?", params)
            conn.commit()
        return api_success(dict(conn.execute("SELECT * FROM source_channels WHERE id = ?", (source_id,)).fetchone()))

@workspaces_bp.route("/<int:id>/scrape", methods=["POST"])
@token_required
def trigger_workspace_scrape(id):
    _scrape_channels()
    return api_success({"message": "Manual scrape triggered successfully."})

@workspaces_bp.route("/<int:id>/prompt", methods=["POST"])
@token_required
def generate_mega_prompt(id):
    data = request.get_json() or {}
    post_ids = data.get("post_ids", [])
    
    if not post_ids:
        raise APIError("VALIDATION_ERROR", "post_ids list cannot be empty.", 400)

    with get_db_connection() as conn:
        ws = verify_workspace_owner(id, g.current_user["id"], conn)
        if not ws.get("style_profile_id"):
            raise APIError("VALIDATION_ERROR", "Workspace must have a style profile assigned to generate prompts.", 400)
            
        profile = conn.execute("SELECT * FROM style_profiles WHERE id = ?", (ws["style_profile_id"],)).fetchone()
        
        placeholders = ",".join("?" for _ in post_ids)
        posts = conn.execute(f"SELECT raw_text FROM scraped_posts WHERE id IN ({placeholders})", post_ids).fetchall()
        
        topics = conn.execute("SELECT summary_topic FROM posted_content WHERE workspace_id = ? ORDER BY id DESC LIMIT 10", (id,)).fetchall()
        recent_topics = [t["summary_topic"] for t in topics if t["summary_topic"]]
        
    system_rules = build_system_prompt(dict(profile), dict(ws), recent_topics)
    
    sources_text = "\n\n".join([f"--- Source {i+1} ---\n{p['raw_text']}" for i, p in enumerate(posts)])
    
    mega_prompt = f"{system_rules}\n\nCombine the following sources into a single, cohesive post according to the rules above:\n\n{sources_text}"
    
    return api_success({"prompt": mega_prompt})

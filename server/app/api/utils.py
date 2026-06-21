from functools import wraps
import requests
from flask import g, jsonify, request
from app.models.db import get_db_connection
from app.utils.telegram_auth import validate_webapp_data
from app.config import Config
from app.utils.timezone import get_current_utc_iso

class APIError(Exception):
    def __init__(self, code, message, status_code=400):
        super().__init__(message)
        self.code = code
        self.message = message
        self.status_code = status_code

def api_success(data=None, status_code=200):
    return jsonify({"success": True, "data": data if data is not None else {}, "error": None}), status_code

def validate_telegram_bot_token(token: str) -> bool:
    try:
        url = f"https://api.telegram.org/bot{token}/getMe"
        return requests.get(url, timeout=5).json().get("ok", False)
    except Exception:
        return False

def token_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        auth_header = request.headers.get("Authorization")
        if not auth_header or not auth_header.startswith("tma "):
            raise APIError("UNAUTHORIZED", "Telegram Web App initData missing.", 401)

        init_data = auth_header.split(" ", 1)[1]
        tg_user = validate_webapp_data(init_data)
        
        if not tg_user or str(tg_user.get("id")) != str(Config.ADMIN_TELEGRAM_CHAT_ID):
            raise APIError("UNAUTHORIZED", "Invalid or unauthorized Telegram user.", 401)

        with get_db_connection() as conn:
            user = conn.execute("SELECT * FROM users WHERE telegram_chat_id = ?", (str(tg_user["id"]),)).fetchone()
            if not user:
                # Auto-create admin on first login
                conn.execute(
                    "INSERT INTO users (username, password_hash, telegram_chat_id, timezone, created_at) VALUES (?, ?, ?, ?, ?)",
                    (tg_user.get("username", "admin"), "disabled", str(tg_user["id"]), "UTC", get_current_utc_iso())
                )
                conn.commit()
                user = conn.execute("SELECT * FROM users WHERE telegram_chat_id = ?", (str(tg_user["id"]),)).fetchone()

        g.current_user = dict(user)
        return f(*args, **kwargs)
    return decorated

def verify_workspace_owner(workspace_id: int, user_id: int, conn) -> dict:
    row = conn.execute("SELECT * FROM workspaces WHERE id = ? AND user_id = ?", (workspace_id, user_id)).fetchone()
    if not row: raise APIError("NOT_FOUND", "Workspace not found.", 404)
    return dict(row)

def verify_profile_owner(profile_id: int, user_id: int, conn) -> dict:
    row = conn.execute("SELECT * FROM style_profiles WHERE id = ? AND user_id = ?", (profile_id, user_id)).fetchone()
    if not row: raise APIError("NOT_FOUND", "Style profile not found.", 404)
    return dict(row)

def verify_source_owner(workspace_id: int, source_id: int, conn) -> dict:
    row = conn.execute("SELECT * FROM source_channels WHERE id = ? AND workspace_id = ?", (source_id, workspace_id)).fetchone()
    if not row: raise APIError("NOT_FOUND", "Source channel not found.", 404)
    return dict(row)

def verify_queue_owner(workspace_id: int, queue_id: int, conn) -> dict:
    row = conn.execute("SELECT * FROM queue WHERE id = ? AND workspace_id = ?", (queue_id, workspace_id)).fetchone()
    if not row: raise APIError("NOT_FOUND", "Queue item not found.", 404)
    return dict(row)

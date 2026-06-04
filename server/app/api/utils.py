from functools import wraps

import requests
from flask import g, jsonify, request

from app.models.db import get_db_connection
from app.utils.jwt import decode_token


class APIError(Exception):
    def __init__(self, code, message, status_code=400):
        super().__init__(message)
        self.code = code
        self.message = message
        self.status_code = status_code


def api_success(data=None, status_code=200):
    return jsonify({
        "success": True,
        "data": data if data is not None else {},
        "error": None,
    }), status_code


def validate_telegram_bot_token(token: str) -> bool:
    try:
        url = f"https://api.telegram.org/bot{token}/getMe"
        response = requests.get(url, timeout=5)
        if response.status_code == 200:
            data = response.json()
            return data.get("ok", False)
    except Exception:
        pass
    return False


def token_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        auth_header = request.headers.get("Authorization")
        if not auth_header or not auth_header.startswith("Bearer "):
            raise APIError("UNAUTHORIZED", "Bearer token is missing or malformed.", 401)

        token = auth_header.split(" ")[1]
        try:
            user_id = decode_token(token)
        except Exception as err:
            raise APIError("TOKEN_EXPIRED", f"Session expired or token signature invalid: {str(err)}", 401)

        with get_db_connection() as conn:
            user = conn.execute(
                "SELECT id, username, telegram_chat_id, timezone FROM users WHERE id = ?",
                (user_id,),
            ).fetchone()
            if not user:
                raise APIError("NOT_FOUND", "User profile matching token not found.", 404)

        g.current_user = dict(user)
        return f(*args, **kwargs)

    return decorated


def verify_workspace_owner(workspace_id: int, user_id: int, conn) -> dict:
    row = conn.execute(
        "SELECT * FROM workspaces WHERE id = ? AND user_id = ?",
        (workspace_id, user_id),
    ).fetchone()
    if not row:
        raise APIError("NOT_FOUND", "Workspace not found or unauthorized access.", 404)
    return dict(row)


def verify_profile_owner(profile_id: int, user_id: int, conn) -> dict:
    row = conn.execute(
        "SELECT * FROM style_profiles WHERE id = ? AND user_id = ?",
        (profile_id, user_id),
    ).fetchone()
    if not row:
        raise APIError("NOT_FOUND", "Style profile not found or unauthorized access.", 404)
    return dict(row)


def verify_source_owner(workspace_id: int, source_id: int, conn) -> dict:
    row = conn.execute(
        "SELECT * FROM source_channels WHERE id = ? AND workspace_id = ?",
        (source_id, workspace_id),
    ).fetchone()
    if not row:
        raise APIError("NOT_FOUND", "Source channel link not found in workspace context.", 404)
    return dict(row)


def verify_queue_owner(workspace_id: int, queue_id: int, conn) -> dict:
    row = conn.execute(
        "SELECT * FROM queue WHERE id = ? AND workspace_id = ?",
        (queue_id, workspace_id),
    ).fetchone()
    if not row:
        raise APIError("NOT_FOUND", "Queue item not found in workspace context.", 404)
    return dict(row)

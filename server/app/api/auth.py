from flask import Blueprint, g, request

from app.api import limiter
from app.api.utils import APIError, api_success, token_required
from app.models.db import get_db_connection
from app.utils.jwt import check_password, generate_token, hash_password
from app.utils.timezone import get_current_utc_iso
from app.utils.validators import validate_user_input

auth_bp = Blueprint("auth", __name__)


@auth_bp.route("/login", methods=["POST"])
@limiter.limit("100 per hour")
def login():
    data = request.get_json() or {}
    username = data.get("username", "").strip()
    password = data.get("password", "")
    if not username or not password:
        raise APIError("INVALID_CREDENTIALS", "Missing username or password fields.", 400)
    with get_db_connection() as conn:
        user = conn.execute(
            "SELECT id, username, password_hash, telegram_chat_id, timezone FROM users WHERE username = ?",
            (username,),
        ).fetchone()
    if not user or not check_password(password, user["password_hash"]):
        raise APIError("INVALID_CREDENTIALS", "The credentials provided are invalid.", 401)
    token = generate_token(user["id"])
    return api_success({
        "token": token,
        "user": {
            "id": user["id"],
            "username": user["username"],
            "timezone": user["timezone"],
            "telegram_chat_id": user["telegram_chat_id"],
        },
    })


@auth_bp.route("/logout", methods=["POST"])
@token_required
def logout():
    return api_success({"message": "Session logged out on mobile side."})


@auth_bp.route("/change-password", methods=["POST"])
@token_required
def change_password():
    data = request.get_json() or {}
    curr_pwd = data.get("current_password", "")
    new_pwd = data.get("new_password", "")
    if not curr_pwd or not new_pwd:
        raise APIError("VALIDATION_ERROR", "Current and new password keys are required.", 400)
    if len(new_pwd) < 8:
        raise APIError("VALIDATION_ERROR", "New password must be at least 8 characters long.", 400)
    with get_db_connection() as conn:
        user_pwd = conn.execute(
            "SELECT password_hash FROM users WHERE id = ?",
            (g.current_user["id"],),
        ).fetchone()
        if not check_password(curr_pwd, user_pwd["password_hash"]):
            raise APIError("INVALID_CREDENTIALS", "The current password provided is incorrect.", 401)
        conn.execute(
            "UPDATE users SET password_hash = ? WHERE id = ?",
            (hash_password(new_pwd), g.current_user["id"]),
        )
        conn.commit()
    return api_success({"message": "Password changed successfully."})


@auth_bp.route("/register-admin", methods=["POST"])
def register_admin():
    data = request.get_json() or {}
    validate_user_input(data, is_new=True)
    with get_db_connection() as conn:
        exists = conn.execute("SELECT id FROM users LIMIT 1").fetchone()
        if exists:
            raise APIError("FORBIDDEN", "An admin user has already been registered in this database.", 403)
        cursor = conn.cursor()
        cursor.execute(
            """INSERT INTO users (username, password_hash, telegram_chat_id, timezone, created_at)
               VALUES (?, ?, ?, ?, ?)""",
            (
                data["username"],
                hash_password(data["password"]),
                data["telegram_chat_id"],
                data.get("timezone", "UTC"),
                get_current_utc_iso(),
            ),
        )
        conn.commit()
        user_id = cursor.lastrowid
    return api_success({"message": "Admin profile created successfully.", "user_id": user_id}, 201)

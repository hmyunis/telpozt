from flask import Blueprint, g, request

from app.api.utils import (
    APIError, api_success, token_required, validate_telegram_bot_token,
    verify_source_owner, verify_workspace_owner,
)
from app.models.db import get_db_connection
from app.utils.timezone import convert_local_slots_to_utc, convert_utc_slots_to_local, get_current_utc_iso
from app.utils.validators import validate_channel_priority

workspaces_bp = Blueprint("workspaces", __name__)


@workspaces_bp.route("", methods=["GET"])
@token_required
def list_workspaces():
    with get_db_connection() as conn:
        rows = conn.execute(
            """SELECT id, name, target_channel_id, is_active, style_profile_id, created_at, updated_at
               FROM workspaces WHERE user_id = ?""",
            (g.current_user["id"],),
        ).fetchall()
    return api_success([dict(row) for row in rows])


@workspaces_bp.route("", methods=["POST"])
@token_required
def create_workspace():
    data = request.get_json() or {}
    name = data.get("name", "").strip()
    target_channel = data.get("target_channel_id", "").strip()
    bot_token = data.get("bot_token", "").strip()
    style_profile_id = data.get("style_profile_id")
    if not name or not target_channel or not bot_token:
        raise APIError("VALIDATION_ERROR", "Name, target_channel_id, and bot_token fields are required.", 400)
    if not validate_telegram_bot_token(bot_token):
        raise APIError("BOT_TOKEN_INVALID", "Validation fails to verify the token with Telegram.", 400)
    now = get_current_utc_iso()
    with get_db_connection() as conn:
        if style_profile_id:
            row = conn.execute(
                "SELECT id FROM style_profiles WHERE id = ? AND user_id = ?",
                (style_profile_id, g.current_user["id"]),
            ).fetchone()
            if not row:
                raise APIError("NOT_FOUND", "Style profile not found or unauthorized access.", 404)
        cursor = conn.cursor()
        cursor.execute(
            """INSERT INTO workspaces (user_id, name, target_channel_id, bot_token, style_profile_id, is_active, created_at, updated_at)
               VALUES (?, ?, ?, ?, ?, 1, ?, ?)""",
            (g.current_user["id"], name, target_channel, bot_token, style_profile_id, now, now),
        )
        workspace_id = cursor.lastrowid
        cursor.execute(
            """INSERT INTO schedule_config (workspace_id, time_slots, timezone, is_enabled, updated_at)
               VALUES (?, '[]', ?, 1, ?)""",
            (workspace_id, g.current_user["timezone"], now),
        )
        conn.commit()
        saved = conn.execute("SELECT * FROM workspaces WHERE id = ?", (workspace_id,)).fetchone()
    return api_success(dict(saved), 201)


@workspaces_bp.route("/<int:id>", methods=["GET"])
@token_required
def get_workspace(id):
    with get_db_connection() as conn:
        workspace = verify_workspace_owner(id, g.current_user["id"], conn)
    return api_success(workspace)


@workspaces_bp.route("/<int:id>", methods=["PUT"])
@token_required
def update_workspace(id):
    data = request.get_json() or {}
    now = get_current_utc_iso()
    with get_db_connection() as conn:
        verify_workspace_owner(id, g.current_user["id"], conn)
        updates = []
        params = []
        for field in ["name", "target_channel_id", "bot_token", "style_profile_id", "is_active"]:
            if field in data:
                updates.append(f"{field} = ?")
                params.append(data[field])
        if not updates:
            raise APIError("VALIDATION_ERROR", "No supported fields supplied for update.", 400)
        params.extend([now, id])
        conn.execute(f"UPDATE workspaces SET {', '.join(updates)}, updated_at = ? WHERE id = ?", params)
        conn.commit()
        updated = conn.execute("SELECT * FROM workspaces WHERE id = ?", (id,)).fetchone()
    return api_success(dict(updated))


@workspaces_bp.route("/<int:id>/source-channels", methods=["GET"])
@token_required
def list_source_channels(id):
    with get_db_connection() as conn:
        verify_workspace_owner(id, g.current_user["id"], conn)
        rows = conn.execute("SELECT * FROM source_channels WHERE workspace_id = ? ORDER BY id DESC", (id,)).fetchall()
    return api_success([dict(row) for row in rows])


@workspaces_bp.route("/<int:id>/source-channels", methods=["POST"])
@token_required
def create_source_channel(id):
    data = request.get_json() or {}
    channel_id = data.get("channel_id", "").strip()
    priority = data.get("priority", "normal").strip()
    if not channel_id:
        raise APIError("VALIDATION_ERROR", "channel_id is required.", 400)
    validate_channel_priority(priority)
    with get_db_connection() as conn:
        verify_workspace_owner(id, g.current_user["id"], conn)
        cursor = conn.cursor()
        cursor.execute(
            """INSERT INTO source_channels (workspace_id, channel_id, display_name, priority, is_active, created_at)
               VALUES (?, ?, ?, ?, 1, ?)""",
            (id, channel_id, data.get("display_name"), priority, get_current_utc_iso()),
        )
        conn.commit()
        row = conn.execute("SELECT * FROM source_channels WHERE id = ?", (cursor.lastrowid,)).fetchone()
    return api_success(dict(row), 201)


@workspaces_bp.route("/<int:id>/source-channels/<int:source_id>", methods=["PUT"])
@token_required
def update_source_channel(id, source_id):
    data = request.get_json() or {}
    with get_db_connection() as conn:
        verify_workspace_owner(id, g.current_user["id"], conn)
        verify_source_owner(id, source_id, conn)
        updates = []
        params = []
        for field in ["channel_id", "display_name", "priority", "is_active"]:
            if field in data:
                if field == "priority":
                    validate_channel_priority(data[field])
                updates.append(f"{field} = ?")
                params.append(data[field])
        if not updates:
            raise APIError("VALIDATION_ERROR", "No supported fields supplied for update.", 400)
        params.append(source_id)
        conn.execute(f"UPDATE source_channels SET {', '.join(updates)} WHERE id = ?", params)
        conn.commit()
        row = conn.execute("SELECT * FROM source_channels WHERE id = ?", (source_id,)).fetchone()
    return api_success(dict(row))


@workspaces_bp.route("/<int:id>/source-channels/<int:source_id>", methods=["DELETE"])
@token_required
def delete_source_channel(id, source_id):
    with get_db_connection() as conn:
        verify_workspace_owner(id, g.current_user["id"], conn)
        verify_source_owner(id, source_id, conn)
        conn.execute("DELETE FROM source_channels WHERE id = ?", (source_id,))
        conn.commit()
    return api_success({"message": "Source channel removed."})


@workspaces_bp.route("/<int:id>/schedule", methods=["GET"])
@token_required
def get_workspace_schedule(id):
    with get_db_connection() as conn:
        verify_workspace_owner(id, g.current_user["id"], conn)
        config = conn.execute("SELECT * FROM schedule_config WHERE workspace_id = ?", (id,)).fetchone()
    local_slots = convert_utc_slots_to_local(config["time_slots"], g.current_user["timezone"])
    return api_success({
        "workspace_id": id,
        "is_enabled": bool(config["is_enabled"]),
        "timezone": g.current_user["timezone"],
        "time_slots": local_slots,
    })


@workspaces_bp.route("/<int:id>/schedule", methods=["PUT"])
@token_required
def update_workspace_schedule(id):
    data = request.get_json() or {}
    time_slots = data.get("time_slots", [])
    is_enabled = int(data.get("is_enabled", True))
    if not isinstance(time_slots, list):
        raise APIError("VALIDATION_ERROR", "time_slots field must be configured as an array.", 400)
    utc_slots_json = convert_local_slots_to_utc(time_slots, g.current_user["timezone"])
    now = get_current_utc_iso()
    with get_db_connection() as conn:
        verify_workspace_owner(id, g.current_user["id"], conn)
        conn.execute(
            """UPDATE schedule_config SET time_slots = ?, timezone = ?, is_enabled = ?, updated_at = ?
               WHERE workspace_id = ?""",
            (utc_slots_json, g.current_user["timezone"], is_enabled, now, id),
        )
        conn.commit()
    return api_success({"message": "Workspace schedule configuration synchronized.", "time_slots": time_slots, "is_enabled": bool(is_enabled)})

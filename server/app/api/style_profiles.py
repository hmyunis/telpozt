from flask import Blueprint, g, request

from app.api.utils import APIError, api_success, token_required, verify_profile_owner
from app.models.db import get_db_connection
from app.utils.timezone import get_current_utc_iso
from app.utils.validators import validate_style_profile

style_profiles_bp = Blueprint("style_profiles", __name__)


@style_profiles_bp.route("", methods=["GET"])
@token_required
def list_profiles():
    with get_db_connection() as conn:
        rows = conn.execute("SELECT * FROM style_profiles WHERE user_id = ?", (g.current_user["id"],)).fetchall()
    return api_success([dict(row) for row in rows])


@style_profiles_bp.route("", methods=["POST"])
@token_required
def create_profile():
    data = request.get_json() or {}
    validate_style_profile(data)
    now = get_current_utc_iso()
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            """INSERT INTO style_profiles (
                user_id, name, entity_name, entity_type, tone, structure, length_preset,
                char_min, char_max, emoji_usage, jargon_handling, call_to_action,
                hashtag_style, additional_instructions, created_at, updated_at
               ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (
                g.current_user["id"], data["name"], data.get("entity_name"), data.get("entity_type"),
                data["tone"], data["structure"], data["length_preset"], data.get("char_min"),
                data.get("char_max"), data["emoji_usage"], data["jargon_handling"], data["call_to_action"],
                data["hashtag_style"], data.get("additional_instructions"), now, now,
            ),
        )
        conn.commit()
        profile_id = cursor.lastrowid
        profile = conn.execute("SELECT * FROM style_profiles WHERE id = ?", (profile_id,)).fetchone()
    return api_success(dict(profile), 201)


@style_profiles_bp.route("/<int:id>", methods=["GET"])
@token_required
def get_profile(id):
    with get_db_connection() as conn:
        profile = verify_profile_owner(id, g.current_user["id"], conn)
    return api_success(profile)


@style_profiles_bp.route("/<int:id>", methods=["PUT"])
@token_required
def update_profile(id):
    data = request.get_json() or {}
    validate_style_profile(data)
    now = get_current_utc_iso()
    with get_db_connection() as conn:
        verify_profile_owner(id, g.current_user["id"], conn)
        conn.execute(
            """UPDATE style_profiles SET
                name = ?, entity_name = ?, entity_type = ?, tone = ?, structure = ?,
                length_preset = ?, char_min = ?, char_max = ?, emoji_usage = ?,
                jargon_handling = ?, call_to_action = ?, hashtag_style = ?,
                additional_instructions = ?, updated_at = ?
               WHERE id = ?""",
            (
                data["name"], data.get("entity_name"), data.get("entity_type"), data["tone"],
                data["structure"], data["length_preset"], data.get("char_min"), data.get("char_max"),
                data["emoji_usage"], data["jargon_handling"], data["call_to_action"], data["hashtag_style"],
                data.get("additional_instructions"), now, id,
            ),
        )
        conn.commit()
        updated = conn.execute("SELECT * FROM style_profiles WHERE id = ?", (id,)).fetchone()
    return api_success(dict(updated))


@style_profiles_bp.route("/<int:id>", methods=["DELETE"])
@token_required
def delete_profile(id):
    with get_db_connection() as conn:
        verify_profile_owner(id, g.current_user["id"], conn)
        in_use = conn.execute("SELECT id, name FROM workspaces WHERE style_profile_id = ? LIMIT 1", (id,)).fetchone()
        if in_use:
            raise APIError("PROFILE_IN_USE", f"Cannot delete profile because it is assigned to workspace: {in_use['name']}", 400)
        conn.execute("DELETE FROM style_profiles WHERE id = ?", (id,))
        conn.commit()
    return api_success({"message": "Style profile successfully deleted."})

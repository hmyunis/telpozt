from flask import Blueprint, g, request

from app.api.utils import APIError, api_success, token_required
from app.models.db import get_db_connection
from app.utils.validators import validate_user_input

users_bp = Blueprint("users", __name__)


@users_bp.route("/me", methods=["GET"])
@token_required
def get_me():
    return api_success(g.current_user)


@users_bp.route("/me", methods=["PATCH"])
@token_required
def update_me():
    data = request.get_json() or {}
    validate_user_input(data, is_new=False)
    if "timezone" not in data:
        raise APIError("VALIDATION_ERROR", "Only modifications to timezone are permitted through patch.", 400)
    with get_db_connection() as conn:
        conn.execute(
            "UPDATE users SET timezone = ? WHERE id = ?",
            (data["timezone"], g.current_user["id"]),
        )
        conn.commit()
    g.current_user["timezone"] = data["timezone"]
    return api_success(g.current_user)

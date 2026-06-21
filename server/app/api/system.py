from flask import Blueprint
from app.api.utils import api_success

system_bp = Blueprint("system", __name__)

@system_bp.route("/health", methods=["GET"])
def health():
    return api_success({
        "status": "ok",
        "message": "Telpozt Backend is running and ready for Telegram Mini App."
    })

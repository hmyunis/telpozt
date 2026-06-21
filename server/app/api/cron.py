from flask import Blueprint, jsonify, request
from app.config import Config
from app.services.cron import run_all_cron_jobs

cron_bp = Blueprint("cron", __name__)

@cron_bp.route("/run", methods=["POST", "GET"])
def trigger_cron():
    key = request.args.get("key")
    if key != Config.CRON_SECRET_KEY:
        return jsonify({"error": "Unauthorized"}), 401
        
    try:
        run_all_cron_jobs()
        return jsonify({"success": True, "message": "Cron jobs executed successfully."})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

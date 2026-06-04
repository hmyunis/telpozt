import logging

import requests
from flask import Blueprint, jsonify, request

from app.api import limiter
from app.models.db import get_db_connection

webhook_bp = Blueprint("webhook", __name__)
logger = logging.getLogger(__name__)


@webhook_bp.route("/telegram", methods=["POST"])
@limiter.exempt
def telegram_bot_webhook():
    payload = request.get_json() or {}
    if "callback_query" in payload:
        callback = payload["callback_query"]
        data = callback.get("data", "")
        chat_id = callback["message"]["chat"]["id"]
        message_id = callback["message"]["message_id"]
        if data.startswith("review_approve_") or data.startswith("review_reject_"):
            parts = data.split("_")
            action = parts[1]
            scraped_post_id = int(parts[2])
            status_map = {"approve": "unique", "reject": "duplicate"}
            new_status = status_map[action]
            with get_db_connection() as conn:
                post = conn.execute(
                    """SELECT s.id, sc.workspace_id, w.bot_token 
                       FROM scraped_posts s
                       JOIN source_channels sc ON s.source_channel_id = sc.id
                       JOIN workspaces w ON sc.workspace_id = w.id
                       WHERE s.id = ?""",
                    (scraped_post_id,),
                ).fetchone()
                if post:
                    conn.execute("UPDATE scraped_posts SET dedup_status = ? WHERE id = ?", (new_status, scraped_post_id))
                    conn.commit()
                    response_text = f"✅ Decided: Post has been marked as <b>{new_status.upper()}</b>."
                    url = f"https://api.telegram.org/bot{post['bot_token']}/editMessageText"
                    edit_payload = {
                        "chat_id": chat_id,
                        "message_id": message_id,
                        "text": response_text,
                        "parse_mode": "HTML",
                    }
                    try:
                        requests.post(url, json=edit_payload, timeout=5)
                    except Exception as e:
                        logger.error(f"Failed to edit webhook source message: {e}")
            return jsonify({"ok": True})
    return jsonify({"ok": True})

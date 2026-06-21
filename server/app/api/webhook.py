import logging
from flask import Blueprint, jsonify, request
from app.api import limiter
from app.models.db import get_db_connection
from app.services.telegram_bot import send_telegram_message
from app.utils.timezone import get_current_utc_iso

webhook_bp = Blueprint("webhook", __name__)
logger = logging.getLogger(__name__)

def _get_keyboard(queue_id: int):
    return {
        "inline_keyboard": [
            [{"text": "🚀 Post Now", "callback_data": f"post_now:{queue_id}"},
             {"text": "📅 Schedule", "callback_data": f"schedule:{queue_id}"}],
            [{"text": "🗑️ Discard", "callback_data": f"discard:{queue_id}"}]
        ]
    }

@webhook_bp.route("/telegram", methods=["POST"])
@limiter.exempt
def telegram_webhook():
    payload = request.get_json() or {}
    now = get_current_utc_iso()

    try:
        # Handle pasted text (New Draft)
        if "message" in payload and "text" in payload["message"]:
            text = payload["message"]["text"]
            chat_id = str(payload["message"]["chat"]["id"])
            
            with get_db_connection() as conn:
                user = conn.execute("SELECT id FROM users WHERE telegram_chat_id = ?", (chat_id,)).fetchone()
                if not user: return jsonify({"ok": True})
                
                ws = conn.execute("SELECT id, bot_token FROM workspaces WHERE user_id = ? AND is_active = 1 LIMIT 1", (user["id"],)).fetchone()
                if not ws:
                    send_telegram_message(payload["message"]["bot_token"], chat_id, "❌ No active workspaces found.")
                    return jsonify({"ok": True})
                
                cursor = conn.execute(
                    """INSERT INTO queue (workspace_id, raw_source_text, generated_text, generation_status, state, created_at, updated_at) 
                       VALUES (?, ?, ?, 'done', 'draft', ?, ?)""",
                    (ws["id"], text, text, now, now)
                )
                conn.commit()
                queue_id = cursor.lastrowid
                
                send_telegram_message(
                    ws["bot_token"], 
                    chat_id, 
                    f"📝 **Draft Saved**\n\n{text[:150]}...\n\nWhat should I do with this?", 
                    reply_markup=_get_keyboard(queue_id)
                )

        # Handle button clicks
        elif "callback_query" in payload:
            cb = payload["callback_query"]
            data = cb.get("data", "")
            chat_id = cb["message"]["chat"]["id"]
            msg_id = cb["message"]["message_id"]
            
            if ":" in data:
                action, q_id = data.split(":")
                with get_db_connection() as conn:
                    item = conn.execute("SELECT q.*, w.bot_token, w.target_channel_id FROM queue q JOIN workspaces w ON q.workspace_id = w.id WHERE q.id = ?", (q_id,)).fetchone()
                    
                    if not item: return jsonify({"ok": True})
                    
                    import requests
                    url = f"https://api.telegram.org/bot{item['bot_token']}/editMessageText"
                    
                    if action == "post_now":
                        send_telegram_message(item["bot_token"], item["target_channel_id"], item["generated_text"])
                        conn.execute("UPDATE queue SET state = 'posted', posted_at_utc = ?, updated_at = ? WHERE id = ?", (now, now, q_id))
                        requests.post(url, json={"chat_id": chat_id, "message_id": msg_id, "text": "✅ Published immediately."})
                    
                    elif action == "schedule":
                        # Simplistic scheduling: just schedule for tomorrow for this spec, frontend/bot can be expanded later
                        from datetime import datetime, timedelta
                        sched_time = (datetime.utcnow() + timedelta(hours=1)).isoformat() + "Z"
                        conn.execute("UPDATE queue SET state = 'scheduled', scheduled_at_utc = ?, updated_at = ? WHERE id = ?", (sched_time, now, q_id))
                        requests.post(url, json={"chat_id": chat_id, "message_id": msg_id, "text": f"⏳ Scheduled for {sched_time}."})
                    
                    elif action == "discard":
                        conn.execute("DELETE FROM queue WHERE id = ?", (q_id,))
                        requests.post(url, json={"chat_id": chat_id, "message_id": msg_id, "text": "🗑️ Draft discarded."})
                        
                    conn.commit()

    except Exception as e:
        logger.error(f"Webhook error: {e}")
        
    return jsonify({"ok": True})

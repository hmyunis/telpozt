import logging

import requests

from app.config import Config

logger = logging.getLogger(__name__)


def send_telegram_message(bot_token: str, chat_id: str, text: str, reply_markup: dict = None) -> dict:
    url = f"https://api.telegram.org/bot{bot_token}/sendMessage"
    payload = {
        "chat_id": chat_id,
        "text": text,
        "parse_mode": "HTML",
        "disable_web_page_preview": True,
    }
    if reply_markup:
        payload["reply_markup"] = reply_markup
    try:
        response = requests.post(url, json=payload, timeout=10)
        response.raise_for_status()
        return response.json()
    except Exception as e:
        logger.error(f"Telegram API delivery failure: {e}")
        raise


def send_admin_notification(text: str):
    if not Config.TELEGRAM_BOT_TOKEN or not Config.ADMIN_TELEGRAM_CHAT_ID:
        return
    try:
        send_telegram_message(Config.TELEGRAM_BOT_TOKEN, Config.ADMIN_TELEGRAM_CHAT_ID, text)
    except Exception as e:
        logger.error(f"Failed to deliver admin update: {e}")


def send_post_preview(workspace_id: int, text: str):
    from app.models.db import get_db_connection

    with get_db_connection() as conn:
        ws = conn.execute("SELECT bot_token FROM workspaces WHERE id = ?", (workspace_id,)).fetchone()
        user = conn.execute(
            "SELECT u.telegram_chat_id FROM users u JOIN workspaces w ON w.user_id = u.id WHERE w.id = ?",
            (workspace_id,),
        ).fetchone()
    if not ws or not user:
        raise ValueError("Workspace config lookup failed.")
    preview_header = f"<b>📝 Draft Preview for Workspace #{workspace_id}:</b>\n\n{text}"
    send_telegram_message(ws["bot_token"], user["telegram_chat_id"], preview_header)


def dispatch_manual_review_prompt(scraped_post_id: int, candidate_text: str, existing_text: str, similarity: float, workspace_id: int):
    from app.models.db import get_db_connection

    with get_db_connection() as conn:
        ws = conn.execute("SELECT bot_token, user_id FROM workspaces WHERE id = ?", (workspace_id,)).fetchone()
        user = conn.execute("SELECT telegram_chat_id FROM users WHERE id = ?", (ws["user_id"],)).fetchone()
    if not ws or not user:
        return
    message = (
        f"⚠️ <b>Deduplication Review Required</b>\n"
        f"A new post (ID: {scraped_post_id}) overlaps with a previously published topic (similarity: {similarity:.1%}).\n\n"
        f"<b>New Candidate:</b>\n<i>{candidate_text[:200]}...</i>\n\n"
        f"<b>Previous Match:</b>\n<i>{existing_text[:200]}...</i>\n\n"
        f"Reply using the interactive controls below:"
    )
    keyboard = {
        "inline_keyboard": [
            [
                {"text": "✅ Approve (Unique)", "callback_data": f"review_approve_{scraped_post_id}"},
                {"text": "❌ Reject (Duplicate)", "callback_data": f"review_reject_{scraped_post_id}"},
            ]
        ]
    }
    send_telegram_message(ws["bot_token"], user["telegram_chat_id"], message, reply_markup=keyboard)

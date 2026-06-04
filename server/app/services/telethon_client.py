import asyncio
import logging

from telethon import TelegramClient

from app.config import Config

logger = logging.getLogger(__name__)


async def _fetch_messages_async(channel_identifier: str, limit: int, offset_id: int) -> list[dict]:
    temp_client = TelegramClient(Config.TELETHON_SESSION_PATH, int(Config.TELEGRAM_API_ID), Config.TELEGRAM_API_HASH)
    await temp_client.connect()
    if not await temp_client.is_user_authorized():
        logger.error("Telethon client is not authorized. Please run authenticate_scraper.py.")
        await temp_client.disconnect()
        return []
    messages = []
    try:
        entity = await temp_client.get_input_entity(channel_identifier)
        async for msg in temp_client.iter_messages(entity, limit=limit, min_id=offset_id):
            if msg.text:
                messages.append({"id": msg.id, "text": msg.text, "date": msg.date.isoformat() if msg.date else ""})
    except Exception as e:
        logger.error(f"Error fetching messages from Telegram channel {channel_identifier}: {e}")
    finally:
        await temp_client.disconnect()
    return messages


def scrape_channel_messages(channel_identifier: str, last_message_id: int, limit: int = 20) -> list[dict]:
    try:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        result = loop.run_until_complete(_fetch_messages_async(channel_identifier, limit, last_message_id))
        loop.close()
        return result
    except Exception as e:
        logger.error(f"Sync Telethon bridge experienced an error: {e}")
        return []

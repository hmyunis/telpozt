import asyncio
import logging
from datetime import datetime

from telethon import TelegramClient

from app.config import Config

logger = logging.getLogger(__name__)


async def _fetch_messages_async(
    channel_identifier: str,
    limit: int,
    offset_id: int,
    from_date: datetime | None = None,
    to_date: datetime | None = None,
) -> list[dict]:
    temp_client = TelegramClient(Config.TELETHON_SESSION_PATH, int(Config.TELEGRAM_API_ID), Config.TELEGRAM_API_HASH)
    await temp_client.connect()
    if not await temp_client.is_user_authorized():
        logger.error("Telethon client is not authorized. Please run authenticate_scraper.py.")
        await temp_client.disconnect()
        return []
    messages = []
    try:
        entity = await temp_client.get_input_entity(channel_identifier)
        scan_limit = limit
        if from_date is not None or to_date is not None:
            scan_limit = max(limit * 5, 100)

        async for msg in temp_client.iter_messages(entity, limit=scan_limit, min_id=offset_id):
            if msg.text:
                message_date = msg.date
                if to_date is not None and message_date and message_date > to_date:
                    continue
                if from_date is not None and message_date and message_date < from_date:
                    break
                messages.append(
                    {
                        "id": msg.id,
                        "text": msg.text,
                        "date": msg.date.isoformat() if msg.date else "",
                        "views": int(msg.views) if msg.views is not None else None,
                    }
                )
                if len(messages) >= limit:
                    break
    except Exception as e:
        logger.error(f"Error fetching messages from Telegram channel {channel_identifier}: {e}")
    finally:
        await temp_client.disconnect()
    return messages


def scrape_channel_messages(
    channel_identifier: str,
    last_message_id: int,
    limit: int = 20,
    from_date: datetime | None = None,
    to_date: datetime | None = None,
) -> list[dict]:
    try:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        result = loop.run_until_complete(
            _fetch_messages_async(
                channel_identifier,
                limit,
                last_message_id,
                from_date=from_date,
                to_date=to_date,
            )
        )
        loop.close()
        return result
    except Exception as e:
        logger.error(f"Sync Telethon bridge experienced an error: {e}")
        return []

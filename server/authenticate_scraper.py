import asyncio
import os

from dotenv import load_dotenv
from telethon import TelegramClient

load_dotenv()


async def main():
    api_id = os.getenv("TELEGRAM_API_ID")
    api_hash = os.getenv("TELEGRAM_API_HASH")
    session_path = os.getenv("TELETHON_SESSION_PATH", "./sessions/scraper.session")

    if not api_id or not api_hash:
        print("Error: TELEGRAM_API_ID or TELEGRAM_API_HASH is missing from your .env file.")
        return

    session_dir = os.path.dirname(session_path)
    if session_dir and not os.path.exists(session_dir):
        os.makedirs(session_dir, exist_ok=True)

    print(f"Initializing Telethon Client session at: {session_path}")
    client = TelegramClient(session_path, int(api_id), api_hash)

    await client.connect()
    if not await client.is_user_authorized():
        phone = input("Enter your Telegram phone number (including country code, e.g., +123456789): ")
        await client.send_code_request(phone)
        code = input("Enter the OTP code received on your Telegram app: ")
        try:
            await client.sign_in(phone, code)
        except Exception:
            password = input("Two-step verification enabled. Enter password: ")
            await client.sign_in(password=password)

    print("\nAuthentication successful!")
    print("Session file saved. You can now use the automated scraper background jobs.")
    await client.disconnect()


if __name__ == "__main__":
    asyncio.run(main())

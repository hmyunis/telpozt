import os
from pathlib import Path

from dotenv import load_dotenv

load_dotenv()

BASE_DIR = Path(__file__).resolve().parent.parent


class Config:
    FLASK_SECRET_KEY = os.getenv("FLASK_SECRET_KEY")
    JWT_SECRET = os.getenv("JWT_SECRET")
    JWT_EXPIRY_HOURS = int(os.getenv("JWT_EXPIRY_HOURS", "720"))

    GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
    GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-2.5-flash-lite")
    GEMINI_EMBEDDING_MODEL = os.getenv("GEMINI_EMBEDDING_MODEL", "text-embedding-004")

    TELEGRAM_BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN")
    TELEGRAM_API_ID = os.getenv("TELEGRAM_API_ID")
    TELEGRAM_API_HASH = os.getenv("TELEGRAM_API_HASH")
    TELETHON_SESSION_PATH = os.path.abspath(
        os.getenv("TELETHON_SESSION_PATH", "./sessions/scraper.session")
    )

    ADMIN_TELEGRAM_CHAT_ID = os.getenv("ADMIN_TELEGRAM_CHAT_ID")

    SCRAPE_INTERVAL_MINUTES = int(os.getenv("SCRAPE_INTERVAL_MINUTES", "60"))
    DEDUP_SIMILARITY_THRESHOLD = float(os.getenv("DEDUP_SIMILARITY_THRESHOLD", "0.88"))
    DEDUP_LOOKBACK_DAYS = int(os.getenv("DEDUP_LOOKBACK_DAYS", "30"))

    DATABASE_PATH = os.path.join(BASE_DIR, "data", "automation_system.db")
    SCHEMA_PATH = os.path.join(BASE_DIR, "app", "models", "schema.sql")

    @classmethod
    def validate(cls):
        required_keys = [
            "FLASK_SECRET_KEY",
            "JWT_SECRET",
            "GEMINI_API_KEY",
            "TELEGRAM_BOT_TOKEN",
            "TELEGRAM_API_ID",
            "TELEGRAM_API_HASH",
        ]
        missing = [key for key in required_keys if not getattr(cls, key)]
        if missing:
            raise ValueError(f"Missing required environment variables: {', '.join(missing)}")

import os
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()

BASE_DIR = Path(__file__).resolve().parent.parent

class Config:
    FLASK_SECRET_KEY = os.getenv("FLASK_SECRET_KEY")
    HF_API_KEY = os.getenv("HF_API_KEY")
    CRON_SECRET_KEY = os.getenv("CRON_SECRET_KEY", "default-cron-secret")
    
    TELEGRAM_BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN")
    TELEGRAM_API_ID = os.getenv("TELEGRAM_API_ID")
    TELEGRAM_API_HASH = os.getenv("TELEGRAM_API_HASH")
    TELETHON_SESSION_PATH = os.path.abspath(os.getenv("TELETHON_SESSION_PATH", "./sessions/scraper.session"))
    ADMIN_TELEGRAM_CHAT_ID = os.getenv("ADMIN_TELEGRAM_CHAT_ID")

    DEDUP_SIMILARITY_THRESHOLD = float(os.getenv("DEDUP_SIMILARITY_THRESHOLD", "0.85"))
    DEDUP_LOOKBACK_DAYS = int(os.getenv("DEDUP_LOOKBACK_DAYS", "30"))

    DATABASE_PATH = os.path.join(BASE_DIR, "data", "automation_system.db")
    SCHEMA_PATH = os.path.join(BASE_DIR, "app", "models", "schema.sql")

    @classmethod
    def validate(cls):
        required = ["TELEGRAM_BOT_TOKEN", "TELEGRAM_API_ID", "TELEGRAM_API_HASH", "HF_API_KEY", "ADMIN_TELEGRAM_CHAT_ID"]
        missing = [k for k in required if not getattr(cls, k)]
        if missing:
            raise ValueError(f"Missing required env vars: {', '.join(missing)}")

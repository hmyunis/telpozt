import os
import sqlite3
from contextlib import contextmanager

from app.config import Config


def _column_exists(conn, table_name: str, column_name: str) -> bool:
    rows = conn.execute(f"PRAGMA table_info({table_name})").fetchall()
    return any(row["name"] == column_name for row in rows)


def _apply_schema_migrations(conn):
    if not _column_exists(conn, "queue", "last_generation_instruction"):
        conn.execute("ALTER TABLE queue ADD COLUMN last_generation_instruction TEXT")
    if not _column_exists(conn, "scraped_posts", "original_posted_at_utc"):
        conn.execute("ALTER TABLE scraped_posts ADD COLUMN original_posted_at_utc TEXT")
    if not _column_exists(conn, "scraped_posts", "view_count"):
        conn.execute("ALTER TABLE scraped_posts ADD COLUMN view_count INTEGER")
    if not _column_exists(conn, "source_channels", "default_scrape_message_count"):
        conn.execute("ALTER TABLE source_channels ADD COLUMN default_scrape_message_count INTEGER")
    if not _column_exists(conn, "source_channels", "default_lookback_days"):
        conn.execute("ALTER TABLE source_channels ADD COLUMN default_lookback_days INTEGER")

    conn.execute(
        """CREATE TABLE IF NOT EXISTS queue_source_posts (
            queue_id         INTEGER NOT NULL REFERENCES queue(id) ON DELETE CASCADE,
            scraped_post_id  INTEGER NOT NULL REFERENCES scraped_posts(id) ON DELETE CASCADE,
            position         INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY(queue_id, scraped_post_id)
        )"""
    )
    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_queue_source_posts_queue ON queue_source_posts(queue_id, position)"
    )


def init_db():
    Config.validate()
    db_dir = os.path.dirname(Config.DATABASE_PATH)
    if db_dir and not os.path.exists(db_dir):
        os.makedirs(db_dir, exist_ok=True)

    with get_db_connection() as conn:
        with open(Config.SCHEMA_PATH, "r", encoding="utf-8") as f:
            conn.executescript(f.read())
        _apply_schema_migrations(conn)
        conn.commit()


@contextmanager
def get_db_connection():
    """
    Returns a database connection. This context manager works across
    standard requests as well as background job threads.
    """
    conn = sqlite3.connect(
        Config.DATABASE_PATH,
        detect_types=sqlite3.PARSE_DECLTYPES,
    )
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON;")
    conn.execute("PRAGMA journal_mode = WAL;")
    try:
        yield conn
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()

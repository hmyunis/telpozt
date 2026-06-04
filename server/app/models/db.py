import os
import sqlite3
from contextlib import contextmanager

from app.config import Config


def init_db():
    Config.validate()
    db_dir = os.path.dirname(Config.DATABASE_PATH)
    if db_dir and not os.path.exists(db_dir):
        os.makedirs(db_dir, exist_ok=True)

    with get_db_connection() as conn:
        with open(Config.SCHEMA_PATH, "r", encoding="utf-8") as f:
            conn.executescript(f.read())
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

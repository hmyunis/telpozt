import sys

from app.models.db import init_db


if __name__ == "__main__":
    try:
        print("Initializing SQLite Database...")
        init_db()
        print("Database initialized successfully at path specified in Config.")
    except Exception as e:
        print(f"Error initializing system: {e}", file=sys.stderr)
        sys.exit(1)

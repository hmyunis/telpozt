import logging
from app.api import create_app
from app.models.db import init_db

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    handlers=[logging.StreamHandler()],
)

init_db()
application = create_app()

if __name__ == "__main__":
    application.run(host="0.0.0.0", port=5000, debug=False)

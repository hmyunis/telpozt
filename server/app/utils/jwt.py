from datetime import datetime, timedelta, timezone

import bcrypt
import jwt

from app.config import Config


def hash_password(password: str) -> str:
    """Hashes a password using bcrypt."""
    salt = bcrypt.gensalt()
    hashed = bcrypt.hashpw(password.encode("utf-8"), salt)
    return hashed.decode("utf-8")


def check_password(password: str, password_hash: str) -> bool:
    """Verifies a password against its bcrypt hash."""
    return bcrypt.checkpw(password.encode("utf-8"), password_hash.encode("utf-8"))


def generate_token(user_id: int) -> str:
    """Creates a JWT for a user ID, using the expiry time from the app config."""
    now = datetime.now(timezone.utc)
    payload = {
        "exp": now + timedelta(hours=Config.JWT_EXPIRY_HOURS),
        "iat": now,
        "sub": user_id,
    }
    return jwt.encode(payload, Config.JWT_SECRET, algorithm="HS256")


def decode_token(token: str) -> int:
    """
    Decodes a JWT and returns the user ID.
    Raises jwt.ExpiredSignatureError or jwt.InvalidTokenError for invalid tokens.
    """
    payload = jwt.decode(token, Config.JWT_SECRET, algorithms=["HS256"])
    return int(payload["sub"])

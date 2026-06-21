import hashlib
import hmac
import json
from urllib.parse import parse_qsl
from app.config import Config

def validate_webapp_data(init_data: str) -> dict | None:
    try:
        parsed = dict(parse_qsl(init_data))
        if "hash" not in parsed:
            return None
            
        hash_val = parsed.pop("hash")
        data_check_string = "\n".join(f"{k}={v}" for k, v in sorted(parsed.items()))
        
        secret_key = hmac.new(b"WebAppData", Config.TELEGRAM_BOT_TOKEN.encode(), hashlib.sha256).digest()
        calc_hash = hmac.new(secret_key, data_check_string.encode(), hashlib.sha256).hexdigest()
        
        if calc_hash == hash_val:
            return json.loads(parsed.get("user", "{}"))
    except Exception:
        pass
    return None

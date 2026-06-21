import logging
import requests
from app.config import Config

logger = logging.getLogger(__name__)

def get_text_embedding(text: str) -> list[float]:
    if not Config.HF_API_KEY:
        logger.warning("HF_API_KEY missing, skipping embeddings.")
        return []
    
    url = "https://api-inference.huggingface.co/pipeline/feature-extraction/sentence-transformers/all-MiniLM-L6-v2"
    headers = {"Authorization": f"Bearer {Config.HF_API_KEY}"}
    
    try:
        normalized = " ".join(text.split())
        resp = requests.post(url, headers=headers, json={"inputs": [normalized]}, timeout=15)
        resp.raise_for_status()
        data = resp.json()
        return data[0] if isinstance(data, list) and len(data) > 0 else []
    except Exception as e:
        logger.error(f"HuggingFace embedding failed: {e}")
        return []

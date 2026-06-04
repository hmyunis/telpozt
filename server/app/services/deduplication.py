import hashlib
import json
import math


def calculate_sha256_hash(text: str) -> str:
    normalized = " ".join(text.lower().split())
    return hashlib.sha256(normalized.encode("utf-8")).hexdigest()


def calculate_cosine_similarity(vec_a: list[float], vec_b: list[float]) -> float:
    if not vec_a or not vec_b:
        return 0.0
    dot_product = sum(x * y for x, y in zip(vec_a, vec_b))
    magnitude_a = math.sqrt(sum(x * x for x in vec_a))
    magnitude_b = math.sqrt(sum(y * y for y in vec_b))
    if not magnitude_a or not magnitude_b:
        return 0.0
    return dot_product / (magnitude_a * magnitude_b)


def parse_blob_to_vector(blob_data) -> list[float]:
    if not blob_data:
        return []
    try:
        if isinstance(blob_data, bytes):
            blob_data = blob_data.decode("utf-8")
        return json.loads(blob_data)
    except Exception:
        return []

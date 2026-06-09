import logging
import socket
import time
from typing import Any
from urllib.parse import urlparse

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

from app.config import Config

logger = logging.getLogger(__name__)


class OllamaServiceError(Exception):
    def __init__(self, code: str, message: str, *, retryable: bool = False, status_code: int = 503):
        super().__init__(message)
        self.code = code
        self.message = message
        self.retryable = retryable
        self.status_code = status_code


def _normalize_ollama_base_url(base_url: str) -> str:
    normalized = (base_url or "").strip().rstrip("/")
    if not normalized:
        normalized = "http://127.0.0.1:11434/api"
    if not normalized.endswith("/api"):
        normalized = f"{normalized}/api"
    return normalized


def _build_session() -> requests.Session:
    retry = Retry(
        total=2,
        connect=2,
        read=2,
        backoff_factor=0.3,
        status_forcelist=(429, 500, 502, 503, 504),
        allowed_methods=frozenset({"GET", "POST"}),
    )
    adapter = HTTPAdapter(max_retries=retry)
    session = requests.Session()
    session.mount("http://", adapter)
    session.mount("https://", adapter)
    return session


_SESSION = _build_session()


def _ollama_url(path: str) -> str:
    return f"{_normalize_ollama_base_url(Config.OLLAMA_BASE_URL)}{path}"


def _request_json(path: str, payload: dict[str, Any] | None = None, *, timeout: int | None = None) -> dict[str, Any]:
    request_timeout = timeout or Config.OLLAMA_REQUEST_TIMEOUT_SECONDS
    url = _ollama_url(path)
    try:
        if payload is None:
            response = _SESSION.get(url, timeout=request_timeout)
        else:
            response = _SESSION.post(url, json=payload, timeout=request_timeout)
    except requests.exceptions.ConnectTimeout as exc:
        raise OllamaServiceError(
            "OLLAMA_CONNECT_TIMEOUT",
            f"Ollama at {Config.OLLAMA_BASE_URL} did not accept the connection before timeout.",
            retryable=True,
        ) from exc
    except requests.exceptions.ReadTimeout as exc:
        raise OllamaServiceError(
            "OLLAMA_RESPONSE_TIMEOUT",
            f"Ollama at {Config.OLLAMA_BASE_URL} started but did not answer in time.",
            retryable=True,
        ) from exc
    except requests.exceptions.ConnectionError as exc:
        raise OllamaServiceError(
            "OLLAMA_UNREACHABLE",
            f"Ollama could not be reached at {Config.OLLAMA_BASE_URL}. Verify the service is running and reachable from the backend host.",
            retryable=True,
        ) from exc
    except requests.exceptions.RequestException as exc:
        raise OllamaServiceError(
            "OLLAMA_REQUEST_FAILED",
            f"Ollama request failed unexpectedly: {exc}",
            retryable=True,
        ) from exc

    try:
        data = response.json()
    except ValueError as exc:
        raise OllamaServiceError(
            "OLLAMA_INVALID_RESPONSE",
            f"Ollama returned a non-JSON response from {url}.",
        ) from exc

    if response.status_code >= 400:
        detail = data.get("error") if isinstance(data, dict) else None
        detail_text = str(detail or response.reason or "Unknown Ollama error").strip()
        if "model" in detail_text.lower() and "not found" in detail_text.lower():
            raise OllamaServiceError(
                "OLLAMA_MODEL_MISSING",
                detail_text,
                status_code=424,
            )
        raise OllamaServiceError(
            "OLLAMA_HTTP_ERROR",
            f"Ollama returned HTTP {response.status_code}: {detail_text}",
            retryable=response.status_code in {429, 500, 502, 503, 504},
            status_code=503,
        )

    if isinstance(data, dict) and data.get("error"):
        detail_text = str(data["error"]).strip()
        if "model" in detail_text.lower() and "not found" in detail_text.lower():
            raise OllamaServiceError(
                "OLLAMA_MODEL_MISSING",
                detail_text,
                status_code=424,
            )
        raise OllamaServiceError("OLLAMA_API_ERROR", detail_text)

    return data


def _available_models() -> list[str]:
    payload = _request_json("/tags", timeout=Config.OLLAMA_DIAGNOSTIC_TIMEOUT_SECONDS)
    models = payload.get("models", []) if isinstance(payload, dict) else []
    return [str(model.get("name", "")).strip() for model in models if isinstance(model, dict) and model.get("name")]


def _require_installed_model(model_name: str, available_models: list[str] | None = None) -> None:
    models = available_models if available_models is not None else _available_models()
    if model_name not in models:
        raise OllamaServiceError(
            "OLLAMA_MODEL_MISSING",
            f"Required Ollama model '{model_name}' is not installed. Run `ollama pull {model_name}` on the Ollama host.",
            status_code=424,
        )


def _extract_text_response(payload: dict[str, Any]) -> str:
    message = payload.get("message")
    if isinstance(message, dict):
        content = str(message.get("content", "")).strip()
        if content:
            return content
    response = str(payload.get("response", "")).strip()
    if response:
        return response
    raise OllamaServiceError("OLLAMA_EMPTY_RESPONSE", "Ollama returned an empty response.")


def generate_rewrite(system_prompt: str, source_text: str) -> str:
    payload = _request_json(
        "/chat",
        {
            "model": Config.OLLAMA_MODEL,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": source_text},
            ],
            "stream": False,
            "think": False,
            "keep_alive": Config.OLLAMA_KEEP_ALIVE,
        },
    )
    return _extract_text_response(payload)


def generate_topic_summary(text: str) -> str:
    try:
        payload = _request_json(
            "/chat",
            {
                "model": Config.OLLAMA_MODEL,
                "messages": [
                    {
                        "role": "system",
                        "content": (
                            "Summarize the main technical or informational topic in exactly one clear sentence. "
                            "Do not add greetings, markdown, or extra commentary."
                        ),
                    },
                    {"role": "user", "content": text},
                ],
                "stream": False,
                "think": False,
                "keep_alive": Config.OLLAMA_KEEP_ALIVE,
            },
        )
        return _extract_text_response(payload)
    except Exception as exc:
        logger.error("Topic summarization failed: %s", exc)
        return "Topic extraction unavailable"


def get_text_embedding(text: str) -> list[float]:
    normalized = " ".join(text.split())
    payload = _request_json(
        "/embed",
        {
            "model": Config.OLLAMA_EMBEDDING_MODEL,
            "input": normalized,
            "truncate": True,
        },
    )
    embeddings = payload.get("embeddings", []) if isinstance(payload, dict) else []
    if embeddings and isinstance(embeddings[0], list):
        return [float(value) for value in embeddings[0]]
    raise OllamaServiceError("OLLAMA_INVALID_EMBEDDING", "Ollama returned an invalid embedding payload.")


def warmup_generation_model() -> dict[str, Any]:
    started_at = time.perf_counter()
    payload = _request_json(
        "/generate",
        {
            "model": Config.OLLAMA_MODEL,
            "prompt": "Reply with OK.",
            "stream": False,
            "think": False,
            "keep_alive": Config.OLLAMA_KEEP_ALIVE,
        },
        timeout=max(Config.OLLAMA_DIAGNOSTIC_TIMEOUT_SECONDS, 20),
    )
    return {
        "response_ms": round((time.perf_counter() - started_at) * 1000),
        "done": payload.get("done", False),
        "done_reason": payload.get("done_reason"),
    }


def get_local_network_hosts() -> list[str]:
    candidates: set[str] = set()
    try:
        hostname = socket.gethostname()
        for family, _, _, _, sockaddr in socket.getaddrinfo(hostname, None):
            if family == socket.AF_INET:
                ip_address = sockaddr[0]
                if not ip_address.startswith("127."):
                    candidates.add(ip_address)
    except OSError:
        pass

    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
            sock.connect(("192.0.2.1", 80))
            ip_address = sock.getsockname()[0]
            if ip_address and not ip_address.startswith("127."):
                candidates.add(ip_address)
    except OSError:
        pass

    return sorted(candidates)


def run_connection_diagnostics() -> dict[str, Any]:
    issues: list[str] = []
    available_models: list[str] = []
    ollama_ok = False
    generation_model_ready = False
    embedding_model_ready = False
    warmup: dict[str, Any] | None = None

    try:
        available_models = _available_models()
        ollama_ok = True
        _require_installed_model(Config.OLLAMA_MODEL, available_models)
        generation_model_ready = True
        _require_installed_model(Config.OLLAMA_EMBEDDING_MODEL, available_models)
        embedding_model_ready = True
        warmup = warmup_generation_model()
    except OllamaServiceError as exc:
        issues.append(exc.message)

    return {
        "provider": "ollama",
        "ollama_base_url": _normalize_ollama_base_url(Config.OLLAMA_BASE_URL),
        "generation_model": Config.OLLAMA_MODEL,
        "embedding_model": Config.OLLAMA_EMBEDDING_MODEL,
        "ollama_reachable": ollama_ok,
        "generation_model_ready": generation_model_ready,
        "embedding_model_ready": embedding_model_ready,
        "warmup": warmup,
        "available_models": available_models,
        "issues": issues,
        "server_ips": get_local_network_hosts(),
    }


def get_ollama_origin_host() -> str:
    return urlparse(_normalize_ollama_base_url(Config.OLLAMA_BASE_URL)).netloc

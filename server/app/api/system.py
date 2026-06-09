import sqlite3
from urllib.parse import urlparse

from flask import Blueprint, request

from app.api.utils import api_success
from app.config import Config
from app.models.db import get_db_connection
from app.services.ollama import get_ollama_origin_host, run_connection_diagnostics

system_bp = Blueprint("system", __name__)


def _build_step(step_id: str, label: str, done: bool, success_message: str, failure_message: str) -> dict:
    return {
        "id": step_id,
        "label": label,
        "status": "done" if done else "failed",
        "message": success_message if done else failure_message,
    }


@system_bp.route("/health", methods=["GET"])
def health():
    diagnostics = run_connection_diagnostics()
    request_base = request.host_url.rstrip("/")
    server_host = urlparse(request_base).netloc
    database_ok = True
    admin_exists = False

    try:
        with get_db_connection() as conn:
            admin_exists = conn.execute("SELECT 1 FROM users LIMIT 1").fetchone() is not None
    except sqlite3.Error:
        database_ok = False

    steps = [
        _build_step(
            "backend_reachable",
            "Mobile app reached the backend",
            True,
            f"Backend responded from {server_host}.",
            "Backend did not respond.",
        ),
        _build_step(
            "database_ready",
            "Backend database is ready",
            database_ok,
            "SQLite opened successfully.",
            "SQLite could not be opened. Check backend startup logs.",
        ),
        _build_step(
            "ollama_reachable",
            "Backend can reach Ollama",
            diagnostics["ollama_reachable"],
            f"Ollama is reachable at {diagnostics['ollama_base_url']}.",
            diagnostics["issues"][0] if diagnostics["issues"] else "Ollama is not reachable from the backend.",
        ),
        _build_step(
            "generation_model_ready",
            "Qwen generation model is installed",
            diagnostics["generation_model_ready"],
            f"{diagnostics['generation_model']} is ready.",
            f"Install {diagnostics['generation_model']} with `ollama pull {diagnostics['generation_model']}`.",
        ),
        _build_step(
            "embedding_model_ready",
            "Embedding model is installed",
            diagnostics["embedding_model_ready"],
            f"{diagnostics['embedding_model']} is ready.",
            f"Install {diagnostics['embedding_model']} with `ollama pull {diagnostics['embedding_model']}`.",
        ),
        _build_step(
            "admin_ready",
            "Admin account exists for sign in",
            admin_exists,
            "At least one admin account exists.",
            "No admin account exists yet. Create one with the backend setup guide.",
        ),
    ]

    preferred_url = f"http://{diagnostics['server_ips'][0]}:5000/api/v1" if diagnostics["server_ips"] else f"{request_base}/api/v1"
    return api_success(
        {
            "backend": {
                "status": "ok",
                "server_host": server_host,
                "preferred_mobile_base_url": preferred_url,
                "detected_server_ips": diagnostics["server_ips"],
            },
            "ai": {
                "provider": diagnostics["provider"],
                "ollama_base_url": diagnostics["ollama_base_url"],
                "ollama_host": get_ollama_origin_host(),
                "generation_model": diagnostics["generation_model"],
                "embedding_model": diagnostics["embedding_model"],
                "warmup": diagnostics["warmup"],
                "available_models": diagnostics["available_models"],
            },
            "guide": {
                "title": "Connect your phone to the Telpozt backend",
                "steps": steps,
                "notes": [
                    "Phone and backend computer must be on the same Wi-Fi or LAN.",
                    "Use the backend computer's LAN IP, not 127.0.0.1 or localhost.",
                    "If Ollama is on another machine, keep OLLAMA_BASE_URL pointed at that machine's /api endpoint.",
                ],
            },
            "issues": diagnostics["issues"],
            "config": {
                "ollama_keep_alive": Config.OLLAMA_KEEP_ALIVE,
                "ollama_timeout_seconds": Config.OLLAMA_REQUEST_TIMEOUT_SECONDS,
            },
        }
    )

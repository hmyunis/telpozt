from flask import Flask, jsonify
from flask_cors import CORS
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address

from app.api.utils import APIError
from app.config import Config

limiter = Limiter(
    key_func=get_remote_address,
    default_limits=["1000 per hour"],
)


def create_app():
    app = Flask(__name__)
    app.config.from_object(Config)

    CORS(app, resources={r"/api/*": {"origins": "*"}})
    limiter.init_app(app)

    @app.errorhandler(APIError)
    def handle_api_exception(err):
        return jsonify({
            "success": False,
            "data": None,
            "error": {
                "code": err.code,
                "message": err.message,
            },
        }), err.status_code

    @app.errorhandler(429)
    def handle_rate_limits(err):
        return jsonify({
            "success": False,
            "data": None,
            "error": {
                "code": "RATE_LIMIT_EXCEEDED",
                "message": f"Rate limit reached: {err.description}",
            },
        }), 429

    @app.errorhandler(500)
    def handle_internal_crash(err):
        return jsonify({
            "success": False,
            "data": None,
            "error": {
                "code": "INTERNAL_SERVER_ERROR",
                "message": "An unhandled execution crash occurred in the backend.",
            },
        }), 500

    from app.api.auth import auth_bp
    from app.api.users import users_bp
    from app.api.style_profiles import style_profiles_bp
    from app.api.workspaces import workspaces_bp
    from app.api.queue import queue_bp
    from app.api.history import history_bp

    app.register_blueprint(auth_bp, url_prefix="/api/v1/auth")
    app.register_blueprint(users_bp, url_prefix="/api/v1/user")
    app.register_blueprint(style_profiles_bp, url_prefix="/api/v1/style-profiles")
    app.register_blueprint(workspaces_bp, url_prefix="/api/v1/workspaces")
    app.register_blueprint(queue_bp, url_prefix="/api/v1/workspaces")
    app.register_blueprint(history_bp, url_prefix="/api/v1/workspaces")

    return app

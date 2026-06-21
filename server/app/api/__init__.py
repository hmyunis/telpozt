from flask import Flask, jsonify
from flask_cors import CORS
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from app.api.utils import APIError
from app.config import Config

limiter = Limiter(key_func=get_remote_address, default_limits=["1000 per hour"])

def create_app():
    app = Flask(__name__)
    app.config.from_object(Config)
    CORS(app, resources={r"/api/*": {"origins": "*"}})
    limiter.init_app(app)

    @app.errorhandler(APIError)
    def handle_api_exception(err):
        return jsonify({"success": False, "error": {"code": err.code, "message": err.message}}), err.status_code

    from app.api.system import system_bp
    from app.api.users import users_bp
    from app.api.style_profiles import style_profiles_bp
    from app.api.workspaces import workspaces_bp
    from app.api.queue import queue_bp
    from app.api.history import history_bp
    from app.api.webhook import webhook_bp
    from app.api.cron import cron_bp
    from app.api.candidates import candidates_bp

    app.register_blueprint(system_bp, url_prefix="/api/v1/system")
    app.register_blueprint(users_bp, url_prefix="/api/v1/user")
    app.register_blueprint(style_profiles_bp, url_prefix="/api/v1/style-profiles")
    app.register_blueprint(workspaces_bp, url_prefix="/api/v1/workspaces")
    app.register_blueprint(queue_bp, url_prefix="/api/v1/workspaces")
    app.register_blueprint(history_bp, url_prefix="/api/v1/workspaces")
    app.register_blueprint(candidates_bp, url_prefix="/api/v1/workspaces")
    app.register_blueprint(webhook_bp, url_prefix="/api/v1/webhook")
    app.register_blueprint(cron_bp, url_prefix="/api/v1/cron")

    return app

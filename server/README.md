# Telegram Channel Automation Backend

This folder contains the Flask backend for the Telegram Channel Automation System. It provides a REST API, SQLite database setup, JWT authentication, Telegram scraping/posting services, Gemini text generation, and background schedulers.

The guide below assumes you are new to Flask, virtual environments, and these tools.

## What You Need

- Python 3.11 or newer
- A terminal, preferably PowerShell on Windows
- A Telegram bot token from BotFather
- Telegram API credentials from <https://my.telegram.org/apps>
- A Gemini API key from Google AI Studio

## 1. Open The Backend Folder

From the project root:

```powershell
cd backend
```

All commands below should be run from the `backend` folder.

## 2. Create A Python Virtual Environment

A virtual environment keeps this project's Python packages separate from the rest of your computer.

```powershell
python -m venv venv
```

Activate it:

```powershell
.\venv\Scripts\Activate.ps1
```

If PowerShell blocks activation scripts, run this once:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

Then activate the environment again:

```powershell
.\venv\Scripts\Activate.ps1
```

When activation works, your terminal prompt should start with `(venv)`.

## 3. Install Dependencies

Install all required Python packages:

```powershell
pip install -r requirements.txt
```

## 4. Create Your Environment File

The backend reads secrets and runtime settings from a `.env` file.

Create it from the example:

```powershell
Copy-Item .env.example .env
```

Open `.env` and replace the placeholder values.

Required values:

```env
FLASK_SECRET_KEY=replace_with_a_long_random_string
JWT_SECRET=replace_with_a_different_long_random_string
GEMINI_API_KEY=your_gemini_api_key
TELEGRAM_BOT_TOKEN=your_telegram_bot_token
TELEGRAM_API_ID=your_telegram_api_id
TELEGRAM_API_HASH=your_telegram_api_hash
```

Useful optional values:

```env
ADMIN_TELEGRAM_CHAT_ID=your_personal_telegram_chat_id
TELETHON_SESSION_PATH=./sessions/scraper.session
SCRAPE_INTERVAL_MINUTES=60
DEDUP_SIMILARITY_THRESHOLD=0.88
DEDUP_LOOKBACK_DAYS=30
```

You can generate random secrets with Python:

```powershell
python -c "import secrets; print(secrets.token_hex(32))"
```

Run that twice: once for `FLASK_SECRET_KEY`, and once for `JWT_SECRET`.

## 5. Initialize The Database

The backend uses SQLite. The database file is created automatically under:

```text
backend/data/automation_system.db
```

Initialize it manually:

```powershell
python init_db.py
```

If this fails with missing environment variables, check that `.env` exists and all required values are filled in.

## 6. Authenticate The Telegram Scraper

The scraper uses Telethon, which needs a one-time Telegram login. This creates a session file so the backend can read source channels later.

Run:

```powershell
python authenticate_scraper.py
```

You will be asked for:

- Your Telegram phone number, including country code
- The login code sent to Telegram
- Your two-step verification password, if enabled

After this succeeds, a session file is saved at the path configured by `TELETHON_SESSION_PATH`.

## 7. Start The Backend

Run:

```powershell
python wsgi.py
```

The API will start at:

```text
http://127.0.0.1:5000
```

The scheduler also starts automatically. It handles scraping, embeddings, deduplication, generation, posting, and watchdog recovery.

## 8. Create The First Admin User

After the server is running, create the first user with this request.

PowerShell example:

```powershell
$body = @{
  username = "admin"
  password = "secure_admin_password_here"
  telegram_chat_id = "YOUR_PERSONAL_TELEGRAM_CHAT_ID"
  timezone = "Africa/Addis_Ababa"
} | ConvertTo-Json

Invoke-RestMethod `
  -Method Post `
  -Uri "http://127.0.0.1:5000/api/v1/auth/register-admin" `
  -ContentType "application/json" `
  -Body $body
```

This endpoint only works once. After a user exists, it returns a forbidden error.

## 9. Log In

```powershell
$body = @{
  username = "admin"
  password = "secure_admin_password_here"
} | ConvertTo-Json

Invoke-RestMethod `
  -Method Post `
  -Uri "http://127.0.0.1:5000/api/v1/auth/login" `
  -ContentType "application/json" `
  -Body $body
```

The response includes a JWT token. Use it in later requests as:

```text
Authorization: Bearer YOUR_TOKEN_HERE
```

## 10. Test The API With Bruno

A Bruno-importable API collection is included at:

```text
telepost-automation-system.bruno-import.postman_collection.json
```

It is a Postman v2.1 collection JSON because Bruno Desktop can import Postman collection files and convert them into Bruno's native format.

To use it:

1. Start the backend with `python wsgi.py`.
2. Open Bruno Desktop.
3. Click `Import Collection`.
4. Select `telepost-automation-system.bruno-import.postman_collection.json`.
5. Open the imported collection variables and check these values:
   - `base_url`: defaults to `http://127.0.0.1:5000/api/v1`
   - `username`: defaults to `hmyunis`
   - `password`: defaults to `hamdi123`
   - `telegram_chat_id`: replace with your Telegram chat ID before using `Register Admin`
   - `bot_token`: replace with a real Telegram bot token before creating a workspace
   - `target_channel_id`: replace with your target channel, for example `@your_target_channel`
   - `source_channel_id`: replace with a source channel, for example `@your_source_channel`
6. Run `Auth > Register Admin` only if the database has no user yet.
7. Run `Auth > Login`. The collection stores the returned JWT in Bruno's runtime `token` variable.
8. Run the other requests as needed.

Recommended test order for a fresh database:

1. `Auth > Register Admin`
2. `Auth > Login`
3. `User > Get Me`
4. `Style Profiles > Create Style Profile`
5. `Workspaces > Create Workspace`
6. `Source Channels > Create Source Channel`
7. `Queue > Create Queue Item`
8. `Queue > Save Manual Queue Text`
9. `Queue > Approve Queue Item`
10. `Queue > Schedule Queue Item`

Some requests depend on earlier IDs. The collection automatically stores successful `style_profile_id`, `workspace_id`, `source_id`, and `queue_id` responses as Bruno runtime variables.

Notes:

- `Register Admin` only works once. If a user already exists, it returns `403`.
- `Create Workspace` validates `bot_token` with Telegram, so placeholder tokens fail.
- `History > Get History Detail` needs an existing `post_history` record.
- `Webhook > Telegram Webhook` is included for reference, but the webhook blueprint is not currently registered in `app/api/__init__.py`, so it may return `404`.

## Main API Routes

Base URL:

```text
http://127.0.0.1:5000/api/v1
```

Common routes:

- `POST /auth/register-admin`
- `POST /auth/login`
- `POST /auth/logout`
- `POST /auth/change-password`
- `GET /user/me`
- `PATCH /user/me`
- `GET /style-profiles`
- `POST /style-profiles`
- `GET /workspaces`
- `POST /workspaces`
- `GET /workspaces/<id>/source-channels`
- `POST /workspaces/<id>/source-channels`
- `GET /workspaces/<id>/queue`
- `POST /workspaces/<id>/queue`
- `GET /workspaces/<id>/history`
- `POST /webhook/telegram`

## Telegram Webhook URL

The Telegram callback webhook route is:

```text
http://YOUR_SERVER_DOMAIN/api/v1/webhook/telegram
```

For local development, Telegram cannot call `127.0.0.1` directly. Use a tunnel such as ngrok if you need to test webhooks from your local machine.

## Troubleshooting

### `Missing required environment variables`

The backend validates configuration during startup. Fill in the missing keys in `.env`, then run the command again.

### `ModuleNotFoundError`

Make sure the virtual environment is active and dependencies are installed:

```powershell
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

### Telethon says the client is not authorized

Run:

```powershell
python authenticate_scraper.py
```

### Port 5000 is already in use

Stop the process using port 5000, or edit the port in `wsgi.py`.

### Telegram bot token validation fails

Check that the token came from BotFather and has no extra spaces. The backend validates bot tokens against Telegram before saving a workspace.

## Stop The Server

Press `Ctrl+C` in the terminal running `python wsgi.py`.

## Development Notes

- Database schema: `app/models/schema.sql`
- Database helpers: `app/models/db.py`
- Flask app factory: `app/api/__init__.py`
- Main server entrypoint: `wsgi.py`
- Scheduler services: `app/services/scheduler.py`
- Telegram scraper login: `authenticate_scraper.py`

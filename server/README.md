# Telpozt Backend

This folder contains the Flask backend for Telpozt.

It provides:

- JWT authentication
- SQLite persistence
- Telegram scraping with Telethon
- Telegram posting
- local Ollama generation and embeddings
- scheduling
- draft-oriented APIs used by the current client UX

## What The Backend Powers

The current product flow is:

1. The client triggers `Find Content`.
2. The backend scrapes active source channels for a workspace.
3. New scraped items are deduplicated and returned as candidate messages.
4. The user selects one or more candidates.
5. The backend creates one merged draft from those selected source items.
6. The user can edit, regenerate, schedule, publish, or delete that draft.

The backend still stores internal queue state, but the public app flow is draft-first.

## Requirements

- Python 3.11 or newer
- Ollama installed on the backend machine or another reachable machine on the same LAN
- Telegram bot token from BotFather
- Telegram API credentials from <https://my.telegram.org/apps>
- Local models:
  - `qwen3.5:0.8b`
  - `qwen3-embedding:0.6b`

## Setup

Run these commands from the `server` folder.

### 1. Create and activate a virtual environment

```powershell
python -m venv venv
.\venv\Scripts\Activate.ps1
```

If PowerShell blocks activation:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
.\venv\Scripts\Activate.ps1
```

### 2. Install dependencies

```powershell
pip install -r requirements.txt
```

### 3. Create `.env`

```powershell
Copy-Item .env.example .env
```

Required values:

```env
FLASK_SECRET_KEY=replace_with_a_long_random_string
JWT_SECRET=replace_with_a_different_long_random_string
OLLAMA_BASE_URL=http://127.0.0.1:11434/api
OLLAMA_MODEL=qwen3.5:0.8b
OLLAMA_EMBEDDING_MODEL=qwen3-embedding:0.6b
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
OLLAMA_KEEP_ALIVE=15m
```

Generate secrets with:

```powershell
python -c "import secrets; print(secrets.token_hex(32))"
```

### 4. Prepare Ollama

```powershell
ollama pull qwen3.5:0.8b
ollama pull qwen3-embedding:0.6b
```

If Ollama runs on another LAN machine:

```env
OLLAMA_BASE_URL=http://192.168.1.50:11434/api
```

### 5. Initialize the database

```powershell
python init_db.py
```

The SQLite database is created under:

```text
server/data/automation_system.db
```

### 6. Authenticate the Telegram scraper

```powershell
python authenticate_scraper.py
```

This creates the Telethon session used to read source channels.

### 7. Start the backend

```powershell
python wsgi.py
```

Default local API base:

```text
http://127.0.0.1:5000/api/v1
```

For a phone on the same Wi-Fi, use the backend computer's LAN IP instead:

```text
http://192.168.1.23:5000/api/v1
```

## First-Time Admin Setup

Create the first admin account once after the server is running:

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

Then log in:

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

## Current API Surface

Base URL:

```text
http://127.0.0.1:5000/api/v1
```

### System and auth

- `GET /system/health`
- `POST /auth/register-admin`
- `POST /auth/login`
- `POST /auth/logout`
- `POST /auth/change-password`
- `GET /user/me`
- `PATCH /user/me`

### Style profiles

- `GET /style-profiles`
- `POST /style-profiles`
- `GET /style-profiles/<id>`
- `PUT /style-profiles/<id>`
- `DELETE /style-profiles/<id>`

### Workspaces

- `GET /workspaces`
- `POST /workspaces`
- `GET /workspaces/<id>`
- `PUT /workspaces/<id>`
- `POST /workspaces/<id>/scrape`

### Source channels

- `GET /workspaces/<id>/source-channels`
- `POST /workspaces/<id>/source-channels`
- `PUT /workspaces/<id>/source-channels/<source_id>`
- `DELETE /workspaces/<id>/source-channels/<source_id>`

### Drafts

- `GET /workspaces/<id>/drafts`
- `POST /workspaces/<id>/drafts`
- `GET /workspaces/<id>/drafts/<draft_id>`
- `POST /workspaces/<id>/drafts/<draft_id>/regenerate`
- `PATCH /workspaces/<id>/drafts/<draft_id>/text`
- `POST /workspaces/<id>/drafts/<draft_id>/publish`
- `POST /workspaces/<id>/drafts/<draft_id>/schedule`
- `DELETE /workspaces/<id>/drafts/<draft_id>`

### Schedule

- `GET /workspaces/<id>/schedule`
- `PUT /workspaces/<id>/schedule`

### Published history

- `GET /workspaces/<id>/history`
- `GET /workspaces/<id>/history/<history_id>`

## Draft Search and Filtering

`GET /workspaces/<id>/drafts` supports:

- `page`
- `per_page`
- `status`
- `q`
- `source_channel_ids` as comma-separated IDs
- `scraped_from_utc`
- `scraped_to_utc`

Defaults:

- `per_page=20`
- published items are separated from active drafts by status filtering

## Scrape Behavior

`POST /workspaces/<id>/scrape` supports optional per-run overrides:

```json
{
  "message_count": 20,
  "from_date_utc": "2026-06-01T00:00:00Z",
  "to_date_utc": "2026-06-09T23:59:59Z"
}
```

If the request omits these values, each source channel falls back to its saved defaults. If a source also has no defaults, the server uses its internal rule.

## Health Checks and Mobile Connection Setup

`GET /system/health` now returns:

- backend reachability
- SQLite readiness
- Ollama reachability
- generation model readiness
- embedding model readiness
- admin-account readiness
- detected server IPs
- preferred mobile base URL

This is what powers the in-app connection setup checklist.

## Database Model Summary

Main tables:

- `users`
- `style_profiles`
- `workspaces`
- `source_channels`
- `scraped_posts`
- `queue`
- `queue_source_posts`
- `posted_content`
- `post_history`
- `schedule_config`

The schema lives in [app/models/schema.sql](app/models/schema.sql).

## Troubleshooting

### Phone cannot connect

- Do not use `127.0.0.1` or `localhost` from a physical phone.
- Use the backend computer's LAN IP.
- Confirm the phone and backend are on the same Wi-Fi or LAN.
- Verify Windows Firewall allows inbound TCP on port `5000`.
- Open `http://YOUR_IP:5000/api/v1/system/health` in the phone browser.

### Ollama unreachable or model missing

- Confirm Ollama is running.
- Confirm `OLLAMA_BASE_URL` includes `/api`.
- Pull both required models:

```powershell
ollama pull qwen3.5:0.8b
ollama pull qwen3-embedding:0.6b
```

### Telegram scraper not authorized

Run:

```powershell
python authenticate_scraper.py
```

### Bot token validation fails

Check that the token is valid and came from BotFather. Workspace creation validates bot tokens against Telegram.

### Database errors after schema changes

If your local DB was created before newer fields such as multi-source draft data or source default scrape rules were added, recreate or migrate the database before continuing.

## Useful Files

- `wsgi.py`
- `app/api/__init__.py`
- `app/api/workspaces.py`
- `app/api/queue.py`
- `app/api/system.py`
- `app/services/scheduler.py`
- `app/services/ollama.py`
- `app/models/schema.sql`

## Stop The Server

Press `Ctrl+C` in the terminal running `python wsgi.py`.

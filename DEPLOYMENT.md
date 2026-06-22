# Telpozt Deployment Guide

This guide walks through deploying:

- the frontend at `https://telpozt.opalbeauty-et.com`
- the Flask backend at `https://api.telpozt.opalbeauty-et.com`
- the Telegram bot webhook
- the Telegram Mini App entrypoint

It is written for your current repo state and your current domains.

## 1. Final architecture

Use this layout:

- Frontend: `https://telpozt.opalbeauty-et.com`
- Backend API: `https://api.telpozt.opalbeauty-et.com`
- Backend health check: `https://api.telpozt.opalbeauty-et.com/api/v1/system/health`
- Telegram webhook endpoint: `https://api.telpozt.opalbeauty-et.com/api/v1/webhook/telegram`

Important repo-specific behavior:

- The frontend authenticates through Telegram Mini App `initData`.
- The backend validates that `initData` against your bot token.
- The backend only allows the Telegram user whose ID matches `ADMIN_TELEGRAM_CHAT_ID`.
- The current checked-in backend code requires `HF_API_KEY`.
- The backend scraper also requires a Telethon user session file, not just the bot token.

## 2. What you need before touching cPanel

Prepare these values first:

- Telegram bot token from `@BotFather`
- Telegram bot username, for example `your_bot_username`
- Telegram API ID from `https://my.telegram.org`
- Telegram API hash from `https://my.telegram.org`
- Hugging Face API key
- Your Telegram personal chat ID, which will become `ADMIN_TELEGRAM_CHAT_ID`

## 3. Get Telegram API ID and hash

The scraper uses Telethon, so you must create Telegram API credentials for your personal Telegram account.

Steps:

1. Log in at `https://my.telegram.org`
2. Open `API development tools`
3. Create an application
4. Copy:
   - `api_id`
   - `api_hash`

You will use them as:

- `TELEGRAM_API_ID`
- `TELEGRAM_API_HASH`

## 4. Get your Telegram admin chat ID

The backend only allows one Telegram user into the Mini App. That user ID must match `ADMIN_TELEGRAM_CHAT_ID`.

Steps:

1. Open your bot in Telegram.
2. Send `/start` to the bot from the Telegram account that should own the app.
3. In a browser, open:

```text
https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates
```

4. Find your message in the JSON.
5. Copy `message.chat.id`.

Example:

```json
{
  "message": {
    "chat": {
      "id": 123456789
    }
  }
}
```

Then:

- `ADMIN_TELEGRAM_CHAT_ID=123456789`

Important:

- Do this before setting the webhook, because once a webhook is active, `getUpdates` will no longer work for normal polling-based inspection.

## 5. Prepare the backend locally first

Do this on your own machine before uploading to cPanel.

From the `server` folder:

```powershell
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

Create a local `.env` based on [server/.env.example](C:\Users\hamdi\Documents\Programming\Misc\telpozt\server\.env.example).

Use values like this:

```env
FLASK_SECRET_KEY=replace_with_random_secret
HF_API_KEY=replace_with_huggingface_key
CRON_SECRET_KEY=replace_with_random_secret
TELEGRAM_BOT_TOKEN=replace_with_bot_token
TELEGRAM_API_ID=replace_with_api_id
TELEGRAM_API_HASH=replace_with_api_hash
TELETHON_SESSION_PATH=./sessions/scraper.session
ADMIN_TELEGRAM_CHAT_ID=replace_with_your_chat_id
DEDUP_SIMILARITY_THRESHOLD=0.85
DEDUP_LOOKBACK_DAYS=30
```

Generate secure secrets with:

```powershell
python -c "import secrets; print(secrets.token_hex(32))"
```

## 6. Create the Telethon session locally

This step authorizes the Telegram account that will read source channels.

From the `server` folder:

```powershell
.\venv\Scripts\Activate.ps1
python authenticate_scraper.py
```

It will ask for:

- your Telegram phone number
- the code sent by Telegram
- your two-factor password if enabled

When it succeeds, you should have:

- `server/sessions/scraper.session`

You must upload this session file to cPanel later.

Important:

- This is a user session, not the bot token.
- The Telegram account used here must actually have access to the channels you want to scrape.

## 7. Create the cPanel subdomains

You already created:

- `telpozt.opalbeauty-et.com`
- `api.telpozt.opalbeauty-et.com`

Verify in cPanel that both exist and each has its own document root.

Recommended document roots:

- `telpozt.opalbeauty-et.com` -> preferably its own isolated folder such as `subdomains/telpozt` or `domains/telpozt`
- `api.telpozt.opalbeauty-et.com` -> use with Python App / Passenger app root, not static files

Important for your hosting layout:

- You already have a root-domain SPA rewrite in `public_html/.htaccess` for `opalbeauty-et.com`.
- If `telpozt.opalbeauty-et.com` points to a subfolder inside `public_html`, the parent `.htaccess` can affect that subdomain too.
- The safest setup is to give `telpozt.opalbeauty-et.com` its own document root outside `public_html`.
- If your host forces the subdomain under `public_html`, then you must add a subdomain-specific `.htaccess` and test routing carefully.

If you ever need to recreate them in cPanel:

1. Go to `cPanel -> Domains`
2. Click `Create a New Domain`
3. Enter the full subdomain
4. Give it its own document root

## 8. Enable SSL first

Do not continue until HTTPS works on both subdomains.

Check:

- `https://telpozt.opalbeauty-et.com`
- `https://api.telpozt.opalbeauty-et.com`

You need valid HTTPS because Telegram webhooks require an HTTPS URL.

If AutoSSL is available in cPanel, let it finish first.

## 9. Upload the backend code to cPanel

Recommended app path under your cPanel home:

```text
/home/<CPANEL_USER>/apps/telpozt_api
```

Upload the contents of the local `server/` folder into that directory.

Recommended resulting structure:

```text
/home/<CPANEL_USER>/apps/telpozt_api/
  app/
  data/
  sessions/
  requirements.txt
  wsgi.py
  init_db.py
  authenticate_scraper.py
  .env
```

Create these directories if they do not exist:

```bash
mkdir -p ~/apps/telpozt_api/data
mkdir -p ~/apps/telpozt_api/sessions
```

Upload the Telethon session file into:

```text
/home/<CPANEL_USER>/apps/telpozt_api/sessions/scraper.session
```

## 10. Decide which cPanel Python flow you have

There are two common cPanel setups:

### Option A: `Setup Python App`

Usually present on CloudLinux hosting.

Path:

- `cPanel -> Software -> Setup Python App`

### Option B: `Application Manager`

Passenger-based app registration.

Path:

- `cPanel -> Software -> Application Manager`

If you see only one of them, use that one.

If you see neither:

- ask your host to enable Python app support, Passenger, and environment variables for your cPanel account

## 11. Backend deployment with `Setup Python App`

If your host gives you `Setup Python App`, do this:

1. Open `cPanel -> Software -> Setup Python App`
2. Click `Create Application`
3. Set:
   - Python version: `3.x`
   - Application root: `apps/telpozt_api`
   - Application URL: `api.telpozt.opalbeauty-et.com`
   - Application startup file: `passenger_wsgi.py`
   - Application entry point: `application`
4. Create the app

After the app is created, cPanel usually shows a virtualenv path and activation command.

Open `cPanel -> Terminal` and run:

```bash
cd ~/apps/telpozt_api
source <CPANEL_PROVIDED_VENV_PATH>/bin/activate
pip install -r requirements.txt
```

If cPanel created the virtualenv inside the app root, use that path instead.

Then create or edit `passenger_wsgi.py` in `~/apps/telpozt_api` to this:

```python
import os
import sys

PROJECT_ROOT = os.path.dirname(__file__)
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

from wsgi import application
```

Then restart the app from cPanel.

## 12. Backend deployment with `Application Manager`

If your host gives you `Application Manager`, do this:

1. Open `cPanel -> Software -> Application Manager`
2. Click `Register Application`
3. Set:
   - Application name: `telpozt-api`
   - Deployment domain: `api.telpozt.opalbeauty-et.com`
   - Base Application URL: `/`
   - Application path: `apps/telpozt_api`
   - Environment: `Production`
4. Deploy

Then open `cPanel -> Terminal` and run:

```bash
cd ~/apps/telpozt_api
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

Create `passenger_wsgi.py` in `~/apps/telpozt_api` with:

```python
import os
import sys

PROJECT_ROOT = os.path.dirname(__file__)
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

from wsgi import application
```

If your host requires a different startup file, keep the cPanel-generated file and change only its import so it exposes:

```python
from wsgi import application
```

Then redeploy or restart the app from cPanel.

## 13. Add backend environment variables

The backend needs its environment variables in production.

If your cPanel UI supports per-app env vars, add these there.

Otherwise place them in:

```text
/home/<CPANEL_USER>/apps/telpozt_api/.env
```

Use:

```env
FLASK_SECRET_KEY=<random_secret>
HF_API_KEY=<huggingface_api_key>
CRON_SECRET_KEY=<random_secret>
TELEGRAM_BOT_TOKEN=<bot_token>
TELEGRAM_API_ID=<api_id>
TELEGRAM_API_HASH=<api_hash>
TELETHON_SESSION_PATH=./sessions/scraper.session
ADMIN_TELEGRAM_CHAT_ID=<your_chat_id>
DEDUP_SIMILARITY_THRESHOLD=0.85
DEDUP_LOOKBACK_DAYS=30
```

Notes:

- `TELETHON_SESSION_PATH=./sessions/scraper.session` is correct relative to the app root.
- Do not commit the production `.env`.
- The current code reads `.env` with `python-dotenv`.

## 14. Initialize the production database

From `cPanel -> Terminal`:

```bash
cd ~/apps/telpozt_api
source venv/bin/activate
python init_db.py
```

This should create:

```text
~/apps/telpozt_api/data/automation_system.db
```

## 15. Verify the backend before touching Telegram

Open:

```text
https://api.telpozt.opalbeauty-et.com/api/v1/system/health
```

Expected result:

```json
{
  "success": true,
  "data": {
    "status": "ok",
    "message": "Telpozt Backend is running and ready for Telegram Mini App."
  },
  "error": null
}
```

If this fails:

1. check cPanel app logs
2. check Python dependencies
3. check `.env`
4. check that `passenger_wsgi.py` imports `application` correctly

## 16. Check backend logs

Depending on your cPanel mode, the Python app log is commonly:

```text
~/apps/telpozt_api/stderr.log
```

Also check any Passenger or app logs cPanel exposes in the UI.

Useful terminal command:

```bash
tail -n 100 ~/apps/telpozt_api/stderr.log
```

## 17. Deploy the frontend to `telpozt.opalbeauty-et.com`

The frontend should talk to the production backend URL.

In `mini_app/.env.production`, use:

```env
VITE_API_BASE_URL=https://api.telpozt.opalbeauty-et.com/api/v1
```

Do not set `VITE_TG_INIT_DATA` in production.

Build locally:

```powershell
cd mini_app
npm install
npm run build
```

Upload the contents of:

```text
mini_app/dist/
```

to the document root for:

```text
telpozt.opalbeauty-et.com
```

Recommended destination:

```text
/home/<CPANEL_USER>/subdomains/telpozt/
```

If your cPanel already created the subdomain under `public_html/telpozt`, that can still work, but it is less isolated because the root `public_html/.htaccess` may influence requests. In that case:

1. keep a dedicated `.htaccess` inside the `telpozt` subdomain document root
2. test direct loads of nested routes such as:

```text
https://telpozt.opalbeauty-et.com/workspaces
https://telpozt.opalbeauty-et.com/sources
```

3. if those routes redirect incorrectly or load the wrong app, move the subdomain document root outside `public_html`

If your frontend router is client-side only, make sure unknown routes fall back to `index.html`.

Use an `.htaccess` like this in the frontend document root if needed:

```apache
RewriteEngine On
RewriteBase /
RewriteRule ^index\.html$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.html [L]
```

Important with your existing `opalbeauty-et.com` setup:

- If `telpozt.opalbeauty-et.com` has its own separate document root outside `public_html`, your existing root-domain `.htaccess` does not change this guide in any meaningful way.
- If `telpozt.opalbeauty-et.com` lives inside `public_html`, then yes, it changes the hosting recommendation: isolate the subdomain if possible, otherwise verify that the root-domain rewrite rules do not interfere.

## 18. Wire the Telegram bot to the Mini App

Your frontend app URL should be:

```text
https://telpozt.opalbeauty-et.com
```

Telegram supports launching Mini Apps from:

- the menu button
- the bot profile as the main Mini App
- inline buttons

For your setup, the easiest path is:

1. Set the Main Mini App in `@BotFather`
2. Also set the Menu Button to the same URL

### 18.1 Set the Main Mini App

In `@BotFather`:

1. Select your bot
2. Open Bot Settings
3. Find the Main Mini App configuration
4. Set the URL to:

```text
https://telpozt.opalbeauty-et.com
```

This gives the bot an `Open App` button on its profile.

### 18.2 Set the Menu Button

In `@BotFather`:

1. Run `/setmenubutton`
2. Choose your bot
3. Set button text, for example:

```text
Open Telpozt
```

4. Set the URL:

```text
https://telpozt.opalbeauty-et.com
```

## 19. Set the Telegram webhook

Your backend webhook route is:

```text
https://api.telpozt.opalbeauty-et.com/api/v1/webhook/telegram
```

Set it by opening this in a browser:

```text
https://api.telegram.org/bot<YOUR_BOT_TOKEN>/setWebhook?url=https://api.telpozt.opalbeauty-et.com/api/v1/webhook/telegram&drop_pending_updates=true
```

Expected response:

```json
{"ok":true,"result":true,"description":"Webhook was set"}
```

Then verify:

```text
https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getWebhookInfo
```

What to check:

- `url` matches your production webhook URL
- `pending_update_count` is not growing forever
- there is no recent `last_error_message`

Important:

- Telegram sends webhook updates as HTTPS POST requests.
- Telegram-supported webhook ports are `443`, `80`, `88`, and `8443`.
- Standard cPanel HTTPS on `443` is the correct choice.

## 20. Test the bot webhook flow

Your current backend webhook logic handles:

- plain text messages sent to the bot
- callback buttons for draft actions

Test it:

1. Open the bot chat in Telegram
2. Send a plain text message
3. The webhook should store it as a draft and reply with action buttons

If nothing happens:

1. check `getWebhookInfo`
2. check cPanel app logs
3. confirm the backend URL is reachable publicly
4. confirm SSL is valid

## 21. Test the Mini App auth flow

This is the critical production test.

Steps:

1. Open the bot in Telegram with the same Telegram account whose ID you placed in `ADMIN_TELEGRAM_CHAT_ID`
2. Launch the Mini App from the menu button or bot profile
3. The frontend should call the backend using `window.Telegram.WebApp.initData`
4. Protected API calls should work without `VITE_TG_INIT_DATA`

If the Mini App opens but API calls return `401`:

1. confirm `TELEGRAM_BOT_TOKEN` is correct on the backend
2. confirm `ADMIN_TELEGRAM_CHAT_ID` exactly matches your Telegram user ID
3. confirm the app is opened inside Telegram, not a normal browser tab
4. confirm the frontend is using the production backend URL

## 22. Add your first style profile, workspace, and source

Once the Mini App works:

1. Create a style profile
2. Create a workspace
3. Add one source channel
4. Trigger a scrape
5. Open the curation screen and verify candidates appear

If scraping fails:

1. confirm the Telethon session file exists on cPanel
2. confirm the Telegram account used for Telethon can access the source channel
3. check backend logs for Telethon errors

## 23. Production checklist

Before announcing the app live, verify all of this:

- `https://telpozt.opalbeauty-et.com` loads
- `https://api.telpozt.opalbeauty-et.com/api/v1/system/health` returns success
- backend dependencies installed successfully
- `.env` exists on the server
- `scraper.session` uploaded
- `automation_system.db` created
- Telegram webhook set
- `getWebhookInfo` shows no recent errors
- Main Mini App URL configured in `@BotFather`
- Menu button URL configured in `@BotFather`
- app opens inside Telegram
- admin Telegram account can access the app
- at least one workspace and source can be created
- scraping returns candidates

## 24. Common failure cases

### 24.1 Frontend works in browser but not inside Telegram

Likely causes:

- wrong Mini App URL in `@BotFather`
- frontend built with wrong `VITE_API_BASE_URL`
- backend rejects your Telegram user ID

### 24.2 Mini App opens but API returns `401`

Likely causes:

- `ADMIN_TELEGRAM_CHAT_ID` does not match your Telegram user ID
- wrong bot token on server
- app not opened from Telegram

### 24.3 Webhook set succeeds but bot does not respond

Likely causes:

- Flask app crashing
- webhook route unreachable
- SSL issue
- Python app not restarted after code upload

### 24.4 Scraping does not work

Likely causes:

- missing `scraper.session`
- invalid `TELEGRAM_API_ID` or `TELEGRAM_API_HASH`
- Telegram account lacks access to the source channel

### 24.5 Startup crashes after deployment

Likely causes:

- missing `HF_API_KEY`
- missing dependencies
- wrong startup file or wrong WSGI import

## 25. Recommended next improvements after first deployment

These are not required to go live, but they are worth doing next:

1. Add a development-only backend auth bypass so local browser testing does not depend on Telegram.
2. Add webhook secret token validation using `X-Telegram-Bot-Api-Secret-Token`.
3. Make the frontend and backend deployment repeatable with Git-based deploy or CI.
4. Decide whether production embeddings should really use Hugging Face, because the checked-in README still mentions Ollama while the current code uses `HF_API_KEY`.

## 26. Useful commands

### Check health

```text
https://api.telpozt.opalbeauty-et.com/api/v1/system/health
```

### Set webhook

```text
https://api.telegram.org/bot<YOUR_BOT_TOKEN>/setWebhook?url=https://api.telpozt.opalbeauty-et.com/api/v1/webhook/telegram&drop_pending_updates=true
```

### Inspect webhook

```text
https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getWebhookInfo
```

### Inspect updates before webhook is enabled

```text
https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates
```

### Create database

```bash
cd ~/apps/telpozt_api
source venv/bin/activate
python init_db.py
```

### Restart after code changes

Use the restart action in:

- `cPanel -> Software -> Setup Python App`
- or `cPanel -> Software -> Application Manager`

## 27. Source references

These external references informed the deployment flow:

- cPanel Application Manager: `https://docs.cpanel.net/cpanel/software/application-manager/102/`
- cPanel Python WSGI deployment: `https://docs.cpanel.net/knowledge-base/web-services/how-to-install-a-python-wsgi-application/`
- cPanel Passenger notes: `https://docs.cpanel.net/knowledge-base/web-services/using-passenger-applications/`
- cPanel domain/subdomain creation: `https://docs.cpanel.net/cpanel/domains/domains/create-a-new-domain/`
- CloudLinux Setup Python App UI: `https://docs.cloudlinux.com/cloudlinuxos/lve_manager/`
- Telegram Bot API webhook docs: `https://core.telegram.org/bots/api`
- Telegram Mini Apps overview: `https://core.telegram.org/bots/webapps`
- Telegram Telegram API ID creation: `https://core.telegram.org/api/obtaining_api_id`

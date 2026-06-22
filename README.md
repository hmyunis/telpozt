# Telpozt

<p align="center">
  Telegram Mini App for sourcing, curating, and turning channel content into post-ready drafts.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/React-19-111827?logo=react" alt="React 19" />
  <img src="https://img.shields.io/badge/Vite-6-111827?logo=vite" alt="Vite 6" />
  <img src="https://img.shields.io/badge/Flask-3-111827?logo=flask" alt="Flask 3" />
  <img src="https://img.shields.io/badge/SQLite-3-111827?logo=sqlite" alt="SQLite" />
  <img src="https://img.shields.io/badge/Telegram-Mini_App-111827?logo=telegram" alt="Telegram Mini App" />
</p>

---

## What It Is

Telpozt is a two-part system:

- [`mini_app/`](mini_app/) is a React + Vite Telegram Mini App
- [`server/`](server/) is a Flask backend with SQLite, Telethon scraping, Telegram webhook handling, and prompt assembly

The current frontend is wired to the real backend. It no longer relies on frontend mock data.

## Product Flow

```text
Source channels -> Scrape -> Candidate review -> Multi-select -> Prompt generation -> Telegram publishing workflow
```

Core user actions:

- manage workspaces
- manage source channels
- manage style profiles
- review scraped candidates
- generate a combined prompt from selected posts

## Stack

| Layer | Current Tech |
| --- | --- |
| Frontend | React 19, Vite, TypeScript, TanStack Query |
| Backend | Flask, Flask-CORS, Flask-Limiter |
| Data | SQLite |
| Telegram | Telegram Mini App auth, Bot API, Telethon |
| Embeddings | Hugging Face Inference API |

## Repo Layout

```text
telpozt/
├─ mini_app/      React Telegram Mini App
├─ server/        Flask API, DB schema, Telegram integrations
├─ DEPLOYMENT.md  cPanel + Telegram deployment guide
├─ SPEC.md        product and behavior notes
└─ README.md
```

## API Surface

Main backend routes exposed today:

- `GET /api/v1/system/health`
- `GET /api/v1/user/me`
- `GET|POST /api/v1/style-profiles`
- `GET|POST /api/v1/workspaces`
- `GET|PUT /api/v1/workspaces/:id`
- `GET|POST /api/v1/workspaces/:id/source-channels`
- `GET /api/v1/workspaces/:id/candidates`
- `POST /api/v1/workspaces/:id/scrape`
- `POST /api/v1/workspaces/:id/prompt`
- `GET /api/v1/workspaces/:id/queue`
- `GET /api/v1/workspaces/:id/history`
- `POST /api/v1/webhook/telegram`

## Local Development

### Frontend

```powershell
cd mini_app
npm install
npm run dev
```

Use `VITE_API_BASE_URL` to point the mini app at your backend.

### Backend

```powershell
cd server
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
python init_db.py
python wsgi.py
```

Backend env values are described in [server/.env.example](server/.env.example).

Important current requirement:

- the checked-in backend expects `HF_API_KEY`
- protected routes expect Telegram Mini App `initData`

## Deployment

Use [DEPLOYMENT.md](DEPLOYMENT.md) for the production setup covering:

- cPanel Python app hosting
- frontend hosting
- Telegram bot wiring
- webhook registration
- Telethon session upload

## Notes

- The root `README.md` you may have seen previously was stale.
- The codebase is currently React-based, not Flutter-based.
- The current backend config uses Hugging Face embeddings, not the older Ollama path described in some older notes.

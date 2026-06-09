# Telpozt

Telpozt is a local-first Telegram content workflow for turning scraped source messages into polished post drafts.

It combines:

- a Flutter client for Android, iOS, desktop, and web
- a Flask backend with SQLite persistence
- Telegram scraping and posting
- local Ollama models on the same LAN or Wi-Fi as the mobile device

The current product flow is draft-first:

1. `Find Content` scrapes one or more configured source channels.
2. The user reviews the candidate messages from that scrape run.
3. The user selects one or more source items.
4. Telpozt generates one merged draft.
5. The user edits, regenerates, saves, posts now, or schedules later.

Internal queue/state-machine storage still exists in the backend, but the user-facing app centers on `candidates`, `drafts`, and `published posts`.

## Current Features

- Local Ollama generation using `qwen3.5:0.8b`
- Local Ollama embeddings using `qwen3-embedding:0.6b`
- Robust mobile-to-backend connection setup with automatic health checks
- Workspace-based publishing setup
- Style profiles for tone, structure, length, CTA, hashtags, and custom instructions
- Source channel management with:
  - add, edit, delete
  - priority
  - default scrape message count
  - default lookback days
  - active/inactive toggles
- Per-run scrape overrides:
  - message count
  - date range
- Candidate review with multi-select draft generation
- Draft composer with:
  - editable generated text
  - selected source previews
  - expandable original scraped messages
  - source metadata such as posted time and view count
  - regenerate with optional inline suggestion
  - copy full external-AI prompt to clipboard
  - save draft
  - post now
  - schedule
- Draft deletion with permanent backend removal
- Draft listing with:
  - server-side pagination
  - server-side search by content
  - multi-source filters
  - scraped-date filtering
- Published history view
- Schedule configuration per workspace
- Biometric app lock
- Light and dark themes

## Repository Layout

```text
telpozt/
├─ client/   Flutter app
├─ server/   Flask API, SQLite schema, scraping, generation, scheduling
└─ README.md
```

## Tech Stack

### Client

- Flutter
- Riverpod
- GoRouter
- Dio
- Local auth

### Server

- Flask
- SQLite
- APScheduler
- Telethon
- python-telegram-bot
- Ollama

## Local Development

### 1. Start the backend

Use the backend setup guide in [server/README.md](server/README.md).

At minimum, you need:

- Python 3.11+
- a configured `.env`
- Ollama running with:
  - `qwen3.5:0.8b`
  - `qwen3-embedding:0.6b`

### 2. Start the Flutter client

```powershell
cd client
flutter pub get
flutter run
```

For a physical phone, the app should point to the backend computer's LAN URL, for example:

```text
http://192.168.1.23:5000/api/v1
```

Do not use `127.0.0.1` or `localhost` from a separate mobile device.

## Android APK

A shareable Android release APK can be built from `client/` with:

```powershell
flutter build apk --release
```

The output path is:

```text
client/build/app/outputs/flutter-apk/app-release.apk
```

## Backend Overview

Key backend resources:

- `GET /api/v1/system/health`
- `POST /api/v1/auth/register-admin`
- `POST /api/v1/auth/login`
- `GET /api/v1/style-profiles`
- `GET /api/v1/workspaces`
- `POST /api/v1/workspaces/<id>/scrape`
- `GET /api/v1/workspaces/<id>/source-channels`
- `GET /api/v1/workspaces/<id>/drafts`
- `POST /api/v1/workspaces/<id>/drafts`
- `POST /api/v1/workspaces/<id>/drafts/<draft_id>/regenerate`
- `PATCH /api/v1/workspaces/<id>/drafts/<draft_id>/text`
- `POST /api/v1/workspaces/<id>/drafts/<draft_id>/publish`
- `POST /api/v1/workspaces/<id>/drafts/<draft_id>/schedule`
- `DELETE /api/v1/workspaces/<id>/drafts/<draft_id>`
- `GET /api/v1/workspaces/<id>/history`

## Notes

- The backend must be reachable by the phone over the same Wi-Fi or LAN.
- Ollama may run on the same backend machine or another reachable machine on the local network.
- Draft generation is multi-source aware.
- Published posts are stored separately from editable drafts.

## GitHub Readiness

This repository intentionally ignores:

- local backend secrets
- SQLite databases
- Telethon sessions
- Python virtual environments
- Flutter build artifacts
- editor and OS noise

Ignore rules now live in [client/.gitignore](client/.gitignore) and [server/.gitignore](server/.gitignore).

# System Specification: Telpozt (Telegram Mini App & Backend)

## 1. Project Overview & Objective
**Telpozt** is a Telegram content curation and publishing system designed for Telegram Channel Admins. The system aggregates news from multiple source channels, flags duplicates, allows the admin to compile a custom "Mega-Prompt" for an external LLM, and provides a frictionless pipeline for publishing the generated content back to their channels via a Telegram Bot.

The system consists of two parts:
1. **The Backend (`/server`):** A Python Flask application using SQLite, designed to run on a restricted cPanel shared hosting environment.
2. **The Frontend (`/mini_app`):** A React-based Telegram Mini App (Web App) that serves as the admin dashboard.

**The Core Philosophy:** The admin curates content via the Telegram Mini App, generates the content manually using an external AI (like ChatGPT Web), and pastes the final text directly into their Telegram Admin Bot. The bot handles the scheduling and publishing.

## 2. Target Architecture & Tech Stack
*   **Frontend:** React (via Vite), TailwindCSS for styling. Must include the Telegram Web App SDK (`https://telegram.org/js/telegram-web-app.js`).
*   **Backend:** Python 3.11+, Flask.
*   **Database:** SQLite.
*   **Telegram Integrations:**
    *   `Telethon`: Used by the backend to scrape source channels.
    *   `python-telegram-bot` (or raw requests): Used for the Admin Bot webhook (listening for pasted drafts, sending inline keyboards, and publishing to target channels).
*   **AI / Deduplication:** Hugging Face Free Inference API (`sentence-transformers/all-MiniLM-L6-v2`).
*   **Background Jobs:** cPanel Cron Jobs hitting secured backend HTTP endpoints/CLI scripts (no long-running daemon schedulers like `APScheduler`).

## 3. The Core User Workflow
The agent must design the system to support this exact flow:
1.  **Scraping (Background):** A cron job triggers the backend to scrape target Telegram channels using Telethon.
2.  **Deduplication (Background):** The backend sends scraped text to the Hugging Face API to get text embeddings. It compares these vectors against previously published posts using cosine similarity. Highly similar posts are flagged as duplicates.
3.  **Curation (Mini App):** The Admin opens the Telegram Mini App. They see a list of fresh, unique scraped posts. They check the boxes next to 1-3 related posts and tap **"Copy Prompt"**.
4.  **Prompt Generation:** The Mini App copies a "Mega-Prompt" to the device clipboard. This prompt combines the admin's configured "Style Profile" (tone, length, rules) with the raw text of the selected posts.
5.  **External Generation:** The Admin closes the Mini App, pastes the prompt into ChatGPT/Claude, and copies the resulting draft.
6.  **The Drop (Telegram Bot):** The Admin pastes the draft as a direct message to their Telegram Admin Bot.
7.  **Action Routing:** The Bot replies to the message echoing the text with an inline keyboard: `[ 🚀 Post Now ]`, `[ 📅 Schedule ]`, `[ 🗑️ Discard ]`.
8.  **Execution:** The admin clicks a button, and the backend executes the action (posting to the public channel immediately or storing it for a cron job to publish later).

## 4. Frontend Specification (React Telegram Mini App)
The frontend must be built as a responsive, mobile-first Web App designed to be opened *inside* Telegram.

### 4.1 Authentication
*   **No Login Screens:** Authentication is handled entirely by the Telegram Web App SDK. 
*   The frontend extracts `window.Telegram.WebApp.initData` and sends it in the `Authorization` header of all API requests.
*   The backend validates this hash using the Telegram Bot Token to ensure the user is the authorized admin.

### 4.2 Key Screens & Features
*   **Dashboard / Curation View:**
    *   Lists "Scraped Posts" (ignoring ones flagged as duplicates by the backend).
    *   Checkbox UI for multi-selection.
    *   Sticky bottom bar with a "Copy Prompt" button. Clicking this compiles the selected texts alongside the active Workspace's Style Profile into a single string and copies it to the clipboard.
*   **Workspaces Management:**
    *   CRUD for Workspaces. A Workspace defines a `target_channel_id` (where posts go), a `bot_token` (the bot doing the posting), and an assigned `style_profile_id`.
*   **Source Channels Management:**
    *   CRUD for Source Channels linked to a Workspace. Defines which Telegram channels (`@channel_name`) the scraper should monitor.
*   **Style Profiles Management:**
    *   CRUD for Style Profiles. These are configurations (e.g., Tone: Formal, Emoji: None, Structure: Bullet Points) that are translated into text instructions for the Mega-Prompt.

## 5. Backend Specification (Flask)
The existing `/server` folder contains the foundation, but requires specific architectural adjustments to fit the cPanel/HuggingFace/Bot paradigm.

### 5.1 Telegram Bot Webhook (Crucial Component)
The backend must expose a public webhook endpoint for the Telegram Bot.
*   **On receiving text from the Admin:** The backend saves the text to the `queue` table as a `draft`. It immediately replies to the Admin using the Telegram API with inline keyboard buttons containing the `queue_id` in the callback data (e.g., `post_now:123`, `schedule:123`, `discard:123`).
*   **On receiving a callback query:**
    *   `post_now`: Publish the text to the Workspace's target channel, update the DB state to `posted`, edit the bot's message to say "✅ Published".
    *   `schedule`: Update the DB state to `scheduled` (assigning the next available time slot based on Workspace settings), edit the message to say "⏳ Scheduled for [Time]".
    *   `discard`: Delete the record from the DB, delete the message from the chat.

### 5.2 Hugging Face Deduplication
*   Remove all dependencies/code related to local `ollama` generation.
*   Implement a service that sends text to `https://api-inference.huggingface.co/pipeline/feature-extraction/sentence-transformers/all-MiniLM-L6-v2`.
*   Use the resulting vector to calculate cosine similarity against the `embedding` column of the `posted_content` table to prevent the scraper from surfacing old news.

### 5.3 Cron-Friendly Background Jobs
cPanel will forcefully kill long-running Python threads. The system cannot rely on memory-resident schedulers.
*   Create a secured endpoint (e.g., `POST /api/v1/cron/run-all?key=SECURE_SECRET`) or a CLI script.
*   When triggered, this script must synchronously:
    1.  Run the Telethon scraper to fetch new messages from `source_channels`.
    2.  Fetch Hugging Face embeddings for new scraped messages and flag duplicates.
    3.  Check the `queue` table for items where `state == 'scheduled'` and `scheduled_at_utc <= NOW()`, and publish them via the Telegram API.

### 5.4 API Endpoints Required for the Mini App
*   `GET /api/v1/workspaces` (with nested Style Profile data)
*   `GET /api/v1/workspaces/:id/sources`
*   `GET /api/v1/workspaces/:id/candidates` (Returns only unique scraped posts ready for curation)
*   `GET /api/v1/style-profiles`
*   Standard CRUD endpoints for the above entities.

## 6. Implementation Phases for the Agent

**Phase 1: Backend Cleanup & Setup**
1. Audit the existing `/server` codebase. Remove all code related to `Ollama` and `APScheduler`.
2. Implement the `initData` Telegram Web App authentication middleware for Flask routes to replace standard JWT password logins.
3. Integrate the Hugging Face API for text embeddings and wire it into the scraping pipeline.
4. Refactor background tasks into a single run-once function suitable for a cron job trigger.

**Phase 2: Telegram Bot Controller**
1. Implement the Webhook handler in Flask to process incoming Telegram messages from the Admin.
2. Implement the logic to save pasted text as drafts and return the inline keyboard.
3. Implement the callback query handlers (`post_now`, `schedule`, `discard`).

**Phase 3: React Mini App Frontend**
1. Initialize a new Vite + React + Tailwind project in a `/mini_app` directory.
2. Implement the Telegram Web App SDK and setup the API client to pass the auth hash.
3. Build the Dashboard (Candidate list + Checkboxes + Copy Prompt logic).
4. Build the Configuration screens (Workspaces, Sources, Style Profiles).

**Phase 4: Integration & Testing**
1. Ensure the prompt copied by the frontend accurately merges the Style Profile text with the scraped texts.
2. Ensure the full lifecycle works: Cron Scrapes -> Admin Copies Prompt -> Admin Pastes to Bot -> Bot Publishes to Channel.
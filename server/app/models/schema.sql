PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS users (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    username        TEXT NOT NULL UNIQUE,
    password_hash   TEXT NOT NULL,
    telegram_chat_id TEXT NOT NULL,
    timezone        TEXT NOT NULL DEFAULT 'UTC',
    created_at      TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS style_profiles (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id         INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name            TEXT NOT NULL,
    entity_name     TEXT,
    entity_type     TEXT CHECK(entity_type IN ('company','individual','media_outlet','community')),
    tone            TEXT NOT NULL CHECK(tone IN ('formal','semi_formal','casual','punchy')),
    structure       TEXT NOT NULL CHECK(structure IN ('paragraph','bullet_points','lead_conclusion','inverted_pyramid')),
    length_preset   TEXT NOT NULL CHECK(length_preset IN ('short','medium','long','custom')),
    char_min        INTEGER,
    char_max        INTEGER,
    emoji_usage     TEXT NOT NULL CHECK(emoji_usage IN ('none','minimal','moderate','heavy')),
    jargon_handling TEXT NOT NULL CHECK(jargon_handling IN ('preserve','simplify','explain_inline')),
    call_to_action  TEXT NOT NULL CHECK(call_to_action IN ('none','soft','strong')),
    hashtag_style   TEXT NOT NULL CHECK(hashtag_style IN ('none','minimal','topical')),
    additional_instructions TEXT,
    created_at      TEXT NOT NULL,
    updated_at      TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS workspaces (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id             INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name                TEXT NOT NULL,
    target_channel_id   TEXT NOT NULL,
    bot_token           TEXT NOT NULL,
    style_profile_id    INTEGER REFERENCES style_profiles(id) ON DELETE SET NULL,
    is_active           INTEGER NOT NULL DEFAULT 1,
    created_at          TEXT NOT NULL,
    updated_at          TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS source_channels (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    workspace_id    INTEGER NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    channel_id      TEXT NOT NULL,
    display_name    TEXT,
    priority        TEXT NOT NULL DEFAULT 'normal' CHECK(priority IN ('high','normal','low')),
    default_scrape_message_count INTEGER,
    default_lookback_days INTEGER,
    is_active       INTEGER NOT NULL DEFAULT 1,
    last_scraped_at TEXT,
    last_message_id INTEGER DEFAULT 0,
    created_at      TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS scraped_posts (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    source_channel_id INTEGER NOT NULL REFERENCES source_channels(id) ON DELETE CASCADE,
    telegram_message_id INTEGER NOT NULL,
    raw_text        TEXT NOT NULL,
    original_posted_at_utc TEXT,
    view_count      INTEGER,
    content_hash    TEXT NOT NULL,
    embedding       BLOB,
    embedding_status TEXT NOT NULL DEFAULT 'pending' CHECK(embedding_status IN ('pending','done','failed')),
    dedup_status    TEXT NOT NULL DEFAULT 'pending' CHECK(dedup_status IN ('pending','duplicate','unique','manual_review')),
    duplicate_of_id INTEGER REFERENCES scraped_posts(id),
    similarity_score REAL,
    scraped_at      TEXT NOT NULL,
    UNIQUE(source_channel_id, telegram_message_id)
);

CREATE TABLE IF NOT EXISTS posted_content (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    workspace_id    INTEGER NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    content_hash    TEXT NOT NULL,
    embedding       BLOB NOT NULL,
    summary_topic   TEXT,
    posted_at       TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_posted_content_workspace ON posted_content(workspace_id);

CREATE TABLE IF NOT EXISTS queue (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    workspace_id        INTEGER NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    scraped_post_id     INTEGER REFERENCES scraped_posts(id) ON DELETE SET NULL,
    raw_source_text     TEXT NOT NULL,
    generated_text      TEXT,
    last_generation_instruction TEXT,
    generation_status   TEXT NOT NULL DEFAULT 'pending' CHECK(generation_status IN ('pending','generating','done','failed')),
    state               TEXT NOT NULL DEFAULT 'draft' CHECK(state IN ('draft','approved','scheduled','posting','posted','cancelled','failed')),
    scheduled_at_utc    TEXT,
    posted_at_utc       TEXT,
    failure_reason      TEXT,
    retry_count         INTEGER NOT NULL DEFAULT 0,
    created_at          TEXT NOT NULL,
    updated_at          TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_queue_workspace_state ON queue(workspace_id, state);
CREATE INDEX IF NOT EXISTS idx_queue_scheduled ON queue(scheduled_at_utc) WHERE state = 'scheduled';

CREATE TABLE IF NOT EXISTS queue_source_posts (
    queue_id         INTEGER NOT NULL REFERENCES queue(id) ON DELETE CASCADE,
    scraped_post_id  INTEGER NOT NULL REFERENCES scraped_posts(id) ON DELETE CASCADE,
    position         INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY(queue_id, scraped_post_id)
);
CREATE INDEX IF NOT EXISTS idx_queue_source_posts_queue ON queue_source_posts(queue_id, position);

CREATE TABLE IF NOT EXISTS post_history (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    queue_id        INTEGER NOT NULL REFERENCES queue(id),
    workspace_id    INTEGER NOT NULL REFERENCES workspaces(id),
    final_text      TEXT NOT NULL,
    source_channel  TEXT,
    telegram_message_id TEXT,
    posted_at_utc   TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS schedule_config (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    workspace_id    INTEGER NOT NULL UNIQUE REFERENCES workspaces(id) ON DELETE CASCADE,
    time_slots      TEXT NOT NULL,
    timezone        TEXT NOT NULL,
    is_enabled      INTEGER NOT NULL DEFAULT 1,
    updated_at      TEXT NOT NULL
);

import logging
import json
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo
from app.config import Config
from app.models.db import get_db_connection
from app.services.deduplication import calculate_sha256_hash, calculate_cosine_similarity, parse_blob_to_vector
from app.services.huggingface import get_text_embedding
from app.services.telethon_client import scrape_channel_messages
from app.services.telegram_bot import send_telegram_message, send_admin_notification
from app.utils.timezone import get_current_utc_iso

logger = logging.getLogger(__name__)

def _resolve_scrape_limit(source_row) -> int:
    return max(1, int(source_row["default_scrape_message_count"])) if source_row["default_scrape_message_count"] else 20

def run_all_cron_jobs():
    logger.info("Executing unified cron pipeline...")
    _scrape_channels()
    _generate_embeddings_and_dedup()
    _publish_scheduled_posts()

def _scrape_channels():
    with get_db_connection() as conn:
        active_sources = conn.execute("SELECT * FROM source_channels WHERE is_active = 1").fetchall()
        for src in active_sources:
            limit = _resolve_scrape_limit(src)
            posts = scrape_channel_messages(src["channel_id"], src["last_message_id"], limit=limit)
            
            for post in posts:
                raw_text = post["text"]
                msg_id = post["id"]
                c_hash = calculate_sha256_hash(raw_text)
                
                existing = conn.execute("SELECT id FROM scraped_posts WHERE content_hash = ?", (c_hash,)).fetchone()
                dedup_status = "duplicate" if existing else "pending"
                
                try:
                    conn.execute(
                        """INSERT INTO scraped_posts (
                            source_channel_id, telegram_message_id, raw_text, content_hash,
                            original_posted_at_utc, view_count, embedding_status, dedup_status, scraped_at
                           ) VALUES (?, ?, ?, ?, ?, ?, 'pending', ?, ?)""",
                        (src["id"], msg_id, raw_text, c_hash, post.get("date"), post.get("views"), dedup_status, get_current_utc_iso())
                    )
                except Exception as e:
                    pass

            if posts:
                max_msg_id = max(post["id"] for post in posts)
                conn.execute("UPDATE source_channels SET last_message_id = ?, last_scraped_at = ? WHERE id = ?", (max_msg_id, get_current_utc_iso(), src["id"]))
                conn.commit()

def _generate_embeddings_and_dedup():
    with get_db_connection() as conn:
        pending = conn.execute("SELECT id, raw_text, source_channel_id FROM scraped_posts WHERE embedding_status = 'pending' AND dedup_status = 'pending' LIMIT 50").fetchall()
        
        for post in pending:
            vector = get_text_embedding(post["raw_text"])
            if not vector:
                continue
                
            vector_blob = json.dumps(vector).encode("utf-8")
            conn.execute("UPDATE scraped_posts SET embedding = ?, embedding_status = 'done' WHERE id = ?", (vector_blob, post["id"]))
            
            ws_id = conn.execute("SELECT workspace_id FROM source_channels WHERE id = ?", (post["source_channel_id"],)).fetchone()["workspace_id"]
            cutoff_date = (datetime.now(ZoneInfo("UTC")) - timedelta(days=Config.DEDUP_LOOKBACK_DAYS)).isoformat()
            
            references = conn.execute("SELECT id, embedding FROM posted_content WHERE workspace_id = ? AND posted_at >= ?", (ws_id, cutoff_date)).fetchall()
            
            is_dup = False
            for ref in references:
                ref_vec = parse_blob_to_vector(ref["embedding"])
                sim = calculate_cosine_similarity(vector, ref_vec)
                if sim >= Config.DEDUP_SIMILARITY_THRESHOLD:
                    conn.execute("UPDATE scraped_posts SET dedup_status = 'duplicate', similarity_score = ?, duplicate_of_id = ? WHERE id = ?", (sim, ref["id"], post["id"]))
                    is_dup = True
                    break
                    
            if not is_dup:
                conn.execute("UPDATE scraped_posts SET dedup_status = 'unique' WHERE id = ?", (post["id"],))
            
            conn.commit()

def _publish_scheduled_posts():
    now_utc = get_current_utc_iso()
    with get_db_connection() as conn:
        targets = conn.execute("SELECT * FROM queue WHERE state = 'scheduled' AND scheduled_at_utc <= ?", (now_utc,)).fetchall()
        
        for t in targets:
            ws = conn.execute("SELECT * FROM workspaces WHERE id = ?", (t["workspace_id"],)).fetchone()
            try:
                response = send_telegram_message(ws["bot_token"], ws["target_channel_id"], t["generated_text"])
                conn.execute("UPDATE queue SET state = 'posted', posted_at_utc = ?, updated_at = ? WHERE id = ?", (now_utc, now_utc, t["id"]))
                
                vector = get_text_embedding(t["generated_text"])
                vector_blob = json.dumps(vector).encode("utf-8") if vector else b""
                
                conn.execute(
                    "INSERT INTO posted_content (workspace_id, content_hash, embedding, posted_at) VALUES (?, ?, ?, ?)",
                    (t["workspace_id"], calculate_sha256_hash(t["generated_text"]), vector_blob, now_utc)
                )
                conn.commit()
            except Exception as e:
                logger.error(f"Failed to publish scheduled post {t['id']}: {e}")

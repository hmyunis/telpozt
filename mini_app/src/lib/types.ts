export interface Workspace {
  id: number;
  name: string;
  target_channel_id: string;
  bot_token: string;
  style_profile_id: number | null;
  is_active: number;
}

export interface Candidate {
  id: number;
  raw_text: string;
  source_channel: string;
  original_posted_at_utc: string | null;
  view_count: number | null;
}

export interface PaginationMeta {
  total_count: number;
  total_pages: number;
  current_page: number;
  limit: number;
}

export interface PaginatedCandidates {
  candidates: Candidate[];
  pagination: PaginationMeta;
}

export interface SourceChannel {
  id: number;
  workspace_id: number;
  channel_id: string;
  display_name: string | null;
  priority: 'high' | 'normal' | 'low';
  is_active: number;
  status?: 'online' | 'rate_limited' | 'offline';
  last_scraped_at?: string | null;
  created_at?: string;
}

export interface StyleProfile {
  id: number;
  name: string;
  entity_name: string | null;
  entity_type: string | null;
  tone: 'formal' | 'semi_formal' | 'casual' | 'punchy';
  structure: 'paragraph' | 'bullet_points' | 'lead_conclusion' | 'inverted_pyramid';
  length_preset: 'short' | 'medium' | 'long' | 'custom';
  char_min: number | null;
  char_max: number | null;
  emoji_usage: 'none' | 'minimal' | 'moderate' | 'heavy';
  jargon_handling: 'preserve' | 'simplify' | 'explain_inline';
  call_to_action: 'none' | 'soft' | 'strong';
  hashtag_style: 'none' | 'minimal' | 'topical';
  additional_instructions?: string | null;
}

export interface WorkspaceAnalytics {
  prompts_generated: number;
  posts_processed: number;
  total_candidates: number;
  active_sources: number;
  weekly_activity: Array<{
    day: string;
    count: number;
  }>;
}

export interface ApiUser {
  id: number;
  username: string;
  telegram_chat_id: string;
  timezone: string;
  created_at: string;
}

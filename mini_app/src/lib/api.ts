import {
  ApiUser,
  Candidate,
  PaginatedCandidates,
  SourceChannel,
  StyleProfile,
  Workspace,
  WorkspaceAnalytics,
} from './types';

const API_BASE_URL = (import.meta.env.VITE_API_BASE_URL || 'http://127.0.0.1:5000/api/v1').replace(/\/$/, '');

type ApiEnvelope<T> = {
  success: boolean;
  data: T;
  error?: {
    code?: string;
    message?: string;
  } | null;
};

type QueueResponse = {
  items: Array<{ id: number }>;
  meta: {
    page: number;
    per_page: number;
    total_items: number;
    total_pages: number;
  };
};

type HistoryResponse = QueueResponse;

function getTelegramInitData(): string {
  const tg = (window as Window & { Telegram?: { WebApp?: { initData?: string } } }).Telegram?.WebApp;
  return tg?.initData || import.meta.env.VITE_TG_INIT_DATA || localStorage.getItem('tg_init_data') || '';
}

async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
  const headers = new Headers(init.headers);
  headers.set('Accept', 'application/json');

  const auth = getTelegramInitData();
  if (auth) {
    headers.set('Authorization', `tma ${auth}`);
  }

  if (init.body && !(init.body instanceof FormData) && !headers.has('Content-Type')) {
    headers.set('Content-Type', 'application/json');
  }

  const response = await fetch(`${API_BASE_URL}${path}`, {
    ...init,
    headers,
  });

  const payload = (await response.json().catch(() => null)) as ApiEnvelope<T> | null;

  if (!response.ok || !payload?.success) {
    const message =
      payload?.error?.message ||
      `Request failed with status ${response.status}`;
    throw new Error(message);
  }

  return payload.data;
}

function normalizeSource(source: SourceChannel): SourceChannel {
  const status: SourceChannel['status'] =
    source.is_active === 0 ? 'offline' : source.last_scraped_at ? 'online' : 'offline';

  return {
    ...source,
    status,
  };
}

function filterAndPaginateCandidates(
  candidates: Candidate[],
  params?: { page?: number; limit?: number; search?: string; filter?: string },
): PaginatedCandidates {
  let filtered = [...candidates];

  if (params?.search) {
    const needle = params.search.toLowerCase();
    filtered = filtered.filter(
      (candidate) =>
        candidate.raw_text.toLowerCase().includes(needle) ||
        candidate.source_channel.toLowerCase().includes(needle),
    );
  }

  if (params?.filter === 'high_views') {
    filtered.sort((a, b) => (b.view_count || 0) - (a.view_count || 0));
  } else if (params?.filter === 'newest') {
    filtered.sort((a, b) => {
      const left = a.original_posted_at_utc ? Date.parse(a.original_posted_at_utc) : 0;
      const right = b.original_posted_at_utc ? Date.parse(b.original_posted_at_utc) : 0;
      return right - left;
    });
  }

  const limit = params?.limit || 10;
  const page = params?.page || 1;
  const totalCount = filtered.length;
  const totalPages = Math.max(1, Math.ceil(totalCount / limit));
  const offset = (page - 1) * limit;

  return {
    candidates: filtered.slice(offset, offset + limit),
    pagination: {
      total_count: totalCount,
      total_pages: totalPages,
      current_page: page,
      limit,
    },
  };
}

function buildWeeklyActivity(candidates: Candidate[]): WorkspaceAnalytics['weekly_activity'] {
  const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  const counts = new Map<string, number>(days.map((day) => [day, 0]));
  const now = new Date();
  const cutoff = now.getTime() - 7 * 24 * 60 * 60 * 1000;

  for (const candidate of candidates) {
    if (!candidate.original_posted_at_utc) continue;
    const timestamp = Date.parse(candidate.original_posted_at_utc);
    if (Number.isNaN(timestamp) || timestamp < cutoff) continue;
    const day = days[new Date(timestamp).getDay()];
    counts.set(day, (counts.get(day) || 0) + 1);
  }

  return days.map((day) => ({
    day,
    count: counts.get(day) || 0,
  }));
}

function toStyleProfilePayload(data: Partial<StyleProfile>) {
  return {
    name: data.name || 'New Profile',
    entity_name: data.entity_name ?? null,
    entity_type: data.entity_type ?? null,
    tone: data.tone || 'semi_formal',
    structure: data.structure || 'bullet_points',
    length_preset: data.length_preset || 'medium',
    char_min: data.length_preset === 'custom' ? data.char_min ?? null : null,
    char_max: data.length_preset === 'custom' ? data.char_max ?? null : null,
    emoji_usage: data.emoji_usage || 'minimal',
    jargon_handling: data.jargon_handling || 'simplify',
    call_to_action: data.call_to_action || 'none',
    hashtag_style: data.hashtag_style || 'none',
    additional_instructions: data.additional_instructions ?? null,
  };
}

export const api = {
  getCurrentUser: async () => request<ApiUser>('/user/me'),

  getWorkspaces: async () => request<Workspace[]>('/workspaces'),

  createWorkspace: async (data: Partial<Workspace>) =>
    request<Workspace>('/workspaces', {
      method: 'POST',
      body: JSON.stringify({
        name: data.name,
        target_channel_id: data.target_channel_id,
        bot_token: data.bot_token,
        style_profile_id: data.style_profile_id ?? null,
      }),
    }),

  updateWorkspace: async (id: number, data: Partial<Workspace>) =>
    request<Workspace>(`/workspaces/${id}`, {
      method: 'PUT',
      body: JSON.stringify(data),
    }),

  getCandidates: async (
    workspaceId: number,
    params?: { page?: number; limit?: number; search?: string; filter?: string },
  ) => {
    const candidates = await request<Candidate[]>(`/workspaces/${workspaceId}/candidates`);
    return filterAndPaginateCandidates(candidates, params);
  },

  generatePrompt: async (workspaceId: number, postIds: number[]) =>
    request<{ prompt: string }>(`/workspaces/${workspaceId}/prompt`, {
      method: 'POST',
      body: JSON.stringify({ post_ids: postIds }),
    }),

  getSources: async (workspaceId: number) => {
    const sources = await request<SourceChannel[]>(`/workspaces/${workspaceId}/source-channels`);
    return sources.map(normalizeSource);
  },

  createSource: async (data: Partial<SourceChannel>) => {
    if (!data.workspace_id) {
      throw new Error('workspace_id is required to create a source channel.');
    }

    const source = await request<SourceChannel>(`/workspaces/${data.workspace_id}/source-channels`, {
      method: 'POST',
      body: JSON.stringify({
        channel_id: data.channel_id,
        display_name: data.display_name ?? null,
        priority: data.priority || 'normal',
      }),
    });

    return normalizeSource(source);
  },

  updateSource: async (workspaceId: number, id: number, data: Partial<SourceChannel>) => {
    const source = await request<SourceChannel>(`/workspaces/${workspaceId}/source-channels/${id}`, {
      method: 'PUT',
      body: JSON.stringify({
        channel_id: data.channel_id,
        display_name: data.display_name ?? null,
        priority: data.priority,
        is_active: data.is_active,
      }),
    });

    return normalizeSource(source);
  },

  triggerWorkspaceScrape: async (workspaceId: number) =>
    request<{ message: string }>(`/workspaces/${workspaceId}/scrape`, {
      method: 'POST',
      body: JSON.stringify({}),
    }),

  getWorkspaceAnalytics: async (workspaceId: number) => {
    const [sources, candidates, queue, history] = await Promise.all([
      api.getSources(workspaceId),
      request<Candidate[]>(`/workspaces/${workspaceId}/candidates`),
      request<QueueResponse>(`/workspaces/${workspaceId}/queue?per_page=1`),
      request<HistoryResponse>(`/workspaces/${workspaceId}/history?per_page=1`),
    ]);

    return {
      prompts_generated: queue.meta.total_items,
      posts_processed: history.meta.total_items,
      total_candidates: candidates.length,
      active_sources: sources.filter((source) => source.is_active === 1).length,
      weekly_activity: buildWeeklyActivity(candidates),
    } satisfies WorkspaceAnalytics;
  },

  getStyleProfiles: async () => request<StyleProfile[]>('/style-profiles'),

  createStyleProfile: async (data: Partial<StyleProfile>) =>
    request<StyleProfile>('/style-profiles', {
      method: 'POST',
      body: JSON.stringify(toStyleProfilePayload(data)),
    }),

  updateStyleProfile: async (id: number, data: Partial<StyleProfile>) =>
    request<StyleProfile>(`/style-profiles/${id}`, {
      method: 'PUT',
      body: JSON.stringify(toStyleProfilePayload(data)),
    }),
};

import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { toast } from 'sonner';
import { api } from '../lib/api';
import { Workspace, Candidate } from '../lib/types';
import { Card, Button, FormHeader, ErrorState, Chip, Input } from '../components/custom';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../components/ui/select';
import { Checkbox } from '../components/ui/checkbox';
import { Skeleton } from '../components/ui/skeleton';
import { Drawer } from 'vaul';
import { ChevronDown, Copy, Eye, Clock, RefreshCw, Radio, TrendingUp, Sparkles, Layers, Plus, BarChart3, LayoutGrid, Filter, Search, X } from 'lucide-react';
import { usePullToRefresh } from '../hooks/usePullToRefresh';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';

export default function Curation() {
  const queryClient = useQueryClient();

  const { data: workspaces = [], isLoading: workspacesLoading, error: workspacesError } = useQuery<Workspace[]>({
    queryKey: ['workspaces'],
    queryFn: api.getWorkspaces,
  });

  const [activeWorkspaceId, setActiveWorkspaceId] = useState<number | null>(null);
  const [selectedIds, setSelectedIds] = useState<Set<number>>(new Set());
  const [detailCandidate, setDetailCandidate] = useState<Candidate | null>(null);
  const [filter, setFilter] = useState<'all' | 'high_views' | 'newest'>('all');
  const [searchQuery, setSearchQuery] = useState('');
  const [debouncedSearch, setDebouncedSearch] = useState('');
  const [page, setPage] = useState(1);

  // Filter Collapse state
  const [collapseFilters, setCollapseFilters] = useState(true);

  // Analytics state
  const [showAnalytics, setShowAnalytics] = useState(false);

  // Debounce search query to prevent hammering the server with every keystroke
  useEffect(() => {
    const handler = setTimeout(() => {
      setDebouncedSearch(searchQuery);
    }, 300);
    return () => clearTimeout(handler);
  }, [searchQuery]);

  // Reset page to 1 on filter or search parameters updates
  useEffect(() => {
    setPage(1);
    setSelectedIds(new Set());
  }, [activeWorkspaceId, filter, debouncedSearch]);

  // Keep state for active workspace, sync it when workspaces are available
  useEffect(() => {
    if (workspaces.length > 0 && !activeWorkspaceId) {
      setActiveWorkspaceId(workspaces[0].id);
    }
  }, [workspaces, activeWorkspaceId]);

  const { data: candidatesData, isLoading: candidatesLoading, error: candidatesError, refetch: refetchCandidates } = useQuery({
    queryKey: ['candidates', activeWorkspaceId, page, filter, debouncedSearch],
    queryFn: () => api.getCandidates(activeWorkspaceId!, { page, limit: 5, filter, search: debouncedSearch }),
    enabled: !!activeWorkspaceId,
  });

  const candidates = candidatesData?.candidates || [];
  const pagination = candidatesData?.pagination || null;

  const { data: analytics = null, isLoading: analyticsLoading } = useQuery({
    queryKey: ['analytics', activeWorkspaceId],
    queryFn: () => api.getWorkspaceAnalytics(activeWorkspaceId!),
    enabled: !!activeWorkspaceId,
  });

  // Pull-to-refresh hook
  const { pullDistance, isRefreshing, containerRef } = usePullToRefresh({
    onRefresh: async () => {
      if (activeWorkspaceId) {
        await refetchCandidates();
      }
    },
    threshold: 60,
    maxPull: 110,
  });

  const generatePromptMutation = useMutation({
    mutationFn: ({ workspaceId, postIds }: { workspaceId: number; postIds: number[] }) => 
      api.generatePrompt(workspaceId, postIds),
    onSuccess: async (res) => {
      await navigator.clipboard.writeText(res.prompt);
      toast.success("Prompt copied to clipboard!");
      setSelectedIds(new Set());
    },
    onError: (e: any) => {
      toast.error("Error: " + (e.message || "Failed to generate prompt"));
    }
  });

  const handleCopyPrompt = () => {
    if (!activeWorkspaceId || selectedIds.size === 0) return;
    generatePromptMutation.mutate({
      workspaceId: activeWorkspaceId,
      postIds: Array.from(selectedIds)
    });
  };

  const toggleSelect = (id: number) => {
    const next = new Set(selectedIds);
    if (next.has(id)) next.delete(id);
    else next.add(id);
    setSelectedIds(next);
  };

  const error = workspacesError || candidatesError;
  const loading = workspacesLoading || (!!activeWorkspaceId && candidatesLoading);
  const loadingAnalytics = analyticsLoading;
  const filteredCandidates = candidates;
  const loadCandidates = (wsId: number) => refetchCandidates();

  if (error) {
    return (
      <ErrorState 
        message={error instanceof Error ? error.message : "Failed to load candidates"} 
        onRetry={() => {
          queryClient.invalidateQueries({ queryKey: ['workspaces'] });
          if (activeWorkspaceId) {
            queryClient.invalidateQueries({ queryKey: ['candidates', activeWorkspaceId] });
            queryClient.invalidateQueries({ queryKey: ['analytics', activeWorkspaceId] });
          }
        }} 
      />
    );
  }

  if (loading && !workspaces.length) {
    return (
      <div className="p-4 space-y-4">
        <Skeleton className="h-12 w-full bg-graphite" />
        <Skeleton className="h-32 w-full bg-graphite" />
        <Skeleton className="h-32 w-full bg-graphite" />
      </div>
    );
  }

  if (!loading && workspaces.length === 0) {
    return (
      <div className="relative min-h-screen flex flex-col pb-24 bg-void">
        <div className="p-6 border-b border-iron bg-obsidian sticky top-0 z-10 shadow-sm">
          <FormHeader subtitle="Review candidates for Mega-Prompt">Curation Queue</FormHeader>
        </div>
        <div className="relative flex flex-col items-center justify-center py-20 px-4 border border-dashed border-iron bg-obsidian/30 rounded-sm overflow-hidden text-center m-4">
          <div className="absolute inset-0 pointer-events-none opacity-10 flex flex-col gap-4 p-4 z-0">
            <Skeleton className="h-32 w-full bg-silver/20" />
            <Skeleton className="h-32 w-full bg-silver/20" />
            <Skeleton className="h-32 w-full bg-silver/20" />
          </div>
          <div className="relative z-10 w-16 h-16 rounded-full bg-graphite flex items-center justify-center mb-4 text-brand-orange shadow-[0_0_15px_rgba(232,102,10,0.15)]">
            <Layers size={32} />
          </div>
          <h3 className="relative z-10 text-white font-display font-medium text-lg uppercase tracking-wider mb-2">Welcome to Curation</h3>
          <p className="relative z-10 text-silver text-xs max-w-sm mb-6 leading-relaxed">
            You need at least one workspace to begin curating content. Head over to the Workspaces tab to get started.
          </p>
          <Link to="/workspaces" className="relative z-10">
            <Button className="flex items-center gap-2">
              <Plus size={16} /> Setup Workspace
            </Button>
          </Link>
        </div>
      </div>
    );
  }

  const activeWorkspaceName = workspaces.find(w => w.id === activeWorkspaceId)?.name || 'Select Workspace';

  return (
    <div 
      ref={containerRef}
      className="relative min-h-screen flex flex-col pb-24 bg-void transition-transform"
    >
      {/* Custom pull-to-refresh spinner (triggers on touch devices / Telegram mobile platform) */}
      <div 
        className="flex flex-col items-center justify-center overflow-hidden transition-all duration-300 bg-obsidian border-b border-iron/45"
        style={{ 
          height: `${pullDistance}px`,
          opacity: pullDistance > 0 ? Math.min(pullDistance / 50, 1) : 0, 
        }}
      >
        <div className="flex flex-col items-center gap-1.5 py-2">
          <div className="relative w-8 h-8 flex items-center justify-center">
            {/* Glow backdrop ring */}
            <div className="absolute inset-x-0.5 inset-y-0.5 rounded-full border-2 border-brand-orange/10" />
            {/* Rotating active ring */}
            <div 
              className={`absolute inset-0 rounded-full border-2 border-transparent border-t-brand-orange border-r-brand-orange/70 ${isRefreshing ? 'animate-spin' : ''}`}
              style={{ 
                transform: isRefreshing ? undefined : `rotate(${pullDistance * 5}deg)`,
                transition: isRefreshing ? undefined : 'transform 0.1s linear'
              }}
            />
            <Sparkles size={11} className={`text-brand-orange-500 text-brand-orange ${isRefreshing ? 'animate-pulse' : ''}`} />
          </div>
          <span className="text-[8px] font-bold font-mono uppercase tracking-[0.2em] text-brand-orange animate-pulse">
            {isRefreshing ? 'Syncing Hub...' : 'Pull to Refresh'}
          </span>
        </div>
      </div>

      <div className="p-4 border-b border-iron/60 bg-obsidian/95 backdrop-blur sticky top-0 z-10 shadow-lg transition-all duration-300">
        <div className="flex items-center justify-between">
          <div className="flex flex-col">
            <span className="text-[8px] font-bold text-silver/60 uppercase tracking-[0.2em] font-mono mb-0.5">CURATION FEED</span>
            <h2 className="text-sm font-black uppercase text-brand-orange leading-none tracking-wide">{activeWorkspaceName}</h2>
          </div>
          <div className="flex items-center gap-1.5">
            <button 
              type="button"
              onClick={() => setShowAnalytics(!showAnalytics)}
              className={`flex items-center justify-center gap-1.5 h-8 px-2.5 border text-[9px] font-mono font-bold uppercase tracking-wider transition-all duration-200 rounded cursor-pointer whitespace-nowrap active:scale-95 ${
                showAnalytics 
                  ? 'border-brand-orange/50 bg-brand-orange/10 text-brand-orange shadow-[0_0_10px_rgba(232,102,10,0.15)]' 
                  : 'border-iron bg-graphite text-silver hover:text-white hover:border-silver'
              }`}
            >
              <BarChart3 size={12} />
              <span>Stats</span>
            </button>
            <button
              type="button"
              onClick={() => setCollapseFilters(!collapseFilters)}
              className={`flex items-center justify-center gap-1 h-8 px-2.5 border text-[9px] font-mono font-bold uppercase tracking-wider transition-all duration-200 rounded cursor-pointer active:scale-95 ${
                !collapseFilters
                  ? 'border-brand-orange/50 bg-brand-orange/10 text-brand-orange'
                  : 'border-iron bg-graphite text-silver hover:text-white'
              }`}
            >
              <Filter size={11} />
              <span>{collapseFilters ? 'Filter' : 'Hide'}</span>
              <ChevronDown size={11} className={`transform transition-transform duration-300 ${!collapseFilters ? 'rotate-180' : ''}`} />
            </button>
          </div>
        </div>

        {/* Global Fuzzy Search Bar */}
        <div className="mt-3 relative">
          <Search size={14} className="absolute left-3 top-2.5 text-ash" />
          <Input 
            type="text"
            placeholder="Fuzzy search candidates (e.g. crto, daily)..."
            className="w-full pl-9 pr-8 text-xs font-mono h-9 bg-graphite border-iron/80"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
          />
          {searchQuery && (
            <button 
              onClick={() => setSearchQuery('')}
              className="absolute right-3 top-2.5 text-ash hover:text-white transition-colors cursor-pointer"
            >
              <X size={14} />
            </button>
          )}
        </div>

        {!collapseFilters && (
          <div className="mt-3 pt-3 border-t border-iron/40 space-y-3 animate-in fade-in duration-200">
            <div>
              <label className="text-[8px] font-bold text-silver/50 uppercase tracking-widest block mb-1 font-mono">Workspace Link</label>
              <Select 
                value={activeWorkspaceId?.toString() || ''}
                onValueChange={(val) => setActiveWorkspaceId(Number(val))}
              >
                <SelectTrigger className="w-full h-8 text-[10px] font-bold uppercase tracking-wider bg-graphite border-iron text-white">
                  <SelectValue placeholder="Select Workspace">
                    {activeWorkspaceName}
                  </SelectValue>
                </SelectTrigger>
                <SelectContent className="bg-graphite border border-iron text-white">
                  {workspaces.map(ws => (
                    <SelectItem key={ws.id} value={ws.id.toString()} className="focus:bg-brand-orange focus:text-white uppercase text-[9px] tracking-widest cursor-pointer">
                      {ws.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div>
              <label className="text-[8px] font-bold text-silver/50 uppercase tracking-widest block mb-1.5 font-mono">Sorting Presets</label>
              <div className="flex items-center gap-1.5 overflow-x-auto pb-0.5 no-scrollbar">
                 <Chip onClick={() => setFilter('all')} selected={filter === 'all'} className="flex items-center gap-1 py-1 px-2.5 text-[9px] rounded font-mono">
                   <LayoutGrid size={10} />
                   <span>All Items</span>
                 </Chip>
                 <Chip onClick={() => setFilter('high_views')} selected={filter === 'high_views'} className="flex items-center gap-1 py-1 px-2.5 text-[9px] rounded font-mono">
                   <TrendingUp size={10} />
                   <span>Popularity</span>
                 </Chip>
                 <Chip onClick={() => setFilter('newest')} selected={filter === 'newest'} className="flex items-center gap-1 py-1 px-2.5 text-[9px] rounded font-mono">
                   <Sparkles size={10} />
                   <span>Temporal</span>
                 </Chip>
              </div>
            </div>
          </div>
        )}
      </div>

      {showAnalytics && (
        <div className="mx-6 mt-4 p-4 bg-obsidian border border-iron rounded-sm text-white transition-all duration-300">
          <div className="flex items-center justify-between border-b border-iron pb-3 mb-4">
            <h3 className="text-xs font-bold uppercase tracking-widest text-brand-orange flex items-center gap-2">
              <BarChart3 size={16} /> Workspace Analytics
            </h3>
            <span className="text-[10px] font-mono text-ash uppercase tracking-wider bg-graphite px-2 py-0.5 rounded border border-iron">
              LIVE DATA
            </span>
          </div>

          {loadingAnalytics ? (
            <div className="space-y-3">
              <Skeleton className="h-20 w-full bg-graphite" />
              <div className="grid grid-cols-2 gap-3">
                <Skeleton className="h-16 bg-graphite" />
                <Skeleton className="h-16 bg-graphite" />
              </div>
            </div>
          ) : analytics ? (
            <div className="space-y-4">
              <div className="grid grid-cols-2 gap-3">
                <div className="bg-graphite p-3 rounded-sm border border-iron">
                  <div className="text-[9px] uppercase font-bold tracking-widest text-silver">Prompts Gen</div>
                  <div className="text-xl font-bold text-brand-orange mt-1 font-display">{analytics.prompts_generated}</div>
                </div>
                <div className="bg-graphite p-3 rounded-sm border border-iron">
                  <div className="text-[9px] uppercase font-bold tracking-widest text-silver">Posts Proc</div>
                  <div className="text-xl font-bold text-white mt-1 font-display">{analytics.posts_processed}</div>
                </div>
                <div className="bg-graphite p-3 rounded-sm border border-iron">
                  <div className="text-[9px] uppercase font-bold tracking-widest text-silver">Active Feeds</div>
                  <div className="text-xl font-bold text-white mt-1 font-display">{analytics.active_sources}</div>
                </div>
                <div className="bg-graphite p-3 rounded-sm border border-iron">
                  <div className="text-[9px] uppercase font-bold tracking-widest text-silver">Candidates</div>
                  <div className="text-xl font-bold text-brand-orange mt-1 font-display">{analytics.total_candidates}</div>
                </div>
              </div>

              {/* Weekly Trend Visualizer using pure SVG - beautiful and 100% React 19 safe! */}
              <div className="bg-graphite p-4 rounded-sm border border-iron">
                <div className="text-[9px] uppercase font-bold tracking-widest text-silver mb-3">Weekly Ingest Volume</div>
                <div className="h-20 flex items-end gap-2 justify-between">
                  {analytics.weekly_activity.map((act) => {
                    // Maximum activity calculation
                    const maxVal = Math.max(...analytics.weekly_activity.map(a => a.count), 1);
                    const heightPercent = `${Math.max((act.count / maxVal) * 100, 10)}%`;
                    return (
                      <div key={act.day} className="flex-1 flex flex-col items-center gap-1.5 h-full justify-end group">
                        <div className="w-full bg-iron/40 hover:bg-brand-orange/70 transition-all duration-300 rounded-sm relative flex items-end justify-center" style={{ height: heightPercent }}>
                          <span className="opacity-0 group-hover:opacity-100 absolute -top-6 bg-obsidian border border-iron px-1 py-0.5 text-[8px] rounded font-mono text-white transition-opacity duration-200 z-10">
                            {act.count}
                          </span>
                        </div>
                        <span className="text-[8px] uppercase font-bold tracking-wider font-mono text-ash">{act.day}</span>
                      </div>
                    );
                  })}
                </div>
              </div>
            </div>
          ) : (
            <div className="text-center text-ash text-xs py-4">No metrics available.</div>
          )}
        </div>
      )}

      <div className="p-4 flex-1 space-y-4">
        {loading ? (
          <div className="space-y-4">
            <Skeleton className="h-32 w-full bg-graphite" />
            <Skeleton className="h-32 w-full bg-graphite" />
            <Skeleton className="h-32 w-full bg-graphite" />
          </div>
        ) : filteredCandidates.length === 0 ? (
          <div className="relative flex flex-col items-center justify-center py-20 px-4 border border-dashed border-iron bg-obsidian/30 rounded-sm overflow-hidden text-center">
            <div className="absolute inset-0 pointer-events-none opacity-10 flex flex-col gap-4 p-4 z-0">
              <Skeleton className="h-32 w-full bg-silver/20" />
              <Skeleton className="h-32 w-full bg-silver/20" />
            </div>
            <div className="relative z-10 w-16 h-16 rounded-full bg-graphite flex items-center justify-center mb-4 text-silver shadow-[0_0_15px_rgba(156,163,175,0.1)]">
              <Sparkles size={32} />
            </div>
            <h3 className="relative z-10 text-white font-display font-medium text-lg uppercase tracking-wider mb-2">
              {searchQuery ? 'No Search Results' : 'Inbox Zero'}
            </h3>
            <p className="relative z-10 text-silver text-xs max-w-sm mb-6 leading-relaxed">
              {searchQuery 
                ? `No candidates found matching "${searchQuery}". This fuzzy search is highly tolerant of spelling mistakes—try a different keyword.` 
                : 'No new content matches your criteria. Check your sources or adjust your filters.'
              }
            </p>
            {searchQuery ? (
              <Button onClick={() => setSearchQuery('')} className="relative z-10 flex items-center gap-2" variant="outline">
                <X size={14} /> Clear Search Query
              </Button>
            ) : (
              <Button onClick={() => activeWorkspaceId && loadCandidates(activeWorkspaceId)} className="relative z-10 flex items-center gap-2" variant="outline">
                <RefreshCw size={16} /> Refresh Candidates
              </Button>
            )}
          </div>
        ) : null}

        {filteredCandidates.map(candidate => {
          const isSelected = selectedIds.has(candidate.id);
          return (
            <Card key={candidate.id} className={`transition-all duration-300 transform hover:scale-[1.01] hover:-translate-y-1 ${isSelected ? 'border-brand-orange shadow-[0_0_8px_rgba(232,102,10,0.15)] bg-graphite/50' : 'border-iron bg-obsidian hover:border-brand-orange/50 hover:shadow-[0_4px_12px_rgba(255,107,0,0.05)]'}`}>
              <div className="flex flex-col relative p-4">
                <div className="flex justify-between items-start mb-4">
                  <div className="flex flex-col cursor-pointer" onClick={() => setDetailCandidate(candidate)}>
                    <span className="text-[10px] font-bold text-brand-orange uppercase tracking-widest flex items-center gap-1.5">
                      <Radio size={12} className="animate-pulse opacity-70" /> {candidate.source_channel}
                    </span>
                    <span className="text-[9px] text-ash uppercase font-bold tracking-wider mt-1 flex items-center gap-1">
                      <Clock size={10} /> 
                      {candidate.original_posted_at_utc ? new Date(candidate.original_posted_at_utc).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit'}) : ''}
                      {candidate.view_count ? ` • ${candidate.view_count >= 1000 ? (candidate.view_count/1000).toFixed(1)+'k' : candidate.view_count} Views` : ''}
                    </span>
                  </div>
                  <Checkbox 
                    className="w-5 h-5 border-iron data-[state=checked]:bg-brand-orange data-[state=checked]:border-brand-orange text-white" 
                    checked={isSelected}
                    onCheckedChange={() => toggleSelect(candidate.id)} 
                  />
                </div>
                
                <p 
                  className="text-silver text-sm leading-relaxed mb-4 cursor-pointer transition-colors duration-300 hover:text-white line-clamp-4"
                  onClick={() => setDetailCandidate(candidate)}
                >
                  {candidate.raw_text}
                </p>
                
                <div className="mt-auto flex justify-between items-end">
                  <div className="flex gap-2">
                    <span className="text-[9px] bg-iron/50 border border-iron px-2 py-1 text-silver uppercase font-bold rounded-sm flex items-center gap-1">
                      <Eye size={10} /> News
                    </span>
                  </div>
                  <button 
                    onClick={() => setDetailCandidate(candidate)}
                    className="flex items-center gap-1 text-brand-orange text-[10px] font-bold uppercase tracking-widest hover:text-neon-orange transition-colors duration-200 active:scale-95"
                  >
                    <Eye size={14}/> Read Full
                  </button>
                </div>
              </div>
            </Card>
          );
        })}

        {/* Pagination Controls */}
        {pagination && pagination.total_pages > 1 && (
          <div className="flex flex-col sm:flex-row items-center justify-between gap-4 pt-4 border-t border-iron/40 mt-6">
            <span className="text-[10px] font-mono text-ash uppercase tracking-wider">
              Showing {Math.min((pagination.current_page - 1) * pagination.limit + 1, pagination.total_count)}–{Math.min(pagination.current_page * pagination.limit, pagination.total_count)} of {pagination.total_count} candidates
            </span>
            <div className="flex items-center gap-1">
              <button
                type="button"
                className="h-8 px-3 text-[10px] font-mono font-bold uppercase tracking-wider bg-graphite border border-iron text-silver rounded flex items-center justify-center transition-all duration-200 active:scale-95 disabled:opacity-40 hover:text-white"
                onClick={() => setPage(prev => Math.max(prev - 1, 1))}
                disabled={pagination.current_page === 1 || loading}
              >
                Prev
              </button>
              
              {Array.from({ length: pagination.total_pages }, (_, i) => i + 1).map((p) => (
                <button
                  key={p}
                  type="button"
                  onClick={() => setPage(p)}
                  className={`h-8 w-8 text-[10px] font-mono font-bold transition-all duration-200 rounded flex items-center justify-center active:scale-95 ${
                    pagination.current_page === p
                      ? 'bg-brand-orange text-white font-black shadow-[0_0_12px_rgba(232,102,10,0.3)]'
                      : 'bg-graphite text-silver border border-iron hover:text-white hover:border-silver'
                  }`}
                  disabled={loading}
                >
                  {p}
                </button>
              ))}

              <button
                type="button"
                className="h-8 px-3 text-[10px] font-mono font-bold uppercase tracking-wider bg-graphite border border-iron text-silver rounded flex items-center justify-center transition-all duration-200 active:scale-95 disabled:opacity-40 hover:text-white"
                onClick={() => setPage(prev => Math.min(prev + 1, pagination.total_pages))}
                disabled={pagination.current_page === pagination.total_pages || loading}
              >
                Next
              </button>
            </div>
          </div>
        )}
      </div>

      <Drawer.Root open={!!detailCandidate} onOpenChange={(open) => !open && setDetailCandidate(null)}>
        <Drawer.Portal>
          <Drawer.Overlay className="fixed inset-0 bg-black/60 z-50 transition-opacity duration-300" />
          <Drawer.Content className="bg-obsidian border-t border-iron flex flex-col rounded-t-[16px] max-h-[85vh] fixed bottom-0 left-0 right-0 z-50 focus:outline-none shadow-[0_-10px_30px_rgba(0,0,0,0.5)]">
            <div className="flex-1 p-6 bg-obsidian rounded-t-[16px] overflow-y-auto max-h-[80vh] no-scrollbar">
              <div className="mx-auto w-12 h-1 flex-shrink-0 rounded-full bg-steel mb-5" />
              
              <div className="flex justify-between items-start mb-4">
                <div>
                  <Drawer.Title className="text-white font-display text-lg uppercase tracking-wider mb-1 flex items-center gap-2">
                    <Radio size={16} className="text-brand-orange animate-pulse" />
                    {detailCandidate?.source_channel}
                  </Drawer.Title>
                  <Drawer.Description className="text-silver text-xs flex gap-2 items-center">
                    <Clock size={12} /> {detailCandidate?.original_posted_at_utc ? new Date(detailCandidate.original_posted_at_utc).toLocaleString() : ''}
                    {detailCandidate?.view_count ? ` • ${detailCandidate.view_count >= 1000 ? (detailCandidate.view_count / 1000).toFixed(1) + 'k' : detailCandidate.view_count} Views` : ''}
                  </Drawer.Description>
                </div>
              </div>

              <div className="mt-4 text-silver leading-relaxed text-sm whitespace-pre-wrap bg-graphite p-4 rounded-sm border border-iron font-sans">
                {detailCandidate?.raw_text}
              </div>

              <div className="mt-6 flex justify-end items-center">
                <button 
                  onClick={() => setDetailCandidate(null)}
                  className="text-[10px] font-bold text-ash hover:text-white uppercase tracking-widest transition-colors"
                >
                  Close Sheet
                </button>
              </div>
            </div>
          </Drawer.Content>
        </Drawer.Portal>
      </Drawer.Root>

      {selectedIds.size > 0 && (
        <div className="fixed bottom-24 left-4 right-4 md:left-1/2 md:right-auto md:-translate-x-1/2 md:w-[500px] p-3 bg-obsidian-solid/95 backdrop-blur-md border border-brand-orange/40 rounded-xl shadow-[0_8px_32px_rgba(0,0,0,0.5)] flex items-center justify-between z-40 transition-all duration-300">
          <div className="flex items-center gap-2 mr-4 flex-shrink-0">
             <span className="text-silver text-[10px] uppercase font-bold tracking-widest font-mono">Selected:</span>
             <span className="bg-graphite border border-brand-orange/30 px-2.5 py-0.5 text-brand-orange font-bold text-xs rounded font-mono">
                {selectedIds.size.toString().padStart(2, '0')}
             </span>
          </div>
          <Button 
            className="flex-1 gap-2 text-xs py-2 rounded-lg" 
            onClick={handleCopyPrompt}
            isLoading={generatePromptMutation.isPending}
          >
            <Copy size={16} /> GENERATE MEGA-PROMPT
          </Button>
        </div>
      )}
    </div>
  );
}

import React, { useEffect, useState } from 'react';
import { toast } from 'sonner';
import { api } from '../lib/api';
import { Workspace, SourceChannel } from '../lib/types';
import { Card, Input, Button, FormHeader, ErrorState } from '../components/custom';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../components/ui/select';
import { Skeleton } from '../components/ui/skeleton';
import { Drawer } from 'vaul';
import { Plus, X, Radio, ArrowUpRight } from 'lucide-react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';

export default function Sources() {
  const queryClient = useQueryClient();

  const { data: workspaces = [], isLoading: workspacesLoading, error: workspacesError } = useQuery<Workspace[]>({
    queryKey: ['workspaces'],
    queryFn: api.getWorkspaces,
  });

  const [activeWorkspaceId, setActiveWorkspaceId] = useState<number | null>(null);
  const [isCreating, setIsCreating] = useState(false);
  const [channelId, setChannelId] = useState('');
  const [priority, setPriority] = useState<'high' | 'normal' | 'low'>('normal');
  const [editSource, setEditSource] = useState<SourceChannel | null>(null);
  const [editDisplayName, setEditDisplayName] = useState('');
  const [editChannelId, setEditChannelId] = useState('');
  const [editPriority, setEditPriority] = useState<'high' | 'normal' | 'low'>('normal');
  const [editIsActive, setEditIsActive] = useState<number>(1);
  const [lastSourceId, setLastSourceId] = useState<number | null>(null);

  useEffect(() => {
    if (workspaces.length > 0 && !activeWorkspaceId) {
      setActiveWorkspaceId(workspaces[0].id);
    }
  }, [workspaces, activeWorkspaceId]);

  const { data: sources = [], isLoading: sourcesLoading, error: sourcesError } = useQuery<SourceChannel[]>({
    queryKey: ['sources', activeWorkspaceId],
    queryFn: () => api.getSources(activeWorkspaceId!),
    enabled: !!activeWorkspaceId,
  });

  useEffect(() => {
    if (editSource && editSource.id !== lastSourceId) {
      setEditDisplayName(editSource.display_name || '');
      setEditChannelId(editSource.channel_id);
      setEditPriority(editSource.priority || 'normal');
      setEditIsActive(editSource.is_active || 0);
      setLastSourceId(editSource.id);
    } else if (!editSource) {
      setLastSourceId(null);
    }
  }, [editSource, lastSourceId]);

  const createSourceMutation = useMutation({
    mutationFn: api.createSource,
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ['sources', activeWorkspaceId] });
      toast.success("Source Added");
      setIsCreating(false);
      setChannelId('');
    },
    onError: (e: any) => {
      toast.error(e.message || "Failed to add source");
    }
  });

  const updateSourceMutation = useMutation({
    mutationFn: ({ workspaceId, id, data }: { workspaceId: number; id: number; data: Partial<SourceChannel> }) =>
      api.updateSource(workspaceId, id, data),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ['sources', activeWorkspaceId] });
      setEditSource(null);
      toast.success("Source Updated");
    },
    onError: (e: any) => {
      toast.error(e.message || "Failed to update source");
    }
  });

  const scrapeWorkspaceMutation = useMutation({
    mutationFn: (workspaceId: number) => api.triggerWorkspaceScrape(workspaceId),
    onSuccess: async () => {
      toast.success("Workspace scrape triggered");
      await queryClient.invalidateQueries({ queryKey: ['sources', activeWorkspaceId] });
      await queryClient.invalidateQueries({ queryKey: ['candidates', activeWorkspaceId] });
      await queryClient.invalidateQueries({ queryKey: ['analytics', activeWorkspaceId] });
    },
    onError: (e: any) => {
      toast.error(e.message || "Failed to trigger scrape");
    }
  });

  function handleUpdate(e: React.FormEvent) {
    e.preventDefault();
    if (!editSource || !activeWorkspaceId) return;

    updateSourceMutation.mutate({
      workspaceId: activeWorkspaceId,
      id: editSource.id,
      data: {
        display_name: editDisplayName,
        channel_id: editChannelId,
        priority: editPriority,
        is_active: editIsActive,
      }
    });
  }

  function handleCreate(e: React.FormEvent) {
    e.preventDefault();
    if (!activeWorkspaceId) return;

    createSourceMutation.mutate({
      workspace_id: activeWorkspaceId,
      channel_id: channelId,
      display_name: channelId.replace('@', ''),
      priority,
      is_active: 1,
    });
  }

  const isLoading = workspacesLoading || (!!activeWorkspaceId && sourcesLoading);
  const error = workspacesError || sourcesError;

  if (error) {
    return (
      <ErrorState
        message={error instanceof Error ? error.message : "Failed to load sources"}
        onRetry={() => {
          queryClient.invalidateQueries({ queryKey: ['workspaces'] });
          if (activeWorkspaceId) {
            queryClient.invalidateQueries({ queryKey: ['sources', activeWorkspaceId] });
          }
        }}
      />
    );
  }

  if (isLoading && !workspaces.length) {
    return (
      <div className="p-4 space-y-4">
        <Skeleton className="h-8 w-32 bg-graphite mb-8" />
        <Skeleton className="h-16 w-full bg-graphite" />
        <Skeleton className="h-16 w-full bg-graphite" />
      </div>
    );
  }

  return (
    <div className="p-4 space-y-6">
      <FormHeader subtitle="Add and monitor scraping sources">Source Channels</FormHeader>

      <Select value={activeWorkspaceId?.toString() || ''} onValueChange={(val) => setActiveWorkspaceId(Number(val))}>
        <SelectTrigger className="w-full text-xs font-bold uppercase tracking-wider bg-graphite border-iron text-white">
          <SelectValue placeholder="Select Workspace">
            {workspaces.find((workspace) => workspace.id.toString() === activeWorkspaceId?.toString())?.name || "Select Workspace"}
          </SelectValue>
        </SelectTrigger>
        <SelectContent className="bg-graphite border border-iron text-white">
          {workspaces.map((workspace) => (
            <SelectItem key={workspace.id} value={workspace.id.toString()} className="focus:bg-brand-orange focus:text-white uppercase text-[10px] tracking-widest cursor-pointer">
              {workspace.name}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>

      <div className="flex items-center justify-between mt-8">
        <h3 className="font-display font-bold text-steel hover:text-silver uppercase text-[10px] tracking-widest pl-1">Configured Channels</h3>
        {!isCreating && (
          <Button variant="ghost" className="h-8 px-3 text-xs tracking-widest" onClick={() => setIsCreating(true)}>
            <Plus size={16} className="mr-1" /> ADD
          </Button>
        )}
      </div>

      {isCreating && (
        <Card className="border-brand-orange relative overflow-hidden bg-graphite shadow-[0_0_16px_rgba(232,102,10,0.1)]">
          <div className="absolute top-4 right-4 cursor-pointer text-ash hover:text-white" onClick={() => setIsCreating(false)}>
            <X size={20} />
          </div>
          <form onSubmit={handleCreate} className="space-y-4 pt-2">
            <div>
              <label className="block text-[10px] font-bold uppercase tracking-widest text-silver mb-2">Telegram Channel</label>
              <Input required className="w-full text-sm" value={channelId} onChange={(event) => setChannelId(event.target.value)} placeholder="@news_source" />
            </div>
            <div>
              <label className="block text-[10px] font-bold uppercase tracking-widest text-silver mb-2">Priority</label>
              <Select value={priority} onValueChange={(val) => setPriority(val as typeof priority)}>
                <SelectTrigger className="w-full text-sm font-bold uppercase tracking-wider bg-graphite border-iron text-white">
                  <SelectValue placeholder="Select priority">
                    {priority === 'high' ? 'High' : priority === 'normal' ? 'Normal' : 'Low'}
                  </SelectValue>
                </SelectTrigger>
                <SelectContent className="bg-graphite border border-iron text-white">
                  <SelectItem value="high" className="text-danger focus:bg-danger focus:text-white uppercase text-[10px] tracking-widest">High</SelectItem>
                  <SelectItem value="normal" className="focus:bg-brand-orange focus:text-white uppercase text-[10px] tracking-widest">Normal</SelectItem>
                  <SelectItem value="low" className="text-ash focus:bg-ash focus:text-white uppercase text-[10px] tracking-widest">Low</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <Button className="w-full mt-4 text-xs" type="submit" isLoading={createSourceMutation.isPending}>Add Source</Button>
          </form>
        </Card>
      )}

      <div className="space-y-3">
        {sources.length === 0 && <div className="text-center text-ash text-[10px] tracking-widest font-bold uppercase py-10 border border-dashed border-iron rounded-sm">No sources configured</div>}
        {sources.map((source) => (
          <Card key={source.id} className="flex items-center justify-between py-3 bg-obsidian transition-all duration-300 transform hover:scale-[1.01] hover:-translate-y-1 hover:border-brand-orange/50 hover:shadow-[0_4px_12px_rgba(255,107,0,0.05)] cursor-pointer" onClick={() => setEditSource(source)}>
            <div className="flex items-center gap-3">
              <div className="text-brand-orange bg-brand-orange/10 p-2 rounded-sm border border-brand-orange/20">
                <Radio size={16} />
              </div>
              <div className="flex flex-col">
                <div className="flex items-center gap-2 flex-wrap">
                  <div className="font-display font-medium text-sm text-white">{source.display_name || source.channel_id}</div>
                  <span className={`inline-flex items-center gap-1.5 text-[8px] font-mono font-bold uppercase tracking-wider px-1.5 py-0.5 rounded-sm border ${
                    source.status === 'online'
                      ? 'bg-success/10 border-success/30 text-success'
                      : 'bg-danger/10 border-danger/30 text-danger'
                  }`}>
                    <span className={`h-1 w-1 rounded-full ${source.status === 'online' ? 'bg-success animate-pulse' : 'bg-danger'}`} />
                    {source.status === 'online' ? 'Online' : 'Offline'}
                  </span>
                </div>
                <div className="text-silver text-[10px] font-bold uppercase tracking-widest mt-0.5">{source.channel_id}</div>
              </div>
            </div>
            <div className={`text-[9px] uppercase font-bold tracking-widest px-2 py-1 border rounded-sm ${
              source.priority === 'high'
                ? 'bg-danger/10 border-danger/30 text-danger'
                : source.priority === 'low'
                  ? 'bg-ash/10 border-ash/30 text-ash'
                  : 'bg-graphite border-iron text-silver'
            }`}>
              {source.priority}
            </div>
          </Card>
        ))}
      </div>

      <Drawer.Root open={!!editSource} onOpenChange={(open) => !open && setEditSource(null)}>
        <Drawer.Portal>
          <Drawer.Overlay className="fixed inset-0 bg-black/60 z-50 transition-opacity duration-300" />
          <Drawer.Content className="bg-obsidian border-t border-iron flex flex-col rounded-t-xl max-h-[85vh] fixed bottom-0 left-0 right-0 z-50 focus:outline-none shadow-[0_-10px_30px_rgba(0,0,0,0.5)] animate-in slide-in-from-bottom duration-300">
            <div className="flex-1 pt-3 pb-5 px-5 bg-obsidian rounded-t-xl overflow-y-auto max-h-[80vh] no-scrollbar">
              <div className="mx-auto w-10 h-1 flex-shrink-0 rounded-full bg-steel mb-3" />
              <Drawer.Title className="text-brand-orange font-display text-base uppercase tracking-wider mb-0.5">
                Edit Source Channel
              </Drawer.Title>
              <Drawer.Description className="text-silver text-[10px] mb-3 leading-relaxed">
                Alter the scraping identifiers, collection speed, and source availability.
              </Drawer.Description>

              <form onSubmit={handleUpdate} className="space-y-3.5">
                <div>
                  <label className="block text-[10px] font-bold uppercase tracking-widest text-silver mb-2">Display Name</label>
                  <Input required className="w-full text-sm" value={editDisplayName} onChange={(event) => setEditDisplayName(event.target.value)} placeholder="e.g. AI News Feed" />
                </div>
                <div>
                  <label className="block text-[10px] font-bold uppercase tracking-widest text-silver mb-2">Telegram Channel ID</label>
                  <Input required className="w-full text-sm" value={editChannelId} onChange={(event) => setEditChannelId(event.target.value)} placeholder="@my_news_source" />
                </div>
                <div>
                  <label className="block text-[10px] font-bold uppercase tracking-widest text-silver mb-2">Scraping Priority</label>
                  <Select value={editPriority} onValueChange={(val) => setEditPriority(val as typeof editPriority)}>
                    <SelectTrigger className="w-full text-sm font-bold uppercase tracking-wider bg-graphite border-iron text-white">
                      <SelectValue placeholder="Select priority">
                        {editPriority === 'high' ? 'High' : editPriority === 'normal' ? 'Normal' : 'Low'}
                      </SelectValue>
                    </SelectTrigger>
                    <SelectContent className="bg-graphite border border-iron text-white">
                      <SelectItem value="high" className="text-danger focus:bg-danger focus:text-white uppercase text-[10px] tracking-widest cursor-pointer">High</SelectItem>
                      <SelectItem value="normal" className="focus:bg-brand-orange focus:text-white uppercase text-[10px] tracking-widest cursor-pointer">Normal</SelectItem>
                      <SelectItem value="low" className="text-ash focus:bg-ash focus:text-white uppercase text-[10px] tracking-widest cursor-pointer">Low</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
                <div>
                  <label className="block text-[10px] font-bold uppercase tracking-widest text-silver mb-2">Scraping Status</label>
                  <div className="flex gap-2">
                    <button
                      type="button"
                      onClick={() => setEditIsActive(1)}
                      className={`flex-1 py-2 text-[10px] font-bold uppercase tracking-widest border rounded transition-all active:scale-95 cursor-pointer ${
                        editIsActive === 1
                          ? 'bg-success/15 border-success text-success shadow-[0_0_10px_rgba(33,197,94,0.1)]'
                          : 'bg-graphite border-iron text-ash hover:text-silver'
                      }`}
                    >
                      Active scraping
                    </button>
                    <button
                      type="button"
                      onClick={() => setEditIsActive(0)}
                      className={`flex-1 py-2 text-[10px] font-bold uppercase tracking-widest border rounded transition-all active:scale-95 cursor-pointer ${
                        editIsActive === 0
                          ? 'bg-danger/15 border-danger text-danger shadow-[0_0_10px_rgba(239,68,68,0.1)]'
                          : 'bg-graphite border-iron text-ash hover:text-silver'
                      }`}
                    >
                      Paused
                    </button>
                  </div>
                </div>

                {editSource && (
                  <div className="p-3 bg-black/40 border border-iron/40 rounded space-y-2 mt-4">
                    <div className="flex items-center justify-between">
                      <span className="text-[10px] font-mono font-bold uppercase tracking-widest text-ash">Scrape Engine</span>
                      <span className={`inline-flex items-center gap-1 text-[8px] font-mono font-bold uppercase tracking-wider px-1.5 py-0.5 rounded-sm border ${
                        editSource.status === 'online'
                          ? 'bg-success/10 border-success/30 text-success'
                          : 'bg-danger/10 border-danger/30 text-danger'
                      }`}>
                        <span className={`h-1 w-1 rounded-full ${editSource.status === 'online' ? 'bg-success animate-pulse' : 'bg-danger'}`} />
                        {editSource.status === 'online' ? 'Online' : 'Offline'}
                      </span>
                    </div>

                    <p className="text-[10px] text-silver leading-relaxed font-mono">
                      {editSource.is_active === 0 && "This source is paused and will not be scraped until it is re-enabled."}
                      {editSource.is_active === 1 && editSource.last_scraped_at && `Last scrape recorded at ${new Date(editSource.last_scraped_at).toLocaleString()}.`}
                      {editSource.is_active === 1 && !editSource.last_scraped_at && "This source is active, but the backend has not recorded a successful scrape yet."}
                    </p>

                    <button
                      type="button"
                      disabled={scrapeWorkspaceMutation.isPending || editIsActive === 0 || !activeWorkspaceId}
                      onClick={() => {
                        if (activeWorkspaceId) {
                          scrapeWorkspaceMutation.mutate(activeWorkspaceId);
                        }
                      }}
                      className="w-full h-8 flex items-center justify-center gap-1.5 text-[9px] font-mono font-bold uppercase tracking-wider bg-graphite border border-iron hover:border-silver text-silver hover:text-white transition-all duration-200 rounded-sm disabled:opacity-30 disabled:cursor-not-allowed"
                    >
                      {scrapeWorkspaceMutation.isPending ? (
                        <>
                          <span className="w-3.5 h-3.5 border-2 border-white/20 border-t-white rounded-full animate-spin"></span>
                          TRIGGERING SCRAPE...
                        </>
                      ) : (
                        <>
                          <ArrowUpRight size={13} className="text-brand-orange" />
                          RUN WORKSPACE SCRAPE
                        </>
                      )}
                    </button>
                  </div>
                )}

                <div className="pt-4 flex gap-2">
                  <Button type="button" variant="outline" size="sm" className="flex-1" onClick={() => setEditSource(null)}>Cancel</Button>
                  <Button type="submit" size="sm" className="flex-1" isLoading={updateSourceMutation.isPending}>Save Changes</Button>
                </div>
              </form>
            </div>
          </Drawer.Content>
        </Drawer.Portal>
      </Drawer.Root>
    </div>
  );
}

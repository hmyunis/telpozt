import React, { useEffect, useState } from 'react';
import { toast } from 'sonner';
import { api } from '../lib/api';
import { Workspace, StyleProfile } from '../lib/types';
import { Card, Input, Button, FormHeader, ErrorState } from '../components/custom';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../components/ui/select';
import { Skeleton } from '../components/ui/skeleton';
import { Drawer } from 'vaul';
import { Plus, X, Layers, Sparkles } from 'lucide-react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';

export default function Workspaces() {
  const queryClient = useQueryClient();

  const { data: workspaces = [], isLoading: workspacesLoading, error: workspacesError } = useQuery<Workspace[]>({
    queryKey: ['workspaces'],
    queryFn: api.getWorkspaces,
  });

  const { data: profiles = [], isLoading: profilesLoading, error: profilesError } = useQuery<StyleProfile[]>({
    queryKey: ['profiles'],
    queryFn: api.getStyleProfiles,
  });

  const [detailWorkspace, setDetailWorkspace] = useState<Workspace | null>(null);
  const [isCreating, setIsCreating] = useState(false);

  // Form State
  const [name, setName] = useState('');
  const [targetChannel, setTargetChannel] = useState('');
  const [botToken, setBotToken] = useState('');
  const [styleProfileId, setStyleProfileId] = useState<number | ''>('');

  // Edit Bottom Sheet Form State
  const [editWorkspace, setEditWorkspace] = useState<Workspace | null>(null);
  const [editName, setEditName] = useState('');
  const [editTargetChannel, setEditTargetChannel] = useState('');
  const [editBotToken, setEditBotToken] = useState('');
  const [editStyleProfileId, setEditStyleProfileId] = useState<number | ''>('');
  const [editIsActive, setEditIsActive] = useState<number>(1);

  // Set default style profile if profiles load and none is selected
  useEffect(() => {
    if (profiles.length > 0 && !styleProfileId) {
      setStyleProfileId(profiles[0].id);
    }
  }, [profiles, styleProfileId]);

  useEffect(() => {
    if (editWorkspace) {
      setEditName(editWorkspace.name);
      setEditTargetChannel(editWorkspace.target_channel_id);
      setEditBotToken(editWorkspace.bot_token || '');
      setEditStyleProfileId(editWorkspace.style_profile_id || '');
      setEditIsActive(editWorkspace.is_active || 0);
    }
  }, [editWorkspace]);

  const createWorkspaceMutation = useMutation({
    mutationFn: api.createWorkspace,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['workspaces'] });
      setIsCreating(false);
      setName('');
      setTargetChannel('');
      setBotToken('');
      toast.success("Workspace Created");
    },
    onError: (e: any) => {
      toast.error(e.message || "Failed to create workspace");
    }
  });

  const updateWorkspaceMutation = useMutation({
    mutationFn: ({ id, data }: { id: number; data: Partial<Workspace> }) => api.updateWorkspace(id, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['workspaces'] });
      setEditWorkspace(null);
      toast.success("Workspace Updated");
    },
    onError: (e: any) => {
      toast.error(e.message || "Failed to update workspace");
    }
  });

  async function handleUpdate(e: React.FormEvent) {
    e.preventDefault();
    if (!editWorkspace) return;
    updateWorkspaceMutation.mutate({
      id: editWorkspace.id,
      data: {
        name: editName,
        target_channel_id: editTargetChannel,
        bot_token: editBotToken,
        style_profile_id: editStyleProfileId ? Number(editStyleProfileId) : null,
        is_active: editIsActive,
      }
    });
  }

  async function handleCreate(e: React.FormEvent) {
    e.preventDefault();
    createWorkspaceMutation.mutate({
      name,
      target_channel_id: targetChannel,
      bot_token: botToken,
      style_profile_id: styleProfileId ? Number(styleProfileId) : null,
    });
  }

  const isLoading = workspacesLoading || profilesLoading;
  const error = workspacesError || profilesError;

  if (error) {
    return (
      <ErrorState 
        message={error instanceof Error ? error.message : "Failed to load workspaces"} 
        onRetry={() => {
          queryClient.invalidateQueries({ queryKey: ['workspaces'] });
          queryClient.invalidateQueries({ queryKey: ['profiles'] });
        }} 
      />
    );
  }

  if (isLoading) {
    return (
      <div className="p-4 space-y-4">
        <Skeleton className="h-8 w-32 bg-graphite mb-8" />
        <Skeleton className="h-24 w-full bg-graphite" />
        <Skeleton className="h-24 w-full bg-graphite" />
      </div>
    );
  }

  return (
    <div className="p-4 space-y-6">
      <div className="flex items-center justify-between mb-4">
        <FormHeader subtitle="Manage destination channels and bots">Workspaces</FormHeader>
        {!isCreating && (
          <Button variant="ghost" className="h-8 px-3 text-xs tracking-widest mt-[-20px]" onClick={() => setIsCreating(true)}>
            <Plus size={16} className="mr-1"/> NEW
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
              <label className="block text-[10px] font-bold uppercase tracking-widest text-silver mb-2">Workspace Name</label>
              <Input required className="w-full text-sm" value={name} onChange={e => setName(e.target.value)} placeholder="e.g. Daily Crypto" />
            </div>
            <div>
              <label className="block text-[10px] font-bold uppercase tracking-widest text-silver mb-2">Target Channel</label>
              <Input required className="w-full text-sm" value={targetChannel} onChange={e => setTargetChannel(e.target.value)} placeholder="@mychannel" />
            </div>
            <div>
              <label className="block text-[10px] font-bold uppercase tracking-widest text-silver mb-2">Bot Token</label>
              <Input required type="password" className="w-full text-sm" value={botToken} onChange={e => setBotToken(e.target.value)} placeholder="123456:ABC-DEF..." />
            </div>
            <div>
              <label className="block text-[10px] font-bold uppercase tracking-widest text-silver mb-2">Style Profile</label>
              <Select value={styleProfileId?.toString() || ''} onValueChange={val => setStyleProfileId(val ? Number(val) : '')}>
                <SelectTrigger className="w-full text-sm bg-graphite text-white border-iron uppercase font-bold tracking-wider">
                  <SelectValue placeholder="Select Profile">
                     {profiles.find(p => p.id.toString() === styleProfileId?.toString())?.name || "None"}
                  </SelectValue>
                </SelectTrigger>
                <SelectContent className="bg-graphite text-white border-iron">
                  <SelectItem value="">None</SelectItem>
                  {profiles.map(p => <SelectItem className="focus:bg-brand-orange focus:text-white" key={p.id} value={p.id.toString()}>{p.name}</SelectItem>)}
                </SelectContent>
              </Select>
            </div>
            <Button className="w-full mt-4 text-xs" type="submit" isLoading={createWorkspaceMutation.isPending}>Create Workspace</Button>
          </form>
        </Card>
      )}

      <div className="space-y-4">
        {workspaces.length === 0 ? (
          <div className="relative flex flex-col items-center justify-center py-20 px-4 mt-4 border border-dashed border-iron bg-obsidian/30 rounded-sm overflow-hidden text-center">
            <div className="absolute inset-0 pointer-events-none opacity-10 flex flex-col gap-4 p-4 z-0">
              <Skeleton className="h-24 w-full bg-silver/20" />
              <Skeleton className="h-24 w-full bg-silver/20" />
            </div>
            <div className="relative z-10 w-16 h-16 rounded-full bg-graphite flex items-center justify-center mb-4 text-brand-orange shadow-[0_0_15px_rgba(232,102,10,0.15)]">
              <Layers size={32} />
            </div>
            <h3 className="relative z-10 text-white font-display font-medium text-lg uppercase tracking-wider mb-2">No Workspaces Yet</h3>
            <p className="relative z-10 text-silver text-xs max-w-sm mb-6 leading-relaxed">
              Create a workspace to start aggregating content, defining source channels, and establishing AI voice profiles.
            </p>
            <Button onClick={() => setIsCreating(true)} className="relative z-10 flex items-center gap-2">
              <Plus size={16} /> Create First Workspace
            </Button>
          </div>
        ) : workspaces.map(ws => {
          const profile = profiles.find(p => p.id === ws.style_profile_id);
          return (
            <Card key={ws.id} className="transition-all duration-300 transform hover:scale-[1.01] hover:-translate-y-1 hover:border-brand-orange/50 hover:shadow-[0_4px_12px_rgba(255,107,0,0.05)] cursor-pointer" onClick={() => setEditWorkspace(ws)}>
              <div className="flex justify-between items-start">
                <div>
                  <h3 className="font-display font-medium text-lg uppercase tracking-wide text-brand-orange transition-colors">{ws.name}</h3>
                  <p className="text-silver text-xs mt-1 font-bold tracking-widest uppercase flex items-center gap-1.5"><Layers size={12} className="opacity-70" /> {ws.target_channel_id}</p>
                </div>
                <div className={`px-2 py-1 text-[9px] font-bold uppercase tracking-widest rounded-sm border ${ws.is_active ? 'bg-success/10 text-success border-success/30' : 'bg-steel text-ash border-transparent'}`}>
                  {ws.is_active ? 'Active' : 'Inactive'}
                </div>
              </div>
              <div className="mt-4 pt-4 border-t border-iron flex flex-col gap-1 text-[10px] uppercase font-bold tracking-widest text-ash">
                <div className="flex justify-between items-center px-1">
                  <span>Style Profile:</span>
                  <span className="text-white bg-graphite border border-iron px-2 py-1 rounded-sm flex items-center gap-1.5">
                    <Sparkles size={10} className="text-brand-orange"/> {profile ? profile.name : 'None'}
                  </span>
                </div>
              </div>
            </Card>
          );
        })}
      </div>

      <Drawer.Root open={!!editWorkspace} onOpenChange={(open) => !open && setEditWorkspace(null)}>
        <Drawer.Portal>
          <Drawer.Overlay className="fixed inset-0 bg-black/60 z-50 transition-opacity duration-300" />
          <Drawer.Content className="bg-obsidian border-t border-iron flex flex-col rounded-t-xl max-h-[85vh] fixed bottom-0 left-0 right-0 z-50 focus:outline-none shadow-[0_-10px_30px_rgba(0,0,0,0.5)] animate-in slide-in-from-bottom duration-300">
            <div className="flex-1 pt-3 pb-5 px-5 bg-obsidian rounded-t-xl overflow-y-auto max-h-[80vh] no-scrollbar">
              <div className="mx-auto w-10 h-1 flex-shrink-0 rounded-full bg-steel mb-3" />
              <Drawer.Title className="text-brand-orange font-display text-base uppercase tracking-wider mb-0.5">
                Edit Workspace
              </Drawer.Title>
              <Drawer.Description className="text-silver text-[10px] mb-3 leading-relaxed">
                Tune target distribution, AI style guides, and webhook authorizations.
              </Drawer.Description>
              
              <form onSubmit={handleUpdate} className="space-y-3.5">
                <div>
                  <label className="block text-[10px] font-bold uppercase tracking-widest text-silver mb-2">Workspace Name</label>
                  <Input required className="w-full text-sm" value={editName} onChange={e => setEditName(e.target.value)} placeholder="e.g. Daily Crypto" />
                </div>
                <div>
                  <label className="block text-[10px] font-bold uppercase tracking-widest text-silver mb-2">Target Channel</label>
                  <Input required className="w-full text-sm" value={editTargetChannel} onChange={e => setEditTargetChannel(e.target.value)} placeholder="@mychannel" />
                </div>
                <div>
                  <label className="block text-[10px] font-bold uppercase tracking-widest text-silver mb-2">Bot Token (Secure)</label>
                  <Input type="password" className="w-full text-sm" value={editBotToken} onChange={e => setEditBotToken(e.target.value)} placeholder="••••••••••••••••••••••••" />
                </div>
                <div>
                  <label className="block text-[10px] font-bold uppercase tracking-widest text-silver mb-2">Style Profile</label>
                  <Select value={editStyleProfileId?.toString() || ''} onValueChange={val => setEditStyleProfileId(val ? Number(val) : '')}>
                    <SelectTrigger className="w-full text-sm bg-graphite text-white border-iron uppercase font-bold tracking-wider">
                      <SelectValue placeholder="Select Profile">
                         {profiles.find(p => p.id.toString() === editStyleProfileId?.toString())?.name || "None"}
                      </SelectValue>
                    </SelectTrigger>
                    <SelectContent className="bg-graphite text-white border-iron">
                      <SelectItem value="">None</SelectItem>
                      {profiles.map(p => <SelectItem className="focus:bg-brand-orange focus:text-white" key={p.id} value={p.id.toString()}>{p.name}</SelectItem>)}
                    </SelectContent>
                  </Select>
                </div>
                <div>
                  <label className="block text-[10px] font-bold uppercase tracking-widest text-silver mb-2">Workspace Status</label>
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
                      Active
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
                      Inactive
                    </button>
                  </div>
                </div>
                
                <div className="pt-4 flex gap-2">
                  <Button type="button" variant="outline" size="sm" className="flex-1" onClick={() => setEditWorkspace(null)}>Cancel</Button>
                  <Button type="submit" size="sm" className="flex-1" isLoading={updateWorkspaceMutation.isPending}>Save Changes</Button>
                </div>
              </form>
            </div>
          </Drawer.Content>
        </Drawer.Portal>
      </Drawer.Root>
    </div>
  );
}

import React, { useEffect, useState } from 'react';
import { toast } from 'sonner';
import { api } from '../lib/api';
import { StyleProfile } from '../lib/types';
import { Card, Input, Button, FormHeader, Chip, ErrorState } from '../components/custom';
import { Skeleton } from '../components/ui/skeleton';
import { Tooltip, TooltipContent, TooltipTrigger } from '../components/ui/tooltip';
import { Drawer } from 'vaul';
import { Plus, X, Sparkles, Info } from 'lucide-react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';

export default function StyleProfiles() {
  const queryClient = useQueryClient();

  const { data: profiles = [], isLoading: profilesLoading, error: profilesError } = useQuery<StyleProfile[]>({
    queryKey: ['profiles'],
    queryFn: api.getStyleProfiles,
  });

  const [detailProfile, setDetailProfile] = useState<StyleProfile | null>(null);
  const [isCreating, setIsCreating] = useState(false);

  // Form State
  const [name, setName] = useState('');
  const [tone, setTone] = useState<StyleProfile['tone']>('semi_formal');
  const [length, setLength] = useState<StyleProfile['length_preset']>('medium');
  const [emoji, setEmoji] = useState<StyleProfile['emoji_usage']>('minimal');

  // Drawer Edit Form State
  const [editProfile, setEditProfile] = useState<StyleProfile | null>(null);
  const [editName, setEditName] = useState('');
  const [editTone, setEditTone] = useState<StyleProfile['tone']>('semi_formal');
  const [editLength, setEditLength] = useState<StyleProfile['length_preset']>('medium');
  const [editEmoji, setEditEmoji] = useState<StyleProfile['emoji_usage']>('minimal');
  const [editStructure, setEditStructure] = useState<string>('bullet_points');

  useEffect(() => {
    if (editProfile) {
      setEditName(editProfile.name);
      setEditTone(editProfile.tone);
      setEditLength(editProfile.length_preset);
      setEditEmoji(editProfile.emoji_usage);
      setEditStructure(editProfile.structure || 'bullet_points');
    }
  }, [editProfile]);

  const createProfileMutation = useMutation({
    mutationFn: api.createStyleProfile,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['profiles'] });
      toast.success("AI Voice Created");
      setIsCreating(false);
      setName('');
    },
    onError: (e: any) => {
      toast.error(e.message || "Failed to create style profile");
    }
  });

  const updateProfileMutation = useMutation({
    mutationFn: ({ id, data }: { id: number; data: Partial<StyleProfile> }) => api.updateStyleProfile(id, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['profiles'] });
      setEditProfile(null);
      toast.success("AI Voice Updated");
    },
    onError: (e: any) => {
      toast.error(e.message || "Failed to update voice");
    }
  });

  async function handleUpdate(e: React.FormEvent) {
    e.preventDefault();
    if (!editProfile) return;
    updateProfileMutation.mutate({
      id: editProfile.id,
      data: {
        name: editName,
        tone: editTone,
        length_preset: editLength,
        emoji_usage: editEmoji,
        structure: editStructure,
      }
    });
  }

  async function handleCreate(e: React.FormEvent) {
    e.preventDefault();
    createProfileMutation.mutate({
      name,
      tone,
      length_preset: length,
      emoji_usage: emoji,
      structure: 'bullet_points',
    });
  }

  const isLoading = profilesLoading;
  const error = profilesError;

  if (error) {
    return (
      <ErrorState 
        message={error instanceof Error ? error.message : "Failed to load style profiles"} 
        onRetry={() => {
          queryClient.invalidateQueries({ queryKey: ['profiles'] });
        }} 
      />
    );
  }

  if (isLoading) {
    return (
      <div className="p-4 space-y-4">
        <Skeleton className="h-8 w-32 bg-graphite mb-8" />
        <Skeleton className="h-32 w-full bg-graphite" />
        <Skeleton className="h-32 w-full bg-graphite" />
      </div>
    );
  }

  return (
    <div className="p-4 space-y-6">
      <div className="flex items-center justify-between mb-4">
        <FormHeader subtitle="Configure automation tones & rules">AI Voices</FormHeader>
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
          <form onSubmit={handleCreate} className="space-y-6 pt-2">
            <div>
              <label className="block text-[10px] font-bold uppercase tracking-widest text-silver mb-2">Profile Name</label>
              <Input required className="w-full text-sm" value={name} onChange={e => setName(e.target.value)} placeholder="e.g. Urgent Crypto Alert" />
            </div>

            <div>
              <div className="flex items-center gap-1.5 mb-2">
                <label className="block text-[10px] font-bold uppercase tracking-widest text-silver">Tone</label>
                <Tooltip>
                  <TooltipTrigger asChild>
                    <Info size={12} className="text-silver cursor-help" />
                  </TooltipTrigger>
                  <TooltipContent className="bg-obsidian border border-iron text-silver text-xs">
                    Controls the emotional resonance and formality of the rewritten messages.
                  </TooltipContent>
                </Tooltip>
              </div>
              <div className="flex flex-wrap gap-2">
                {['formal', 'semi_formal', 'casual', 'punchy'].map((t) => (
                  <Chip key={t} selected={tone === t} onClick={() => setTone(t as any)}>
                    {t.replace('_', ' ')}
                  </Chip>
                ))}
              </div>
            </div>

            <div>
              <div className="flex items-center gap-1.5 mb-2">
                <label className="block text-[10px] font-bold uppercase tracking-widest text-silver">Length</label>
                <Tooltip>
                  <TooltipTrigger asChild>
                    <Info size={12} className="text-silver cursor-help" />
                  </TooltipTrigger>
                  <TooltipContent className="bg-obsidian border border-iron text-silver text-xs">
                    Determines the verbosity of the AI output. Short removes pleasantries. Medium is balanced. Long adds details.
                  </TooltipContent>
                </Tooltip>
              </div>
              <div className="flex flex-wrap gap-2">
                {['short', 'medium', 'long'].map((l) => (
                  <Chip key={l} selected={length === l} onClick={() => setLength(l as any)}>
                    {l}
                  </Chip>
                ))}
              </div>
            </div>

            <div>
              <div className="flex items-center gap-1.5 mb-2">
                <label className="block text-[10px] font-bold uppercase tracking-widest text-silver">Emoji Usage</label>
                <Tooltip>
                  <TooltipTrigger asChild>
                    <Info size={12} className="text-silver cursor-help" />
                  </TooltipTrigger>
                  <TooltipContent className="bg-obsidian border border-iron text-silver text-xs">
                    Regulates how many emojis are injected per paragraph.
                  </TooltipContent>
                </Tooltip>
              </div>
              <div className="flex flex-wrap gap-2">
                {['none', 'minimal', 'moderate', 'heavy'].map((e) => (
                  <Chip key={e} selected={emoji === e} onClick={() => setEmoji(e as any)}>
                    {e}
                  </Chip>
                ))}
              </div>
            </div>

            <Button className="w-full mt-4 text-xs" type="submit" isLoading={createProfileMutation.isPending}>Create Voice</Button>
          </form>
        </Card>
      )}

      <div className="space-y-4">
        {profiles.map((p) => (
          <Card key={p.id} className="border-l-4 border-l-brand-orange bg-obsidian transition-all duration-300 transform hover:scale-[1.01] hover:-translate-y-1 hover:shadow-[0_4px_12px_rgba(255,107,0,0.05)] cursor-pointer" onClick={() => setEditProfile(p)}>
            <h3 className="font-display font-medium text-lg text-white mb-4 uppercase tracking-wide transition-colors hover:text-brand-orange">
              <Sparkles size={16} className="inline-block mr-2 mb-1 text-brand-orange opacity-80" />
              {p.name}
            </h3>
            
            <div className="flex flex-wrap gap-2">
              <span className="px-2 py-1 bg-graphite rounded-sm text-[9px] uppercase font-bold tracking-widest text-silver border border-iron transition-colors hover:border-brand-orange/50 hover:text-white">Tone: <span className="text-white ml-1">{p.tone.replace('_', ' ')}</span></span>
              <span className="px-2 py-1 bg-graphite rounded-sm text-[9px] uppercase font-bold tracking-widest text-silver border border-iron transition-colors hover:border-brand-orange/50 hover:text-white">Length: <span className="text-white ml-1">{p.length_preset}</span></span>
              <span className="px-2 py-1 bg-graphite rounded-sm text-[9px] uppercase font-bold tracking-widest text-silver border border-iron transition-colors hover:border-brand-orange/50 hover:text-white">Emoji: <span className="text-white ml-1">{p.emoji_usage}</span></span>
              <span className="px-2 py-1 bg-graphite rounded-sm text-[9px] uppercase font-bold tracking-widest text-silver border border-iron transition-colors hover:border-brand-orange/50 hover:text-white">Structure: <span className="text-white ml-1">{p.structure.replace('_', ' ')}</span></span>
            </div>
          </Card>
        ))}
      </div>

      <Drawer.Root open={!!editProfile} onOpenChange={(open) => !open && setEditProfile(null)}>
        <Drawer.Portal>
          <Drawer.Overlay className="fixed inset-0 bg-black/60 z-50 transition-opacity duration-300" />
          <Drawer.Content className="bg-obsidian border-t border-iron flex flex-col rounded-t-xl max-h-[85vh] fixed bottom-0 left-0 right-0 z-50 focus:outline-none shadow-[0_-10px_30px_rgba(0,0,0,0.5)] animate-in slide-in-from-bottom duration-300">
            <div className="flex-1 pt-3 pb-5 px-5 bg-obsidian rounded-t-xl overflow-y-auto max-h-[80vh] no-scrollbar">
              <div className="mx-auto w-10 h-1 flex-shrink-0 rounded-full bg-steel mb-3" />
              <Drawer.Title className="text-brand-orange font-display text-base uppercase tracking-wider mb-0.5">
                Edit AI Voice Profile
              </Drawer.Title>
              <Drawer.Description className="text-silver text-[10px] mb-3 leading-relaxed">
                Refine rewrite configurations, layout designs, and character limits.
              </Drawer.Description>
              
              <form onSubmit={handleUpdate} className="space-y-3.5">
                <div>
                  <label className="block text-[10px] font-bold uppercase tracking-widest text-silver mb-2 font-mono">Profile Name</label>
                  <Input required className="w-full text-sm" value={editName} onChange={e => setEditName(e.target.value)} placeholder="e.g. Daily Crypto Bulletin" />
                </div>

                <div>
                  <label className="block text-[10px] font-bold uppercase tracking-widest text-silver mb-2 font-mono">Voice Tone</label>
                  <div className="flex flex-wrap gap-2">
                    {['formal', 'semi_formal', 'casual', 'punchy'].map((t) => (
                      <Chip key={t} selected={editTone === t} onClick={() => setEditTone(t as any)} type="button">
                        {t.replace('_', ' ')}
                      </Chip>
                    ))}
                  </div>
                </div>

                <div>
                  <label className="block text-[10px] font-bold uppercase tracking-widest text-silver mb-2 font-mono">Length Preset</label>
                  <div className="flex flex-wrap gap-2">
                    {['short', 'medium', 'long'].map((l) => (
                      <Chip key={l} selected={editLength === l} onClick={() => setEditLength(l as any)} type="button">
                        {l}
                      </Chip>
                    ))}
                  </div>
                </div>

                <div>
                  <label className="block text-[10px] font-bold uppercase tracking-widest text-silver mb-2 font-mono">Emoji Density</label>
                  <div className="flex flex-wrap gap-2">
                    {['none', 'minimal', 'moderate', 'heavy'].map((e) => (
                      <Chip key={e} selected={editEmoji === e} onClick={() => setEditEmoji(e as any)} type="button">
                        {e}
                      </Chip>
                    ))}
                  </div>
                </div>

                <div>
                  <label className="block text-[10px] font-bold uppercase tracking-widest text-silver mb-2 font-mono">Structure Layout</label>
                  <div className="flex flex-wrap gap-2">
                    {[
                      { key: 'bullet_points', text: 'Bullet Points' },
                      { key: 'lead_conclusion', text: 'Lead-Conclusion' },
                      { key: 'inverted_pyramid', text: 'Inverted Pyramid' },
                      { key: 'paragraph', text: 'Standard Paragraphs' },
                    ].map((s) => (
                      <Chip key={s.key} selected={editStructure === s.key} onClick={() => setEditStructure(s.key)} type="button">
                        {s.text}
                      </Chip>
                    ))}
                  </div>
                </div>
                
                <div className="pt-4 flex gap-2">
                  <Button type="button" variant="outline" size="sm" className="flex-1" onClick={() => setEditProfile(null)}>Cancel</Button>
                  <Button type="submit" size="sm" className="flex-1" isLoading={updateProfileMutation.isPending}>Save Changes</Button>
                </div>
              </form>
            </div>
          </Drawer.Content>
        </Drawer.Portal>
      </Drawer.Root>
    </div>
  );
}

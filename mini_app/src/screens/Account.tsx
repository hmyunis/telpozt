import React, { useState } from 'react';
import { toast } from 'sonner';
import { useQuery } from '@tanstack/react-query';
import { api } from '../lib/api';
import { Card, FormHeader, Input, Button } from '../components/custom';
import { User, ShieldAlert, Monitor, Bell, HardDrive, Key, Download } from 'lucide-react';
import { Drawer } from 'vaul';
import { Checkbox } from '../components/ui/checkbox';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../components/ui/select';

export default function Account() {
  const [showConfirm, setShowConfirm] = useState(false);
  const { data: currentUser } = useQuery({
    queryKey: ['current-user'],
    queryFn: api.getCurrentUser,
  });

  // Load Display Settings from localStorage or use defaults
  const [displayDensity, setDisplayDensity] = useState(() => localStorage.getItem('pref_display_density') || 'comfortable');
  const [displayAccent, setDisplayAccent] = useState(() => localStorage.getItem('pref_display_accent') || 'orange');
  const [animationsEnabled, setAnimationsEnabled] = useState(() => localStorage.getItem('pref_animations') !== 'false');
  const [soundEffects, setSoundEffects] = useState(() => localStorage.getItem('pref_sound') === 'true');

  // Load Notification Settings from localStorage or use defaults
  const [notifyCandidates, setNotifyCandidates] = useState(() => localStorage.getItem('pref_notify_candidates') !== 'false');
  const [notifyMegaprompt, setNotifyMegaprompt] = useState(() => localStorage.getItem('pref_notify_megaprompt') !== 'false');
  const [telegramWebhook, setTelegramWebhook] = useState(() => localStorage.getItem('pref_telegram_webhook') || '');
  const [quietHours, setQuietHours] = useState(() => localStorage.getItem('pref_quiet_hours') === 'true');

  // Load Data Settings from localStorage or use defaults
  const [backupInterval, setBackupInterval] = useState(() => localStorage.getItem('pref_backup_interval') || 'off');
  const [backupEmail, setBackupEmail] = useState(() => localStorage.getItem('pref_backup_email') || '');

  // Drawer open states
  const [displayOpen, setDisplayOpen] = useState(false);
  const [notifyOpen, setNotifyOpen] = useState(false);
  const [dataOpen, setDataOpen] = useState(false);

  const handleSaveDisplay = (e: React.FormEvent) => {
    e.preventDefault();
    localStorage.setItem('pref_display_density', displayDensity);
    localStorage.setItem('pref_display_accent', displayAccent);
    localStorage.setItem('pref_animations', String(animationsEnabled));
    localStorage.setItem('pref_sound', String(soundEffects));
    
    // Attempt dynamic feedback
    document.documentElement.setAttribute('data-accent', displayAccent);
    
    toast.success('Display preferences updated successfully!');
    setDisplayOpen(false);
  };

  const handleSaveNotifications = (e: React.FormEvent) => {
    e.preventDefault();
    localStorage.setItem('pref_notify_candidates', String(notifyCandidates));
    localStorage.setItem('pref_notify_megaprompt', String(notifyMegaprompt));
    localStorage.setItem('pref_telegram_webhook', telegramWebhook);
    localStorage.setItem('pref_quiet_hours', String(quietHours));
    
    toast.success('Notification thresholds synchronized!');
    setNotifyOpen(false);
  };

  const handleSaveData = (e: React.FormEvent) => {
    e.preventDefault();
    localStorage.setItem('pref_backup_interval', backupInterval);
    localStorage.setItem('pref_backup_email', backupEmail);
    
    toast.success('Data policies compiled and secured!');
    setDataOpen(false);
  };

  const handleExportData = async () => {
    try {
      const workspaces = await api.getWorkspaces();
      const profiles = await api.getStyleProfiles();
      const sourcesByWorkspace = await Promise.all(
        workspaces.map(async (workspace) => ({
          workspaceId: workspace.id,
          workspaceName: workspace.name,
          sources: await api.getSources(workspace.id),
        })),
      );

      const dataToExport = {
        meta: {
          exportedAt: new Date().toISOString(),
          version: 'backend-live-export',
          targetUser: currentUser?.username || 'unknown',
        },
        preferences: {
          displayDensity,
          displayAccent,
          animationsEnabled,
          soundEffects,
          notifyCandidates,
          notifyMegaprompt,
          telegramWebhook,
          quietHours,
          backupInterval,
          backupEmail,
        },
        user: currentUser || null,
        workspaces,
        sourceChannels: sourcesByWorkspace,
        profiles,
      };

      const dataStr = "data:text/json;charset=utf-8," + encodeURIComponent(JSON.stringify(dataToExport, null, 2));
      const downloadAnchor = document.createElement('a');
      downloadAnchor.setAttribute("href", dataStr);
      downloadAnchor.setAttribute("download", `hub-schema-export-${new Date().toISOString().split('T')[0]}.json`);
      document.body.appendChild(downloadAnchor);
      downloadAnchor.click();
      downloadAnchor.remove();

      toast.success('Workspace schema exported successfully!');
    } catch (err) {
      console.error(err);
      toast.error('Failed to bundle data for export.');
    }
  };

  const handleDeleteAccount = () => {
    // Purge settings policies & configurations
    const keysToPurge = [
      'pref_display_density', 'pref_display_accent', 'pref_animations', 'pref_sound',
      'pref_notify_candidates', 'pref_notify_megaprompt', 'pref_telegram_webhook', 'pref_quiet_hours',
      'pref_backup_interval', 'pref_backup_email'
    ];
    keysToPurge.forEach(k => localStorage.removeItem(k));

    toast.success('Local preferences cleared.');
    setShowConfirm(false);

    // Refresh layout state
    setTimeout(() => {
      window.location.reload();
    }, 1200);
  };

  return (
    <div className="p-4 space-y-6">
      <div className="flex items-center gap-3 mb-6">
        <div className="w-12 h-12 rounded-full bg-brand-orange/20 border-2 border-brand-orange flex items-center justify-center text-brand-orange font-bold text-xl uppercase shadow-[0_0_12px_rgba(232,102,10,0.2)]">
          {currentUser?.username?.slice(0, 1) || 'U'}
        </div>
        <div>
          <h1 className="font-display font-bold text-xl text-white uppercase tracking-wider">{currentUser?.username || 'User'}</h1>
          <p className="text-silver text-xs font-bold uppercase tracking-widest mt-1 font-mono text-brand-orange">
            {currentUser ? `telegram_chat_id: ${currentUser.telegram_chat_id}` : 'Loading account...'}
          </p>
        </div>
      </div>

      <FormHeader subtitle="Configure your application preferences">Settings</FormHeader>

      <div className="space-y-3">
        {/* DISPLAY SETTINGS CARD */}
        <Card 
          onClick={() => setDisplayOpen(true)}
          className="bg-obsidian border-iron flex justify-between items-center py-4 group cursor-pointer transition-all hover:border-brand-orange/50 hover:bg-graphite/30"
        >
          <div className="flex items-center gap-3">
            <Monitor className="text-ash group-hover:text-brand-orange transition-colors" size={20} />
            <div>
              <div className="text-sm font-bold text-white uppercase tracking-wider">Display Settings</div>
              <div className="text-[9px] text-silver uppercase tracking-widest mt-1 font-mono">
                Theme: <span className="text-brand-orange">Dark</span> • Density: <span className="text-white">{displayDensity}</span> • Accent: <span className="text-white">{displayAccent}</span>
              </div>
            </div>
          </div>
        </Card>

        {/* NOTIFICATION SETTINGS CARD */}
        <Card 
          onClick={() => setNotifyOpen(true)}
          className="bg-obsidian border-iron flex justify-between items-center py-4 group cursor-pointer transition-all hover:border-brand-orange/50 hover:bg-graphite/30"
        >
          <div className="flex items-center gap-3">
            <Bell className="text-ash group-hover:text-brand-orange transition-colors" size={20} />
            <div>
              <div className="text-sm font-bold text-white uppercase tracking-wider">Notifications</div>
              <div className="text-[9px] text-silver uppercase tracking-widest mt-1 font-mono">
                Candidate alerts: <span className={notifyCandidates ? 'text-brand-orange' : 'text-ash'}>{notifyCandidates ? 'ENABLED' : 'MUTED'}</span> • Webhook: <span className="text-white">{telegramWebhook ? 'CONNECTED' : 'NOT SET'}</span>
              </div>
            </div>
          </div>
        </Card>

        {/* DATA SETTINGS CARD */}
        <Card 
          onClick={() => setDataOpen(true)}
          className="bg-obsidian border-iron flex justify-between items-center py-4 group cursor-pointer transition-all hover:border-brand-orange/50 hover:bg-graphite/30"
        >
          <div className="flex items-center gap-3">
            <HardDrive className="text-ash group-hover:text-brand-orange transition-colors" size={20} />
            <div>
              <div className="text-sm font-bold text-white uppercase tracking-wider">Data Settings</div>
              <div className="text-[9px] text-silver uppercase tracking-widest mt-1 font-mono">
                Sync Frequency: <span className="text-brand-orange">{backupInterval.toUpperCase()}</span> {backupEmail && `• Sync target: ${backupEmail}`}
              </div>
            </div>
          </div>
        </Card>
      </div>

      <FormHeader subtitle="Permanent account actions">Danger Zone</FormHeader>

      <Card className="border-danger/30 bg-danger/5 relative overflow-hidden">
        <div className="flex items-start gap-4">
          <ShieldAlert className="text-danger flex-shrink-0 animate-pulse" size={24} />
          <div>
            <h3 className="text-danger font-bold uppercase tracking-wider text-sm mb-2">Clear Local Preferences</h3>
            <p className="text-silver text-xs leading-relaxed mb-4">
              Remove locally saved display, notification, and export preferences from this browser. Backend data is not deleted here because the current server API does not expose account deletion.
            </p>
            <button 
              onClick={() => setShowConfirm(true)}
              className="bg-danger hover:bg-danger/80 text-white font-bold uppercase text-[10px] tracking-widest py-2 px-4 rounded-sm transition-all shadow-[0_0_12px_rgba(239,68,68,0.2)] hover:shadow-[0_0_16px_rgba(239,68,68,0.4)] active:scale-95"
            >
              Clear Preferences
            </button>
          </div>
        </div>
      </Card>

      {/* -------------------- DRAWERS -------------------- */}

      {/* DISPLAY DRAWER */}
      <Drawer.Root open={displayOpen} onOpenChange={setDisplayOpen}>
        <Drawer.Portal>
          <Drawer.Overlay className="fixed inset-0 bg-black/60 z-50 transition-opacity duration-300" />
          <Drawer.Content className="bg-obsidian border-t border-iron flex flex-col rounded-t-xl max-h-[85vh] fixed bottom-0 left-0 right-0 z-50 focus:outline-none shadow-[0_-10px_30px_rgba(0,0,0,0.5)] animate-in slide-in-from-bottom duration-300">
            <div className="flex-1 pt-3 pb-6 px-5 bg-obsidian rounded-t-xl overflow-y-auto max-h-[80vh] no-scrollbar">
              <div className="mx-auto w-10 h-1 flex-shrink-0 rounded-full bg-steel mb-4" />
              
              <Drawer.Title className="text-brand-orange font-display text-base uppercase tracking-wider mb-0.5 flex items-center gap-1.5">
                <Monitor size={16} /> Display Settings
              </Drawer.Title>
              <Drawer.Description className="text-silver text-[10px] mb-4 leading-relaxed font-mono">
                PERSIST THEME STYLE AND GRAPHICAL RATIOS
              </Drawer.Description>

              <form onSubmit={handleSaveDisplay} className="space-y-4 font-sans">
                {/* Visual Ratio Selector */}
                <div>
                  <label className="block text-[10px] font-bold uppercase tracking-widest text-silver mb-2 font-mono">Ratio Density</label>
                  <div className="grid grid-cols-3 gap-2">
                    {['comfortable', 'compact', 'dense'].map((density) => (
                      <button
                        key={density}
                        type="button"
                        onClick={() => setDisplayDensity(density)}
                        className={`py-2 text-[10px] uppercase font-bold tracking-wider rounded border text-center transition-all ${
                          displayDensity === density 
                            ? 'border-brand-orange bg-brand-orange/10 text-brand-orange font-bold' 
                            : 'border-iron bg-graphite text-silver hover:text-white'
                        }`}
                      >
                        {density}
                      </button>
                    ))}
                  </div>
                </div>

                {/* Accent Color Selection */}
                <div>
                  <label className="block text-[10px] font-bold uppercase tracking-widest text-silver mb-2 font-mono">Color Theme Accent</label>
                  <div className="flex gap-2.5">
                    {[
                      { key: 'orange', name: 'Coral', bg: 'bg-[#e8660a]' },
                      { key: 'cyan', name: 'Laser', bg: 'bg-[#06b6d4]' },
                      { key: 'green', name: 'Acid', bg: 'bg-[#22c55e]' },
                      { key: 'purple', name: 'Nebula', bg: 'bg-[#a855f7]' },
                    ].map((accent) => (
                      <button
                        key={accent.key}
                        type="button"
                        onClick={() => setDisplayAccent(accent.key)}
                        className={`h-8 flex-1 rounded border text-[9px] font-bold uppercase tracking-widest flex items-center justify-center gap-1 transition-all ${
                          displayAccent === accent.key 
                            ? 'border-brand-orange bg-brand-orange/10 text-brand-orange font-bold' 
                            : 'border-iron bg-graphite text-silver'
                        }`}
                      >
                        <span className={`w-2.5 h-2.5 rounded-full ${accent.bg} inline-block`} />
                        <span>{accent.name}</span>
                      </button>
                    ))}
                  </div>
                </div>

                {/* Animation Toggle Row */}
                <div className="flex items-center justify-between py-2 border-b border-iron/40 font-mono text-[10px]">
                  <div>
                    <h4 className="text-white font-bold uppercase tracking-wider">Haptic animations</h4>
                    <p className="text-[9px] text-silver uppercase tracking-wider mt-0.5">Active spring layouts and transitions</p>
                  </div>
                  <div className="flex items-center">
                    <Checkbox 
                      id="animations-toggle" 
                      checked={animationsEnabled}
                      onCheckedChange={(checked) => setAnimationsEnabled(!!checked)}
                      className="border-iron bg-graphite data-[state=checked]:bg-brand-orange data-[state=checked]:border-brand-orange" 
                    />
                  </div>
                </div>

                {/* Sounds Toggle Row */}
                <div className="flex items-center justify-between py-2 border-b border-iron/40 font-mono text-[10px]">
                  <div>
                    <h4 className="text-white font-bold uppercase tracking-wider">Success Sound Chimes</h4>
                    <p className="text-[9px] text-silver uppercase tracking-wider mt-0.5">Auditory confirmation upon megaprompt load</p>
                  </div>
                  <div className="flex items-center">
                    <Checkbox 
                      id="sounds-toggle" 
                      checked={soundEffects}
                      onCheckedChange={(checked) => setSoundEffects(!!checked)}
                      className="border-iron bg-graphite data-[state=checked]:bg-brand-orange data-[state=checked]:border-brand-orange" 
                    />
                  </div>
                </div>

                <div className="pt-4 flex gap-2">
                  <Button type="submit" size="sm" className="flex-1">
                    Apply Configurations
                  </Button>
                  <button 
                    type="button"
                    onClick={() => setDisplayOpen(false)}
                    className="h-9 px-4 text-[10px] font-bold text-silver hover:text-white uppercase tracking-wider border border-iron rounded-sm flex items-center justify-center transition-all duration-200 active:scale-95"
                  >
                    Dismiss
                  </button>
                </div>
              </form>
            </div>
          </Drawer.Content>
        </Drawer.Portal>
      </Drawer.Root>

      {/* NOTIFICATIONS DRAWER */}
      <Drawer.Root open={notifyOpen} onOpenChange={setNotifyOpen}>
        <Drawer.Portal>
          <Drawer.Overlay className="fixed inset-0 bg-black/60 z-50 transition-opacity duration-300" />
          <Drawer.Content className="bg-obsidian border-t border-iron flex flex-col rounded-t-xl max-h-[85vh] fixed bottom-0 left-0 right-0 z-50 focus:outline-none shadow-[0_-10px_30px_rgba(0,0,0,0.5)] animate-in slide-in-from-bottom duration-300">
            <div className="flex-1 pt-3 pb-6 px-5 bg-obsidian rounded-t-xl overflow-y-auto max-h-[80vh] no-scrollbar">
              <div className="mx-auto w-10 h-1 flex-shrink-0 rounded-full bg-steel mb-4" />
              
              <Drawer.Title className="text-brand-orange font-display text-base uppercase tracking-wider mb-0.5 flex items-center gap-1.5">
                <Bell size={16} /> Notification Thresholds
              </Drawer.Title>
              <Drawer.Description className="text-silver text-[10px] mb-4 leading-relaxed font-mono">
                INTEGRATE FEED TRANSMISSIONS AND WEBHOOK CHANNELS
              </Drawer.Description>

              <form onSubmit={handleSaveNotifications} className="space-y-4 font-sans">
                {/* Webhook endpoint input */}
                <div>
                  <label className="block text-[10px] font-bold uppercase tracking-widest text-silver mb-2 font-mono">Telegram Bot Webhook Target</label>
                  <div className="relative">
                    <Key className="absolute left-3 top-2.5 text-ash" size={14} />
                    <Input 
                      className="w-full text-xs h-9 pl-9 font-mono bg-graphite" 
                      value={telegramWebhook} 
                      onChange={e => setTelegramWebhook(e.target.value)} 
                      placeholder="e.g. haptic_telegram_key..." 
                    />
                  </div>
                  <span className="text-[8px] text-silver/60 uppercase block mt-1 tracking-wider leading-relaxed">Required for pushing compiled workspace newsletters directly to curated channels.</span>
                </div>

                {/* Candidate collects toggle */}
                <div className="flex items-center justify-between py-2 border-b border-iron/40 font-mono text-[10px]">
                  <div>
                    <h4 className="text-white font-bold uppercase tracking-wider">Candidate Collection Alerts</h4>
                    <p className="text-[9px] text-silver uppercase tracking-wider mt-0.5">Flash push alert whenever raw news lands in queue</p>
                  </div>
                  <div className="flex items-center">
                    <Checkbox 
                      id="candidate-toggle" 
                      checked={notifyCandidates}
                      onCheckedChange={(checked) => setNotifyCandidates(!!checked)}
                      className="border-iron bg-graphite data-[state=checked]:bg-brand-orange data-[state=checked]:border-brand-orange" 
                    />
                  </div>
                </div>

                {/* Daily megaprompt compiles toggle */}
                <div className="flex items-center justify-between py-2 border-b border-iron/40 font-mono text-[10px]">
                  <div>
                    <h4 className="text-white font-bold uppercase tracking-wider">Synthesized MegaPrompt Signals</h4>
                    <p className="text-[9px] text-silver uppercase tracking-wider mt-0.5">Alert when workspace summaries finish processing</p>
                  </div>
                  <div className="flex items-center">
                    <Checkbox 
                      id="summary-toggle" 
                      checked={notifyMegaprompt}
                      onCheckedChange={(checked) => setNotifyMegaprompt(!!checked)}
                      className="border-iron bg-graphite data-[state=checked]:bg-brand-orange data-[state=checked]:border-brand-orange" 
                    />
                  </div>
                </div>

                {/* Quiet Hours toggle */}
                <div className="flex items-center justify-between py-2 border-b border-iron/40 font-mono text-[10px]">
                  <div>
                    <h4 className="text-white font-bold uppercase tracking-wider">Quiet Dusk Protocols</h4>
                    <p className="text-[9px] text-silver uppercase tracking-wider mt-0.5">Silence transmission logs from 23:00 to 07:00</p>
                  </div>
                  <div className="flex items-center">
                    <Checkbox 
                      id="quiet-hours-toggle" 
                      checked={quietHours}
                      onCheckedChange={(checked) => setQuietHours(!!checked)}
                      className="border-iron bg-graphite data-[state=checked]:bg-brand-orange data-[state=checked]:border-brand-orange" 
                    />
                  </div>
                </div>

                <div className="pt-4 flex gap-2">
                  <Button type="submit" size="sm" className="flex-1">
                    Apply Transmissions
                  </Button>
                  <button 
                    type="button"
                    onClick={() => setNotifyOpen(false)}
                    className="h-9 px-4 text-[10px] font-bold text-silver hover:text-white uppercase tracking-wider border border-iron rounded-sm flex items-center justify-center transition-all duration-200 active:scale-95"
                  >
                    Dismiss
                  </button>
                </div>
              </form>
            </div>
          </Drawer.Content>
        </Drawer.Portal>
      </Drawer.Root>

      {/* DATA DRAWER */}
      <Drawer.Root open={dataOpen} onOpenChange={setDataOpen}>
        <Drawer.Portal>
          <Drawer.Overlay className="fixed inset-0 bg-black/60 z-50 transition-opacity duration-300" />
          <Drawer.Content className="bg-obsidian border-t border-iron flex flex-col rounded-t-xl max-h-[85vh] fixed bottom-0 left-0 right-0 z-50 focus:outline-none shadow-[0_-10px_30px_rgba(0,0,0,0.5)] animate-in slide-in-from-bottom duration-300">
            <div className="flex-1 pt-3 pb-6 px-5 bg-obsidian rounded-t-xl overflow-y-auto max-h-[80vh] no-scrollbar">
              <div className="mx-auto w-10 h-1 flex-shrink-0 rounded-full bg-steel mb-4" />
              
              <Drawer.Title className="text-brand-orange font-display text-base uppercase tracking-wider mb-0.5 flex items-center gap-1.5">
                <HardDrive size={16} /> Data Settings & Policies
              </Drawer.Title>
              <Drawer.Description className="text-silver text-[10px] mb-4 leading-relaxed font-mono">
                CONSOLIDATE RETENTION POLICIES AND BACKUPS
              </Drawer.Description>

              <form onSubmit={handleSaveData} className="space-y-4 font-sans">
                {/* Auto-backup Frequency Select */}
                <div>
                  <label className="block text-[10px] font-bold uppercase tracking-widest text-silver mb-2 font-mono">Sync Backup Frequency</label>
                  <Select 
                    value={backupInterval}
                    onValueChange={(val) => setBackupInterval(val)}
                  >
                    <SelectTrigger className="w-full h-9 text-[10px] font-bold uppercase tracking-wider bg-graphite border-iron text-white rounded">
                      <SelectValue placeholder="Select frequency">
                        {backupInterval.toUpperCase()}
                      </SelectValue>
                    </SelectTrigger>
                    <SelectContent className="bg-graphite border border-iron text-white">
                      <SelectItem value="off" className="focus:bg-brand-orange focus:text-white uppercase text-[9px] tracking-widest cursor-pointer">
                        Mute Auto-Backup
                      </SelectItem>
                      <SelectItem value="daily" className="focus:bg-brand-orange focus:text-white uppercase text-[9px] tracking-widest cursor-pointer">
                        Daily Synchronization
                      </SelectItem>
                      <SelectItem value="weekly" className="focus:bg-brand-orange focus:text-white uppercase text-[9px] tracking-widest cursor-pointer">
                        Weekly Compilation
                      </SelectItem>
                    </SelectContent>
                  </Select>
                </div>

                {/* Target email destination */}
                <div>
                  <label className="block text-[10px] font-bold uppercase tracking-widest text-silver mb-2 font-mono">Target Email Destination</label>
                  <Input 
                    type="email" 
                    className="w-full text-xs h-9 font-mono bg-graphite" 
                    value={backupEmail} 
                    onChange={e => setBackupEmail(e.target.value)} 
                    placeholder="e.g. target@network.com" 
                  />
                  <span className="text-[8px] text-silver/60 uppercase block mt-1 tracking-wider">Required for sending secure zip exports of daily channels state directly to offline storage.</span>
                </div>

                {/* Live Export Trigger button */}
                <div className="pt-2">
                  <button
                    type="button"
                    onClick={handleExportData}
                    className="w-full py-2.5 bg-graphite hover:bg-iron/85 border border-iron/80 text-white font-bold uppercase text-[10px] tracking-widest rounded flex items-center justify-center gap-2 transition-all active:scale-[0.98]"
                  >
                    <Download size={14} className="text-brand-orange" />
                    <span>Download Workspace Schema (.json)</span>
                  </button>
                </div>

                <div className="pt-4 flex gap-2">
                  <Button type="submit" size="sm" className="flex-1">
                    Apply Policies
                  </Button>
                  <button 
                    type="button"
                    onClick={() => setDataOpen(false)}
                    className="h-9 px-4 text-[10px] font-bold text-silver hover:text-white uppercase tracking-wider border border-iron rounded-sm flex items-center justify-center transition-all duration-200 active:scale-95"
                  >
                    Dismiss
                  </button>
                </div>
              </form>
            </div>
          </Drawer.Content>
        </Drawer.Portal>
      </Drawer.Root>

      {/* CONFIRMATION DIALOG MODAL */}
      {showConfirm && (
        <div className="fixed inset-0 z-[100] bg-black/80 flex items-center justify-center p-4 backdrop-blur-sm animate-in fade-in duration-200">
          <Card className="w-full max-w-sm bg-obsidian border-danger shadow-[0_0_40px_rgba(239,68,68,0.2)] animate-in zoom-in-95 duration-200 p-6">
            <div className="flex flex-col items-center text-center">
              <div className="w-16 h-16 rounded-full bg-danger/20 flex items-center justify-center text-danger mb-4">
                <ShieldAlert size={32} />
              </div>
              <h2 className="text-danger font-display font-bold text-xl uppercase tracking-wider mb-2">Final Warning</h2>
              <p className="text-silver text-sm mb-6 leading-relaxed">
                You are about to clear locally stored preferences from this browser. Backend data will remain untouched. Continue?
              </p>
              
              <div className="flex flex-col w-full gap-3">
                <button 
                  onClick={handleDeleteAccount}
                  className="w-full bg-danger hover:bg-danger/80 text-white font-bold uppercase text-[11px] tracking-widest py-3 rounded-sm transition-all active:scale-95"
                >
                  Yes, Clear Preferences
                </button>
                <button 
                  onClick={() => setShowConfirm(false)}
                  className="w-full bg-graphite hover:bg-iron text-white font-bold uppercase text-[11px] tracking-widest py-3 rounded-sm transition-all active:scale-95"
                >
                  Cancel
                </button>
              </div>
            </div>
          </Card>
        </div>
      )}

    </div>
  );
}

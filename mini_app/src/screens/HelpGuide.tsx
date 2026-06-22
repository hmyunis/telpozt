import { useNavigate } from 'react-router-dom';
import { ChevronLeft, Info, Layers, Radio, Sparkles, LayoutGrid, ArrowRight } from 'lucide-react';
import { Card } from '../components/custom';

export default function HelpGuide() {
  const navigate = useNavigate();

  return (
    <div className="flex flex-col h-screen overflow-hidden bg-void relative">
      <header className="h-16 flex items-center px-4 bg-obsidian border-b border-iron shrink-0 sticky top-0 z-10 w-full">
        <button 
          onClick={() => navigate(-1)}
          className="p-2 -ml-2 text-silver hover:text-brand-orange transition-colors flex items-center"
        >
          <ChevronLeft size={24} />
          <span className="ml-1 text-xs font-bold uppercase tracking-widest">Back</span>
        </button>
        <h1 className="flex-1 text-center pr-12 text-sm font-display font-medium uppercase tracking-widest text-white">How To Use</h1>
      </header>

      <div className="flex-1 overflow-y-auto w-full max-w-2xl mx-auto p-4 space-y-6 pb-20">
        <div className="flex items-center justify-center p-8">
          <div className="w-16 h-16 bg-brand-orange/10 flex items-center justify-center rounded-full text-brand-orange border border-brand-orange/30">
            <Info size={32} />
          </div>
        </div>

        <div className="text-center space-y-2 mb-8">
          <h2 className="text-xl font-display text-white uppercase tracking-wider">Platform Workflow</h2>
          <p className="text-silver text-sm">Follow these 4 steps to fully automate your content pipeline.</p>
        </div>

        <div className="space-y-4">
          <Card className="flex flex-col relative overflow-hidden">
            <div className="absolute top-0 left-0 w-1 h-full bg-brand-orange"></div>
            <div className="flex items-center gap-3 mb-2">
              <div className="w-8 h-8 rounded-sm bg-graphite flex items-center justify-center text-brand-orange">
                <Layers size={18} />
              </div>
              <h3 className="font-display font-medium text-white uppercase tracking-widest text-sm">1. Workspaces</h3>
            </div>
            <p className="text-silver text-xs pl-11 leading-relaxed">
              Start by creating a Workspace. Workspaces organize your content queues and are linked to a specific Style Profile (AI Voice).
            </p>
          </Card>

          <div className="flex justify-center -my-2 text-iron">
            <ArrowRight size={20} className="rotate-90" />
          </div>

          <Card className="flex flex-col relative overflow-hidden">
            <div className="absolute top-0 left-0 w-1 h-full bg-brand-orange"></div>
            <div className="flex items-center gap-3 mb-2">
              <div className="w-8 h-8 rounded-sm bg-graphite flex items-center justify-center text-brand-orange">
                <Sparkles size={18} />
              </div>
              <h3 className="font-display font-medium text-white uppercase tracking-widest text-sm">2. AI Voices (Style Profiles)</h3>
            </div>
            <p className="text-silver text-xs pl-11 leading-relaxed">
              Create a Style Profile to give your AI a unique voice. You can configure the tone (e.g. analytical, engaging) and specific rules (e.g. no emojis). Link this profile to your Workspace.
            </p>
          </Card>

          <div className="flex justify-center -my-2 text-iron">
            <ArrowRight size={20} className="rotate-90" />
          </div>

          <Card className="flex flex-col relative overflow-hidden">
            <div className="absolute top-0 left-0 w-1 h-full bg-brand-orange"></div>
            <div className="flex items-center gap-3 mb-2">
              <div className="w-8 h-8 rounded-sm bg-graphite flex items-center justify-center text-brand-orange">
                <Radio size={18} />
              </div>
              <h3 className="font-display font-medium text-white uppercase tracking-widest text-sm">3. Sources</h3>
            </div>
            <p className="text-silver text-xs pl-11 leading-relaxed">
              Add Telegram Channels as Sources. The system will automatically scrape top messages from these sources and ingest them into your Workspace's curation queue.
            </p>
          </Card>

          <div className="flex justify-center -my-2 text-iron">
            <ArrowRight size={20} className="rotate-90" />
          </div>

          <Card className="flex flex-col relative overflow-hidden">
            <div className="absolute top-0 left-0 w-1 h-full bg-brand-orange"></div>
            <div className="flex items-center gap-3 mb-2">
              <div className="w-8 h-8 rounded-sm bg-graphite flex items-center justify-center text-brand-orange">
                <LayoutGrid size={18} />
              </div>
              <h3 className="font-display font-medium text-white uppercase tracking-widest text-sm">4. Curation</h3>
            </div>
            <p className="text-silver text-xs pl-11 leading-relaxed">
              Review scraped messages in the Curation tab. Select the best candidates and click generate to rewrite them using your Workspace's AI Voice.
            </p>
          </Card>
        </div>
      </div>
    </div>
  );
}

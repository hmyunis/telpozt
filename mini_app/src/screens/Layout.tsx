import { useEffect, useState } from 'react';
import { NavLink, Outlet, useLocation, Link } from 'react-router-dom';
import { LayoutGrid, Layers, Radio, Sparkles, HelpCircle, Sun, Moon, User } from 'lucide-react';

export default function Layout() {
  const location = useLocation();
  const [isDark, setIsDark] = useState(true);

  useEffect(() => {
    // Initial setup
    const root = document.documentElement;
    if (isDark) {
      root.classList.add('dark');
    } else {
      root.classList.remove('dark');
    }

    try {
      const tg = (window as any).Telegram?.WebApp;
      if (tg) {
        tg.ready();
        tg.expand();
        
        const applyTheme = () => {
          const isTgDark = tg.colorScheme === 'dark';
          setIsDark(isTgDark);
          
          if (isTgDark) {
            root.classList.add('dark');
            tg.setHeaderColor('#0A0A0A');
            tg.setBackgroundColor('#0A0A0A');
          } else {
            root.classList.remove('dark');
            tg.setHeaderColor('#f4f4f5');
            tg.setBackgroundColor('#ffffff');
          }
        };

        applyTheme();
        tg.onEvent('themeChanged', applyTheme);
      }
    } catch (e) {
      console.error(e);
    }
  }, []);

  const toggleTheme = () => {
    setIsDark(!isDark);
    const root = document.documentElement;
    if (!isDark) {
      root.classList.add('dark');
    } else {
      root.classList.remove('dark');
    }
  };

  const navItems = [
    { path: '/', icon: <LayoutGrid size={18} className="transition-transform duration-200 group-hover:scale-110" />, label: 'Curation' },
    { path: '/workspaces', icon: <Layers size={18} className="transition-transform duration-200 group-hover:scale-110" />, label: 'Workspaces' },
    { path: '/sources', icon: <Radio size={18} className="transition-transform duration-200 group-hover:scale-110" />, label: 'Sources' },
    { path: '/profiles', icon: <Sparkles size={18} className="transition-transform duration-200 group-hover:scale-110" />, label: 'AI Voices' },
    { path: '/account', icon: <User size={18} className="transition-transform duration-200 group-hover:scale-110" />, label: 'Account' },
  ];

  return (
    <div className="flex flex-col h-screen overflow-hidden bg-void text-white transition-colors duration-300">
      <header className="h-16 flex items-center justify-between px-4 bg-obsidian border-b border-iron shrink-0 transition-colors duration-300">
        <div className="flex items-center gap-3">
          <div className="w-8 h-8 bg-brand-orange flex items-center justify-center rounded-sm font-bold text-white font-display shadow-sm cursor-pointer hover:shadow-[0_0_8px_rgba(232,102,10,0.5)] transition-all duration-300">T</div>
          <div className="flex flex-col cursor-pointer transition-opacity hover:opacity-80">
            <span className="text-brand-orange text-xs font-bold tracking-[0.2em] uppercase leading-none">Telpozt</span>
            <span className="text-silver text-[9px] uppercase tracking-widest mt-1 hidden sm:inline-block">Automation Control</span>
          </div>
        </div>
        <div className="flex items-center gap-1">
          <button 
            onClick={toggleTheme}
            className="p-2 text-silver hover:text-brand-orange hover:bg-graphite rounded-full transition-all duration-300 active:scale-95"
            aria-label="Toggle theme"
          >
            {isDark ? <Sun size={20} className="animate-in fade-in zoom-in spin-in-90" /> : <Moon size={20} className="animate-in fade-in zoom-in spin-in-90" />}
          </button>
          <Link to="/help" className="p-2 text-silver hover:text-brand-orange hover:bg-graphite rounded-full transition-all duration-300 active:scale-95">
            <HelpCircle size={20} />
          </Link>
        </div>
      </header>

      <main className="flex-1 overflow-y-auto pb-28 relative">
        <Outlet />
      </main>
      
      <nav className="fixed bottom-4 left-4 right-4 md:left-1/2 md:right-auto md:-translate-x-1/2 md:w-[540px] h-16 bg-obsidian/90 backdrop-blur-md border border-iron/65 rounded-full flex justify-around items-center px-3 z-50 shadow-[0_12px_40px_rgba(0,0,0,0.7)] transition-all duration-300">
        {navItems.map((item) => {
          const isActive = location.pathname === item.path || 
            (item.path !== '/' && location.pathname.startsWith(item.path));
          
          return (
            <NavLink
              key={item.path}
              to={item.path}
              className={`group flex items-center justify-center gap-1.5 px-3 py-2 rounded-full transition-all duration-300 active:scale-95 select-none ${
                isActive 
                  ? 'text-brand-orange bg-brand-orange/10 font-bold border border-brand-orange/25 shadow-[0_0_15px_rgba(232,102,10,0.1)]' 
                  : 'text-ash hover:text-white hover:bg-graphite/40 border border-transparent'
              }`}
            >
              <div className={`transition-transform duration-300 ${isActive ? 'scale-110 text-brand-orange' : 'group-hover:scale-105'}`}>{item.icon}</div>
              <span className={`text-[9.5px] font-bold uppercase tracking-widest transition-all duration-300 font-mono ${isActive ? 'inline-block text-brand-orange' : 'hidden md:inline-block opacity-65 group-hover:opacity-100'}`}>{item.label}</span>
            </NavLink>
          );
        })}
      </nav>
    </div>
  );
}

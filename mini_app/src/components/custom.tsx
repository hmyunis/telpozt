import React from 'react';

export function Card({ children, className = '', ...props }: React.ComponentProps<'div'>) {
  return (
    <div {...props} className={`bg-obsidian border border-iron rounded-sm p-4 ${className}`}>
      {children}
    </div>
  );
}

export function Input(props: React.InputHTMLAttributes<HTMLInputElement>) {
  return (
    <input
      {...props}
      className={`bg-graphite border border-iron rounded-sm px-3 py-2 text-white placeholder-ash 
      focus:border-brand-orange focus:shadow-[0_0_8px_rgba(232,102,10,0.5)] focus:outline-none transition-all duration-200 ${props.className || ''}`}
    />
  );
}

export function ErrorState({ message, onRetry }: { message: string, onRetry: () => void }) {
  return (
    <div className="flex flex-col items-center justify-center p-8 text-center bg-obsidian border border-iron rounded-sm m-4">
      <div className="w-12 h-12 bg-danger/10 text-danger rounded-full flex items-center justify-center mb-4">
        <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>
      </div>
      <h3 className="font-display font-medium text-lg uppercase tracking-wide text-white mb-2">Something went wrong</h3>
      <p className="text-silver text-sm font-body mb-6">{message}</p>
      <Button onClick={onRetry} variant="ghost" className="px-6 h-10 border border-brand-orange text-xs text-brand-orange">
        TRY AGAIN
      </Button>
    </div>
  );
}

interface ButtonProps {
  variant?: 'primary' | 'ghost' | 'outline';
  size?: 'sm' | 'md' | 'lg';
  isLoading?: boolean;
  children?: React.ReactNode;
  className?: string;
  onClick?: (e: React.MouseEvent<HTMLButtonElement>) => void;
  disabled?: boolean;
  type?: 'button' | 'submit' | 'reset';
}

export function Button({ variant = 'primary', size = 'md', isLoading, children, className = '', ...props }: ButtonProps) {
  const sizeClasses = {
    sm: "h-9 text-[10px] px-4 font-bold tracking-wider",
    md: "h-12 text-xs px-6 font-medium tracking-widest",
    lg: "h-14 text-sm px-8 font-semibold tracking-widest"
  };

  const baseClasses = "uppercase font-display rounded-sm flex items-center justify-center transition-all duration-300 transform active:scale-[0.98] disabled:opacity-50 disabled:cursor-not-allowed hover:-translate-y-0.5 disabled:hover:translate-y-0";
  
  const variants = {
    primary: "bg-brand-orange hover:bg-neon-orange active:bg-ember text-white shadow-[0_0_16px_rgba(232,102,10,0.3)] hover:shadow-[0_0_24px_rgba(255,107,0,0.5)]",
    ghost: "bg-transparent text-brand-orange hover:bg-graphite border border-transparent",
    outline: "bg-transparent border border-brand-orange text-brand-orange hover:bg-brand-orange/10"
  };

  return (
    <button {...props} className={`${baseClasses} ${sizeClasses[size]} ${variants[variant]} ${className}`}>
      {isLoading ? (
        <span className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin"></span>
      ) : children}
    </button>
  );
}

export function FormHeader({ children, subtitle }: { children: React.ReactNode, subtitle?: string }) {
  return (
    <div className="flex items-end justify-between border-l-4 border-brand-orange pl-4 mb-6 transition-all duration-300 hover:border-l-8">
      <div className="flex flex-col">
        <h2 className="text-xl font-bold uppercase tracking-[0.15em] text-brand-orange">{children}</h2>
        {subtitle && <p className="text-silver text-[10px] font-medium tracking-wide uppercase mt-1">{subtitle}</p>}
      </div>
    </div>
  );
}

export function Chip({ 
  selected, 
  onClick, 
  children,
  className = '',
  ...props
}: { 
  selected: boolean; 
  onClick: () => void; 
  children: React.ReactNode;
  className?: string;
} & Omit<React.ComponentProps<'button'>, 'onClick'>) {
  return (
    <button
      type="button"
      onClick={onClick as any}
      {...props}
      className={`flex items-center justify-center gap-1.5 px-3 py-1.5 rounded-sm text-xs font-bold uppercase tracking-widest transition-all duration-300 transform active:scale-95 border ${
        selected 
          ? 'border-brand-orange bg-graphite text-brand-orange shadow-[0_0_8px_rgba(232,102,10,0.15)] hover:bg-obsidian' 
          : 'border-transparent bg-graphite text-ash hover:bg-iron hover:text-white'
      } ${className}`}
    >
      {children}
    </button>
  );
}

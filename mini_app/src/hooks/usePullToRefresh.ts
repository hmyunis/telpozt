import React, { useState, useEffect, useRef } from 'react';

interface UsePullToRefreshOptions {
  onRefresh: () => Promise<void>;
  threshold?: number;
  maxPull?: number;
}

export function usePullToRefresh({
  onRefresh,
  threshold = 60,
  maxPull = 120,
}: UsePullToRefreshOptions) {
  const [pullDistance, setPullDistance] = useState(0);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const startYRef = useRef<number | null>(null);
  const containerRef = useRef<HTMLDivElement | null>(null);

  // Detect if running on a mobile device & Telegram WebApp environment
  const isEligibleDevice = () => {
    if (typeof window === 'undefined') return false;

    const hasTouch = 'ontouchstart' in window || navigator.maxTouchPoints > 0;
    
    // Check Telegram WebApp object
    const tg = (window as any).Telegram?.WebApp;
    const isTelegramMobile = tg?.platform && ['android', 'ios', 'mobile'].includes(tg.platform.toLowerCase());
    
    // We trigger on mobile devices or Telegram WebApp running on a mobile platform
    return hasTouch || isTelegramMobile;
  };

  useEffect(() => {
    if (!isEligibleDevice()) return;

    const handleTouchStart = (e: TouchEvent) => {
      // Check if container is scrolled to the top
      const scrollEl = containerRef.current || document.documentElement;
      if (scrollEl.scrollTop === 0 && !isRefreshing) {
        startYRef.current = e.touches[0].clientY;
      }
    };

    const handleTouchMove = (e: TouchEvent) => {
      if (startYRef.current === null || isRefreshing) return;

      const currentY = e.touches[0].clientY;
      const progress = currentY - startYRef.current;

      if (progress > 0) {
        // Apply dampening calculation (resistive feel)
        const resistance = 0.45;
        const dampenedDistance = Math.min(progress * resistance, maxPull);
        setPullDistance(dampenedDistance);

        // Prevent native bounce / reload if we are actively pulling
        if (progress > 15 && e.cancelable) {
          e.preventDefault();
        }
      } else {
        setPullDistance(0);
      }
    };

    const handleTouchEnd = async () => {
      if (startYRef.current === null || isRefreshing) return;

      if (pullDistance >= threshold) {
        setIsRefreshing(true);
        setPullDistance(threshold); // Lock to threshold height during refresh
        
        try {
          // Trigger haptic feedback via Telegram WebApp if available
          const tg = (window as any).Telegram?.WebApp;
          if (tg?.HapticFeedback) {
            tg.HapticFeedback.notificationOccurred('success');
          }
        } catch (err) {
          console.error('Telegram Haptic Feedback error:', err);
        }

        try {
          await onRefresh();
        } catch (error) {
          console.error('Error during pull-to-refresh:', error);
        } finally {
          setIsRefreshing(false);
          // Smooth slide up animation
          let current = threshold;
          const shrink = () => {
            current = Math.max(0, current - 8);
            setPullDistance(current);
            if (current > 0) {
              requestAnimationFrame(shrink);
            }
          };
          requestAnimationFrame(shrink);
        }
      } else {
        // Snap back to 0
        setPullDistance(0);
      }
      
      startYRef.current = null;
    };

    window.addEventListener('touchstart', handleTouchStart, { passive: false });
    window.addEventListener('touchmove', handleTouchMove, { passive: false });
    window.addEventListener('touchend', handleTouchEnd);

    return () => {
      window.removeEventListener('touchstart', handleTouchStart);
      window.removeEventListener('touchmove', handleTouchMove);
      window.removeEventListener('touchend', handleTouchEnd);
    };
  }, [pullDistance, isRefreshing, onRefresh, threshold, maxPull]);

  return {
    pullDistance,
    isRefreshing,
    containerRef,
    isMobileTelegram: isEligibleDevice(),
  };
}

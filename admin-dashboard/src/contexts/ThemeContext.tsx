'use client';

import { createContext, useContext, useState, useEffect, ReactNode, useCallback } from 'react';

export type Theme = 'light' | 'dark' | 'system';
export type AccentColor = '#C6E94B' | '#6366F1' | '#A855F7' | '#EC4899' | '#22D3EE' | '#FB923C';
export type FontSize = 'small' | 'medium' | 'large';
export type SidebarWidth = 'compact' | 'standard' | 'wide';

interface AppearanceSettings {
  theme: Theme;
  accentColor: AccentColor;
  fontSize: FontSize;
  sidebarWidth: SidebarWidth;
  compactMode: boolean;
}

const DEFAULT_APPEARANCE: AppearanceSettings = {
  theme: 'light',
  accentColor: '#C6E94B',
  fontSize: 'medium',
  sidebarWidth: 'standard',
  compactMode: false,
};

const ACCENT_CSS_MAP: Record<AccentColor, { accent: string; hover: string; light: string; dark: string; glow: string }> = {
  '#C6E94B': { accent: '#C6E94B', hover: '#B8DC3D', light: '#F0F9D6', dark: '#7A9A1E', glow: 'rgba(198,233,75,0.35)' },
  '#6366F1': { accent: '#6366F1', hover: '#4F46E5', light: '#EEF2FF', dark: '#4338CA', glow: 'rgba(99,102,241,0.35)' },
  '#A855F7': { accent: '#A855F7', hover: '#9333EA', light: '#FAF5FF', dark: '#7E22CE', glow: 'rgba(168,85,247,0.35)' },
  '#EC4899': { accent: '#EC4899', hover: '#DB2777', light: '#FDF2F8', dark: '#BE185D', glow: 'rgba(236,72,153,0.35)' },
  '#22D3EE': { accent: '#22D3EE', hover: '#06B6D4', light: '#ECFEFF', dark: '#0891B2', glow: 'rgba(34,211,238,0.35)' },
  '#FB923C': { accent: '#FB923C', hover: '#F97316', light: '#FFF7ED', dark: '#C2410C', glow: 'rgba(251,146,60,0.35)' },
};

const FONT_SIZE_MAP: Record<FontSize, string> = {
  small: '14px',
  medium: '16px',
  large: '18px',
};

const SIDEBAR_WIDTH_MAP: Record<SidebarWidth, string> = {
  compact: '200px',
  standard: '240px',
  wide: '280px',
};

interface ThemeContextType {
  appearance: AppearanceSettings;
  setTheme: (theme: Theme) => void;
  setAccentColor: (color: AccentColor) => void;
  setFontSize: (size: FontSize) => void;
  setSidebarWidth: (width: SidebarWidth) => void;
  setCompactMode: (enabled: boolean) => void;
  sidebarPx: string;
  resolvedTheme: 'light' | 'dark';
}

const ThemeContext = createContext<ThemeContextType | undefined>(undefined);

function loadAppearance(): AppearanceSettings {
  if (typeof window === 'undefined') return DEFAULT_APPEARANCE;
  try {
    const stored = localStorage.getItem('nv_appearance');
    return stored ? { ...DEFAULT_APPEARANCE, ...JSON.parse(stored) } : DEFAULT_APPEARANCE;
  } catch {
    return DEFAULT_APPEARANCE;
  }
}

export function ThemeProvider({ children }: { children: ReactNode }) {
  const [appearance, setAppearance] = useState<AppearanceSettings>(DEFAULT_APPEARANCE);
  const [mounted, setMounted] = useState(false);

  // Load from localStorage once mounted
  useEffect(() => {
    setAppearance(loadAppearance());
    setMounted(true);
  }, []);

  // Persist to localStorage whenever appearance changes
  useEffect(() => {
    if (!mounted) return;
    localStorage.setItem('nv_appearance', JSON.stringify(appearance));
  }, [appearance, mounted]);

  // Apply CSS variables whenever appearance changes
  useEffect(() => {
    if (!mounted) return;
    const root = document.documentElement;

    // Accent color
    const colors = ACCENT_CSS_MAP[appearance.accentColor] || ACCENT_CSS_MAP['#C6E94B'];
    root.style.setProperty('--accent', colors.accent);
    root.style.setProperty('--accent-hover', colors.hover);
    root.style.setProperty('--accent-light', colors.light);
    root.style.setProperty('--accent-dark', colors.dark);
    root.style.setProperty('--accent-glow', colors.glow);

    // Font size
    root.style.setProperty('--base-font-size', FONT_SIZE_MAP[appearance.fontSize]);

    // Theme (dark mode)
    const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
    const isDark = appearance.theme === 'dark' || (appearance.theme === 'system' && prefersDark);
    if (isDark) {
      root.style.setProperty('--dash-bg', '#0F1117');
      root.style.setProperty('--dash-dark', '#F1F2F6');
      root.style.setProperty('--dash-text', '#C4C7D7');
      root.style.setProperty('--dash-muted', '#6B6F85');
      root.style.setProperty('--dash-border', '#2A2D3A');
      root.classList.add('dark');
    } else {
      root.style.setProperty('--dash-bg', '#F5F6FA');
      root.style.setProperty('--dash-dark', '#1A1D29');
      root.style.setProperty('--dash-text', '#3D4155');
      root.style.setProperty('--dash-muted', '#8B8FA8');
      root.style.setProperty('--dash-border', '#ECEDF2');
      root.classList.remove('dark');
    }

    // Compact mode
    root.style.setProperty('--spacing-scale', appearance.compactMode ? '0.85' : '1');

    // Sidebar width
    root.style.setProperty('--sidebar-width', SIDEBAR_WIDTH_MAP[appearance.sidebarWidth]);
  }, [appearance, mounted]);

  // Listen for system theme changes
  useEffect(() => {
    if (appearance.theme !== 'system') return;
    const mq = window.matchMedia('(prefers-color-scheme: dark)');
    const handler = () => setAppearance((prev) => ({ ...prev })); // trigger re-render
    mq.addEventListener('change', handler);
    return () => mq.removeEventListener('change', handler);
  }, [appearance.theme]);

  const resolvedTheme: 'light' | 'dark' = (() => {
    if (appearance.theme === 'dark') return 'dark';
    if (appearance.theme === 'system') {
      if (typeof window !== 'undefined' && window.matchMedia('(prefers-color-scheme: dark)').matches) return 'dark';
    }
    return 'light';
  })();

  const setTheme = useCallback((theme: Theme) => setAppearance((prev) => ({ ...prev, theme })), []);
  const setAccentColor = useCallback((accentColor: AccentColor) => setAppearance((prev) => ({ ...prev, accentColor })), []);
  const setFontSize = useCallback((fontSize: FontSize) => setAppearance((prev) => ({ ...prev, fontSize })), []);
  const setSidebarWidth = useCallback((sidebarWidth: SidebarWidth) => setAppearance((prev) => ({ ...prev, sidebarWidth })), []);
  const setCompactMode = useCallback((compactMode: boolean) => setAppearance((prev) => ({ ...prev, compactMode })), []);

  return (
    <ThemeContext.Provider
      value={{
        appearance,
        setTheme,
        setAccentColor,
        setFontSize,
        setSidebarWidth,
        setCompactMode,
        sidebarPx: SIDEBAR_WIDTH_MAP[appearance.sidebarWidth],
        resolvedTheme,
      }}
    >
      {children}
    </ThemeContext.Provider>
  );
}

export function useTheme() {
  const context = useContext(ThemeContext);
  if (context === undefined) {
    throw new Error('useTheme must be used within a ThemeProvider');
  }
  return context;
}

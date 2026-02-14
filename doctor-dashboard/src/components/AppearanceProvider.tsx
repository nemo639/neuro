'use client';

import { useEffect } from 'react';

type AccentColor = '#C6E94B' | '#6366F1' | '#A855F7' | '#EC4899' | '#22D3EE' | '#FB923C';
type ThemeOption = 'light' | 'dark' | 'system';

function load<T>(key: string, fallback: T): T {
  if (typeof window === 'undefined') return fallback;
  try {
    const v = localStorage.getItem(key);
    return v ? JSON.parse(v) : fallback;
  } catch {
    return fallback;
  }
}

const ACCENT_MAP: Record<AccentColor, { hover: string; light: string; dark: string }> = {
  '#C6E94B': { hover: '#B8DC3D', light: '#F0F9D6', dark: '#7A9A1E' },
  '#6366F1': { hover: '#5558E6', light: '#E0E0FF', dark: '#4338CA' },
  '#A855F7': { hover: '#9333EA', light: '#F0E0FF', dark: '#7E22CE' },
  '#EC4899': { hover: '#DB2777', light: '#FCE0F0', dark: '#BE185D' },
  '#22D3EE': { hover: '#06B6D4', light: '#D4F5FB', dark: '#0E7490' },
  '#FB923C': { hover: '#F97316', light: '#FFF0E0', dark: '#C2410C' },
};

function applyTheme(theme: ThemeOption) {
  const root = document.documentElement;
  const isDark =
    theme === 'dark' ||
    (theme === 'system' && window.matchMedia('(prefers-color-scheme: dark)').matches);

  if (isDark) {
    root.style.setProperty('--dash-bg', '#0F1117');
    root.style.setProperty('--dash-dark', '#F0F1F5');
    root.style.setProperty('--dash-text', '#C4C7D7');
    root.style.setProperty('--dash-muted', '#6B7194');
    root.style.setProperty('--dash-border', '#2A2D3E');
    document.body.style.background = '#0F1117';
    document.body.style.color = '#C4C7D7';
    document.querySelectorAll('.card, aside, header').forEach((el) => {
      (el as HTMLElement).style.backgroundColor = '#1A1D2E';
    });
  } else {
    root.style.setProperty('--dash-bg', '#F5F6FA');
    root.style.setProperty('--dash-dark', '#1A1D29');
    root.style.setProperty('--dash-text', '#3D4155');
    root.style.setProperty('--dash-muted', '#8B8FA8');
    root.style.setProperty('--dash-border', '#ECEDF2');
    document.body.style.background = '#F5F6FA';
    document.body.style.color = '#3D4155';
    document.querySelectorAll('.card, aside, header').forEach((el) => {
      (el as HTMLElement).style.backgroundColor = '';
    });
  }
}

function applyAccent(accent: AccentColor) {
  const root = document.documentElement;
  const a = ACCENT_MAP[accent] || ACCENT_MAP['#C6E94B'];
  root.style.setProperty('--accent', accent);
  root.style.setProperty('--accent-hover', a.hover);
  root.style.setProperty('--accent-light', a.light);
  root.style.setProperty('--accent-dark', a.dark);
}

function applyFontSize(size: string) {
  const sizes: Record<string, string> = { small: '14px', medium: '16px', large: '18px' };
  document.documentElement.style.fontSize = sizes[size] || '16px';
}

function applyCompactMode(compact: boolean) {
  document.documentElement.classList.toggle('compact-mode', compact);
}

/**
 * Reads appearance settings from localStorage on mount and applies them globally.
 * This ensures theme/accent/font persist across login page and dashboard.
 */
export default function AppearanceProvider({ children }: { children: React.ReactNode }) {
  useEffect(() => {
    const theme = load<ThemeOption>('nv_doc_theme', 'light');
    const accent = load<AccentColor>('nv_doc_accent', '#C6E94B');
    const fontSize = load<string>('nv_doc_fontSize', 'medium');
    const compact = load<boolean>('nv_doc_compactMode', false);

    applyTheme(theme);
    applyAccent(accent);
    applyFontSize(fontSize);
    applyCompactMode(compact);

    // Listen for system theme changes when using 'system' mode
    if (theme === 'system') {
      const mq = window.matchMedia('(prefers-color-scheme: dark)');
      const handler = () => applyTheme('system');
      mq.addEventListener('change', handler);
      return () => mq.removeEventListener('change', handler);
    }
  }, []);

  // Re-apply when localStorage changes from another tab
  useEffect(() => {
    const handler = (e: StorageEvent) => {
      if (e.key === 'nv_doc_theme') applyTheme(load('nv_doc_theme', 'light'));
      if (e.key === 'nv_doc_accent') applyAccent(load('nv_doc_accent', '#C6E94B'));
      if (e.key === 'nv_doc_fontSize') applyFontSize(load('nv_doc_fontSize', 'medium'));
      if (e.key === 'nv_doc_compactMode') applyCompactMode(load('nv_doc_compactMode', false));
    };
    window.addEventListener('storage', handler);
    return () => window.removeEventListener('storage', handler);
  }, []);

  // Re-apply when settings page saves (same tab)
  useEffect(() => {
    const handler = () => {
      applyTheme(load('nv_doc_theme', 'light'));
      applyAccent(load('nv_doc_accent', '#C6E94B'));
      applyFontSize(load('nv_doc_fontSize', 'medium'));
      applyCompactMode(load('nv_doc_compactMode', false));
    };
    window.addEventListener('nv-appearance-changed', handler);
    return () => window.removeEventListener('nv-appearance-changed', handler);
  }, []);

  return <>{children}</>;
}

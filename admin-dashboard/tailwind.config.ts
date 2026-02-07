import type { Config } from 'tailwindcss';

const config: Config = {
  content: [
    './src/pages/**/*.{js,ts,jsx,tsx,mdx}',
    './src/components/**/*.{js,ts,jsx,tsx,mdx}',
    './src/app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        accent: {
          DEFAULT: 'var(--accent)',
          hover: 'var(--accent-hover)',
          light: 'var(--accent-light)',
          bg: 'var(--accent-light)',
          dark: 'var(--accent-dark)',
          50: '#FAFEE8',
          100: '#F4FBCE',
          200: '#E8F8A2',
          300: '#D6F16B',
          400: 'var(--accent)',
          500: '#A7CC23',
          600: '#82A318',
        },
        dash: {
          bg: 'var(--dash-bg)',
          card: '#FFFFFF',
          border: 'var(--dash-border)',
          dark: 'var(--dash-dark)',
          text: 'var(--dash-text)',
          muted: 'var(--dash-muted)',
          light: '#C4C7D7',
        },
        side: {
          bg: '#FFFFFF',
          active: 'var(--accent)',
          text: 'var(--dash-muted)',
          hover: 'var(--dash-bg)',
        },
        chart: {
          lime: '#C6E94B',
          blue: '#6366F1',
          purple: '#A855F7',
          orange: '#FB923C',
          pink: '#EC4899',
          cyan: '#22D3EE',
          indigo: '#818CF8',
        },
      },
      borderRadius: {
        '2xl': '16px',
        '3xl': '20px',
        '4xl': '24px',
      },
      boxShadow: {
        card: '0 1px 3px rgba(0,0,0,0.04), 0 1px 2px rgba(0,0,0,0.02)',
        'card-hover': '0 4px 12px rgba(0,0,0,0.06), 0 2px 4px rgba(0,0,0,0.03)',
        elevated: '0 8px 24px rgba(0,0,0,0.08)',
        'input-focus': '0 0 0 3px var(--accent-glow, rgba(198,233,75,0.25))',
        'accent-glow': '0 4px 14px var(--accent-glow, rgba(198,233,75,0.35))',
        'login-card': '0 8px 32px rgba(0,0,0,0.08), 0 2px 8px rgba(0,0,0,0.04)',
        'login-card-hover': '0 12px 40px rgba(0,0,0,0.12), 0 4px 12px rgba(0,0,0,0.06)',
      },
      fontSize: {
        '2xs': ['10px', '14px'],
      },
      animation: {
        'fade-in': 'fadeIn 0.4s ease-out',
        'slide-up': 'slideUp 0.4s ease-out',
        'slide-down': 'slideDown 0.3s ease-out',
        'scale-in': 'scaleIn 0.3s ease-out',
        'count-up': 'countUp 1s ease-out',
      },
      keyframes: {
        fadeIn: {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' },
        },
        slideUp: {
          '0%': { opacity: '0', transform: 'translateY(12px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' },
        },
        slideDown: {
          '0%': { opacity: '0', transform: 'translateY(-12px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' },
        },
        scaleIn: {
          '0%': { opacity: '0', transform: 'scale(0.95)' },
          '100%': { opacity: '1', transform: 'scale(1)' },
        },
      },
    },
  },
  plugins: [],
};

export default config;

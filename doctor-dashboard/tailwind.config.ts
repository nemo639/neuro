import type { Config } from 'tailwindcss'

const config: Config = {
  content: [
    './src/pages/**/*.{js,ts,jsx,tsx,mdx}',
    './src/components/**/*.{js,ts,jsx,tsx,mdx}',
    './src/app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        // NeuroVerse Color Scheme - Matching Flutter App
        'neuro-bg': '#F7F7F7',
        'neuro-mint': '#B8E8D1',
        'neuro-lavender': '#E8DFF0',
        'neuro-beige': '#F5EBE0',
        'neuro-yellow': '#FFF3CD',
        'neuro-dark': '#1A1A1A',
        'neuro-nav': '#FAFAFA',
        'neuro-blue': '#3B82F6',
        'neuro-purple': '#8B5CF6',
        'neuro-green': '#10B981',
        'neuro-orange': '#F97316',
        'neuro-pink': '#EC4899',
        'neuro-teal': '#14B8A6',
        'neuro-red': '#EF4444',
        // Additional colors for doctor dashboard
        'neuro-card-dark': '#1A1A1A',
        'neuro-surface': '#FFFFFF',
        'neuro-muted': '#6B7280',
        'neuro-border': 'rgba(0, 0, 0, 0.08)',
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
      },
      animation: {
        'float': 'float 6s ease-in-out infinite',
        'pulse-slow': 'pulse 3s ease-in-out infinite',
        'slide-up': 'slideUp 0.5s ease-out',
        'slide-down': 'slideDown 0.5s ease-out',
        'fade-in': 'fadeIn 0.5s ease-out',
        'scale-in': 'scaleIn 0.3s ease-out',
        'shimmer': 'shimmer 2s linear infinite',
      },
      keyframes: {
        float: {
          '0%, 100%': { transform: 'translateY(0px)' },
          '50%': { transform: 'translateY(-10px)' },
        },
        slideUp: {
          '0%': { opacity: '0', transform: 'translateY(20px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' },
        },
        slideDown: {
          '0%': { opacity: '0', transform: 'translateY(-20px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' },
        },
        fadeIn: {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' },
        },
        scaleIn: {
          '0%': { opacity: '0', transform: 'scale(0.95)' },
          '100%': { opacity: '1', transform: 'scale(1)' },
        },
        shimmer: {
          '0%': { backgroundPosition: '-200% 0' },
          '100%': { backgroundPosition: '200% 0' },
        },
      },
      backdropBlur: {
        xs: '2px',
      },
      boxShadow: {
        'neuro': '0 4px 20px rgba(0, 0, 0, 0.08)',
        'neuro-lg': '0 10px 40px rgba(0, 0, 0, 0.12)',
        'neuro-glow': '0 0 30px rgba(59, 130, 246, 0.3)',
      },
    },
  },
  plugins: [],
}

export default config

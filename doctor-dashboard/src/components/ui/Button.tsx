'use client';

import { motion } from 'framer-motion';
import { ReactNode, ButtonHTMLAttributes } from 'react';

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'ghost' | 'danger';
  size?: 'sm' | 'md' | 'lg';
  icon?: ReactNode;
  children: ReactNode;
  loading?: boolean;
}

const variantStyles = {
  primary:
    'bg-gradient-to-r from-neuro-purple to-neuro-blue text-white shadow-lg hover:shadow-neuro-glow',
  secondary: 'bg-white/80 text-neuro-dark border border-neuro-dark/10 hover:border-neuro-purple/30',
  ghost: 'bg-transparent text-neuro-dark/70 hover:bg-neuro-bg',
  danger: 'bg-neuro-red/10 text-neuro-red hover:bg-neuro-red/20',
};

const sizeStyles = {
  sm: 'px-3 py-1.5 text-sm',
  md: 'px-4 py-2',
  lg: 'px-6 py-3 text-lg',
};

export function Button({
  variant = 'primary',
  size = 'md',
  icon,
  children,
  loading,
  className = '',
  disabled,
  onClick,
  type,
}: ButtonProps) {
  return (
    <motion.button
      whileHover={{ scale: disabled ? 1 : 1.02 }}
      whileTap={{ scale: disabled ? 1 : 0.98 }}
      disabled={disabled || loading}
      onClick={onClick}
      type={type}
      className={`flex items-center justify-center gap-2 font-medium rounded-xl transition-all
                 ${variantStyles[variant]} ${sizeStyles[size]}
                 disabled:opacity-50 disabled:cursor-not-allowed
                 ${className}`}
    >
      {loading ? (
        <div className="w-5 h-5 border-2 border-current border-t-transparent rounded-full animate-spin" />
      ) : (
        icon
      )}
      {children}
    </motion.button>
  );
}

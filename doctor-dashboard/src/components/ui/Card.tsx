'use client';

import { motion } from 'framer-motion';
import { ReactNode } from 'react';

interface CardProps {
  children: ReactNode;
  className?: string;
  hover?: boolean;
  onClick?: () => void;
}

export function Card({ children, className = '', hover = false, onClick }: CardProps) {
  return (
    <motion.div
      whileHover={hover ? { y: -4 } : undefined}
      onClick={onClick}
      className={`bg-white/80 backdrop-blur-xl rounded-2xl p-6 border border-white/50 
                 ${hover ? 'hover:border-neuro-purple/30 hover:shadow-neuro cursor-pointer' : ''} 
                 shadow-neuro transition-all ${className}`}
    >
      {children}
    </motion.div>
  );
}

interface CardHeaderProps {
  title: string;
  subtitle?: string;
  icon?: ReactNode;
  action?: ReactNode;
}

export function CardHeader({ title, subtitle, icon, action }: CardHeaderProps) {
  return (
    <div className="flex items-start justify-between mb-6">
      <div className="flex items-center gap-3">
        {icon && (
          <div className="p-2 bg-neuro-purple/10 rounded-xl">
            <div className="text-neuro-purple">{icon}</div>
          </div>
        )}
        <div>
          <h3 className="text-lg font-semibold text-neuro-dark">{title}</h3>
          {subtitle && <p className="text-sm text-neuro-dark/60">{subtitle}</p>}
        </div>
      </div>
      {action}
    </div>
  );
}

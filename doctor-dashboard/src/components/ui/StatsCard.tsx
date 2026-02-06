'use client';

import { motion } from 'framer-motion';
import { ReactNode } from 'react';

interface StatsCardProps {
  title: string;
  value: string | number;
  change?: number;
  icon: ReactNode;
  color: 'purple' | 'blue' | 'green' | 'orange' | 'red';
  index?: number;
}

const colorConfig = {
  purple: {
    gradient: 'from-neuro-purple to-neuro-purple/80',
    bg: 'bg-neuro-purple/10',
    text: 'text-neuro-purple',
  },
  blue: {
    gradient: 'from-neuro-blue to-neuro-blue/80',
    bg: 'bg-neuro-blue/10',
    text: 'text-neuro-blue',
  },
  green: {
    gradient: 'from-neuro-green to-neuro-green/80',
    bg: 'bg-neuro-green/10',
    text: 'text-neuro-green',
  },
  orange: {
    gradient: 'from-neuro-orange to-neuro-orange/80',
    bg: 'bg-neuro-orange/10',
    text: 'text-neuro-orange',
  },
  red: {
    gradient: 'from-neuro-red to-neuro-red/80',
    bg: 'bg-neuro-red/10',
    text: 'text-neuro-red',
  },
};

export function StatsCard({ title, value, change, icon, color, index = 0 }: StatsCardProps) {
  const config = colorConfig[color];

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: index * 0.1 }}
      whileHover={{ y: -4, scale: 1.02 }}
      className="relative bg-white/80 backdrop-blur-xl rounded-2xl p-6 border border-white/50 
                 hover:border-neuro-purple/30 shadow-neuro hover:shadow-neuro-glow transition-all 
                 overflow-hidden group"
    >
      {/* Background Decoration */}
      <div
        className={`absolute top-0 right-0 w-32 h-32 ${config.bg} rounded-full -translate-y-1/2 
                    translate-x-1/2 blur-2xl opacity-50 group-hover:opacity-70 transition-opacity`}
      />

      <div className="relative flex items-start justify-between">
        <div>
          <p className="text-neuro-dark/60 text-sm font-medium mb-2">{title}</p>
          <p className="text-3xl font-bold text-neuro-dark">{value}</p>
          {change !== undefined && (
            <p
              className={`text-sm mt-2 font-medium ${
                change >= 0 ? 'text-neuro-green' : 'text-neuro-red'
              }`}
            >
              {change >= 0 ? '↑' : '↓'} {Math.abs(change)}% from last week
            </p>
          )}
        </div>
        <div className={`p-3 rounded-xl ${config.bg}`}>
          <div className={config.text}>{icon}</div>
        </div>
      </div>
    </motion.div>
  );
}

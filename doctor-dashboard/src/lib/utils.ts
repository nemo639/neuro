import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function getRiskLevel(score: number): 'Low' | 'Moderate' | 'High' {
  if (score < 40) return 'Low';
  if (score < 70) return 'Moderate';
  return 'High';
}

export function getRiskColor(level: string): string {
  switch (level.toLowerCase()) {
    case 'low':
      return 'text-[#2AC9A0] bg-[#2AC9A0]/12';
    case 'moderate':
      return 'text-[#F5A623] bg-[#F5A623]/12';
    case 'high':
      return 'text-[#E8637A] bg-[#E8637A]/12';
    default:
      return 'text-gray-600 bg-gray-100';
  }
}

/* Hex risk colors used by inline styles */
export const RISK_COLORS = {
  low: '#2AC9A0',
  mod: '#F5A623',
  high: '#E8637A',
  lowBg: 'rgba(42,201,160,0.12)',
  modBg: 'rgba(245,166,35,0.12)',
  highBg: 'rgba(232,99,122,0.12)',
} as const;

export function riskHex(score: number): string {
  if (score >= 70) return RISK_COLORS.high;
  if (score >= 40) return RISK_COLORS.mod;
  return RISK_COLORS.low;
}

export function formatDate(date: string | Date): string {
  return new Date(date).toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  });
}

export function formatDateTime(date: string | Date): string {
  return new Date(date).toLocaleString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

export function formatTimeAgo(date: string | Date): string {
  const now = new Date();
  const past = new Date(date);
  const diffMs = now.getTime() - past.getTime();
  const diffMins = Math.floor(diffMs / 60000);
  const diffHours = Math.floor(diffMs / 3600000);
  const diffDays = Math.floor(diffMs / 86400000);

  if (diffMins < 1) return 'Just now';
  if (diffMins < 60) return `${diffMins}m ago`;
  if (diffHours < 24) return `${diffHours}h ago`;
  if (diffDays < 7) return `${diffDays}d ago`;
  return formatDate(date);
}

export function getInitials(firstName: string, lastName: string): string {
  return `${firstName.charAt(0)}${lastName.charAt(0)}`.toUpperCase();
}

export function calculateAge(dateOfBirth: string): number {
  const today = new Date();
  const birthDate = new Date(dateOfBirth);
  let age = today.getFullYear() - birthDate.getFullYear();
  const monthDiff = today.getMonth() - birthDate.getMonth();
  if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birthDate.getDate())) {
    age--;
  }
  return age;
}

// Return icon name instead of emoji - to be used with Lucide icons
export type CategoryIconType = 'brain' | 'mic' | 'hand' | 'footprints' | 'smile' | 'activity';

export function getCategoryIconName(category: string): CategoryIconType {
  switch (category.toLowerCase()) {
    case 'cognitive':
      return 'brain';
    case 'speech':
      return 'mic';
    case 'motor':
      return 'hand';
    case 'gait':
      return 'footprints';
    case 'facial':
      return 'smile';
    default:
      return 'activity';
  }
}

// Keep for backwards compatibility but mark as deprecated
/** @deprecated Use getCategoryIconName with Lucide icons instead */
export function getCategoryIcon(category: string): string {
  switch (category.toLowerCase()) {
    case 'cognitive':
      return '🧠';
    case 'speech':
      return '🎙️';
    case 'motor':
      return '✋';
    case 'gait':
      return '🚶';
    case 'facial':
      return '😊';
    default:
      return '📊';
  }
}

export function getCategoryColor(category: string): string {
  switch (category.toLowerCase()) {
    case 'cognitive':
      return 'bg-emerald-100 text-emerald-700 border-emerald-200';
    case 'speech':
      return 'bg-blue-100 text-blue-700 border-blue-200';
    case 'motor':
      return 'bg-green-100 text-green-700 border-green-200';
    case 'gait':
      return 'bg-amber-100 text-amber-700 border-amber-200';
    case 'facial':
      return 'bg-pink-100 text-pink-700 border-pink-200';
    default:
      return 'bg-gray-100 text-gray-700 border-gray-200';
  }
}

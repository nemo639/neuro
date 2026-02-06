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
      return 'text-neuro-green bg-neuro-green/10';
    case 'moderate':
      return 'text-neuro-orange bg-neuro-orange/10';
    case 'high':
      return 'text-neuro-red bg-neuro-red/10';
    default:
      return 'text-neuro-dark bg-neuro-dark/10';
  }
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
      return 'bg-neuro-purple/10 text-neuro-purple border-neuro-purple/20';
    case 'speech':
      return 'bg-neuro-blue/10 text-neuro-blue border-neuro-blue/20';
    case 'motor':
      return 'bg-neuro-green/10 text-neuro-green border-neuro-green/20';
    case 'gait':
      return 'bg-neuro-orange/10 text-neuro-orange border-neuro-orange/20';
    case 'facial':
      return 'bg-neuro-pink/10 text-neuro-pink border-neuro-pink/20';
    default:
      return 'bg-neuro-dark/10 text-neuro-dark border-neuro-dark/20';
  }
}

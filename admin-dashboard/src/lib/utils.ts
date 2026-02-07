import { type ClassValue, clsx } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function formatTimeAgo(dateString: string): string {
  const date = new Date(dateString);
  const now = new Date();
  const seconds = Math.floor((now.getTime() - date.getTime()) / 1000);

  if (seconds < 60) return 'just now';
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
  if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ago`;
  if (seconds < 604800) return `${Math.floor(seconds / 86400)}d ago`;
  return date.toLocaleDateString();
}

export function formatRole(role: string): string {
  return role?.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase()) || 'Admin';
}

export function getInitials(firstName?: string, lastName?: string): string {
  return `${(firstName || '')[0] || ''}${(lastName || '')[0] || ''}`.toUpperCase();
}

export function getStatusColor(status: string): string {
  switch (status?.toLowerCase()) {
    case 'active':
    case 'verified':
      return 'bg-emerald-50 text-emerald-600';
    case 'suspended':
    case 'rejected':
      return 'bg-red-50 text-red-600';
    case 'pending':
      return 'bg-amber-50 text-amber-600';
    case 'inactive':
      return 'bg-gray-100 text-gray-500';
    default:
      return 'bg-gray-100 text-gray-500';
  }
}

export function getPriorityColor(priority: string): string {
  switch (priority?.toLowerCase()) {
    case 'critical':
      return 'bg-red-50 text-red-600';
    case 'high':
      return 'bg-orange-50 text-orange-600';
    case 'medium':
      return 'bg-blue-50 text-blue-600';
    case 'low':
      return 'bg-emerald-50 text-emerald-600';
    default:
      return 'bg-gray-100 text-gray-500';
  }
}

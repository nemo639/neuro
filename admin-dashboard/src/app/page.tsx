'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/contexts/AuthContext';

export default function HomePage() {
  const router = useRouter();
  const { isAuthenticated, isLoading } = useAuth();

  useEffect(() => {
    if (!isLoading) {
      router.replace(isAuthenticated ? '/dashboard' : '/login');
    }
  }, [isLoading, isAuthenticated, router]);

  return (
    <div className="min-h-screen bg-admin-bg flex items-center justify-center">
      <div className="w-10 h-10 border-4 border-admin-indigo-light border-t-admin-indigo rounded-full animate-spin" />
    </div>
  );
}

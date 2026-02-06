'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import Cookies from 'js-cookie';

export default function Home() {
  const router = useRouter();

  useEffect(() => {
    const token = Cookies.get('doctor_token');
    if (token) {
      router.push('/dashboard');
    } else {
      router.push('/login');
    }
  }, [router]);

  return (
    <main className="min-h-screen bg-neuro-bg flex items-center justify-center">
      <div className="relative">
        {/* Animated Background Blobs */}
        <div className="blob blob-1" />
        <div className="blob blob-2" />
        
        {/* Loading Spinner */}
        <div className="flex flex-col items-center gap-4">
          <div className="w-16 h-16 border-4 border-neuro-mint border-t-neuro-purple rounded-full animate-spin" />
          <p className="text-neuro-dark/60 font-medium">Loading NeuroVerse...</p>
        </div>
      </div>
    </main>
  );
}

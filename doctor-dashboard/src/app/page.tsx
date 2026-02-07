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
    <main className="min-h-screen bg-[#F5F6FA] flex items-center justify-center">
      <div className="flex flex-col items-center gap-4">
        <div className="w-16 h-16 border-4 border-gray-200 border-t-emerald-500 rounded-full animate-spin" />
        <p className="text-gray-500 font-medium">Loading NeuroVerse...</p>
      </div>
    </main>
  );
}

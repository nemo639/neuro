'use client';

import { ReactNode } from 'react';
import { AuthProvider } from '@/contexts/AuthContext';
import AppearanceProvider from '@/components/AppearanceProvider';

export function Providers({ children }: { children: ReactNode }) {
  return (
    <AuthProvider>
      <AppearanceProvider>
        {children}
      </AppearanceProvider>
    </AuthProvider>
  );
}

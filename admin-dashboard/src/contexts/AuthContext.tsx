'use client';

import { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import { useRouter } from 'next/navigation';
import Cookies from 'js-cookie';
import { authApi } from '@/lib/api';

export interface AdminProfile {
  id: number;
  email: string;
  first_name: string;
  last_name: string;
  role: string;
  profile_image_url?: string | null;
}

interface AuthContextType {
  admin: AdminProfile | null;
  isLoading: boolean;
  isAuthenticated: boolean;
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
  updateAdminProfile: (updates: Partial<AdminProfile>) => void;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [admin, setAdmin] = useState<AdminProfile | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const router = useRouter();

  useEffect(() => {
    const checkAuth = () => {
      const token = Cookies.get('admin_token');
      const storedAdmin = Cookies.get('admin_profile');

      if (token && storedAdmin) {
        try {
          const parsed = JSON.parse(storedAdmin);
          setAdmin(parsed);
        } catch {
          Cookies.remove('admin_token');
          Cookies.remove('admin_profile');
          setAdmin(null);
        }
      } else {
        setAdmin(null);
      }
      setIsLoading(false);
    };

    checkAuth();
  }, []);

  const login = async (email: string, password: string) => {
    const response = await authApi.login(email, password);

    Cookies.set('admin_token', response.access_token, { expires: 1 });

    const profileData: AdminProfile = {
      id: response.admin.id,
      email: response.admin.email,
      first_name: response.admin.first_name,
      last_name: response.admin.last_name,
      role: response.admin.role || 'admin',
      profile_image_url: response.admin.profile_image_url || null,
    };
    Cookies.set('admin_profile', JSON.stringify(profileData), { expires: 1 });

    setAdmin(profileData);
    router.replace('/dashboard');
  };

  const logout = () => {
    Cookies.remove('admin_token');
    Cookies.remove('admin_profile');
    setAdmin(null);
    router.replace('/login');
  };

  const updateAdminProfile = (updates: Partial<AdminProfile>) => {
    setAdmin((prev) => {
      if (!prev) return prev;
      const updated = { ...prev, ...updates };
      Cookies.set('admin_profile', JSON.stringify(updated), { expires: 1 });
      return updated;
    });
  };

  return (
    <AuthContext.Provider value={{ admin, isLoading, isAuthenticated: !!admin, login, logout, updateAdminProfile }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}

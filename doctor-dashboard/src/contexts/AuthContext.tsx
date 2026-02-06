'use client';

import { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import { useRouter } from 'next/navigation';
import Cookies from 'js-cookie';
import { authApi } from '@/lib/api';

// Doctor profile type
export interface DoctorProfile {
  id: number;
  email: string;
  first_name: string;
  last_name: string;
  specialization?: string;
  hospital_affiliation?: string;
}

interface AuthContextType {
  doctor: DoctorProfile | null;
  isLoading: boolean;
  isAuthenticated: boolean;
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [doctor, setDoctor] = useState<DoctorProfile | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const router = useRouter();

  // Check for existing session on mount
  useEffect(() => {
    const checkAuth = () => {
      const token = Cookies.get('doctor_token');
      const storedDoctor = Cookies.get('doctor_profile');

      if (token && storedDoctor) {
        try {
          const parsed = JSON.parse(storedDoctor);
          setDoctor(parsed);
        } catch {
          // Clear invalid cookies
          Cookies.remove('doctor_token');
          Cookies.remove('doctor_refresh_token');
          Cookies.remove('doctor_profile');
          setDoctor(null);
        }
      } else {
        setDoctor(null);
      }
      setIsLoading(false);
    };

    checkAuth();
  }, []);

  const login = async (email: string, password: string) => {
    const response = await authApi.login(email, password);
    
    // Store tokens in cookies
    Cookies.set('doctor_token', response.access_token, { expires: 1 });
    if (response.refresh_token) {
      Cookies.set('doctor_refresh_token', response.refresh_token, { expires: 7 });
    }
    
    // Store profile data
    const profileData: DoctorProfile = {
      id: response.doctor.id,
      email: response.doctor.email,
      first_name: response.doctor.first_name,
      last_name: response.doctor.last_name,
      specialization: response.doctor.specialization || 'neurologist',
      hospital_affiliation: response.doctor.hospital_affiliation || '',
    };
    Cookies.set('doctor_profile', JSON.stringify(profileData), { expires: 1 });
    
    setDoctor(profileData);
    router.replace('/dashboard');
  };

  const logout = () => {
    Cookies.remove('doctor_token');
    Cookies.remove('doctor_refresh_token');
    Cookies.remove('doctor_profile');
    setDoctor(null);
    router.replace('/login');
  };

  return (
    <AuthContext.Provider value={{ 
      doctor, 
      isLoading, 
      isAuthenticated: !!doctor,
      login, 
      logout 
    }}>
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

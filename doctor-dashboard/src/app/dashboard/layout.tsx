'use client';

import { useState, useEffect } from 'react';
import { usePathname, useRouter } from 'next/navigation';
import { motion, AnimatePresence } from 'framer-motion';
import Link from 'next/link';
import Image from 'next/image';
import { useAuth } from '@/contexts/AuthContext';
import {
  LayoutDashboard,
  Users,
  FileText,
  Bell,
  Settings,
  LogOut,
  Shield,
  Search,
  Menu,
  X,
  ChevronDown,
  BarChart3,
} from 'lucide-react';

const API_BASE = process.env.NEXT_PUBLIC_API_URL || 'http://10.54.16.25:8000';

const navItems = [
  { href: '/dashboard', label: 'Dashboard', icon: LayoutDashboard },
  { href: '/dashboard/patients', label: 'Patients', icon: Users },
  { href: '/dashboard/notes', label: 'Notes', icon: FileText },
  { href: '/dashboard/alerts', label: 'Alerts', icon: Bell },
  { href: '/dashboard/reports', label: 'Reports', icon: BarChart3 },
  { href: '/dashboard/settings', label: 'Settings', icon: Settings },
];

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const { doctor, isLoading, logout } = useAuth();
  const [mobileOpen, setMobileOpen] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [sidebarW, setSidebarW] = useState(240);

  useEffect(() => {
    try {
      const stored = localStorage.getItem('nv_doc_sidebarWidth');
      if (stored) {
        const val = JSON.parse(stored);
        setSidebarW(val === 'compact' ? 200 : val === 'wide' ? 280 : 240);
      }
    } catch {}
  }, []);

  useEffect(() => {
    if (!isLoading && !doctor) router.replace('/login');
  }, [isLoading, doctor, router]);

  const isActive = (href: string) => {
    if (href === '/dashboard') return pathname === '/dashboard';
    return pathname.startsWith(href);
  };

  if (isLoading || !doctor) {
    return (
      <div className="min-h-screen bg-dash-bg flex items-center justify-center">
        <div className="flex flex-col items-center gap-3">
          <div className="w-10 h-10 bg-accent rounded-xl flex items-center justify-center">
            <Shield className="w-5 h-5 text-dash-dark" />
          </div>
          <div className="w-6 h-6 border-2 border-accent border-t-transparent rounded-full animate-spin" />
        </div>
      </div>
    );
  }

  const initials = `${doctor.first_name?.[0] || ''}${doctor.last_name?.[0] || ''}`;
  const fullName = `Dr. ${doctor.first_name || ''} ${doctor.last_name || ''}`.trim();
  // profile_image_path from DB is like "avatars/file.jpg", from upload response it's "/uploads/avatars/file.jpg"
  const avatarUrl = doctor.profile_image_path
    ? `${API_BASE}${doctor.profile_image_path.startsWith('/') ? '' : '/uploads/'}${doctor.profile_image_path}`
    : null;

  return (
    <div className="min-h-screen bg-dash-bg flex">
      {/* ═══ Sidebar — Desktop ═══ */}
      <aside className="hidden lg:flex flex-col fixed left-0 top-0 h-screen bg-white border-r border-dash-border z-50" style={{ width: sidebarW }}>
        {/* Logo */}
        <div className="h-16 flex items-center px-6 border-b border-dash-border">
          <Link href="/dashboard" className="flex items-center gap-2.5">
            <div className="w-9 h-9 bg-accent rounded-xl flex items-center justify-center">
              <Shield className="w-4 h-4 text-dash-dark" />
            </div>
            <span className="text-lg font-bold text-dash-dark">NeuroVerse</span>
          </Link>
        </div>

        {/* Nav */}
        <nav className="flex-1 py-4 px-3 space-y-1 overflow-y-auto">
          {navItems.map((item) => {
            const active = isActive(item.href);
            return (
              <Link key={item.href} href={item.href}>
                <div className={`nav-item ${active ? 'nav-item-active' : 'nav-item-inactive'}`}>
                  <item.icon className="w-[18px] h-[18px]" />
                  <span>{item.label}</span>
                </div>
              </Link>
            );
          })}
        </nav>

        {/* User */}
        <div className="p-4 border-t border-dash-border">
          <div className="flex items-center gap-3 mb-3">
            {avatarUrl ? (
              <img src={avatarUrl} alt={fullName} className="w-9 h-9 rounded-xl object-cover" />
            ) : (
              <div className="w-9 h-9 rounded-xl bg-dash-dark text-white flex items-center justify-center text-xs font-bold">
                {initials}
              </div>
            )}
            <div className="flex-1 min-w-0">
              <p className="text-sm font-semibold text-dash-dark truncate">{fullName}</p>
              <p className="text-2xs text-dash-muted truncate capitalize">{doctor.specialization?.replace('_', ' ') || 'Doctor'}</p>
            </div>
          </div>
          <button
            onClick={logout}
            className="w-full nav-item nav-item-inactive text-red-400 hover:text-red-500 hover:bg-red-50"
          >
            <LogOut className="w-[18px] h-[18px]" />
            <span>Sign Out</span>
          </button>
        </div>
      </aside>

      {/* ═══ Mobile overlay ═══ */}
      <AnimatePresence>
        {mobileOpen && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="lg:hidden fixed inset-0 bg-black/30 z-50"
            onClick={() => setMobileOpen(false)}
          />
        )}
      </AnimatePresence>

      {/* ═══ Mobile sidebar ═══ */}
      <AnimatePresence>
        {mobileOpen && (
          <motion.aside
            initial={{ x: -280 }}
            animate={{ x: 0 }}
            exit={{ x: -280 }}
            transition={{ type: 'spring', damping: 25, stiffness: 300 }}
            className="lg:hidden fixed left-0 top-0 h-screen w-[260px] bg-white z-50 shadow-elevated"
          >
            <div className="h-16 flex items-center justify-between px-5 border-b border-dash-border">
              <div className="flex items-center gap-2.5">
                <div className="w-9 h-9 bg-accent rounded-xl flex items-center justify-center">
                  <Shield className="w-4 h-4 text-dash-dark" />
                </div>
                <span className="text-lg font-bold text-dash-dark">NeuroVerse</span>
              </div>
              <button onClick={() => setMobileOpen(false)} className="p-2 hover:bg-gray-50 rounded-xl">
                <X className="w-5 h-5 text-dash-muted" />
              </button>
            </div>
            <nav className="py-4 px-3 space-y-1">
              {navItems.map((item) => {
                const active = isActive(item.href);
                return (
                  <Link key={item.href} href={item.href} onClick={() => setMobileOpen(false)}>
                    <div className={`nav-item ${active ? 'nav-item-active' : 'nav-item-inactive'}`}>
                      <item.icon className="w-[18px] h-[18px]" />
                      <span>{item.label}</span>
                    </div>
                  </Link>
                );
              })}
            </nav>
          </motion.aside>
        )}
      </AnimatePresence>

      {/* ═══ Main ═══ */}
      <main className="flex-1" style={{ marginLeft: undefined }} >
        {/* Use dynamic sidebar width */}
        <style>{`@media (min-width: 1024px) { main { margin-left: ${sidebarW}px !important; } }`}</style>
        {/* Top bar */}
        <header className="h-16 bg-white border-b border-dash-border sticky top-0 z-40 px-6 flex items-center justify-between">
          <div className="flex items-center gap-4">
            <button
              onClick={() => setMobileOpen(true)}
              className="lg:hidden p-2 hover:bg-gray-50 rounded-xl"
            >
              <Menu className="w-5 h-5 text-dash-dark" />
            </button>

            {/* Search */}
            <div className="hidden md:flex items-center w-[360px]">
              <div className="relative w-full">
                <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-dash-muted" />
                <input
                  type="text"
                  placeholder="Search patients, notes..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="w-full pl-10 pr-4 py-2 bg-dash-bg border-0 rounded-xl text-sm text-dash-dark
                           placeholder:text-dash-muted focus:outline-none focus:ring-2 focus:ring-accent/30 transition-all"
                />
              </div>
            </div>
          </div>

          {/* Right actions */}
          <div className="flex items-center gap-3">
            <Link href="/dashboard/alerts">
              <div className="relative p-2.5 hover:bg-gray-50 rounded-xl transition-colors cursor-pointer">
                <Bell className="w-5 h-5 text-dash-muted" />
                <span className="absolute top-1.5 right-1.5 w-2 h-2 bg-red-500 rounded-full" />
              </div>
            </Link>

            <div className="hidden md:flex items-center gap-3 pl-3 border-l border-dash-border">
              <div className="flex items-center gap-3 cursor-pointer">
                {avatarUrl ? (
                  <img src={avatarUrl} alt={fullName} className="w-9 h-9 rounded-xl object-cover" />
                ) : (
                  <div className="w-9 h-9 rounded-xl bg-dash-dark text-white flex items-center justify-center text-xs font-bold">
                    {initials}
                  </div>
                )}
                <div className="text-right">
                  <p className="text-sm font-semibold text-dash-dark">{fullName}</p>
                  <p className="text-2xs text-dash-muted capitalize">{doctor.specialization?.replace('_', ' ') || 'Doctor'}</p>
                </div>
                <ChevronDown className="w-4 h-4 text-dash-muted" />
              </div>
            </div>
          </div>
        </header>

        {/* Page content */}
        <div className="p-6 lg:p-8">
          {children}
        </div>
      </main>
    </div>
  );
}

'use client';

import { useState, useEffect } from 'react';
import { useRouter, usePathname } from 'next/navigation';
import Link from 'next/link';
import { motion, AnimatePresence } from 'framer-motion';
import { useAuth } from '@/contexts/AuthContext';
import { useTheme } from '@/contexts/ThemeContext';
import { formatRole, getInitials } from '@/lib/utils';
import {
  LayoutDashboard,
  Users,
  Stethoscope,
  TicketCheck,
  BarChart3,
  Settings,
  Shield,
  LogOut,
  Bell,
  Search,
  Menu,
  X,
  ChevronDown,
  MessageSquareText,
} from 'lucide-react';

const API_BASE = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000';

const navItems = [
  { href: '/dashboard', label: 'Dashboard', icon: LayoutDashboard },
  { href: '/dashboard/users', label: 'Users', icon: Users },
  { href: '/dashboard/doctors', label: 'Doctors', icon: Stethoscope },
  { href: '/dashboard/tickets', label: 'Tickets', icon: TicketCheck },
  { href: '/dashboard/feedback', label: 'Feedback', icon: MessageSquareText },
  { href: '/dashboard/analytics', label: 'Analytics', icon: BarChart3 },
  { href: '/dashboard/settings', label: 'Settings', icon: Settings },
];

function AdminAvatar({ admin, size = 'sm' }: { admin: { first_name: string; last_name: string; profile_image_url?: string | null }; size?: 'sm' | 'md' }) {
  const dim = size === 'sm' ? 'w-9 h-9' : 'w-10 h-10';
  const textSize = size === 'sm' ? 'text-xs' : 'text-sm';

  if (admin.profile_image_url) {
    const imgSrc = admin.profile_image_url.startsWith('/uploads')
      ? `${API_BASE}${admin.profile_image_url}`
      : admin.profile_image_url;
    return (
      <div className={`${dim} rounded-xl overflow-hidden flex-shrink-0`}>
        <img src={imgSrc} alt="Avatar" className="w-full h-full object-cover" />
      </div>
    );
  }

  return (
    <div className={`${dim} rounded-xl bg-dash-dark text-white flex items-center justify-center ${textSize} font-bold flex-shrink-0`}>
      {getInitials(admin.first_name, admin.last_name)}
    </div>
  );
}

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  const { admin, isLoading, isAuthenticated, logout } = useAuth();
  const { sidebarPx } = useTheme();
  const router = useRouter();
  const pathname = usePathname();
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');

  useEffect(() => {
    if (!isLoading && !isAuthenticated) router.replace('/login');
  }, [isLoading, isAuthenticated, router]);

  const isActive = (href: string) => {
    if (href === '/dashboard') return pathname === '/dashboard';
    return pathname.startsWith(href);
  };

  if (isLoading || !isAuthenticated) {
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

  return (
    <div className="min-h-screen bg-dash-bg flex">
      {/* Sidebar — Desktop */}
      <aside className="hidden lg:flex flex-col fixed left-0 top-0 h-screen bg-white border-r border-dash-border z-50 transition-all duration-300" style={{ width: sidebarPx }}>
        {/* Logo */}
        <div className="h-16 flex items-center px-6 border-b border-dash-border">
          <Link href="/dashboard" className="flex items-center gap-2.5">
            <div className="w-9 h-9 bg-accent rounded-xl flex items-center justify-center">
              <Shield className="w-4.5 h-4.5 text-dash-dark" />
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
          {admin && (
            <div className="flex items-center gap-3 mb-3">
              <AdminAvatar admin={admin} size="sm" />
              <div className="flex-1 min-w-0">
                <p className="text-sm font-semibold text-dash-dark truncate">
                  {admin.first_name} {admin.last_name}
                </p>
                <p className="text-2xs text-dash-muted truncate">{formatRole(admin.role)}</p>
              </div>
            </div>
          )}
          <button
            onClick={logout}
            className="w-full nav-item nav-item-inactive text-red-400 hover:text-red-500 hover:bg-red-50"
          >
            <LogOut className="w-[18px] h-[18px]" />
            <span>Sign Out</span>
          </button>
        </div>
      </aside>

      {/* Mobile overlay */}
      <AnimatePresence>
        {isMobileMenuOpen && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="lg:hidden fixed inset-0 bg-black/30 z-50"
            onClick={() => setIsMobileMenuOpen(false)}
          />
        )}
      </AnimatePresence>

      {/* Mobile sidebar */}
      <AnimatePresence>
        {isMobileMenuOpen && (
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
                  <Shield className="w-4.5 h-4.5 text-dash-dark" />
                </div>
                <span className="text-lg font-bold text-dash-dark">NeuroVerse</span>
              </div>
              <button onClick={() => setIsMobileMenuOpen(false)} className="p-2 hover:bg-gray-50 rounded-xl">
                <X className="w-5 h-5 text-dash-muted" />
              </button>
            </div>
            <nav className="py-4 px-3 space-y-1">
              {navItems.map((item) => {
                const active = isActive(item.href);
                return (
                  <Link key={item.href} href={item.href} onClick={() => setIsMobileMenuOpen(false)}>
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

      {/* Main */}
      <main className="flex-1 transition-all duration-300" style={{ marginLeft: sidebarPx }}>
        <style>{`@media (max-width: 1023px) { main { margin-left: 0 !important; } }`}</style>
        {/* Top bar */}
        <header className="h-16 bg-white border-b border-dash-border sticky top-0 z-40 px-6 flex items-center justify-between">
          <div className="flex items-center gap-4">
            <button
              onClick={() => setIsMobileMenuOpen(true)}
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
                  placeholder="Search candidate, vacancy etc"
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
            <button className="relative p-2.5 hover:bg-gray-50 rounded-xl transition-colors">
              <Bell className="w-5 h-5 text-dash-muted" />
              <span className="absolute top-1.5 right-1.5 w-2 h-2 bg-red-500 rounded-full" />
            </button>

            <div className="hidden md:flex items-center gap-3 pl-3 border-l border-dash-border">
              {admin && (
                <div className="flex items-center gap-3 cursor-pointer">
                  <AdminAvatar admin={admin} size="sm" />
                  <div className="text-right">
                    <p className="text-sm font-semibold text-dash-dark">
                      {admin.first_name} {admin.last_name}
                    </p>
                    <p className="text-2xs text-dash-muted">{formatRole(admin.role)}</p>
                  </div>
                  <ChevronDown className="w-4 h-4 text-dash-muted" />
                </div>
              )}
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

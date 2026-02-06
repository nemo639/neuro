'use client';

import { useState } from 'react';
import { usePathname, useRouter } from 'next/navigation';
import { motion, AnimatePresence } from 'framer-motion';
import Link from 'next/link';
import { useAuth } from '@/contexts/AuthContext';
import {
  LayoutDashboard,
  Users,
  FileText,
  Bell,
  Settings,
  LogOut,
  Brain,
  ChevronLeft,
  ChevronRight,
  Search,
  Menu,
  X,
} from 'lucide-react';

interface DashboardLayoutProps {
  children: React.ReactNode;
}

const navItems = [
  { icon: LayoutDashboard, label: 'Dashboard', href: '/dashboard' },
  { icon: Users, label: 'Patients', href: '/dashboard/patients' },
  { icon: FileText, label: 'Clinical Notes', href: '/dashboard/notes' },
  { icon: Bell, label: 'Alerts', href: '/dashboard/alerts' },
  { icon: Settings, label: 'Settings', href: '/dashboard/settings' },
];

export default function DashboardLayout({ children }: DashboardLayoutProps) {
  const pathname = usePathname();
  const router = useRouter();
  const { doctor, isLoading, logout } = useAuth();
  const [isSidebarCollapsed, setIsSidebarCollapsed] = useState(false);
  const [isMobileSidebarOpen, setIsMobileSidebarOpen] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [notifications, setNotifications] = useState(3);

  const handleLogout = () => {
    logout();
  };

  const isActive = (href: string) => pathname === href;

  // Show loading state while checking authentication
  if (isLoading) {
    return (
      <div className="min-h-screen bg-neuro-bg flex items-center justify-center">
        <div className="flex flex-col items-center gap-4">
          <div className="w-12 h-12 border-4 border-neuro-mint border-t-neuro-purple rounded-full animate-spin" />
          <p className="text-neuro-dark/60">Loading...</p>
        </div>
      </div>
    );
  }

  // If not authenticated after loading, show nothing (redirect will happen from AuthContext)
  if (!doctor) {
    return (
      <div className="min-h-screen bg-neuro-bg flex items-center justify-center">
        <div className="flex flex-col items-center gap-4">
          <div className="w-12 h-12 border-4 border-neuro-mint border-t-neuro-purple rounded-full animate-spin" />
          <p className="text-neuro-dark/60">Redirecting to login...</p>
        </div>
      </div>
    );
  }

  const doctorProfile = doctor;

  return (
    <div className="min-h-screen bg-neuro-bg flex">
      {/* Sidebar - Desktop */}
      <motion.aside
        initial={false}
        animate={{ width: isSidebarCollapsed ? 80 : 280 }}
        transition={{ duration: 0.3, ease: 'easeInOut' }}
        className="hidden lg:flex flex-col fixed left-0 top-0 h-screen bg-white/80 backdrop-blur-xl 
                   border-r border-neuro-dark/5 z-50"
      >
        {/* Logo */}
        <div className="h-20 flex items-center px-6 border-b border-neuro-dark/5">
          <Link href="/dashboard" className="flex items-center gap-3">
            <motion.div
              whileHover={{ rotate: 360 }}
              transition={{ duration: 0.5 }}
              className="w-10 h-10 rounded-xl bg-gradient-to-br from-neuro-purple to-neuro-blue 
                         flex items-center justify-center shadow-lg flex-shrink-0"
            >
              <Brain className="w-6 h-6 text-white" />
            </motion.div>
            <AnimatePresence>
              {!isSidebarCollapsed && (
                <motion.div
                  initial={{ opacity: 0, x: -10 }}
                  animate={{ opacity: 1, x: 0 }}
                  exit={{ opacity: 0, x: -10 }}
                  transition={{ duration: 0.2 }}
                >
                  <h1 className="text-xl font-bold gradient-text">NeuroVerse</h1>
                  <p className="text-xs text-neuro-dark/50">Doctor Portal</p>
                </motion.div>
              )}
            </AnimatePresence>
          </Link>
        </div>

        {/* Navigation */}
        <nav className="flex-1 py-6 px-4 space-y-1 overflow-y-auto">
          {navItems.map((item) => (
            <Link key={item.href} href={item.href}>
              <motion.div
                whileHover={{ scale: 1.02 }}
                whileTap={{ scale: 0.98 }}
                className={`flex items-center gap-3 px-4 py-3 rounded-xl transition-all duration-200 cursor-pointer
                  ${isActive(item.href)
                    ? 'bg-gradient-to-r from-neuro-purple/10 to-neuro-blue/10 text-neuro-purple border border-neuro-purple/20 shadow-sm'
                    : 'text-neuro-dark/60 hover:bg-neuro-bg/80 hover:text-neuro-dark'
                  }`}
              >
                <item.icon className={`w-5 h-5 flex-shrink-0 ${isActive(item.href) ? 'text-neuro-purple' : ''}`} />
                <AnimatePresence>
                  {!isSidebarCollapsed && (
                    <motion.span
                      initial={{ opacity: 0 }}
                      animate={{ opacity: 1 }}
                      exit={{ opacity: 0 }}
                      transition={{ duration: 0.15 }}
                      className="font-medium"
                    >
                      {item.label}
                    </motion.span>
                  )}
                </AnimatePresence>
              </motion.div>
            </Link>
          ))}
        </nav>

        {/* User Profile */}
        <div className="p-4 border-t border-neuro-dark/5">
          {doctorProfile && (
            <div className={`flex items-center gap-3 ${isSidebarCollapsed ? 'justify-center' : ''}`}>
              <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-neuro-mint to-neuro-green 
                            flex items-center justify-center text-white font-semibold flex-shrink-0">
                {doctorProfile.first_name?.[0]}{doctorProfile.last_name?.[0]}
              </div>
              <AnimatePresence>
                {!isSidebarCollapsed && (
                  <motion.div
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    exit={{ opacity: 0 }}
                    className="flex-1 min-w-0"
                  >
                    <p className="text-sm font-semibold text-neuro-dark truncate">
                      Dr. {doctorProfile.first_name} {doctorProfile.last_name}
                    </p>
                    <p className="text-xs text-neuro-dark/50 capitalize truncate">
                      {doctorProfile.specialization?.replace('_', ' ')}
                    </p>
                  </motion.div>
                )}
              </AnimatePresence>
            </div>
          )}
          
          {/* Logout Button */}
          <motion.button
            whileHover={{ scale: 1.02 }}
            whileTap={{ scale: 0.98 }}
            onClick={handleLogout}
            className={`mt-4 w-full flex items-center gap-3 px-4 py-3 rounded-xl text-neuro-red/80 
                       hover:bg-neuro-red/10 transition-all duration-200 ${isSidebarCollapsed ? 'justify-center' : ''}`}
          >
            <LogOut className="w-5 h-5 flex-shrink-0" />
            {!isSidebarCollapsed && <span className="font-medium">Sign Out</span>}
          </motion.button>
        </div>

        {/* Collapse Toggle */}
        <button
          onClick={() => setIsSidebarCollapsed(!isSidebarCollapsed)}
          className="absolute -right-3 top-24 w-6 h-6 bg-white border border-neuro-dark/10 
                     rounded-full flex items-center justify-center shadow-sm hover:shadow-md 
                     transition-all duration-200"
        >
          {isSidebarCollapsed ? (
            <ChevronRight className="w-4 h-4 text-neuro-dark/60" />
          ) : (
            <ChevronLeft className="w-4 h-4 text-neuro-dark/60" />
          )}
        </button>
      </motion.aside>

      {/* Mobile Sidebar Overlay */}
      <AnimatePresence>
        {isMobileSidebarOpen && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="lg:hidden fixed inset-0 bg-black/50 backdrop-blur-sm z-50"
            onClick={() => setIsMobileSidebarOpen(false)}
          />
        )}
      </AnimatePresence>

      {/* Mobile Sidebar */}
      <AnimatePresence>
        {isMobileSidebarOpen && (
          <motion.aside
            initial={{ x: -300 }}
            animate={{ x: 0 }}
            exit={{ x: -300 }}
            transition={{ type: 'spring', damping: 25 }}
            className="lg:hidden fixed left-0 top-0 h-screen w-72 bg-white z-50 shadow-xl"
          >
            <div className="h-20 flex items-center justify-between px-6 border-b border-neuro-dark/5">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-neuro-purple to-neuro-blue 
                               flex items-center justify-center">
                  <Brain className="w-6 h-6 text-white" />
                </div>
                <div>
                  <h1 className="text-xl font-bold gradient-text">NeuroVerse</h1>
                  <p className="text-xs text-neuro-dark/50">Doctor Portal</p>
                </div>
              </div>
              <button onClick={() => setIsMobileSidebarOpen(false)}>
                <X className="w-6 h-6 text-neuro-dark/60" />
              </button>
            </div>
            
            <nav className="py-6 px-4 space-y-2">
              {navItems.map((item) => (
                <Link key={item.href} href={item.href} onClick={() => setIsMobileSidebarOpen(false)}>
                  <div className={`flex items-center gap-3 px-4 py-3 rounded-xl transition-all
                    ${isActive(item.href)
                      ? 'bg-gradient-to-r from-neuro-purple/10 to-neuro-blue/10 text-neuro-purple'
                      : 'text-neuro-dark/60 hover:bg-neuro-bg'
                    }`}
                  >
                    <item.icon className="w-5 h-5" />
                    <span className="font-medium">{item.label}</span>
                  </div>
                </Link>
              ))}
            </nav>
          </motion.aside>
        )}
      </AnimatePresence>

      {/* Main Content */}
      <main className={`flex-1 transition-all duration-300 ${isSidebarCollapsed ? 'lg:ml-20' : 'lg:ml-[280px]'}`}>
        {/* Top Header */}
        <header className="h-20 bg-white/60 backdrop-blur-xl border-b border-neuro-dark/5 
                         sticky top-0 z-40 px-6 flex items-center justify-between">
          {/* Mobile Menu Button */}
          <button
            onClick={() => setIsMobileSidebarOpen(true)}
            className="lg:hidden p-2 hover:bg-neuro-bg rounded-xl transition-colors"
          >
            <Menu className="w-6 h-6 text-neuro-dark" />
          </button>

          {/* Search Bar */}
          <div className="hidden md:flex items-center flex-1 max-w-xl">
            <div className="relative w-full">
              <Search className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-neuro-dark/40" />
              <input
                type="text"
                placeholder="Search patients, notes, reports..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="w-full pl-12 pr-4 py-3 bg-neuro-bg/50 border border-neuro-dark/10 rounded-xl
                         focus:outline-none focus:ring-2 focus:ring-neuro-purple/20 focus:border-neuro-purple/30
                         text-neuro-dark placeholder:text-neuro-dark/40 transition-all"
              />
            </div>
          </div>

          {/* Right Actions */}
          <div className="flex items-center gap-4">
            {/* Notifications */}
            <motion.button
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
              className="relative p-3 bg-neuro-bg/50 rounded-xl hover:bg-neuro-lavender/50 transition-colors"
            >
              <Bell className="w-5 h-5 text-neuro-dark/70" />
              {notifications > 0 && (
                <span className="absolute -top-1 -right-1 w-5 h-5 bg-neuro-red text-white text-xs 
                               rounded-full flex items-center justify-center font-medium">
                  {notifications}
                </span>
              )}
            </motion.button>

            {/* Profile Quick View - Desktop */}
            <div className="hidden md:flex items-center gap-3 pl-4 border-l border-neuro-dark/10">
              {doctorProfile && (
                <>
                  <div className="text-right">
                    <p className="text-sm font-semibold text-neuro-dark">
                      Dr. {doctorProfile.first_name}
                    </p>
                    <p className="text-xs text-neuro-dark/50">
                      {doctorProfile.hospital_affiliation || 'NeuroVerse Clinic'}
                    </p>
                  </div>
                  <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-neuro-mint to-neuro-green 
                                flex items-center justify-center text-white font-semibold">
                    {doctorProfile.first_name?.[0]}{doctorProfile.last_name?.[0]}
                  </div>
                </>
              )}
            </div>
          </div>
        </header>

        {/* Page Content */}
        <div className="p-6">
          {children}
        </div>
      </main>
    </div>
  );
}

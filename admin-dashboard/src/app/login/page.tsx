'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { motion } from 'framer-motion';
import { useAuth } from '@/contexts/AuthContext';
import { Eye, EyeOff, Shield, AlertCircle, ArrowRight } from 'lucide-react';

export default function AdminLoginPage() {
  const router = useRouter();
  const { login, isLoading: authLoading, isAuthenticated } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    if (!authLoading && isAuthenticated) router.replace('/dashboard');
  }, [authLoading, isAuthenticated, router]);

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);
    setError('');
    try {
      await login(email, password);
    } catch (err: any) {
      setError(err.response?.data?.detail || 'Invalid credentials');
    } finally {
      setIsLoading(false);
    }
  };

  if (authLoading || isAuthenticated) {
    return (
      <div className="min-h-screen bg-dash-bg flex items-center justify-center">
        <div className="w-8 h-8 border-3 border-accent border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-dash-bg flex">
      {/* Left panel — branding */}
      <div className="hidden lg:flex lg:w-[55%] bg-dash-dark relative overflow-hidden flex-col justify-between p-12">
        {/* Decorative circles */}
        <div className="absolute -top-32 -left-32 w-96 h-96 rounded-full bg-accent/5" />
        <div className="absolute -bottom-20 -right-20 w-80 h-80 rounded-full bg-accent/8" />
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[500px] h-[500px] rounded-full bg-accent/3" />

        {/* Top — Logo */}
        <motion.div initial={{ opacity: 0, y: -20 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.6 }}>
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-accent rounded-xl flex items-center justify-center">
              <Shield className="w-5 h-5 text-dash-dark" />
            </div>
            <span className="text-white text-xl font-bold">NeuroVerse</span>
          </div>
        </motion.div>

        {/* Center — Hero text */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 0.2 }}
          className="relative z-10"
        >
          <h1 className="text-5xl font-extrabold text-white leading-tight mb-4">
            Admin<br />
            <span className="text-accent">Dashboard</span>
          </h1>
          <p className="text-dash-muted text-lg max-w-md leading-relaxed">
            Manage your platform, monitor analytics, verify doctors, and resolve support tickets — all from one place.
          </p>

          {/* Stats row */}
          <div className="flex gap-8 mt-10">
            {[
              { value: '2,847', label: 'Total Users' },
              { value: '72', label: 'Active Doctors' },
              { value: '98.9%', label: 'Uptime' },
            ].map((stat, i) => (
              <motion.div
                key={stat.label}
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.5, delay: 0.4 + i * 0.1 }}
              >
                <p className="text-3xl font-bold text-white">{stat.value}</p>
                <p className="text-dash-muted text-sm mt-1">{stat.label}</p>
              </motion.div>
            ))}
          </div>
        </motion.div>

        {/* Bottom */}
        <motion.p
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.8 }}
          className="text-dash-muted/50 text-sm"
        >
          © 2026 NeuroVerse AI Health Platform
        </motion.p>
      </div>

      {/* Right panel — login form */}
      <div className="flex-1 flex items-center justify-center p-8">
        <motion.div
          initial={{ opacity: 0, x: 20 }}
          animate={{ opacity: 1, x: 0 }}
          transition={{ duration: 0.5 }}
          className="w-full max-w-[440px]"
        >
          {/* Mobile logo */}
          <div className="lg:hidden flex items-center gap-3 mb-10">
            <div className="w-10 h-10 bg-accent rounded-xl flex items-center justify-center">
              <Shield className="w-5 h-5 text-dash-dark" />
            </div>
            <span className="text-dash-dark text-xl font-bold">NeuroVerse</span>
          </div>

          {/* Card wrapper */}
          <motion.div
            whileHover={{ y: -2, boxShadow: '0 12px 40px rgba(0,0,0,0.12), 0 4px 12px rgba(0,0,0,0.06)' }}
            transition={{ duration: 0.2 }}
            className="bg-white rounded-2xl border border-dash-border shadow-login-card p-8 lg:p-10"
          >
            <h2 className="text-2xl font-bold text-dash-dark mb-2">Welcome back</h2>
            <p className="text-dash-muted text-sm mb-8">Enter your credentials to access the admin panel</p>

            {error && (
              <motion.div
                initial={{ opacity: 0, y: -10 }}
                animate={{ opacity: 1, y: 0 }}
                className="flex items-center gap-2 p-3 mb-6 bg-red-50 border border-red-100 text-red-600 text-sm rounded-xl"
              >
                <AlertCircle className="w-4 h-4 flex-shrink-0" />
                {error}
              </motion.div>
            )}

            <form onSubmit={handleLogin} className="space-y-5">
              <div>
                <label className="block text-sm font-medium text-dash-dark mb-2">Email</label>
                <input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="admin@neuroverse.com"
                  className="input hover:border-dash-muted"
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-dash-dark mb-2">Password</label>
                <div className="relative">
                  <input
                    type={showPassword ? 'text' : 'password'}
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    placeholder="Enter your password"
                    className="input pr-11 hover:border-dash-muted"
                    required
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword(!showPassword)}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-dash-muted hover:text-dash-text transition-colors p-1 rounded-lg hover:bg-dash-bg"
                  >
                    {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                  </button>
                </div>
              </div>

              <div className="flex items-center justify-between">
                <label className="flex items-center gap-2 cursor-pointer group">
                  <input type="checkbox" className="w-4 h-4 rounded border-dash-border accent-accent" />
                  <span className="text-sm text-dash-muted group-hover:text-dash-text transition-colors">Remember me</span>
                </label>
                <a href="/forgot-password" className="text-sm font-medium text-accent-dark hover:text-dash-dark transition-colors">
                  Forgot password?
                </a>
              </div>

              <motion.button
                type="submit"
                disabled={isLoading}
                whileHover={{ scale: 1.02, boxShadow: '0 4px 14px var(--accent-glow, rgba(198,233,75,0.35))' }}
                whileTap={{ scale: 0.98 }}
                className="w-full btn-primary py-3.5 flex items-center justify-center gap-2 disabled:opacity-60 text-[15px]"
              >
                {isLoading ? (
                  <div className="w-5 h-5 border-2 border-dash-dark/30 border-t-dash-dark rounded-full animate-spin" />
                ) : (
                  <>
                    Sign In
                    <ArrowRight className="w-4 h-4" />
                  </>
                )}
              </motion.button>
            </form>
          </motion.div>

          <p className="text-center text-dash-muted text-xs mt-6">
            Secured with 256-bit encryption
          </p>
        </motion.div>
      </div>
    </div>
  );
}

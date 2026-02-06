'use client';

import { useState, useEffect } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { motion } from 'framer-motion';
import Cookies from 'js-cookie';
import { useAuth } from '@/contexts/AuthContext';
import { 
  Eye, 
  EyeOff, 
  Mail, 
  Lock, 
  Brain, 
  Activity,
  Sparkles,
  ArrowRight,
  AlertCircle
} from 'lucide-react';

export default function LoginPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const { login, isLoading: authLoading, isAuthenticated } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState('');

  // If redirected here due to auth failure, clear any stale cookies
  useEffect(() => {
    const from = searchParams.get('from');
    if (from) {
      // User was redirected from a protected page, clear stale auth
      Cookies.remove('doctor_token');
      Cookies.remove('doctor_refresh_token');
      Cookies.remove('doctor_profile');
    }
  }, [searchParams]);

  // Redirect if already authenticated
  useEffect(() => {
    if (!authLoading && isAuthenticated) {
      router.replace('/dashboard');
    }
  }, [authLoading, isAuthenticated, router]);

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);
    setError('');

    try {
      await login(email, password);
      // Redirect handled by AuthContext
    } catch (err: any) {
      setError(err.response?.data?.detail || 'Invalid email or password');
    } finally {
      setIsLoading(false);
    }
  };

  // Show loading while checking auth
  if (authLoading) {
    return (
      <div className="min-h-screen bg-neuro-bg flex items-center justify-center">
        <div className="w-12 h-12 border-4 border-neuro-mint border-t-neuro-purple rounded-full animate-spin" />
      </div>
    );
  }

  // Don't render login form if already authenticated (will redirect)
  if (isAuthenticated) {
    return (
      <div className="min-h-screen bg-neuro-bg flex items-center justify-center">
        <div className="flex flex-col items-center gap-4">
          <div className="w-12 h-12 border-4 border-neuro-mint border-t-neuro-purple rounded-full animate-spin" />
          <p className="text-neuro-dark/60">Redirecting to dashboard...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-neuro-bg relative overflow-hidden">
      {/* Animated Background Blobs */}
      <motion.div
        className="absolute w-[500px] h-[500px] rounded-full"
        style={{
          background: 'linear-gradient(135deg, rgba(184, 232, 209, 0.5) 0%, rgba(59, 130, 246, 0.2) 100%)',
          filter: 'blur(80px)',
          top: '-200px',
          right: '-200px',
        }}
        animate={{
          scale: [1, 1.1, 1],
          x: [0, 20, 0],
          y: [0, -20, 0],
        }}
        transition={{
          duration: 8,
          repeat: Infinity,
          ease: 'easeInOut',
        }}
      />
      <motion.div
        className="absolute w-[600px] h-[600px] rounded-full"
        style={{
          background: 'linear-gradient(135deg, rgba(232, 223, 240, 0.6) 0%, rgba(139, 92, 246, 0.2) 100%)',
          filter: 'blur(80px)',
          bottom: '-250px',
          left: '-250px',
        }}
        animate={{
          scale: [1, 1.15, 1],
          x: [0, -30, 0],
          y: [0, 30, 0],
        }}
        transition={{
          duration: 10,
          repeat: Infinity,
          ease: 'easeInOut',
          delay: 1,
        }}
      />
      <motion.div
        className="absolute w-[300px] h-[300px] rounded-full"
        style={{
          background: 'linear-gradient(135deg, rgba(254, 243, 226, 0.4) 0%, rgba(249, 115, 22, 0.15) 100%)',
          filter: 'blur(60px)',
          top: '40%',
          left: '60%',
        }}
        animate={{
          scale: [1, 1.2, 1],
          rotate: [0, 180, 360],
        }}
        transition={{
          duration: 15,
          repeat: Infinity,
          ease: 'linear',
        }}
      />

      {/* Content */}
      <div className="relative z-10 min-h-screen flex">
        {/* Left Side - Branding */}
        <div className="hidden lg:flex lg:w-1/2 flex-col justify-center items-center p-12">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.8 }}
            className="max-w-lg"
          >
            {/* Logo */}
            <motion.div 
              className="flex items-center gap-3 mb-8"
              initial={{ opacity: 0, x: -20 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ delay: 0.2 }}
            >
              <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-neuro-purple to-neuro-blue flex items-center justify-center shadow-lg">
                <Brain className="w-8 h-8 text-white" />
              </div>
              <div>
                <h1 className="text-3xl font-bold gradient-text">NeuroVerse</h1>
                <p className="text-neuro-dark/60 text-sm">Doctor Portal</p>
              </div>
            </motion.div>

            {/* Hero Text */}
            <motion.h2 
              className="text-4xl font-bold text-neuro-dark mb-4 leading-tight"
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.3 }}
            >
              AI-Powered Neurological
              <span className="gradient-text"> Health Screening</span>
            </motion.h2>
            
            <motion.p 
              className="text-neuro-dark/60 text-lg mb-8"
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.4 }}
            >
              Monitor patient progress, analyze test results, and make informed 
              clinical decisions with our explainable AI platform.
            </motion.p>

            {/* Feature Cards */}
            <div className="grid grid-cols-2 gap-4">
              {[
                { icon: Activity, title: 'Real-time Monitoring', color: 'bg-neuro-mint' },
                { icon: Brain, title: 'AI Risk Analysis', color: 'bg-neuro-lavender' },
                { icon: Sparkles, title: 'XAI Explanations', color: 'bg-neuro-beige' },
              ].map((feature, index) => (
                <motion.div
                  key={feature.title}
                  className={`p-4 rounded-2xl ${feature.color} card-hover`}
                  initial={{ opacity: 0, y: 20 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: 0.5 + index * 0.1 }}
                >
                  <feature.icon className="w-6 h-6 text-neuro-dark mb-2" />
                  <p className="text-sm font-medium text-neuro-dark">{feature.title}</p>
                </motion.div>
              ))}
            </div>
          </motion.div>
        </div>

        {/* Right Side - Login Form */}
        <div className="w-full lg:w-1/2 flex items-center justify-center p-6">
          <motion.div
            initial={{ opacity: 0, scale: 0.95 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{ duration: 0.5 }}
            className="w-full max-w-md"
          >
            {/* Mobile Logo */}
            <div className="lg:hidden flex items-center gap-3 mb-8 justify-center">
              <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-neuro-purple to-neuro-blue flex items-center justify-center">
                <Brain className="w-7 h-7 text-white" />
              </div>
              <div>
                <h1 className="text-2xl font-bold gradient-text">NeuroVerse</h1>
                <p className="text-neuro-dark/60 text-xs">Doctor Portal</p>
              </div>
            </div>

            {/* Login Card */}
            <motion.div 
              className="bg-white/80 backdrop-blur-xl rounded-3xl p-8 shadow-neuro-lg border border-white/50"
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.2 }}
            >
              <div className="text-center mb-8">
                <h2 className="text-2xl font-bold text-neuro-dark mb-2">Welcome Back</h2>
                <p className="text-neuro-dark/60">Sign in to your doctor account</p>
              </div>

              {/* Error Message */}
              {error && (
                <motion.div
                  initial={{ opacity: 0, y: -10 }}
                  animate={{ opacity: 1, y: 0 }}
                  className="mb-6 p-4 bg-neuro-red/10 border border-neuro-red/20 rounded-xl flex items-center gap-3"
                >
                  <AlertCircle className="w-5 h-5 text-neuro-red" />
                  <p className="text-sm text-neuro-red">{error}</p>
                </motion.div>
              )}

              <form onSubmit={handleLogin} className="space-y-5">
                {/* Email Input */}
                <div className="space-y-2">
                  <label className="text-sm font-medium text-neuro-dark/70">Email Address</label>
                  <div className="relative">
                    <Mail className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-neuro-dark/40" />
                    <input
                      type="email"
                      value={email}
                      onChange={(e) => setEmail(e.target.value)}
                      placeholder="doctor@hospital.com"
                      className="w-full pl-12 pr-4 py-4 bg-neuro-bg/50 border border-neuro-dark/10 rounded-xl 
                               focus:outline-none focus:ring-2 focus:ring-neuro-purple/30 focus:border-neuro-purple
                               transition-all duration-200 text-neuro-dark placeholder:text-neuro-dark/40"
                      required
                    />
                  </div>
                </div>

                {/* Password Input */}
                <div className="space-y-2">
                  <label className="text-sm font-medium text-neuro-dark/70">Password</label>
                  <div className="relative">
                    <Lock className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-neuro-dark/40" />
                    <input
                      type={showPassword ? 'text' : 'password'}
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                      placeholder="••••••••"
                      className="w-full pl-12 pr-12 py-4 bg-neuro-bg/50 border border-neuro-dark/10 rounded-xl 
                               focus:outline-none focus:ring-2 focus:ring-neuro-purple/30 focus:border-neuro-purple
                               transition-all duration-200 text-neuro-dark placeholder:text-neuro-dark/40"
                      required
                    />
                    <button
                      type="button"
                      onClick={() => setShowPassword(!showPassword)}
                      className="absolute right-4 top-1/2 -translate-y-1/2 text-neuro-dark/40 hover:text-neuro-dark transition-colors"
                    >
                      {showPassword ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
                    </button>
                  </div>
                </div>

                {/* Remember & Forgot */}
                <div className="flex items-center justify-between">
                  <label className="flex items-center gap-2 cursor-pointer">
                    <input 
                      type="checkbox" 
                      className="w-4 h-4 rounded border-neuro-dark/20 text-neuro-purple focus:ring-neuro-purple"
                    />
                    <span className="text-sm text-neuro-dark/60">Remember me</span>
                  </label>
                  <a href="/forgot-password" className="text-sm text-neuro-purple hover:underline">
                    Forgot password?
                  </a>
                </div>

                {/* Submit Button */}
                <motion.button
                  type="submit"
                  disabled={isLoading}
                  whileHover={{ scale: 1.02 }}
                  whileTap={{ scale: 0.98 }}
                  className="w-full py-4 bg-gradient-to-r from-neuro-purple to-neuro-blue text-white font-semibold 
                           rounded-xl shadow-lg hover:shadow-neuro-glow transition-all duration-300
                           disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
                >
                  {isLoading ? (
                    <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                  ) : (
                    <>
                      Sign In
                      <ArrowRight className="w-5 h-5" />
                    </>
                  )}
                </motion.button>
              </form>

              {/* Divider */}
              <div className="my-6 flex items-center gap-4">
                <div className="flex-1 h-px bg-neuro-dark/10" />
                <span className="text-sm text-neuro-dark/40">or</span>
                <div className="flex-1 h-px bg-neuro-dark/10" />
              </div>

              {/* Contact Admin */}
              <p className="text-center text-sm text-neuro-dark/60">
                Don't have an account?{' '}
                <a href="mailto:admin@neuroverse.pk" className="text-neuro-purple font-medium hover:underline">
                  Contact Admin
                </a>
              </p>
            </motion.div>

            {/* Footer */}
            <p className="text-center text-xs text-neuro-dark/40 mt-6">
              © 2026 NeuroVerse. FAST-NUCES Chiniot. All rights reserved.
            </p>
          </motion.div>
        </div>
      </div>
    </div>
  );
}

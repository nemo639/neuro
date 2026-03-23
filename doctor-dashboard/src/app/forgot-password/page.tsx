'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { motion } from 'framer-motion';
import { Shield, ArrowLeft, Mail, KeyRound, Lock, Eye, EyeOff, CheckCircle, AlertCircle } from 'lucide-react';
import { authApi } from '@/lib/api';

type Step = 'email' | 'otp' | 'reset' | 'done';

export default function ForgotPasswordPage() {
  const router = useRouter();
  const [step, setStep] = useState<Step>('email');
  const [email, setEmail] = useState('');
  const [otp, setOtp] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState('');

  const handleSendOTP = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);
    setError('');
    try {
      await authApi.forgotPassword(email);
      setStep('otp');
    } catch (err: any) {
      setError(err?.response?.data?.detail || 'Failed to send OTP. Please try again.');
    } finally {
      setIsLoading(false);
    }
  };

  const handleVerifyAndReset = async (e: React.FormEvent) => {
    e.preventDefault();
    if (newPassword !== confirmPassword) {
      setError('Passwords do not match');
      return;
    }
    if (newPassword.length < 8) {
      setError('Password must be at least 8 characters');
      return;
    }
    setIsLoading(true);
    setError('');
    try {
      await authApi.resetPassword(email, otp, newPassword);
      setStep('done');
    } catch (err: any) {
      setError(err?.response?.data?.detail || 'Invalid or expired OTP. Please try again.');
    } finally {
      setIsLoading(false);
    }
  };

  const stepConfig = {
    email: { title: 'Forgot Password', subtitle: 'Enter your email and we\'ll send you a verification code' },
    otp: { title: 'Enter Verification Code', subtitle: `We sent a 6-digit code to ${email}` },
    reset: { title: 'Set New Password', subtitle: 'Choose a strong password for your account' },
    done: { title: 'Password Reset!', subtitle: 'Your password has been changed successfully' },
  };

  return (
    <div className="min-h-screen bg-dash-bg flex">
      {/* Left panel */}
      <div className="hidden lg:flex lg:w-[55%] bg-dash-dark relative overflow-hidden flex-col justify-between p-12">
        <div className="absolute -top-32 -left-32 w-96 h-96 rounded-full bg-accent/5" />
        <div className="absolute -bottom-20 -right-20 w-80 h-80 rounded-full bg-accent/8" />
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[500px] h-[500px] rounded-full bg-accent/3" />

        <motion.div initial={{ opacity: 0, y: -20 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.6 }}>
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-accent rounded-xl flex items-center justify-center">
              <Shield className="w-5 h-5 text-dash-dark" />
            </div>
            <span className="text-white text-xl font-bold">NeuroVerse</span>
          </div>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 0.2 }}
          className="relative z-10"
        >
          <h1 className="text-5xl font-extrabold text-white leading-tight mb-4">
            Account<br />
            <span className="text-accent">Recovery</span>
          </h1>
          <p className="text-dash-muted text-lg max-w-md leading-relaxed">
            Don't worry, it happens to the best of us. We'll help you get back into your account in no time.
          </p>
        </motion.div>

        <motion.p
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.8 }}
          className="text-dash-muted/50 text-sm"
        >
          &copy; 2026 NeuroVerse AI Health Platform
        </motion.p>
      </div>

      {/* Right panel */}
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

          <motion.div
            key={step}
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.3 }}
            className="bg-white rounded-2xl border border-dash-border shadow-login-card p-8 lg:p-10"
          >
            {/* Back button */}
            {step !== 'done' && (
              <button
                onClick={() => {
                  if (step === 'email') router.push('/login');
                  else if (step === 'otp') setStep('email');
                  else if (step === 'reset') setStep('otp');
                }}
                className="flex items-center gap-1.5 text-sm text-dash-muted hover:text-dash-dark transition-colors mb-6"
              >
                <ArrowLeft className="w-4 h-4" />
                Back
              </button>
            )}

            {/* Step indicator */}
            {step !== 'done' && (
              <div className="flex gap-2 mb-6">
                {['email', 'otp', 'reset'].map((s, i) => (
                  <div
                    key={s}
                    className={`h-1.5 flex-1 rounded-full transition-colors ${
                      i <= ['email', 'otp', 'reset'].indexOf(step)
                        ? 'bg-accent'
                        : 'bg-dash-border'
                    }`}
                  />
                ))}
              </div>
            )}

            <h2 className="text-2xl font-bold text-dash-dark mb-2">{stepConfig[step].title}</h2>
            <p className="text-dash-muted text-sm mb-8">{stepConfig[step].subtitle}</p>

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

            {/* ── Step 1: Email ── */}
            {step === 'email' && (
              <form onSubmit={handleSendOTP} className="space-y-5">
                <div>
                  <label className="block text-sm font-medium text-dash-dark mb-2">Email Address</label>
                  <div className="relative">
                    <Mail className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-dash-muted" />
                    <input
                      type="email"
                      value={email}
                      onChange={(e) => setEmail(e.target.value)}
                      placeholder="doctor@neuroverse.com"
                      className="input pl-11 hover:border-dash-muted"
                      required
                    />
                  </div>
                </div>
                <motion.button
                  type="submit"
                  disabled={isLoading}
                  whileHover={{ scale: 1.02, boxShadow: '0 4px 14px var(--accent-glow)' }}
                  whileTap={{ scale: 0.98 }}
                  className="w-full btn-primary py-3.5 flex items-center justify-center gap-2 disabled:opacity-60"
                >
                  {isLoading ? (
                    <div className="w-5 h-5 border-2 border-dash-dark/30 border-t-dash-dark rounded-full animate-spin" />
                  ) : (
                    'Send Verification Code'
                  )}
                </motion.button>
              </form>
            )}

            {/* ── Step 2: OTP ── */}
            {step === 'otp' && (
              <div className="space-y-5">
                <div>
                  <label className="block text-sm font-medium text-dash-dark mb-2">Verification Code</label>
                  <div className="relative">
                    <KeyRound className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-dash-muted" />
                    <input
                      type="text"
                      value={otp}
                      onChange={(e) => {
                        const val = e.target.value.replace(/\D/g, '').slice(0, 6);
                        setOtp(val);
                        setError('');
                      }}
                      placeholder="Enter 6-digit code"
                      className="input pl-11 text-center text-lg tracking-[0.5em] font-mono hover:border-dash-muted"
                      maxLength={6}
                    />
                  </div>
                  <p className="text-xs text-dash-muted mt-2">
                    Didn't receive the code?{' '}
                    <button
                      onClick={async () => {
                        setError('');
                        try {
                          await authApi.forgotPassword(email);
                          setError('');
                        } catch {
                          setError('Failed to resend. Try again.');
                        }
                      }}
                      className="text-accent-dark hover:text-dash-dark font-medium transition-colors"
                    >
                      Resend
                    </button>
                  </p>
                </div>
                <motion.button
                  onClick={() => {
                    if (otp.length !== 6) {
                      setError('Please enter the 6-digit code');
                      return;
                    }
                    setError('');
                    setStep('reset');
                  }}
                  whileHover={{ scale: 1.02, boxShadow: '0 4px 14px var(--accent-glow)' }}
                  whileTap={{ scale: 0.98 }}
                  className="w-full btn-primary py-3.5 flex items-center justify-center gap-2"
                >
                  Verify Code
                </motion.button>
              </div>
            )}

            {/* ── Step 3: New Password ── */}
            {step === 'reset' && (
              <form onSubmit={handleVerifyAndReset} className="space-y-5">
                <div>
                  <label className="block text-sm font-medium text-dash-dark mb-2">New Password</label>
                  <div className="relative">
                    <Lock className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-dash-muted" />
                    <input
                      type={showPassword ? 'text' : 'password'}
                      value={newPassword}
                      onChange={(e) => setNewPassword(e.target.value)}
                      placeholder="At least 8 characters"
                      className="input pl-11 pr-11 hover:border-dash-muted"
                      required
                      minLength={8}
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
                <div>
                  <label className="block text-sm font-medium text-dash-dark mb-2">Confirm Password</label>
                  <div className="relative">
                    <Lock className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-dash-muted" />
                    <input
                      type={showPassword ? 'text' : 'password'}
                      value={confirmPassword}
                      onChange={(e) => setConfirmPassword(e.target.value)}
                      placeholder="Re-enter password"
                      className="input pl-11 hover:border-dash-muted"
                      required
                      minLength={8}
                    />
                  </div>
                </div>
                {/* Password strength hints */}
                <div className="space-y-1.5">
                  {[
                    { label: 'At least 8 characters', met: newPassword.length >= 8 },
                    { label: 'Contains a number', met: /\d/.test(newPassword) },
                    { label: 'Passwords match', met: newPassword.length > 0 && newPassword === confirmPassword },
                  ].map((hint) => (
                    <div key={hint.label} className="flex items-center gap-2">
                      <div className={`w-3.5 h-3.5 rounded-full flex items-center justify-center ${hint.met ? 'bg-accent' : 'bg-dash-border'}`}>
                        {hint.met && <CheckCircle className="w-3 h-3 text-dash-dark" />}
                      </div>
                      <span className={`text-xs ${hint.met ? 'text-dash-dark' : 'text-dash-muted'}`}>{hint.label}</span>
                    </div>
                  ))}
                </div>
                <motion.button
                  type="submit"
                  disabled={isLoading}
                  whileHover={{ scale: 1.02, boxShadow: '0 4px 14px var(--accent-glow)' }}
                  whileTap={{ scale: 0.98 }}
                  className="w-full btn-primary py-3.5 flex items-center justify-center gap-2 disabled:opacity-60"
                >
                  {isLoading ? (
                    <div className="w-5 h-5 border-2 border-dash-dark/30 border-t-dash-dark rounded-full animate-spin" />
                  ) : (
                    'Reset Password'
                  )}
                </motion.button>
              </form>
            )}

            {/* ── Step 4: Success ── */}
            {step === 'done' && (
              <div className="text-center">
                <div className="w-16 h-16 bg-accent/20 rounded-full flex items-center justify-center mx-auto mb-6">
                  <CheckCircle className="w-8 h-8 text-accent-dark" />
                </div>
                <p className="text-dash-muted text-sm mb-8">
                  You can now sign in with your new password.
                </p>
                <motion.button
                  onClick={() => router.push('/login')}
                  whileHover={{ scale: 1.02, boxShadow: '0 4px 14px var(--accent-glow)' }}
                  whileTap={{ scale: 0.98 }}
                  className="w-full btn-primary py-3.5"
                >
                  Back to Sign In
                </motion.button>
              </div>
            )}
          </motion.div>

          <p className="text-center text-dash-muted text-xs mt-6">
            Secured with 256-bit encryption
          </p>
        </motion.div>
      </div>
    </div>
  );
}

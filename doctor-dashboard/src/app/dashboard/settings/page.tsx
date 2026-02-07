'use client';

import { useState, useEffect, useRef } from 'react';
import { motion } from 'framer-motion';
import {
  User, Mail, Phone, Building, Briefcase, Shield,
  Bell, Save, Camera, Lock, Eye, EyeOff, Check,
  ChevronRight, Palette, Stethoscope, Upload, Trash2,
  ToggleLeft, ToggleRight, Sun, Moon, Monitor,
  Loader2, AlertCircle, Clock, FileText, Activity,
} from 'lucide-react';
import { useAuth } from '@/contexts/AuthContext';

const API_BASE = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000';

const container = { hidden: { opacity: 0 }, visible: { opacity: 1, transition: { staggerChildren: 0.06 } } };
const item = { hidden: { opacity: 0, y: 12 }, visible: { opacity: 1, y: 0, transition: { duration: 0.4 } } };

type Tab = 'profile' | 'security' | 'notifications' | 'appearance' | 'clinical';

const DEFAULT_NOTIFICATIONS = {
  email_alerts: true,
  email_critical: true,
  email_weekly_report: false,
  email_new_results: true,
  push_critical: true,
  push_appointments: true,
  push_messages: true,
};

const DEFAULT_CLINICAL = {
  default_assessment: 'cognitive',
  consultation_duration: '30',
  auto_reminders: true,
  show_risk_scores: true,
  require_notes: false,
  auto_save_notes: true,
  data_export_format: 'pdf',
  session_timeout: '30',
};

type AccentColor = '#C6E94B' | '#6366F1' | '#A855F7' | '#EC4899' | '#22D3EE' | '#FB923C';
type ThemeOption = 'light' | 'dark' | 'system';

function loadFromStorage<T>(key: string, fallback: T): T {
  if (typeof window === 'undefined') return fallback;
  try {
    const stored = localStorage.getItem(key);
    return stored ? JSON.parse(stored) : fallback;
  } catch {
    return fallback;
  }
}

export default function SettingsPage() {
  const { doctor } = useAuth();

  const [activeTab, setActiveTab] = useState<Tab>('profile');
  const [saving, setSaving] = useState(false);
  const [saveSuccess, setSaveSuccess] = useState(false);

  /* ── Profile ── */
  const [profileForm, setProfileForm] = useState({
    first_name: doctor?.first_name || 'Sarah',
    last_name: doctor?.last_name || 'Ahmed',
    email: doctor?.email || 'dr.sarah@hospital.com',
    phone: '+92 300 1234567',
    specialization: doctor?.specialization || 'neurologist',
    hospital_affiliation: doctor?.hospital_affiliation || 'NeuroVerse Clinic',
    bio: 'Experienced neurologist specializing in neurodegenerative diseases.',
  });

  /* ── Avatar ── */
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [avatarUploading, setAvatarUploading] = useState(false);
  const [avatarPreview, setAvatarPreview] = useState<string | null>(null);

  const handleAvatarSelect = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    const validTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];
    if (!validTypes.includes(file.type)) return;
    if (file.size > 10 * 1024 * 1024) return;
    const reader = new FileReader();
    reader.onload = (ev) => setAvatarPreview(ev.target?.result as string);
    reader.readAsDataURL(file);
    setAvatarUploading(true);
    await new Promise((r) => setTimeout(r, 800));
    setAvatarUploading(false);
    if (fileInputRef.current) fileInputRef.current.value = '';
  };

  const handleRemoveAvatar = () => setAvatarPreview(null);

  /* ── Password ── */
  const [showPassword, setShowPassword] = useState(false);
  const [showNewPassword, setShowNewPassword] = useState(false);
  const [passwordForm, setPasswordForm] = useState({ current_password: '', new_password: '', confirm_password: '' });
  const [passwordError, setPasswordError] = useState<string | null>(null);
  const [passwordSuccess, setPasswordSuccess] = useState(false);
  const [passwordLoading, setPasswordLoading] = useState(false);

  const handleChangePassword = async () => {
    setPasswordError(null);
    setPasswordSuccess(false);
    if (passwordForm.new_password !== passwordForm.confirm_password) {
      setPasswordError('New passwords do not match');
      return;
    }
    if (passwordForm.new_password.length < 6) {
      setPasswordError('New password must be at least 6 characters');
      return;
    }
    try {
      setPasswordLoading(true);
      await new Promise((r) => setTimeout(r, 1200));
      setPasswordSuccess(true);
      setPasswordForm({ current_password: '', new_password: '', confirm_password: '' });
      setTimeout(() => setPasswordSuccess(false), 3000);
    } catch {
      setPasswordError('Failed to change password');
    } finally {
      setPasswordLoading(false);
    }
  };

  /* ── Notifications ── */
  const [notifications, setNotifications] = useState(DEFAULT_NOTIFICATIONS);

  /* ── Appearance ── */
  const [theme, setTheme] = useState<ThemeOption>('light');
  const [accentColor, setAccentColor] = useState<AccentColor>('#C6E94B');
  const [fontSize, setFontSize] = useState<'small' | 'medium' | 'large'>('medium');
  const [sidebarWidth, setSidebarWidth] = useState<'compact' | 'standard' | 'wide'>('standard');
  const [compactMode, setCompactMode] = useState(false);

  /* ── Clinical ── */
  const [clinical, setClinical] = useState(DEFAULT_CLINICAL);

  /* ── Load localStorage ── */
  useEffect(() => {
    setNotifications(loadFromStorage('nv_doc_notifications', DEFAULT_NOTIFICATIONS));
    setClinical(loadFromStorage('nv_doc_clinical', DEFAULT_CLINICAL));
    setTheme(loadFromStorage('nv_doc_theme', 'light'));
    setAccentColor(loadFromStorage('nv_doc_accent', '#C6E94B'));
    setFontSize(loadFromStorage('nv_doc_fontSize', 'medium'));
    setSidebarWidth(loadFromStorage('nv_doc_sidebarWidth', 'standard'));
    setCompactMode(loadFromStorage('nv_doc_compactMode', false));
  }, []);

  /* ── Save ── */
  const handleSave = async () => {
    setSaving(true);
    if (activeTab === 'profile') {
      await new Promise((r) => setTimeout(r, 1200));
    } else if (activeTab === 'notifications') {
      localStorage.setItem('nv_doc_notifications', JSON.stringify(notifications));
    } else if (activeTab === 'clinical') {
      localStorage.setItem('nv_doc_clinical', JSON.stringify(clinical));
    } else if (activeTab === 'appearance') {
      localStorage.setItem('nv_doc_theme', JSON.stringify(theme));
      localStorage.setItem('nv_doc_accent', JSON.stringify(accentColor));
      localStorage.setItem('nv_doc_fontSize', JSON.stringify(fontSize));
      localStorage.setItem('nv_doc_sidebarWidth', JSON.stringify(sidebarWidth));
      localStorage.setItem('nv_doc_compactMode', JSON.stringify(compactMode));
    }
    setSaving(false);
    setSaveSuccess(true);
    setTimeout(() => setSaveSuccess(false), 2000);
  };

  /* ── Tabs ── */
  const tabs: { id: Tab; label: string; icon: typeof User }[] = [
    { id: 'profile', label: 'Profile', icon: User },
    { id: 'security', label: 'Security', icon: Lock },
    { id: 'notifications', label: 'Notifications', icon: Bell },
    { id: 'appearance', label: 'Appearance', icon: Palette },
    { id: 'clinical', label: 'Clinical', icon: Stethoscope },
  ];

  /* ── Toggle component ── */
  const Toggle = ({ checked, onChange }: { checked: boolean; onChange: () => void }) => (
    <button onClick={onChange} className="relative">
      {checked ? (
        <ToggleRight className="w-10 h-10 text-accent" />
      ) : (
        <ToggleLeft className="w-10 h-10 text-dash-border" />
      )}
    </button>
  );

  const initials = `${profileForm.first_name?.[0] || ''}${profileForm.last_name?.[0] || ''}`.toUpperCase() || 'D';

  return (
    <motion.div variants={container} initial="hidden" animate="visible" className="space-y-6">
      {/* Header */}
      <motion.div variants={item} className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-dash-dark">Settings</h1>
          <p className="text-sm text-dash-muted mt-1">Manage your account and preferences</p>
        </div>
        <button onClick={handleSave} disabled={saving} className="btn-primary flex items-center gap-2">
          {saving ? <Loader2 className="w-4 h-4 animate-spin" /> : saveSuccess ? <Check className="w-4 h-4" /> : <Save className="w-4 h-4" />}
          {saving ? 'Saving...' : saveSuccess ? 'Saved!' : 'Save Changes'}
        </button>
      </motion.div>

      <motion.div variants={item} className="grid grid-cols-1 xl:grid-cols-4 gap-6">
        {/* ═══ Sidebar Tabs ═══ */}
        <div className="xl:col-span-1">
          <div className="card overflow-hidden">
            {tabs.map((t) => {
              const isActive = activeTab === t.id;
              return (
                <button
                  key={t.id}
                  onClick={() => setActiveTab(t.id)}
                  className={`w-full flex items-center gap-3 px-4 py-3.5 text-sm font-medium transition-all border-b border-dash-border/50 last:border-0 ${
                    isActive ? 'bg-accent text-dash-dark' : 'text-dash-text hover:bg-dash-bg'
                  }`}
                >
                  <t.icon className="w-4 h-4 flex-shrink-0" />
                  <span className="flex-1 text-left">{t.label}</span>
                  <ChevronRight className={`w-3.5 h-3.5 ${isActive ? 'text-dash-dark/50' : 'text-dash-muted/40'}`} />
                </button>
              );
            })}
          </div>
        </div>

        {/* ═══ Content ═══ */}
        <div className="xl:col-span-3 space-y-6 min-w-0">

          {/* ── Profile Tab ── */}
          {activeTab === 'profile' && (
            <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} className="space-y-6">
              {/* Avatar Section */}
              <div className="card p-6">
                <h3 className="font-semibold text-dash-dark mb-6">Profile Photo</h3>
                <div className="flex items-center gap-6">
                  <div className="relative">
                    {avatarPreview ? (
                      <img src={avatarPreview} alt="Avatar" className="w-24 h-24 rounded-2xl object-cover" />
                    ) : (
                      <div className="w-24 h-24 rounded-2xl bg-accent flex items-center justify-center text-dash-dark text-3xl font-bold">
                        {initials}
                      </div>
                    )}
                    <button
                      onClick={() => fileInputRef.current?.click()}
                      disabled={avatarUploading}
                      className="absolute -bottom-2 -right-2 w-8 h-8 rounded-xl bg-dash-dark text-white flex items-center justify-center hover:bg-gray-800 transition-colors"
                    >
                      {avatarUploading ? <Loader2 className="w-4 h-4 animate-spin" /> : <Camera className="w-4 h-4" />}
                    </button>
                  </div>
                  <div className="flex-1">
                    <h4 className="font-medium text-dash-dark">Dr. {profileForm.first_name} {profileForm.last_name}</h4>
                    <p className="text-xs text-dash-muted capitalize mt-0.5">{profileForm.specialization}</p>
                    <div className="flex items-center gap-3 mt-3">
                      <button
                        onClick={() => fileInputRef.current?.click()}
                        disabled={avatarUploading}
                        className="text-xs font-medium text-accent-dark hover:underline flex items-center gap-1"
                      >
                        <Upload className="w-3 h-3" /> Upload Photo
                      </button>
                      {avatarPreview && (
                        <button onClick={handleRemoveAvatar} className="text-xs font-medium text-red-500 hover:underline flex items-center gap-1">
                          <Trash2 className="w-3 h-3" /> Remove
                        </button>
                      )}
                    </div>
                  </div>
                  <input ref={fileInputRef} type="file" accept="image/*" className="hidden" onChange={handleAvatarSelect} />
                </div>
              </div>

              {/* Profile Form */}
              <div className="card p-6">
                <h3 className="font-semibold text-dash-dark mb-6">Personal Information</h3>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
                  <div>
                    <label className="block text-sm font-medium text-dash-dark mb-2">First Name</label>
                    <input className="input" value={profileForm.first_name}
                      onChange={(e) => setProfileForm({ ...profileForm, first_name: e.target.value })} />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-dash-dark mb-2">Last Name</label>
                    <input className="input" value={profileForm.last_name}
                      onChange={(e) => setProfileForm({ ...profileForm, last_name: e.target.value })} />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-dash-dark mb-2">Email</label>
                    <input className="input bg-dash-bg text-dash-muted cursor-not-allowed" disabled value={profileForm.email} />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-dash-dark mb-2">Phone</label>
                    <input className="input" value={profileForm.phone}
                      onChange={(e) => setProfileForm({ ...profileForm, phone: e.target.value })} />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-dash-dark mb-2">Specialization</label>
                    <select className="input" value={profileForm.specialization}
                      onChange={(e) => setProfileForm({ ...profileForm, specialization: e.target.value })}>
                      <option value="neurologist">Neurologist</option>
                      <option value="psychiatrist">Psychiatrist</option>
                      <option value="radiologist">Radiologist</option>
                      <option value="general_practitioner">General Practitioner</option>
                      <option value="researcher">Researcher</option>
                    </select>
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-dash-dark mb-2">Hospital</label>
                    <input className="input" value={profileForm.hospital_affiliation}
                      onChange={(e) => setProfileForm({ ...profileForm, hospital_affiliation: e.target.value })} />
                  </div>
                  <div className="md:col-span-2">
                    <label className="block text-sm font-medium text-dash-dark mb-2">Bio</label>
                    <textarea className="input min-h-[100px] resize-none" value={profileForm.bio}
                      onChange={(e) => setProfileForm({ ...profileForm, bio: e.target.value })} />
                  </div>
                </div>
              </div>

              {/* Stats Row */}
              <div className="grid grid-cols-3 gap-4">
                {[
                  { label: 'Total Patients', value: '142', icon: User },
                  { label: 'Assessments', value: '384', icon: FileText },
                  { label: 'Reports Generated', value: '67', icon: Activity },
                ].map((s) => (
                  <div key={s.label} className="card p-4 text-center">
                    <s.icon className="w-5 h-5 text-accent mx-auto mb-2" />
                    <p className="text-xl font-bold text-dash-dark">{s.value}</p>
                    <p className="text-2xs text-dash-muted mt-0.5">{s.label}</p>
                  </div>
                ))}
              </div>
            </motion.div>
          )}

          {/* ── Security Tab ── */}
          {activeTab === 'security' && (
            <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} className="space-y-6">
              {/* Change Password */}
              <div className="card p-6">
                <h3 className="font-semibold text-dash-dark mb-6">Change Password</h3>

                {passwordError && (
                  <div className="flex items-center gap-2 p-3 rounded-xl bg-red-50 text-red-700 text-sm mb-4">
                    <AlertCircle className="w-4 h-4 flex-shrink-0" />
                    {passwordError}
                  </div>
                )}
                {passwordSuccess && (
                  <div className="flex items-center gap-2 p-3 rounded-xl bg-green-50 text-green-700 text-sm mb-4">
                    <Check className="w-4 h-4 flex-shrink-0" />
                    Password updated successfully!
                  </div>
                )}

                <div className="space-y-4 max-w-md">
                  <div>
                    <label className="block text-sm font-medium text-dash-dark mb-2">Current Password</label>
                    <div className="relative">
                      <input type={showPassword ? 'text' : 'password'} className="input pr-10"
                        value={passwordForm.current_password}
                        onChange={(e) => setPasswordForm({ ...passwordForm, current_password: e.target.value })} />
                      <button onClick={() => setShowPassword(!showPassword)} className="absolute right-3 top-1/2 -translate-y-1/2">
                        {showPassword ? <EyeOff className="w-4 h-4 text-dash-muted" /> : <Eye className="w-4 h-4 text-dash-muted" />}
                      </button>
                    </div>
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-dash-dark mb-2">New Password</label>
                    <div className="relative">
                      <input type={showNewPassword ? 'text' : 'password'} className="input pr-10"
                        value={passwordForm.new_password}
                        onChange={(e) => setPasswordForm({ ...passwordForm, new_password: e.target.value })} />
                      <button onClick={() => setShowNewPassword(!showNewPassword)} className="absolute right-3 top-1/2 -translate-y-1/2">
                        {showNewPassword ? <EyeOff className="w-4 h-4 text-dash-muted" /> : <Eye className="w-4 h-4 text-dash-muted" />}
                      </button>
                    </div>
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-dash-dark mb-2">Confirm New Password</label>
                    <input type="password" className="input"
                      value={passwordForm.confirm_password}
                      onChange={(e) => setPasswordForm({ ...passwordForm, confirm_password: e.target.value })} />
                  </div>
                  <button onClick={handleChangePassword} disabled={passwordLoading}
                    className="btn-primary flex items-center gap-2">
                    {passwordLoading ? <Loader2 className="w-4 h-4 animate-spin" /> : <Lock className="w-4 h-4" />}
                    {passwordLoading ? 'Updating...' : 'Update Password'}
                  </button>
                </div>
              </div>

              {/* Two-Factor Auth */}
              <div className="card p-6">
                <h3 className="font-semibold text-dash-dark mb-4">Two-Factor Authentication</h3>
                <div className="space-y-1">
                  {[
                    { label: 'Authenticator App', desc: 'Use an authenticator app to generate codes', status: 'Not configured' },
                    { label: 'SMS Verification', desc: 'Receive verification codes via SMS', status: 'Active' },
                    { label: 'Recovery Codes', desc: 'Backup codes for account recovery', status: '8 remaining' },
                  ].map((method) => (
                    <div key={method.label} className="flex items-center justify-between py-4 border-b border-dash-border last:border-0">
                      <div>
                        <p className="text-sm font-medium text-dash-dark">{method.label}</p>
                        <p className="text-xs text-dash-muted mt-0.5">{method.desc}</p>
                      </div>
                      <span className={`text-xs px-3 py-1 rounded-full ${
                        method.status === 'Active' ? 'bg-green-50 text-green-700' : 'bg-dash-bg text-dash-muted'
                      }`}>
                        {method.status}
                      </span>
                    </div>
                  ))}
                </div>
              </div>

              {/* Active Sessions */}
              <div className="card p-6">
                <h3 className="font-semibold text-dash-dark mb-4">Active Sessions</h3>
                <div className="space-y-3">
                  {[
                    { device: 'Windows PC — Chrome', location: 'Lahore, PK', current: true, time: 'Now' },
                    { device: 'iPhone 15 — Safari', location: 'Lahore, PK', current: false, time: '2 hours ago' },
                  ].map((session, i) => (
                    <div key={i} className="flex items-center justify-between py-3 border-b border-dash-border last:border-0">
                      <div className="flex items-center gap-3">
                        <div className={`w-2 h-2 rounded-full ${session.current ? 'bg-green-500' : 'bg-dash-muted'}`} />
                        <div>
                          <p className="text-sm font-medium text-dash-dark">{session.device}</p>
                          <p className="text-xs text-dash-muted">{session.location} · {session.time}</p>
                        </div>
                      </div>
                      {session.current ? (
                        <span className="text-xs px-3 py-1 rounded-full bg-green-50 text-green-700">Current</span>
                      ) : (
                        <button className="text-xs text-red-500 hover:underline">Revoke</button>
                      )}
                    </div>
                  ))}
                </div>
              </div>
            </motion.div>
          )}

          {/* ── Notifications Tab ── */}
          {activeTab === 'notifications' && (
            <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} className="space-y-6">
              <div className="card p-6">
                <h3 className="font-semibold text-dash-dark mb-2">Email Notifications</h3>
                <p className="text-xs text-dash-muted mb-4">Choose which email notifications you receive</p>
                <div className="space-y-1">
                  {[
                    { key: 'email_alerts', label: 'Patient Alerts', desc: 'Get notified about patient updates' },
                    { key: 'email_critical', label: 'Critical Alerts', desc: 'High-risk patient notifications' },
                    { key: 'email_weekly_report', label: 'Weekly Report', desc: 'Summary of weekly activity' },
                    { key: 'email_new_results', label: 'New Test Results', desc: 'When patients complete assessments' },
                  ].map((n) => (
                    <div key={n.key} className="flex items-center justify-between py-4 border-b border-dash-border last:border-0">
                      <div>
                        <p className="text-sm font-medium text-dash-dark">{n.label}</p>
                        <p className="text-xs text-dash-muted mt-0.5">{n.desc}</p>
                      </div>
                      <Toggle
                        checked={notifications[n.key as keyof typeof notifications]}
                        onChange={() => setNotifications({ ...notifications, [n.key]: !notifications[n.key as keyof typeof notifications] })}
                      />
                    </div>
                  ))}
                </div>
              </div>

              <div className="card p-6">
                <h3 className="font-semibold text-dash-dark mb-2">Push Notifications</h3>
                <p className="text-xs text-dash-muted mb-4">Real-time notifications on your device</p>
                <div className="space-y-1">
                  {[
                    { key: 'push_critical', label: 'Critical Updates', desc: 'Urgent patient-related alerts' },
                    { key: 'push_appointments', label: 'Appointments', desc: 'Upcoming appointment reminders' },
                    { key: 'push_messages', label: 'Messages', desc: 'New messages from patients or staff' },
                  ].map((n) => (
                    <div key={n.key} className="flex items-center justify-between py-4 border-b border-dash-border last:border-0">
                      <div>
                        <p className="text-sm font-medium text-dash-dark">{n.label}</p>
                        <p className="text-xs text-dash-muted mt-0.5">{n.desc}</p>
                      </div>
                      <Toggle
                        checked={notifications[n.key as keyof typeof notifications]}
                        onChange={() => setNotifications({ ...notifications, [n.key]: !notifications[n.key as keyof typeof notifications] })}
                      />
                    </div>
                  ))}
                </div>
              </div>
            </motion.div>
          )}

          {/* ── Appearance Tab ── */}
          {activeTab === 'appearance' && (
            <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} className="space-y-6">
              <div className="card p-6">
                <h3 className="font-semibold text-dash-dark mb-2">Theme</h3>
                <p className="text-xs text-dash-muted mb-4">Select your preferred color scheme</p>
                <div className="grid grid-cols-3 gap-4">
                  {[
                    { name: 'Light', value: 'light' as ThemeOption, icon: Sun, bg: 'bg-white', desc: 'Clean & bright' },
                    { name: 'Dark', value: 'dark' as ThemeOption, icon: Moon, bg: 'bg-gray-900', desc: 'Easy on the eyes' },
                    { name: 'System', value: 'system' as ThemeOption, icon: Monitor, bg: 'bg-gradient-to-br from-white to-gray-900', desc: 'Match OS setting' },
                  ].map((t) => {
                    const isActive = theme === t.value;
                    return (
                      <button
                        key={t.value}
                        onClick={() => setTheme(t.value)}
                        className={`p-4 rounded-xl border-2 transition-all text-left ${isActive ? 'border-accent shadow-sm' : 'border-dash-border hover:border-dash-muted'}`}
                      >
                        <div className={`h-20 rounded-lg mb-3 ${t.bg} border border-dash-border flex items-center justify-center`}>
                          <t.icon className={`w-6 h-6 ${t.value === 'dark' ? 'text-white' : 'text-dash-muted'}`} />
                        </div>
                        <p className="text-sm font-medium text-dash-dark">{t.name}</p>
                        <p className="text-2xs text-dash-muted mt-0.5">{t.desc}</p>
                        {isActive && (
                          <div className="flex items-center gap-1 mt-1.5">
                            <Check className="w-3 h-3 text-accent-dark" />
                            <span className="text-2xs text-accent-dark font-medium">Active</span>
                          </div>
                        )}
                      </button>
                    );
                  })}
                </div>
              </div>

              <div className="card p-6">
                <h3 className="font-semibold text-dash-dark mb-2">Accent Color</h3>
                <p className="text-xs text-dash-muted mb-4">Choose the primary accent color across the dashboard</p>
                <div className="flex items-center gap-3">
                  {(['#C6E94B', '#6366F1', '#A855F7', '#EC4899', '#22D3EE', '#FB923C'] as AccentColor[]).map((color) => {
                    const isActive = accentColor === color;
                    return (
                      <button
                        key={color}
                        onClick={() => setAccentColor(color)}
                        className={`w-10 h-10 rounded-xl transition-all hover:scale-110 flex items-center justify-center ${isActive ? 'ring-2 ring-offset-2 ring-current scale-110' : ''}`}
                        style={{ backgroundColor: color, color: color }}
                      >
                        {isActive && <Check className="w-4 h-4 text-white drop-shadow" />}
                      </button>
                    );
                  })}
                </div>
                <p className="text-2xs text-dash-muted mt-3">Selected: {accentColor}</p>
              </div>

              <div className="card p-6">
                <h3 className="font-semibold text-dash-dark mb-6">Display</h3>
                <div className="space-y-5">
                  <div>
                    <label className="block text-sm font-medium text-dash-dark mb-2">Sidebar Width</label>
                    <select value={sidebarWidth} onChange={(e) => setSidebarWidth(e.target.value as typeof sidebarWidth)} className="input">
                      <option value="compact">Compact (200px)</option>
                      <option value="standard">Standard (240px)</option>
                      <option value="wide">Wide (280px)</option>
                    </select>
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-dash-dark mb-2">Font Size</label>
                    <select value={fontSize} onChange={(e) => setFontSize(e.target.value as typeof fontSize)} className="input">
                      <option value="small">Small</option>
                      <option value="medium">Medium</option>
                      <option value="large">Large</option>
                    </select>
                  </div>
                  <div className="flex items-center justify-between">
                    <div>
                      <p className="text-sm font-medium text-dash-dark">Compact Mode</p>
                      <p className="text-xs text-dash-muted mt-0.5">Reduce spacing and padding</p>
                    </div>
                    <Toggle checked={compactMode} onChange={() => setCompactMode(!compactMode)} />
                  </div>
                </div>
              </div>
            </motion.div>
          )}

          {/* ── Clinical Tab ── */}
          {activeTab === 'clinical' && (
            <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} className="space-y-6">
              <div className="card p-6">
                <h3 className="font-semibold text-dash-dark mb-6">Clinical Preferences</h3>
                <div className="space-y-1">
                  {[
                    { key: 'auto_reminders', label: 'Auto Reminders', desc: 'Send automatic appointment reminders to patients' },
                    { key: 'show_risk_scores', label: 'Show Risk Scores', desc: 'Display risk assessment scores on patient cards' },
                    { key: 'require_notes', label: 'Require Session Notes', desc: 'Require notes before closing a session' },
                    { key: 'auto_save_notes', label: 'Auto-Save Notes', desc: 'Automatically save clinical notes as you type' },
                  ].map((setting) => (
                    <div key={setting.key} className="flex items-center justify-between py-4 border-b border-dash-border last:border-0">
                      <div>
                        <p className="text-sm font-medium text-dash-dark">{setting.label}</p>
                        <p className="text-xs text-dash-muted mt-0.5">{setting.desc}</p>
                      </div>
                      <Toggle
                        checked={clinical[setting.key as keyof typeof clinical] as boolean}
                        onChange={() => setClinical({ ...clinical, [setting.key]: !clinical[setting.key as keyof typeof clinical] })}
                      />
                    </div>
                  ))}
                </div>
              </div>

              <div className="card p-6">
                <h3 className="font-semibold text-dash-dark mb-6">Assessment & Session</h3>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
                  <div>
                    <label className="block text-sm font-medium text-dash-dark mb-2">Default Assessment Type</label>
                    <select value={clinical.default_assessment}
                      onChange={(e) => setClinical({ ...clinical, default_assessment: e.target.value })}
                      className="input">
                      <option value="cognitive">Cognitive Assessment</option>
                      <option value="memory">Memory Assessment</option>
                      <option value="motor">Motor Function</option>
                      <option value="behavioral">Behavioral Assessment</option>
                      <option value="comprehensive">Comprehensive</option>
                    </select>
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-dash-dark mb-2">Consultation Duration (min)</label>
                    <input type="number" value={clinical.consultation_duration}
                      onChange={(e) => setClinical({ ...clinical, consultation_duration: e.target.value })}
                      className="input" />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-dash-dark mb-2">Data Export Format</label>
                    <select value={clinical.data_export_format}
                      onChange={(e) => setClinical({ ...clinical, data_export_format: e.target.value })}
                      className="input">
                      <option value="pdf">PDF</option>
                      <option value="csv">CSV</option>
                      <option value="json">JSON</option>
                    </select>
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-dash-dark mb-2">Session Timeout (min)</label>
                    <input type="number" value={clinical.session_timeout}
                      onChange={(e) => setClinical({ ...clinical, session_timeout: e.target.value })}
                      className="input" />
                  </div>
                </div>
              </div>

              <div className="card p-6 border-red-100">
                <h3 className="font-semibold text-red-600 mb-4">Danger Zone</h3>
                <div className="space-y-4">
                  <div className="flex items-center justify-between py-3 border-b border-dash-border">
                    <div>
                      <p className="text-sm font-medium text-dash-dark">Clear Patient Cache</p>
                      <p className="text-xs text-dash-muted mt-0.5">Clear locally cached patient data</p>
                    </div>
                    <button className="px-4 py-2 text-xs font-medium rounded-xl border border-red-200 text-red-600 hover:bg-red-50 transition-all">
                      Clear Cache
                    </button>
                  </div>
                  <div className="flex items-center justify-between py-3 border-b border-dash-border">
                    <div>
                      <p className="text-sm font-medium text-dash-dark">Reset Preferences</p>
                      <p className="text-xs text-dash-muted mt-0.5">Reset all clinical preferences to default</p>
                    </div>
                    <button className="px-4 py-2 text-xs font-medium rounded-xl border border-red-200 text-red-600 hover:bg-red-50 transition-all">
                      Reset
                    </button>
                  </div>
                  <div className="flex items-center justify-between py-3">
                    <div>
                      <p className="text-sm font-medium text-dash-dark">Export All Data</p>
                      <p className="text-xs text-dash-muted mt-0.5">Download all your clinical data</p>
                    </div>
                    <button className="btn-secondary text-xs py-2">
                      Export
                    </button>
                  </div>
                </div>
              </div>
            </motion.div>
          )}
        </div>
      </motion.div>
    </motion.div>
  );
}

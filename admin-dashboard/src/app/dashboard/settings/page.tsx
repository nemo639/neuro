'use client';

import { useState, useEffect, useCallback, useRef } from 'react';
import { motion } from 'framer-motion';
import { useAuth } from '@/contexts/AuthContext';
import { useTheme, type AccentColor, type Theme, type FontSize, type SidebarWidth } from '@/contexts/ThemeContext';
import { settingsApi } from '@/lib/api';
import Image from 'next/image';
import {
  Settings,
  User,
  Shield,
  Bell,
  Palette,
  Globe,
  Database,
  Lock,
  Mail,
  Save,
  Camera,
  Eye,
  EyeOff,
  ChevronRight,
  ToggleLeft,
  ToggleRight,
  Check,
  Loader2,
  AlertCircle,
  Trash2,
  Upload,
  Sun,
  Moon,
  Monitor,
} from 'lucide-react';

const API_BASE = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000';

const container = { hidden: { opacity: 0 }, visible: { opacity: 1, transition: { staggerChildren: 0.06 } } };
const item = { hidden: { opacity: 0, y: 12 }, visible: { opacity: 1, y: 0, transition: { duration: 0.4 } } };

type Tab = 'profile' | 'security' | 'notifications' | 'appearance' | 'system';

interface AdminSettingsProfile {
  id: string;
  email: string;
  first_name: string;
  last_name: string;
  phone: string | null;
  role: string;
  profile_image_url: string | null;
  is_active: boolean;
  total_actions: number;
  tickets_resolved: number;
  users_managed: number;
  created_at: string;
  last_login_at: string | null;
}

const DEFAULT_NOTIFICATIONS = {
  email_new_user: true,
  email_tickets: true,
  email_doctor_verify: true,
  email_weekly_report: false,
  push_critical: true,
  push_tickets: true,
  push_mentions: true,
};

const DEFAULT_SYSTEM = {
  maintenance_mode: false,
  allow_registration: true,
  require_email_verify: true,
  auto_approve_doctors: false,
  max_upload_size: '10',
  session_timeout: '30',
  backup_frequency: 'daily',
};

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
  const { admin, updateAdminProfile } = useAuth();
  const { appearance, setTheme, setAccentColor, setFontSize, setSidebarWidth, setCompactMode, resolvedTheme } = useTheme();
  const [activeTab, setActiveTab] = useState<Tab>('profile');
  const [showPassword, setShowPassword] = useState(false);
  const [saveSuccess, setSaveSuccess] = useState(false);
  const [saving, setSaving] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Avatar
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [avatarUploading, setAvatarUploading] = useState(false);
  const [avatarPreview, setAvatarPreview] = useState<string | null>(null);

  // Profile state (from API)
  const [profileData, setProfileData] = useState<AdminSettingsProfile | null>(null);
  const [profileForm, setProfileForm] = useState({
    first_name: '',
    last_name: '',
    phone: '',
  });

  // Password state
  const [passwordForm, setPasswordForm] = useState({
    current_password: '',
    new_password: '',
    confirm_password: '',
  });
  const [passwordError, setPasswordError] = useState<string | null>(null);
  const [passwordSuccess, setPasswordSuccess] = useState(false);
  const [passwordLoading, setPasswordLoading] = useState(false);

  // Notifications state (localStorage)
  const [notifications, setNotifications] = useState(DEFAULT_NOTIFICATIONS);

  // System state (localStorage)
  const [system, setSystem] = useState(DEFAULT_SYSTEM);

  // Load profile from API
  const fetchProfile = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const data = await settingsApi.getProfile();
      setProfileData(data);
      setProfileForm({
        first_name: data.first_name || '',
        last_name: data.last_name || '',
        phone: data.phone || '',
      });
    } catch (err: any) {
      console.error('Settings profile fetch error:', err);
      setError(err?.response?.data?.detail || 'Failed to load profile');
    } finally {
      setLoading(false);
    }
  }, []);

  // Load localStorage preferences on mount
  useEffect(() => {
    fetchProfile();
    setNotifications(loadFromStorage('nv_notifications', DEFAULT_NOTIFICATIONS));
    setSystem(loadFromStorage('nv_system', DEFAULT_SYSTEM));
  }, [fetchProfile]);

  // Set initial avatar preview from profile data
  useEffect(() => {
    if (profileData?.profile_image_url) {
      setAvatarPreview(`${API_BASE}${profileData.profile_image_url}`);
    }
  }, [profileData?.profile_image_url]);

  // Handle avatar file selection
  const handleAvatarSelect = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    // Validate
    const validTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];
    if (!validTypes.includes(file.type)) {
      setError('Invalid file type. Please use JPG, PNG, or WebP');
      return;
    }
    if (file.size > 10 * 1024 * 1024) {
      setError('File too large. Maximum size is 10MB');
      return;
    }

    // Preview immediately
    const reader = new FileReader();
    reader.onload = (ev) => setAvatarPreview(ev.target?.result as string);
    reader.readAsDataURL(file);

    // Upload
    try {
      setAvatarUploading(true);
      setError(null);
      const result = await settingsApi.uploadAvatar(file);
      const fullUrl = `${API_BASE}${result.profile_image_url}`;
      setAvatarPreview(fullUrl);
      // Update AuthContext so sidebar/header update instantly
      updateAdminProfile({ profile_image_url: result.profile_image_url });
      // Refresh profile to get updated data
      await fetchProfile();
    } catch (err: any) {
      console.error('Avatar upload error:', err);
      setError(err?.response?.data?.detail || 'Failed to upload avatar');
      // Revert preview
      setAvatarPreview(profileData?.profile_image_url ? `${API_BASE}${profileData.profile_image_url}` : null);
    } finally {
      setAvatarUploading(false);
      // Reset file input
      if (fileInputRef.current) fileInputRef.current.value = '';
    }
  };

  // Remove avatar
  const handleRemoveAvatar = async () => {
    try {
      setAvatarUploading(true);
      await settingsApi.deleteAvatar();
      setAvatarPreview(null);
      updateAdminProfile({ profile_image_url: null });
      await fetchProfile();
    } catch (err: any) {
      console.error('Avatar delete error:', err);
      setError(err?.response?.data?.detail || 'Failed to remove avatar');
    } finally {
      setAvatarUploading(false);
    }
  };

  // Save profile to API
  const handleSaveProfile = async () => {
    try {
      setSaving(true);
      await settingsApi.updateProfile({
        first_name: profileForm.first_name,
        last_name: profileForm.last_name,
        phone: profileForm.phone,
      });
      setSaveSuccess(true);
      setTimeout(() => setSaveSuccess(false), 2000);
      // Sync name changes to AuthContext (updates sidebar/header)
      updateAdminProfile({
        first_name: profileForm.first_name,
        last_name: profileForm.last_name,
      });
      // Refresh profile data
      await fetchProfile();
    } catch (err: any) {
      console.error('Profile save error:', err);
      setError(err?.response?.data?.detail || 'Failed to save profile');
    } finally {
      setSaving(false);
    }
  };

  // Save notifications/system to localStorage
  const handleSavePreferences = () => {
    localStorage.setItem('nv_notifications', JSON.stringify(notifications));
    localStorage.setItem('nv_system', JSON.stringify(system));
    setSaveSuccess(true);
    setTimeout(() => setSaveSuccess(false), 2000);
  };

  // Combined save handler
  const handleSave = async () => {
    if (activeTab === 'profile') {
      await handleSaveProfile();
    } else if (activeTab === 'notifications' || activeTab === 'system') {
      handleSavePreferences();
    } else if (activeTab === 'appearance') {
      // Appearance auto-saves via ThemeContext, but show feedback
      setSaveSuccess(true);
      setTimeout(() => setSaveSuccess(false), 2000);
    }
  };

  // Change password
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
      await settingsApi.changePassword({
        current_password: passwordForm.current_password,
        new_password: passwordForm.new_password,
      });
      setPasswordSuccess(true);
      setPasswordForm({ current_password: '', new_password: '', confirm_password: '' });
      setTimeout(() => setPasswordSuccess(false), 3000);
    } catch (err: any) {
      console.error('Password change error:', err);
      setPasswordError(err?.response?.data?.detail || 'Failed to change password');
    } finally {
      setPasswordLoading(false);
    }
  };

  const tabs: { id: Tab; label: string; icon: typeof User }[] = [
    { id: 'profile', label: 'Profile', icon: User },
    { id: 'security', label: 'Security', icon: Lock },
    { id: 'notifications', label: 'Notifications', icon: Bell },
    { id: 'appearance', label: 'Appearance', icon: Palette },
    { id: 'system', label: 'System', icon: Database },
  ];

  const Toggle = ({ checked, onChange }: { checked: boolean; onChange: () => void }) => (
    <button onClick={onChange} className="relative">
      {checked ? (
        <ToggleRight className="w-10 h-10 text-accent" />
      ) : (
        <ToggleLeft className="w-10 h-10 text-dash-border" />
      )}
    </button>
  );

  const roleLabel = profileData?.role?.replace('_', ' ').replace(/\b\w/g, (l) => l.toUpperCase()) || 'Admin';
  const initials = `${profileForm.first_name?.[0] || ''}${profileForm.last_name?.[0] || ''}`.toUpperCase() || 'A';

  if (loading && !profileData) {
    return (
      <div className="flex items-center justify-center h-96">
        <div className="flex flex-col items-center gap-3">
          <Loader2 className="w-8 h-8 animate-spin text-accent" />
          <p className="text-sm text-dash-muted">Loading settings...</p>
        </div>
      </div>
    );
  }

  return (
    <motion.div variants={container} initial="hidden" animate="visible" className="space-y-6">
      {/* Header */}
      <motion.div variants={item} className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-dash-dark">Settings</h1>
          <p className="text-sm text-dash-muted mt-1">Manage your account and platform settings</p>
        </div>
        <button onClick={handleSave} disabled={saving} className="btn-primary flex items-center gap-2">
          {saving ? <Loader2 className="w-4 h-4 animate-spin" /> : saveSuccess ? <Check className="w-4 h-4" /> : <Save className="w-4 h-4" />}
          {saving ? 'Saving...' : saveSuccess ? 'Saved!' : 'Save Changes'}
        </button>
      </motion.div>

      {/* Tabs + Content */}
      <motion.div variants={item} className="grid grid-cols-1 xl:grid-cols-4 gap-6">
        {/* Sidebar Tabs */}
        <div className="card p-3 h-fit">
          <nav className="space-y-1">
            {tabs.map((tab) => (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id)}
                className={`w-full flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium transition-all
                  ${activeTab === tab.id ? 'bg-accent text-dash-dark' : 'text-dash-muted hover:bg-dash-bg hover:text-dash-text'}`}
              >
                <tab.icon className="w-4 h-4" />
                {tab.label}
                <ChevronRight className={`w-4 h-4 ml-auto transition-transform ${activeTab === tab.id ? 'rotate-90' : ''}`} />
              </button>
            ))}
          </nav>
        </div>

        {/* Content Area */}
        <div className="xl:col-span-3 space-y-6">
          {/* Profile Settings */}
          {activeTab === 'profile' && (
            <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} className="space-y-6">
              <div className="card p-6">
                <h3 className="font-semibold text-dash-dark mb-6">Profile Information</h3>

                {/* Avatar Upload */}
                <div className="flex items-center gap-5 mb-8">
                  <div className="relative">
                    {avatarPreview ? (
                      <div className="w-20 h-20 rounded-2xl overflow-hidden relative">
                        <img
                          src={avatarPreview}
                          alt="Profile"
                          className="w-full h-full object-cover"
                        />
                        {avatarUploading && (
                          <div className="absolute inset-0 bg-black/40 flex items-center justify-center rounded-2xl">
                            <Loader2 className="w-5 h-5 animate-spin text-white" />
                          </div>
                        )}
                      </div>
                    ) : (
                      <div className="w-20 h-20 rounded-2xl bg-accent/20 text-dash-dark flex items-center justify-center text-2xl font-bold relative">
                        {initials}
                        {avatarUploading && (
                          <div className="absolute inset-0 bg-black/40 flex items-center justify-center rounded-2xl">
                            <Loader2 className="w-5 h-5 animate-spin text-white" />
                          </div>
                        )}
                      </div>
                    )}
                    <button
                      onClick={() => fileInputRef.current?.click()}
                      disabled={avatarUploading}
                      className="absolute -bottom-1 -right-1 w-8 h-8 bg-accent rounded-xl flex items-center justify-center shadow-sm hover:bg-accent-hover transition-colors disabled:opacity-50"
                    >
                      <Camera className="w-4 h-4 text-dash-dark" />
                    </button>
                    <input
                      ref={fileInputRef}
                      type="file"
                      accept="image/jpeg,image/jpg,image/png,image/webp"
                      className="hidden"
                      onChange={handleAvatarSelect}
                    />
                  </div>
                  <div>
                    <p className="font-semibold text-dash-dark">{profileForm.first_name} {profileForm.last_name}</p>
                    <p className="text-sm text-dash-muted">{roleLabel}</p>
                    <div className="flex items-center gap-3 mt-1.5">
                      <button
                        onClick={() => fileInputRef.current?.click()}
                        disabled={avatarUploading}
                        className="text-xs text-accent-dark font-medium hover:underline flex items-center gap-1 disabled:opacity-50"
                      >
                        <Upload className="w-3 h-3" />
                        Upload Photo
                      </button>
                      {avatarPreview && (
                        <button
                          onClick={handleRemoveAvatar}
                          disabled={avatarUploading}
                          className="text-xs text-red-500 font-medium hover:underline flex items-center gap-1 disabled:opacity-50"
                        >
                          <Trash2 className="w-3 h-3" />
                          Remove
                        </button>
                      )}
                    </div>
                    <p className="text-2xs text-dash-muted mt-1">JPG, PNG or WebP. Max 10MB.</p>
                  </div>
                </div>

                {/* Form */}
                <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
                  <div>
                    <label className="block text-sm font-medium text-dash-dark mb-2">First Name</label>
                    <input
                      type="text"
                      value={profileForm.first_name}
                      onChange={(e) => setProfileForm({ ...profileForm, first_name: e.target.value })}
                      className="input"
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-dash-dark mb-2">Last Name</label>
                    <input
                      type="text"
                      value={profileForm.last_name}
                      onChange={(e) => setProfileForm({ ...profileForm, last_name: e.target.value })}
                      className="input"
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-dash-dark mb-2">Email Address</label>
                    <input
                      type="email"
                      value={profileData?.email || ''}
                      disabled
                      className="input bg-dash-bg text-dash-muted cursor-not-allowed"
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-dash-dark mb-2">Phone Number</label>
                    <input
                      type="text"
                      value={profileForm.phone}
                      onChange={(e) => setProfileForm({ ...profileForm, phone: e.target.value })}
                      className="input"
                      placeholder="+92 300 1234567"
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-dash-dark mb-2">Role</label>
                    <input type="text" value={roleLabel} disabled className="input bg-dash-bg text-dash-muted cursor-not-allowed" />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-dash-dark mb-2">Member Since</label>
                    <input
                      type="text"
                      value={profileData?.created_at ? new Date(profileData.created_at).toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' }) : ''}
                      disabled
                      className="input bg-dash-bg text-dash-muted cursor-not-allowed"
                    />
                  </div>
                </div>

                {/* Stats */}
                <div className="mt-6 pt-6 border-t border-dash-border grid grid-cols-3 gap-4">
                  <div className="text-center p-3 bg-dash-bg rounded-xl">
                    <p className="text-lg font-bold text-dash-dark">{profileData?.total_actions || 0}</p>
                    <p className="text-xs text-dash-muted mt-0.5">Total Actions</p>
                  </div>
                  <div className="text-center p-3 bg-dash-bg rounded-xl">
                    <p className="text-lg font-bold text-dash-dark">{profileData?.tickets_resolved || 0}</p>
                    <p className="text-xs text-dash-muted mt-0.5">Tickets Resolved</p>
                  </div>
                  <div className="text-center p-3 bg-dash-bg rounded-xl">
                    <p className="text-lg font-bold text-dash-dark">{profileData?.users_managed || 0}</p>
                    <p className="text-xs text-dash-muted mt-0.5">Users Managed</p>
                  </div>
                </div>
              </div>
            </motion.div>
          )}

          {/* Security */}
          {activeTab === 'security' && (
            <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} className="space-y-6">
              <div className="card p-6">
                <h3 className="font-semibold text-dash-dark mb-6">Change Password</h3>
                <div className="space-y-5 max-w-md">
                  {passwordError && (
                    <div className="flex items-center gap-2 p-3 bg-red-50 border border-red-200 rounded-xl">
                      <AlertCircle className="w-4 h-4 text-red-500 flex-shrink-0" />
                      <p className="text-sm text-red-600">{passwordError}</p>
                    </div>
                  )}
                  {passwordSuccess && (
                    <div className="flex items-center gap-2 p-3 bg-emerald-50 border border-emerald-200 rounded-xl">
                      <Check className="w-4 h-4 text-emerald-500 flex-shrink-0" />
                      <p className="text-sm text-emerald-600">Password changed successfully</p>
                    </div>
                  )}
                  <div>
                    <label className="block text-sm font-medium text-dash-dark mb-2">Current Password</label>
                    <div className="relative">
                      <input
                        type={showPassword ? 'text' : 'password'}
                        placeholder="Enter current password"
                        value={passwordForm.current_password}
                        onChange={(e) => setPasswordForm({ ...passwordForm, current_password: e.target.value })}
                        className="input pr-10"
                      />
                      <button onClick={() => setShowPassword(!showPassword)} className="absolute right-3 top-1/2 -translate-y-1/2 text-dash-muted hover:text-dash-text">
                        {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                      </button>
                    </div>
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-dash-dark mb-2">New Password</label>
                    <input
                      type="password"
                      placeholder="Enter new password"
                      value={passwordForm.new_password}
                      onChange={(e) => setPasswordForm({ ...passwordForm, new_password: e.target.value })}
                      className="input"
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-dash-dark mb-2">Confirm New Password</label>
                    <input
                      type="password"
                      placeholder="Confirm new password"
                      value={passwordForm.confirm_password}
                      onChange={(e) => setPasswordForm({ ...passwordForm, confirm_password: e.target.value })}
                      className="input"
                    />
                  </div>
                  <button
                    onClick={handleChangePassword}
                    disabled={passwordLoading || !passwordForm.current_password || !passwordForm.new_password || !passwordForm.confirm_password}
                    className="btn-primary flex items-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    {passwordLoading && <Loader2 className="w-4 h-4 animate-spin" />}
                    {passwordLoading ? 'Updating...' : 'Update Password'}
                  </button>
                </div>
              </div>

              <div className="card p-6">
                <h3 className="font-semibold text-dash-dark mb-6">Two-Factor Authentication</h3>
                <div className="flex items-center justify-between py-4 border-b border-dash-border">
                  <div>
                    <p className="text-sm font-medium text-dash-dark">Authenticator App</p>
                    <p className="text-xs text-dash-muted mt-0.5">Use an authenticator app to generate codes</p>
                  </div>
                  <button className="btn-secondary text-xs py-2">Setup</button>
                </div>
                <div className="flex items-center justify-between py-4 border-b border-dash-border">
                  <div>
                    <p className="text-sm font-medium text-dash-dark">SMS Verification</p>
                    <p className="text-xs text-dash-muted mt-0.5">Receive codes via SMS</p>
                  </div>
                  <span className="badge-success">Active</span>
                </div>
                <div className="flex items-center justify-between py-4">
                  <div>
                    <p className="text-sm font-medium text-dash-dark">Recovery Codes</p>
                    <p className="text-xs text-dash-muted mt-0.5">Download backup recovery codes</p>
                  </div>
                  <button className="btn-ghost text-xs">Generate</button>
                </div>
              </div>

              <div className="card p-6">
                <h3 className="font-semibold text-dash-dark mb-4">Active Sessions</h3>
                <div className="space-y-3">
                  {[
                    { device: 'Current Browser Session', location: 'Active Now', time: 'Current session', active: true },
                    ...(profileData?.last_login_at ? [{
                      device: 'Previous Login',
                      location: '',
                      time: new Date(profileData.last_login_at).toLocaleString(),
                      active: false,
                    }] : []),
                  ].map((session, i) => (
                    <div key={i} className="flex items-center justify-between py-3 border-b border-dash-border last:border-0">
                      <div className="flex items-center gap-3">
                        <div className={`w-2 h-2 rounded-full ${session.active ? 'bg-emerald-500' : 'bg-dash-border'}`} />
                        <div>
                          <p className="text-sm font-medium text-dash-dark">{session.device}</p>
                          <p className="text-xs text-dash-muted">{session.location} · {session.time}</p>
                        </div>
                      </div>
                      {!session.active && (
                        <button className="text-xs text-red-500 font-medium hover:underline">Revoke</button>
                      )}
                    </div>
                  ))}
                </div>
              </div>
            </motion.div>
          )}

          {/* Notifications */}
          {activeTab === 'notifications' && (
            <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} className="space-y-6">
              <div className="card p-6">
                <h3 className="font-semibold text-dash-dark mb-6">Email Notifications</h3>
                <div className="space-y-1">
                  {[
                    { key: 'email_new_user', label: 'New User Registration', desc: 'Get notified when a new user signs up' },
                    { key: 'email_tickets', label: 'Support Tickets', desc: 'Receive alerts for new support tickets' },
                    { key: 'email_doctor_verify', label: 'Doctor Verification', desc: 'Get notified for new doctor verification requests' },
                    { key: 'email_weekly_report', label: 'Weekly Report', desc: 'Receive weekly analytics summary' },
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
                <h3 className="font-semibold text-dash-dark mb-6">Push Notifications</h3>
                <div className="space-y-1">
                  {[
                    { key: 'push_critical', label: 'Critical Alerts', desc: 'System errors and critical issues' },
                    { key: 'push_tickets', label: 'Ticket Updates', desc: 'Updates on assigned tickets' },
                    { key: 'push_mentions', label: 'Mentions', desc: 'When someone mentions you' },
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

          {/* Appearance */}
          {activeTab === 'appearance' && (
            <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} className="space-y-6">
              <div className="card p-6">
                <h3 className="font-semibold text-dash-dark mb-6">Theme</h3>
                <div className="grid grid-cols-3 gap-4">
                  {([
                    { name: 'Light', value: 'light' as Theme, icon: Sun, bg: 'bg-white', desc: 'Classic light interface' },
                    { name: 'Dark', value: 'dark' as Theme, icon: Moon, bg: 'bg-gray-900', desc: 'Easy on the eyes' },
                    { name: 'System', value: 'system' as Theme, icon: Monitor, bg: 'bg-gradient-to-r from-white to-gray-900', desc: 'Follows your OS' },
                  ]).map((t) => {
                    const isActive = appearance.theme === t.value;
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
                    const isActive = appearance.accentColor === color;
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
                <p className="text-2xs text-dash-muted mt-3">Selected: {appearance.accentColor}</p>
              </div>

              <div className="card p-6">
                <h3 className="font-semibold text-dash-dark mb-6">Display</h3>
                <div className="space-y-5">
                  <div>
                    <label className="block text-sm font-medium text-dash-dark mb-2">Sidebar Width</label>
                    <select
                      value={appearance.sidebarWidth}
                      onChange={(e) => setSidebarWidth(e.target.value as SidebarWidth)}
                      className="input"
                    >
                      <option value="compact">Compact (200px)</option>
                      <option value="standard">Standard (240px)</option>
                      <option value="wide">Wide (280px)</option>
                    </select>
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-dash-dark mb-2">Font Size</label>
                    <select
                      value={appearance.fontSize}
                      onChange={(e) => setFontSize(e.target.value as FontSize)}
                      className="input"
                    >
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
                    <Toggle checked={appearance.compactMode} onChange={() => setCompactMode(!appearance.compactMode)} />
                  </div>
                </div>
              </div>
            </motion.div>
          )}

          {/* System */}
          {activeTab === 'system' && (
            <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} className="space-y-6">
              <div className="card p-6">
                <h3 className="font-semibold text-dash-dark mb-6">Platform Configuration</h3>
                <div className="space-y-1">
                  {[
                    { key: 'maintenance_mode', label: 'Maintenance Mode', desc: 'Enable maintenance mode for all users', danger: true },
                    { key: 'allow_registration', label: 'Allow Registration', desc: 'Allow new user registrations' },
                    { key: 'require_email_verify', label: 'Require Email Verification', desc: 'Users must verify email before access' },
                    { key: 'auto_approve_doctors', label: 'Auto-Approve Doctors', desc: 'Automatically approve doctor registrations' },
                  ].map((setting) => (
                    <div key={setting.key} className="flex items-center justify-between py-4 border-b border-dash-border last:border-0">
                      <div>
                        <p className={`text-sm font-medium ${setting.danger ? 'text-red-600' : 'text-dash-dark'}`}>{setting.label}</p>
                        <p className="text-xs text-dash-muted mt-0.5">{setting.desc}</p>
                      </div>
                      <Toggle
                        checked={system[setting.key as keyof typeof system] as boolean}
                        onChange={() => setSystem({ ...system, [setting.key]: !system[setting.key as keyof typeof system] })}
                      />
                    </div>
                  ))}
                </div>
              </div>

              <div className="card p-6">
                <h3 className="font-semibold text-dash-dark mb-6">Storage & Performance</h3>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
                  <div>
                    <label className="block text-sm font-medium text-dash-dark mb-2">Max Upload Size (MB)</label>
                    <input
                      type="number"
                      value={system.max_upload_size}
                      onChange={(e) => setSystem({ ...system, max_upload_size: e.target.value })}
                      className="input"
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-dash-dark mb-2">Session Timeout (min)</label>
                    <input
                      type="number"
                      value={system.session_timeout}
                      onChange={(e) => setSystem({ ...system, session_timeout: e.target.value })}
                      className="input"
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-dash-dark mb-2">Backup Frequency</label>
                    <select
                      value={system.backup_frequency}
                      onChange={(e) => setSystem({ ...system, backup_frequency: e.target.value })}
                      className="input"
                    >
                      <option value="hourly">Hourly</option>
                      <option value="daily">Daily</option>
                      <option value="weekly">Weekly</option>
                    </select>
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-dash-dark mb-2">API Rate Limit</label>
                    <input type="text" value="1000 req/min" disabled className="input bg-dash-bg text-dash-muted cursor-not-allowed" />
                  </div>
                </div>
              </div>

              <div className="card p-6 border-red-100">
                <h3 className="font-semibold text-red-600 mb-4">Danger Zone</h3>
                <div className="space-y-4">
                  <div className="flex items-center justify-between py-3 border-b border-dash-border">
                    <div>
                      <p className="text-sm font-medium text-dash-dark">Clear Cache</p>
                      <p className="text-xs text-dash-muted mt-0.5">Clear all cached data and temporary files</p>
                    </div>
                    <button className="px-4 py-2 text-xs font-medium rounded-xl border border-red-200 text-red-600 hover:bg-red-50 transition-all">
                      Clear Cache
                    </button>
                  </div>
                  <div className="flex items-center justify-between py-3 border-b border-dash-border">
                    <div>
                      <p className="text-sm font-medium text-dash-dark">Reset Analytics</p>
                      <p className="text-xs text-dash-muted mt-0.5">Reset all analytics data to zero</p>
                    </div>
                    <button className="px-4 py-2 text-xs font-medium rounded-xl border border-red-200 text-red-600 hover:bg-red-50 transition-all">
                      Reset Data
                    </button>
                  </div>
                  <div className="flex items-center justify-between py-3">
                    <div>
                      <p className="text-sm font-medium text-dash-dark">Export All Data</p>
                      <p className="text-xs text-dash-muted mt-0.5">Download complete platform data backup</p>
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

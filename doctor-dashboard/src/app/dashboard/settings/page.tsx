'use client';

import { useState } from 'react';
import { motion } from 'framer-motion';
import {
  User,
  Mail,
  Phone,
  Building,
  Briefcase,
  Shield,
  Bell,
  Moon,
  Sun,
  Save,
  Camera,
} from 'lucide-react';

const containerVariants = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: { staggerChildren: 0.1 },
  },
};

const itemVariants = {
  hidden: { opacity: 0, y: 20 },
  visible: { opacity: 1, y: 0 },
};

export default function SettingsPage() {
  const [profile, setProfile] = useState({
    first_name: 'Sarah',
    last_name: 'Ahmed',
    email: 'dr.sarah@hospital.com',
    phone: '+92 300 1234567',
    specialization: 'neurologist',
    hospital_affiliation: 'NeuroVerse Clinic',
    department: 'Neurology',
    bio: 'Experienced neurologist specializing in neurodegenerative diseases.',
  });

  const [notifications, setNotifications] = useState({
    email_alerts: true,
    critical_alerts: true,
    weekly_digest: false,
    new_tests: true,
  });

  const [isDarkMode, setIsDarkMode] = useState(false);

  return (
    <motion.div
      variants={containerVariants}
      initial="hidden"
      animate="visible"
      className="space-y-6 max-w-4xl"
    >
      {/* Header */}
      <motion.div variants={itemVariants}>
        <h1 className="text-3xl font-bold text-neuro-dark">Settings</h1>
        <p className="text-neuro-dark/60 mt-1">Manage your account and preferences</p>
      </motion.div>

      {/* Profile Section */}
      <motion.div
        variants={itemVariants}
        className="bg-white/80 backdrop-blur-xl rounded-2xl p-6 border border-white/50 shadow-neuro"
      >
        <h2 className="text-lg font-semibold text-neuro-dark mb-6 flex items-center gap-2">
          <User className="w-5 h-5 text-neuro-purple" />
          Profile Information
        </h2>

        {/* Avatar */}
        <div className="flex items-center gap-6 mb-6">
          <div className="relative">
            <div className="w-24 h-24 rounded-2xl bg-gradient-to-br from-neuro-purple to-neuro-blue 
                          flex items-center justify-center text-white text-3xl font-bold">
              {profile.first_name[0]}{profile.last_name[0]}
            </div>
            <button className="absolute -bottom-2 -right-2 p-2 bg-white rounded-xl shadow-md 
                             hover:shadow-lg transition-all">
              <Camera className="w-4 h-4 text-neuro-dark/60" />
            </button>
          </div>
          <div>
            <h3 className="text-xl font-semibold text-neuro-dark">
              Dr. {profile.first_name} {profile.last_name}
            </h3>
            <p className="text-neuro-dark/60 capitalize">{profile.specialization}</p>
          </div>
        </div>

        {/* Form */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="text-sm font-medium text-neuro-dark/70 mb-2 block">First Name</label>
            <div className="relative">
              <User className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-neuro-dark/40" />
              <input
                type="text"
                value={profile.first_name}
                onChange={(e) => setProfile({ ...profile, first_name: e.target.value })}
                className="w-full pl-12 pr-4 py-3 bg-neuro-bg/50 border border-neuro-dark/10 rounded-xl
                         focus:outline-none focus:ring-2 focus:ring-neuro-purple/20 transition-all"
              />
            </div>
          </div>
          <div>
            <label className="text-sm font-medium text-neuro-dark/70 mb-2 block">Last Name</label>
            <div className="relative">
              <User className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-neuro-dark/40" />
              <input
                type="text"
                value={profile.last_name}
                onChange={(e) => setProfile({ ...profile, last_name: e.target.value })}
                className="w-full pl-12 pr-4 py-3 bg-neuro-bg/50 border border-neuro-dark/10 rounded-xl
                         focus:outline-none focus:ring-2 focus:ring-neuro-purple/20 transition-all"
              />
            </div>
          </div>
          <div>
            <label className="text-sm font-medium text-neuro-dark/70 mb-2 block">Email</label>
            <div className="relative">
              <Mail className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-neuro-dark/40" />
              <input
                type="email"
                value={profile.email}
                disabled
                className="w-full pl-12 pr-4 py-3 bg-neuro-bg/30 border border-neuro-dark/10 rounded-xl
                         text-neuro-dark/50 cursor-not-allowed"
              />
            </div>
          </div>
          <div>
            <label className="text-sm font-medium text-neuro-dark/70 mb-2 block">Phone</label>
            <div className="relative">
              <Phone className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-neuro-dark/40" />
              <input
                type="tel"
                value={profile.phone}
                onChange={(e) => setProfile({ ...profile, phone: e.target.value })}
                className="w-full pl-12 pr-4 py-3 bg-neuro-bg/50 border border-neuro-dark/10 rounded-xl
                         focus:outline-none focus:ring-2 focus:ring-neuro-purple/20 transition-all"
              />
            </div>
          </div>
          <div>
            <label className="text-sm font-medium text-neuro-dark/70 mb-2 block">Hospital</label>
            <div className="relative">
              <Building className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-neuro-dark/40" />
              <input
                type="text"
                value={profile.hospital_affiliation}
                onChange={(e) => setProfile({ ...profile, hospital_affiliation: e.target.value })}
                className="w-full pl-12 pr-4 py-3 bg-neuro-bg/50 border border-neuro-dark/10 rounded-xl
                         focus:outline-none focus:ring-2 focus:ring-neuro-purple/20 transition-all"
              />
            </div>
          </div>
          <div>
            <label className="text-sm font-medium text-neuro-dark/70 mb-2 block">Department</label>
            <div className="relative">
              <Briefcase className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-neuro-dark/40" />
              <input
                type="text"
                value={profile.department}
                onChange={(e) => setProfile({ ...profile, department: e.target.value })}
                className="w-full pl-12 pr-4 py-3 bg-neuro-bg/50 border border-neuro-dark/10 rounded-xl
                         focus:outline-none focus:ring-2 focus:ring-neuro-purple/20 transition-all"
              />
            </div>
          </div>
          <div className="md:col-span-2">
            <label className="text-sm font-medium text-neuro-dark/70 mb-2 block">Bio</label>
            <textarea
              value={profile.bio}
              onChange={(e) => setProfile({ ...profile, bio: e.target.value })}
              rows={3}
              className="w-full px-4 py-3 bg-neuro-bg/50 border border-neuro-dark/10 rounded-xl
                       focus:outline-none focus:ring-2 focus:ring-neuro-purple/20 transition-all resize-none"
            />
          </div>
        </div>
      </motion.div>

      {/* Notifications Section */}
      <motion.div
        variants={itemVariants}
        className="bg-white/80 backdrop-blur-xl rounded-2xl p-6 border border-white/50 shadow-neuro"
      >
        <h2 className="text-lg font-semibold text-neuro-dark mb-6 flex items-center gap-2">
          <Bell className="w-5 h-5 text-neuro-purple" />
          Notification Preferences
        </h2>

        <div className="space-y-4">
          {[
            { key: 'email_alerts', label: 'Email Alerts', desc: 'Receive alerts via email' },
            { key: 'critical_alerts', label: 'Critical Alerts', desc: 'Get notified for high-risk patients' },
            { key: 'new_tests', label: 'New Test Results', desc: 'Alert when patients complete tests' },
            { key: 'weekly_digest', label: 'Weekly Digest', desc: 'Receive weekly summary reports' },
          ].map((item) => (
            <div key={item.key} className="flex items-center justify-between p-4 bg-neuro-bg/30 rounded-xl">
              <div>
                <p className="font-medium text-neuro-dark">{item.label}</p>
                <p className="text-sm text-neuro-dark/60">{item.desc}</p>
              </div>
              <button
                onClick={() => setNotifications({ 
                  ...notifications, 
                  [item.key]: !notifications[item.key as keyof typeof notifications] 
                })}
                className={`w-12 h-7 rounded-full transition-all relative
                  ${notifications[item.key as keyof typeof notifications] 
                    ? 'bg-neuro-purple' 
                    : 'bg-neuro-dark/20'}`}
              >
                <div className={`absolute top-1 w-5 h-5 bg-white rounded-full shadow transition-all
                  ${notifications[item.key as keyof typeof notifications] ? 'left-6' : 'left-1'}`} 
                />
              </button>
            </div>
          ))}
        </div>
      </motion.div>

      {/* Save Button */}
      <motion.div variants={itemVariants} className="flex justify-end">
        <motion.button
          whileHover={{ scale: 1.02 }}
          whileTap={{ scale: 0.98 }}
          className="flex items-center gap-2 px-8 py-3 bg-gradient-to-r from-neuro-purple to-neuro-blue 
                     text-white font-semibold rounded-xl shadow-lg hover:shadow-neuro-glow transition-all"
        >
          <Save className="w-5 h-5" />
          Save Changes
        </motion.button>
      </motion.div>
    </motion.div>
  );
}

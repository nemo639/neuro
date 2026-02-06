'use client';

import { useState } from 'react';
import { motion } from 'framer-motion';
import {
  Bell,
  AlertTriangle,
  TrendingUp,
  Brain,
  Activity,
  Check,
  X,
  ChevronRight,
  Clock,
} from 'lucide-react';

const containerVariants = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: { staggerChildren: 0.05 },
  },
};

const itemVariants = {
  hidden: { opacity: 0, y: 20 },
  visible: { opacity: 1, y: 0 },
};

// Mock alerts data
const mockAlerts = [
  {
    id: 'critical_1',
    type: 'critical',
    title: 'Critical Risk Level',
    message: 'Hassan Raza\'s AD risk score has exceeded 85. Immediate attention required.',
    patient_name: 'Hassan Raza',
    severity: 'critical',
    is_read: false,
    created_at: '2026-02-02T08:30:00Z',
  },
  {
    id: 'high_risk_2',
    type: 'high_risk',
    title: 'High Risk Alert',
    message: 'Ahmed Khan shows significant cognitive decline in recent SDMT test.',
    patient_name: 'Ahmed Khan',
    severity: 'warning',
    is_read: false,
    created_at: '2026-02-02T07:15:00Z',
  },
  {
    id: 'new_test_3',
    type: 'new_test',
    title: 'New Test Completed',
    message: 'Fatima Ali has completed the motor function assessment.',
    patient_name: 'Fatima Ali',
    severity: 'info',
    is_read: false,
    created_at: '2026-02-01T16:45:00Z',
  },
  {
    id: 'pending_4',
    type: 'pending_review',
    title: 'Pending Review',
    message: 'Zainab Ahmed\'s speech test results are awaiting your review.',
    patient_name: 'Zainab Ahmed',
    severity: 'info',
    is_read: true,
    created_at: '2026-02-01T14:20:00Z',
  },
  {
    id: 'trend_5',
    type: 'trend',
    title: 'Positive Trend',
    message: 'Muhammad Usman\'s PD risk score has decreased by 15% this month.',
    patient_name: 'Muhammad Usman',
    severity: 'success',
    is_read: true,
    created_at: '2026-02-01T10:00:00Z',
  },
];

const severityConfig: Record<string, { icon: any; color: string; bg: string }> = {
  critical: { icon: AlertTriangle, color: 'text-neuro-red', bg: 'bg-neuro-red/10 border-neuro-red/20' },
  warning: { icon: AlertTriangle, color: 'text-neuro-orange', bg: 'bg-neuro-orange/10 border-neuro-orange/20' },
  info: { icon: Bell, color: 'text-neuro-blue', bg: 'bg-neuro-blue/10 border-neuro-blue/20' },
  success: { icon: TrendingUp, color: 'text-neuro-green', bg: 'bg-neuro-green/10 border-neuro-green/20' },
};

export default function AlertsPage() {
  const [alerts, setAlerts] = useState(mockAlerts);
  const [filter, setFilter] = useState<'all' | 'unread'>('all');

  const filteredAlerts = alerts.filter((alert) => {
    if (filter === 'unread') return !alert.is_read;
    return true;
  });

  const unreadCount = alerts.filter((a) => !a.is_read).length;

  const markAsRead = (alertId: string) => {
    setAlerts(alerts.map((a) => (a.id === alertId ? { ...a, is_read: true } : a)));
  };

  const markAllAsRead = () => {
    setAlerts(alerts.map((a) => ({ ...a, is_read: true })));
  };

  const dismissAlert = (alertId: string) => {
    setAlerts(alerts.filter((a) => a.id !== alertId));
  };

  return (
    <motion.div
      variants={containerVariants}
      initial="hidden"
      animate="visible"
      className="space-y-6"
    >
      {/* Header */}
      <motion.div variants={itemVariants} className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold text-neuro-dark">Alerts</h1>
          <p className="text-neuro-dark/60 mt-1">
            Stay updated on important patient events
          </p>
        </div>
        <div className="flex items-center gap-3">
          {unreadCount > 0 && (
            <motion.button
              whileHover={{ scale: 1.02 }}
              whileTap={{ scale: 0.98 }}
              onClick={markAllAsRead}
              className="px-4 py-2 text-neuro-purple font-medium hover:bg-neuro-purple/10 rounded-xl transition-colors"
            >
              Mark all as read
            </motion.button>
          )}
          <span className="px-4 py-2 bg-neuro-red/10 text-neuro-red rounded-xl font-medium">
            {unreadCount} Unread
          </span>
        </div>
      </motion.div>

      {/* Filter Tabs */}
      <motion.div variants={itemVariants} className="flex gap-2">
        <button
          onClick={() => setFilter('all')}
          className={`px-4 py-2 rounded-xl font-medium transition-all
            ${filter === 'all' 
              ? 'bg-neuro-purple text-white' 
              : 'bg-white/80 text-neuro-dark/60 hover:bg-neuro-bg'}`}
        >
          All Alerts
        </button>
        <button
          onClick={() => setFilter('unread')}
          className={`px-4 py-2 rounded-xl font-medium transition-all
            ${filter === 'unread' 
              ? 'bg-neuro-purple text-white' 
              : 'bg-white/80 text-neuro-dark/60 hover:bg-neuro-bg'}`}
        >
          Unread ({unreadCount})
        </button>
      </motion.div>

      {/* Alerts List */}
      <motion.div variants={itemVariants} className="space-y-4">
        {filteredAlerts.map((alert) => {
          const config = severityConfig[alert.severity];
          const Icon = config.icon;

          return (
            <motion.div
              key={alert.id}
              variants={itemVariants}
              whileHover={{ x: 4 }}
              className={`relative bg-white/80 backdrop-blur-xl rounded-2xl p-6 border transition-all
                ${!alert.is_read ? 'border-l-4 border-l-neuro-purple shadow-neuro' : 'border-white/50'}
                hover:shadow-neuro`}
            >
              {/* Unread Indicator */}
              {!alert.is_read && (
                <div className="absolute top-4 right-4 w-3 h-3 bg-neuro-purple rounded-full animate-pulse" />
              )}

              <div className="flex items-start gap-4">
                {/* Icon */}
                <div className={`p-3 rounded-xl ${config.bg} border`}>
                  <Icon className={`w-5 h-5 ${config.color}`} />
                </div>

                {/* Content */}
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 mb-1">
                    <h3 className="font-semibold text-neuro-dark">{alert.title}</h3>
                    <span className={`px-2 py-0.5 rounded-full text-xs font-medium capitalize ${config.bg} ${config.color}`}>
                      {alert.severity}
                    </span>
                  </div>
                  <p className="text-neuro-dark/70 mb-2">{alert.message}</p>
                  <div className="flex items-center gap-4 text-sm text-neuro-dark/50">
                    <span className="flex items-center gap-1">
                      <Clock className="w-4 h-4" />
                      {new Date(alert.created_at).toLocaleString('en-US', {
                        month: 'short',
                        day: 'numeric',
                        hour: '2-digit',
                        minute: '2-digit',
                      })}
                    </span>
                    <span>Patient: {alert.patient_name}</span>
                  </div>
                </div>

                {/* Actions */}
                <div className="flex items-center gap-2">
                  {!alert.is_read && (
                    <motion.button
                      whileHover={{ scale: 1.1 }}
                      whileTap={{ scale: 0.9 }}
                      onClick={() => markAsRead(alert.id)}
                      className="p-2 hover:bg-neuro-green/10 rounded-lg transition-colors"
                      title="Mark as read"
                    >
                      <Check className="w-5 h-5 text-neuro-green" />
                    </motion.button>
                  )}
                  <motion.button
                    whileHover={{ scale: 1.1 }}
                    whileTap={{ scale: 0.9 }}
                    onClick={() => dismissAlert(alert.id)}
                    className="p-2 hover:bg-neuro-red/10 rounded-lg transition-colors"
                    title="Dismiss"
                  >
                    <X className="w-5 h-5 text-neuro-red/60" />
                  </motion.button>
                  <motion.button
                    whileHover={{ scale: 1.1 }}
                    whileTap={{ scale: 0.9 }}
                    className="p-2 hover:bg-neuro-bg rounded-lg transition-colors"
                    title="View details"
                  >
                    <ChevronRight className="w-5 h-5 text-neuro-dark/60" />
                  </motion.button>
                </div>
              </div>
            </motion.div>
          );
        })}
      </motion.div>

      {/* Empty State */}
      {filteredAlerts.length === 0 && (
        <motion.div
          variants={itemVariants}
          className="text-center py-16"
        >
          <Bell className="w-16 h-16 text-neuro-dark/20 mx-auto mb-4" />
          <h3 className="text-xl font-semibold text-neuro-dark mb-2">No alerts</h3>
          <p className="text-neuro-dark/60">
            {filter === 'unread' ? 'All caught up! No unread alerts.' : 'No alerts to display.'}
          </p>
        </motion.div>
      )}
    </motion.div>
  );
}

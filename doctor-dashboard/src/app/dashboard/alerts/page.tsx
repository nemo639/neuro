'use client';

import { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import {
  Bell,
  AlertTriangle,
  AlertCircle,
  Info,
  CheckCircle2,
  Eye,
  X,
  Clock,
} from 'lucide-react';
import { dashboardApi } from '@/lib/api';

const cv = { hidden: { opacity: 0 }, visible: { opacity: 1, transition: { staggerChildren: 0.05 } } };
const iv = { hidden: { opacity: 0, y: 12 }, visible: { opacity: 1, y: 0, transition: { duration: 0.4 } } };

type Alert = {
  id: string;
  type: 'critical' | 'warning' | 'info' | 'success';
  title: string;
  message: string;
  patient_name?: string;
  created_at: string;
  is_read: boolean;
};

const alertConfig: Record<string, { icon: React.ElementType; bg: string; iconBg: string; iconColor: string }> = {
  critical: { icon: AlertTriangle, bg: 'bg-red-50', iconBg: 'bg-red-100', iconColor: 'text-red-600' },
  warning: { icon: AlertCircle, bg: 'bg-amber-50', iconBg: 'bg-amber-100', iconColor: 'text-amber-600' },
  info: { icon: Info, bg: 'bg-blue-50', iconBg: 'bg-blue-100', iconColor: 'text-blue-600' },
  success: { icon: CheckCircle2, bg: 'bg-emerald-50', iconBg: 'bg-emerald-100', iconColor: 'text-emerald-600' },
};

export default function AlertsPage() {
  const [alerts, setAlerts] = useState<Alert[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<'all' | 'unread' | 'critical' | 'warning'>('all');

  useEffect(() => {
    (async () => {
      try {
        const res = await dashboardApi.getAlerts();
        setAlerts(res.alerts || []);
      } catch {
        setAlerts([
          { id: '1', type: 'critical', title: 'High AD Risk Detected', message: 'Patient Ahmed Khan has an AD risk score of 78%, exceeding the critical threshold. Immediate review recommended.', patient_name: 'Ahmed Khan', created_at: '2026-02-06T08:30:00', is_read: false },
          { id: '2', type: 'warning', title: 'Pending Test Review', message: 'Sara Qureshi completed a gait analysis test that requires your review within 48 hours.', patient_name: 'Sara Qureshi', created_at: '2026-02-05T16:15:00', is_read: false },
          { id: '3', type: 'info', title: 'New Patient Assigned', message: 'Bilal Hassan has been assigned to you. Review their initial assessment data at your earliest convenience.', patient_name: 'Bilal Hassan', created_at: '2026-02-05T10:00:00', is_read: true },
          { id: '4', type: 'success', title: 'Report Generated', message: 'Monthly assessment report for January 2026 has been successfully generated and is ready for download.', created_at: '2026-02-04T09:00:00', is_read: true },
          { id: '5', type: 'critical', title: 'PD Risk Alert', message: 'Patient Maryam Noor PD risk score increased by 15% in the last assessment. Review patient history.', patient_name: 'Maryam Noor', created_at: '2026-02-03T14:30:00', is_read: false },
        ]);
      } finally {
        setLoading(false);
      }
    })();
  }, []);

  const markRead = (id: string) => setAlerts(alerts.map((a) => (a.id === id ? { ...a, is_read: true } : a)));
  const markAllRead = () => setAlerts(alerts.map((a) => ({ ...a, is_read: true })));
  const dismiss = (id: string) => setAlerts(alerts.filter((a) => a.id !== id));

  const filtered = alerts.filter((a) => {
    if (filter === 'unread') return !a.is_read;
    if (filter === 'critical') return a.type === 'critical';
    if (filter === 'warning') return a.type === 'warning';
    return true;
  });

  const unreadCount = alerts.filter((a) => !a.is_read).length;
  const criticalCount = alerts.filter((a) => a.type === 'critical').length;

  const fmtDate = (iso: string) => {
    try { return new Date(iso).toLocaleDateString('en-US', { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' }); }
    catch { return iso; }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-[60vh]">
        <div className="w-8 h-8 border-2 border-accent border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  return (
    <motion.div variants={cv} initial="hidden" animate="visible">
      <div className="grid grid-cols-1 xl:grid-cols-[1fr_300px] gap-6">
        {/* ════ LEFT ════ */}
        <div className="space-y-6 min-w-0">
          {/* Header */}
          <motion.div variants={iv} className="flex items-center justify-between">
            <div>
              <h1 className="text-2xl font-bold text-dash-dark">Alerts</h1>
              <p className="text-sm text-dash-muted mt-0.5">{unreadCount} unread notifications</p>
            </div>
            {unreadCount > 0 && (
              <button onClick={markAllRead} className="btn-secondary text-xs">Mark all read</button>
            )}
          </motion.div>

          {/* Filter Pills */}
          <motion.div variants={iv} className="flex flex-wrap gap-2">
            {[
              { key: 'all', label: 'All' },
              { key: 'unread', label: `Unread (${unreadCount})` },
              { key: 'critical', label: `Critical (${criticalCount})` },
              { key: 'warning', label: 'Warnings' },
            ].map((t) => (
              <button
                key={t.key}
                onClick={() => setFilter(t.key as any)}
                className={`px-3.5 py-1.5 rounded-full text-xs font-medium transition-all
                  ${filter === t.key ? 'bg-dash-dark text-white' : 'bg-white text-dash-muted border border-dash-border hover:bg-dash-bg'}`}
              >
                {t.label}
              </button>
            ))}
          </motion.div>

          {/* Alerts List */}
          <motion.div variants={iv} className="space-y-3">
            {filtered.map((alert) => {
              const cfg = alertConfig[alert.type] || alertConfig.info;
              const Icon = cfg.icon;
              return (
                <div
                  key={alert.id}
                  className={`card p-4 transition-all hover:shadow-md ${!alert.is_read ? 'ring-1 ring-gray-200' : ''}`}
                >
                  <div className="flex items-start gap-3">
                    <div className={`w-10 h-10 rounded-xl ${cfg.iconBg} flex items-center justify-center flex-shrink-0`}>
                      <Icon className={`w-4 h-4 ${cfg.iconColor}`} />
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2 mb-0.5">
                        <h4 className="font-semibold text-dash-dark text-sm">{alert.title}</h4>
                        {!alert.is_read && <span className="w-2 h-2 rounded-full bg-accent flex-shrink-0" />}
                      </div>
                      <p className="text-xs text-gray-500 mb-1.5 line-clamp-2">{alert.message}</p>
                      <div className="flex items-center gap-3 text-[11px] text-gray-400">
                        {alert.patient_name && <span>{alert.patient_name}</span>}
                        <span className="flex items-center gap-0.5"><Clock className="w-2.5 h-2.5" />{fmtDate(alert.created_at)}</span>
                      </div>
                    </div>
                    <div className="flex items-center gap-0.5 flex-shrink-0">
                      {!alert.is_read && (
                        <button onClick={() => markRead(alert.id)} className="p-1.5 hover:bg-gray-100 rounded-lg" title="Mark read">
                          <Eye className="w-3.5 h-3.5 text-gray-400" />
                        </button>
                      )}
                      <button onClick={() => dismiss(alert.id)} className="p-1.5 hover:bg-gray-100 rounded-lg" title="Dismiss">
                        <X className="w-3.5 h-3.5 text-gray-400" />
                      </button>
                    </div>
                  </div>
                </div>
              );
            })}
          </motion.div>

          {filtered.length === 0 && (
            <div className="text-center py-16">
              <Bell className="w-8 h-8 text-dash-border mx-auto mb-2" />
              <p className="text-sm text-dash-muted">No alerts</p>
            </div>
          )}
        </div>

        {/* ════ RIGHT — Summary Panel ════ */}
        <motion.div variants={iv} className="space-y-4">
          {/* Overview Card */}
          <div className="card p-5">
            <h4 className="text-sm font-semibold text-dash-dark mb-4">Overview</h4>
            <div className="space-y-3">
              {[
                { label: 'Total Alerts', value: alerts.length, bg: 'bg-accent/10', color: '#C6E94B' },
                { label: 'Unread', value: unreadCount, bg: 'bg-blue-50', color: '#3B82F6' },
                { label: 'Critical', value: criticalCount, bg: 'bg-red-50', color: '#EF4444' },
              ].map((s) => (
                <div key={s.label} className={`${s.bg} rounded-xl p-3 flex items-center justify-between`}>
                  <span className="text-xs text-gray-600">{s.label}</span>
                  <span className="text-lg font-bold" style={{ color: s.color }}>{s.value}</span>
                </div>
              ))}
            </div>
          </div>

          {/* Recent Critical */}
          <div className="card p-5">
            <h4 className="text-sm font-semibold text-dash-dark mb-3">Recent Critical</h4>
            <div className="space-y-2">
              {alerts.filter(a => a.type === 'critical').slice(0, 3).map((a) => (
                <div key={a.id} className="flex items-center gap-2 py-2 border-b border-gray-50 last:border-0">
                  <AlertTriangle className="w-3.5 h-3.5 text-red-500 flex-shrink-0" />
                  <div className="min-w-0">
                    <p className="text-xs font-medium text-gray-700 truncate">{a.title}</p>
                    <p className="text-[10px] text-gray-400">{a.patient_name || 'System'}</p>
                  </div>
                </div>
              ))}
              {alerts.filter(a => a.type === 'critical').length === 0 && (
                <p className="text-xs text-gray-400">No critical alerts</p>
              )}
            </div>
          </div>
        </motion.div>
      </div>
    </motion.div>
  );
}

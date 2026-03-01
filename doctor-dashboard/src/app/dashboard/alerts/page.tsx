'use client';

import { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import {
  Bell, AlertTriangle, AlertCircle, Info, CheckCircle2,
  Eye, X, Clock, Loader2, Brain, Activity, RefreshCw,
} from 'lucide-react';
import { dashboardApi } from '@/lib/api';
import Link from 'next/link';

const cv = { hidden: { opacity: 0 }, visible: { opacity: 1, transition: { staggerChildren: 0.05 } } };
const iv = { hidden: { opacity: 0, y: 12 }, visible: { opacity: 1, y: 0, transition: { duration: 0.4 } } };

type Alert = {
  id: string;
  type: string;         // high_risk, new_test, pending_review
  title: string;
  message: string;
  patient_id?: number;
  patient_name?: string;
  severity: string;     // critical, warning, info
  is_read: boolean;
  created_at: string;
};

const severityConfig: Record<string, { icon: React.ElementType; bg: string; iconBg: string; iconColor: string; ring: string }> = {
  critical: { icon: AlertTriangle, bg: 'bg-[#E8637A]/12', iconBg: 'bg-[#E8637A]/18', iconColor: 'text-[#E8637A]', ring: 'ring-[#E8637A]/20' },
  warning: { icon: AlertCircle, bg: 'bg-[#F5A623]/12', iconBg: 'bg-[#F5A623]/18', iconColor: 'text-[#F5A623]', ring: 'ring-[#F5A623]/20' },
  info: { icon: Info, bg: 'bg-blue-50', iconBg: 'bg-blue-100', iconColor: 'text-blue-600', ring: 'ring-blue-200' },
};

const fmtDate = (iso?: string) => {
  if (!iso) return '—';
  try { return new Date(iso).toLocaleDateString('en-US', { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' }); }
  catch { return iso; }
};

const timeAgo = (iso: string) => {
  try {
    const d = new Date(iso);
    const now = new Date();
    const diff = Math.floor((now.getTime() - d.getTime()) / 1000);
    if (diff < 60) return 'just now';
    if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
    if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
    return `${Math.floor(diff / 86400)}d ago`;
  } catch { return ''; }
};

export default function AlertsPage() {
  const [alerts, setAlerts] = useState<Alert[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [filter, setFilter] = useState<'all' | 'unread' | 'critical' | 'warning'>('all');
  const [refreshing, setRefreshing] = useState(false);

  const loadAlerts = async (isRefresh = false) => {
    if (isRefresh) setRefreshing(true); else setLoading(true);
    setError('');
    try {
      const res = await dashboardApi.getAlerts();
      setAlerts(res.alerts || []);
    } catch (e: any) {
      setError(e?.response?.data?.detail || 'Failed to load alerts');
      setAlerts([]);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  useEffect(() => { loadAlerts(); }, []);

  const markRead = (id: string) => {
    setAlerts(prev => prev.map(a => a.id === id ? { ...a, is_read: true } : a));
    try { dashboardApi.markAlertRead(id); } catch {}
  };

  const markAllRead = () => {
    setAlerts(prev => prev.map(a => ({ ...a, is_read: true })));
    alerts.filter(a => !a.is_read).forEach(a => {
      try { dashboardApi.markAlertRead(a.id); } catch {}
    });
  };

  const dismiss = (id: string) => setAlerts(prev => prev.filter(a => a.id !== id));

  const filtered = alerts.filter((a) => {
    if (filter === 'unread') return !a.is_read;
    if (filter === 'critical') return a.severity === 'critical';
    if (filter === 'warning') return a.severity === 'warning';
    return true;
  });

  const unreadCount = alerts.filter(a => !a.is_read).length;
  const criticalCount = alerts.filter(a => a.severity === 'critical').length;
  const warningCount = alerts.filter(a => a.severity === 'warning').length;
  const infoCount = alerts.filter(a => a.severity === 'info').length;

  if (loading) {
    return (
      <div className="flex items-center justify-center h-[60vh]">
        <Loader2 className="w-8 h-8 animate-spin text-accent" />
      </div>
    );
  }

  return (
    <motion.div variants={cv} initial="hidden" animate="visible">
      <div className="grid grid-cols-1 xl:grid-cols-[1fr_300px] gap-6">
        {/* ════ LEFT ════ */}
        <div className="space-y-5 min-w-0">
          {/* Header */}
          <motion.div variants={iv} className="flex items-center justify-between">
            <div>
              <h1 className="text-2xl font-bold text-dash-dark">Alerts</h1>
              <p className="text-sm text-dash-muted mt-0.5">
                {unreadCount > 0 ? `${unreadCount} unread notification${unreadCount > 1 ? 's' : ''}` : 'All caught up!'}
              </p>
            </div>
            <div className="flex items-center gap-2">
              <button onClick={() => loadAlerts(true)} disabled={refreshing}
                className="p-2.5 rounded-xl border border-dash-border hover:bg-dash-bg transition-colors disabled:opacity-50">
                <RefreshCw className={`w-4 h-4 text-dash-muted ${refreshing ? 'animate-spin' : ''}`} />
              </button>
              {unreadCount > 0 && (
                <button onClick={markAllRead} className="btn-secondary text-xs">Mark all read</button>
              )}
            </div>
          </motion.div>

          {/* Stat Cards */}
          <motion.div variants={iv} className="grid grid-cols-4 gap-3">
            {[
              { label: 'Total', value: alerts.length, bg: 'bg-[#F4F7D8]', color: '#C6E94B', icon: Bell },
              { label: 'Unread', value: unreadCount, bg: 'bg-blue-50', color: '#3B82F6', icon: Eye },
              { label: 'Critical', value: criticalCount, bg: 'bg-[#FDEEF0]', color: '#E8637A', icon: AlertTriangle },
              { label: 'Warnings', value: warningCount, bg: 'bg-[#FEF3E0]', color: '#F5A623', icon: AlertCircle },
            ].map((s) => (
              <div key={s.label} className={`${s.bg} rounded-2xl p-3.5 flex items-center gap-3`}>
                <div className="w-9 h-9 rounded-xl bg-white/70 flex items-center justify-center flex-shrink-0">
                  <s.icon className="w-4 h-4" style={{ color: s.color }} />
                </div>
                <div>
                  <p className="text-lg font-bold text-dash-dark">{s.value}</p>
                  <p className="text-[10px] text-dash-muted">{s.label}</p>
                </div>
              </div>
            ))}
          </motion.div>

          {/* Filter Pills */}
          <motion.div variants={iv} className="flex flex-wrap gap-2">
            {[
              { key: 'all', label: `All (${alerts.length})` },
              { key: 'unread', label: `Unread (${unreadCount})` },
              { key: 'critical', label: `Critical (${criticalCount})` },
              { key: 'warning', label: `Warnings (${warningCount})` },
            ].map((t) => (
              <button key={t.key} onClick={() => setFilter(t.key as any)}
                className={`px-3.5 py-1.5 rounded-full text-xs font-medium transition-all ${
                  filter === t.key ? 'bg-dash-dark text-white' : 'bg-white text-dash-muted border border-dash-border hover:bg-dash-bg'
                }`}>
                {t.label}
              </button>
            ))}
          </motion.div>

          {/* Error */}
          {error && (
            <motion.div variants={iv} className="flex items-center gap-3 p-4 bg-red-50 rounded-xl">
              <AlertTriangle className="w-5 h-5 text-red-400 flex-shrink-0" />
              <p className="text-sm text-red-600">{error}</p>
              <button onClick={() => loadAlerts()} className="text-xs text-red-500 hover:underline ml-auto">Retry</button>
            </motion.div>
          )}

          {/* Alerts List */}
          <motion.div variants={iv} className="space-y-3">
            {filtered.map((alert) => {
              const cfg = severityConfig[alert.severity] || severityConfig.info;
              const Icon = cfg.icon;
              return (
                <div key={alert.id}
                  className={`card p-4 transition-all hover:shadow-md ${!alert.is_read ? `ring-1 ${cfg.ring}` : ''}`}>
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
                        <span className={`px-2 py-0.5 rounded-full text-[10px] font-medium capitalize ${cfg.bg} ${cfg.iconColor}`}>
                          {alert.severity}
                        </span>
                        {alert.patient_name && (
                          <Link href={`/dashboard/patients/${alert.patient_id}`}
                            className="hover:text-accent-dark transition-colors">
                            {alert.patient_name}
                          </Link>
                        )}
                        <span className="flex items-center gap-0.5">
                          <Clock className="w-2.5 h-2.5" />{timeAgo(alert.created_at)}
                        </span>
                        <span className="text-gray-300 capitalize">{alert.type.replace('_', ' ')}</span>
                      </div>
                    </div>
                    <div className="flex items-center gap-0.5 flex-shrink-0">
                      {!alert.is_read && (
                        <button onClick={() => markRead(alert.id)} className="p-1.5 hover:bg-gray-100 rounded-lg" title="Mark read">
                          <Eye className="w-3.5 h-3.5 text-gray-400" />
                        </button>
                      )}
                      {alert.patient_id && (
                        <Link href={`/dashboard/patients/${alert.patient_id}`} className="p-1.5 hover:bg-accent/10 rounded-lg" title="View patient">
                          <Brain className="w-3.5 h-3.5 text-gray-400 hover:text-accent-dark" />
                        </Link>
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

          {filtered.length === 0 && !error && (
            <div className="text-center py-16">
              <Bell className="w-8 h-8 text-dash-border mx-auto mb-2" />
              <p className="text-sm text-dash-muted">
                {filter === 'all' ? 'No alerts at the moment' : `No ${filter} alerts`}
              </p>
              <p className="text-xs text-dash-muted mt-1">Alerts are generated from patient risk scores and new test completions</p>
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
                { label: 'Warnings', value: warningCount, bg: 'bg-amber-50', color: '#F59E0B' },
                { label: 'Info', value: infoCount, bg: 'bg-blue-50/50', color: '#60A5FA' },
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
              {alerts.filter(a => a.severity === 'critical').slice(0, 5).map((a) => (
                <Link key={a.id} href={a.patient_id ? `/dashboard/patients/${a.patient_id}` : '#'}
                  className="flex items-center gap-2 py-2 border-b border-gray-50 last:border-0 hover:bg-red-50/50 rounded-lg px-1 -mx-1 transition-colors">
                  <AlertTriangle className="w-3.5 h-3.5 text-red-500 flex-shrink-0" />
                  <div className="min-w-0 flex-1">
                    <p className="text-xs font-medium text-gray-700 truncate">{a.title}</p>
                    <p className="text-[10px] text-gray-400">{a.patient_name || 'System'} · {timeAgo(a.created_at)}</p>
                  </div>
                  {!a.is_read && <span className="w-1.5 h-1.5 rounded-full bg-red-400 flex-shrink-0" />}
                </Link>
              ))}
              {alerts.filter(a => a.severity === 'critical').length === 0 && (
                <div className="text-center py-4">
                  <CheckCircle2 className="w-6 h-6 text-emerald-300 mx-auto mb-1" />
                  <p className="text-xs text-gray-400">No critical alerts</p>
                </div>
              )}
            </div>
          </div>

          {/* Alert Types Breakdown */}
          {alerts.length > 0 && (
            <div className="card p-5">
              <h4 className="text-sm font-semibold text-dash-dark mb-3">By Type</h4>
              <div className="space-y-2.5">
                {Object.entries(alerts.reduce<Record<string, number>>((acc, a) => {
                  const t = a.type.replace('_', ' ');
                  acc[t] = (acc[t] || 0) + 1;
                  return acc;
                }, {})).map(([type, count]) => {
                  const pct = Math.round((count / alerts.length) * 100);
                  return (
                    <div key={type}>
                      <div className="flex items-center justify-between mb-1">
                        <span className="text-xs text-dash-muted capitalize">{type}</span>
                        <span className="text-xs font-semibold text-dash-dark">{count}</span>
                      </div>
                      <div className="w-full h-1.5 rounded-full bg-gray-100">
                        <div className="h-full rounded-full bg-accent transition-all duration-500" style={{ width: `${pct}%` }} />
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          )}
        </motion.div>
      </div>
    </motion.div>
  );
}

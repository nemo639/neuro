'use client';

import { useState, useEffect, useMemo } from 'react';
import { motion } from 'framer-motion';
import {
  Users, FileText, ChevronRight, ArrowUpRight, ArrowDownRight,
  ClipboardCheck, BarChart3, Calendar, MoreHorizontal, AlertTriangle,
  Loader2, Brain, Activity, TrendingUp, Zap, Clock,
} from 'lucide-react';
import {
  PieChart, Pie, Cell, ResponsiveContainer,
  AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip,
  BarChart, Bar, RadialBarChart, RadialBar, Legend,
} from 'recharts';
import { dashboardApi } from '@/lib/api';
import { useAuth } from '@/contexts/AuthContext';
import Link from 'next/link';

const container = { hidden: { opacity: 0 }, visible: { opacity: 1, transition: { staggerChildren: 0.06 } } };
const item = { hidden: { opacity: 0, y: 12 }, visible: { opacity: 1, y: 0, transition: { duration: 0.4 } } };

/* ─── Multi-color bar palette ─── */
const BAR_COLORS = ['#C6E94B', '#6366F1', '#A855F7', '#FB923C', '#EC4899', '#22D3EE', '#818CF8'];

/* ─── Fallback data when API fails ─── */
const FALLBACK = {
  total_patients: 0, pending_reviews: 0, reports_today: 0,
  critical_alerts: 0, tests_completed: 0,
  recent_patients: [],
  pending_diagnostics: [],
  tests_by_category: [
    { category: 'Cognitive', count: 120, color: '#C6E94B' },
    { category: 'Speech', count: 95, color: '#6366F1' },
    { category: 'Motor', count: 80, color: '#A855F7' },
    { category: 'Gait', count: 65, color: '#FB923C' },
    { category: 'Facial', count: 50, color: '#EC4899' },
  ],
  monthly_patient_flow: [
    { month: 'Jul', new_patients: 24, discharged: 12 },
    { month: 'Aug', new_patients: 32, discharged: 18 },
    { month: 'Sep', new_patients: 28, discharged: 22 },
    { month: 'Oct', new_patients: 38, discharged: 20 },
    { month: 'Nov', new_patients: 42, discharged: 25 },
    { month: 'Dec', new_patients: 35, discharged: 30 },
    { month: 'Jan', new_patients: 48, discharged: 28 },
    { month: 'Feb', new_patients: 52, discharged: 32 },
  ],
  weekly_visits: [
    { day: 'Mon', visits: 18 }, { day: 'Tue', visits: 24 }, { day: 'Wed', visits: 32 },
    { day: 'Thu', visits: 28 }, { day: 'Fri', visits: 38 }, { day: 'Sat', visits: 14 },
    { day: 'Sun', visits: 8 },
  ],
  risk_distribution: [
    { level: 'Low', count: 85 }, { level: 'Moderate', count: 42 }, { level: 'High', count: 18 },
  ],
};

/* ─── Custom Tooltip ─── */
const CustomTooltip = ({ active, payload, label }: any) => {
  if (!active || !payload) return null;
  return (
    <div className="bg-white p-3 rounded-xl shadow-elevated border border-dash-border">
      <p className="text-xs font-semibold text-dash-dark mb-1">{label}</p>
      {payload.map((entry: any, i: number) => (
        <p key={i} className="text-xs text-dash-muted">
          <span className="inline-block w-2 h-2 rounded-full mr-1.5" style={{ backgroundColor: entry.color }} />
          {entry.name}: <span className="font-semibold text-dash-dark">{entry.value}</span>
        </p>
      ))}
    </div>
  );
};

export default function DashboardPage() {
  const { doctor } = useAuth();
  const [data, setData] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(false);
  const [selectedDate, setSelectedDate] = useState('');

  useEffect(() => {
    (async () => {
      try {
        const res = await dashboardApi.getDashboard();
        setData(res);
      } catch {
        setError(true);
        setData(FALLBACK);
      } finally {
        setLoading(false);
      }
    })();
  }, []);

  /* ─── Derived chart data ─── */
  const donutData = useMemo(() =>
    (data?.tests_by_category || FALLBACK.tests_by_category).map((c: any) => ({
      name: c.category, value: c.count, color: c.color,
    })), [data]);

  const areaData = useMemo(() =>
    (data?.monthly_patient_flow || FALLBACK.monthly_patient_flow).map((m: any) => ({
      month: m.month, newPatients: m.new_patients, discharged: m.discharged,
    })), [data]);

  const weeklyData = useMemo(() =>
    data?.weekly_visits || FALLBACK.weekly_visits, [data]);

  const riskData = useMemo(() => {
    const raw = data?.risk_distribution || FALLBACK.risk_distribution;
    const colors: Record<string, string> = { Low: '#2AC9A0', Moderate: '#F5A623', High: '#E8637A' };
    return raw.map((r: any) => ({ ...r, color: colors[r.level] || '#8B8FA8' }));
  }, [data]);

  const totalTests = useMemo(() => donutData.reduce((a: number, d: any) => a + d.value, 0), [donutData]);
  const weeklyTotal = useMemo(() => weeklyData.reduce((a: number, d: any) => a + d.visits, 0), [weeklyData]);
  const maxVisits = useMemo(() => Math.max(...weeklyData.map((d: any) => d.visits), 1), [weeklyData]);

  const stats = useMemo(() => [
    { title: 'Total Patients', value: data?.total_patients ?? 0, change: '+12.5%', up: true, icon: Users, color: '#C6E94B' },
    { title: 'Tests Completed', value: data?.tests_completed ?? totalTests, change: '+8.2%', up: true, icon: ClipboardCheck, color: '#6366F1' },
    { title: 'Pending Reviews', value: data?.pending_reviews ?? 0, change: '-3.1%', up: false, icon: FileText, color: '#FB923C' },
    { title: 'Critical Alerts', value: data?.critical_alerts ?? 0, change: data?.critical_alerts > 0 ? 'Needs attention' : 'All clear', up: (data?.critical_alerts ?? 0) === 0, icon: AlertTriangle, color: '#E8637A' },
  ], [data, totalTests]);

  const patients = data?.recent_patients || [];
  const diagnostics = data?.pending_diagnostics || [];

  if (loading) {
    return (
      <div className="flex items-center justify-center h-[60vh]">
        <div className="flex flex-col items-center gap-3">
          <Loader2 className="w-8 h-8 animate-spin text-accent" />
          <p className="text-sm text-dash-muted">Loading dashboard...</p>
        </div>
      </div>
    );
  }

  return (
    <motion.div variants={container} initial="hidden" animate="visible" className="space-y-6">
      {/* ═══ Header ═══ */}
      <motion.div variants={item} className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-dash-dark">
            Welcome back, {data?.doctor_name || `Dr. ${doctor?.first_name || 'Doctor'}`}
          </h1>
          <p className="text-sm text-dash-muted mt-0.5">
            Here&apos;s what&apos;s happening with your patients today
          </p>
        </div>
        <div className="flex items-center gap-2">
          <label className="relative inline-flex items-center gap-2 btn-secondary py-2 cursor-pointer">
            <Calendar className="w-4 h-4" />
            <span className="text-sm">
              {selectedDate
                ? new Date(selectedDate + 'T00:00:00').toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
                : 'Today'}
            </span>
            <input
              type="date"
              className="absolute inset-0 w-full h-full opacity-0 cursor-pointer z-10"
              value={selectedDate}
              max={new Date().toISOString().split('T')[0]}
              onChange={(e) => setSelectedDate(e.target.value)}
            />
          </label>
        </div>
      </motion.div>

      {error && (
        <motion.div variants={item} className="flex items-center gap-2 p-3 rounded-xl bg-amber-50 border border-amber-100 text-amber-700 text-sm">
          <AlertTriangle className="w-4 h-4 flex-shrink-0" />
          Unable to connect to backend — showing sample data
        </motion.div>
      )}

      {/* ═══ Stat Cards ═══ */}
      <motion.div variants={item} className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        {stats.map((stat, idx) => (
          <div key={stat.title} className="card p-5 relative overflow-hidden group hover:shadow-card-hover transition-all">
            <div className="flex items-start justify-between mb-3">
              <div className="w-10 h-10 rounded-xl flex items-center justify-center" style={{ backgroundColor: `${stat.color}15` }}>
                <stat.icon className="w-5 h-5" style={{ color: stat.color }} />
              </div>
              <button className="p-1 hover:bg-black/5 rounded-lg transition-colors opacity-0 group-hover:opacity-100">
                <MoreHorizontal className="w-4 h-4 text-dash-muted" />
              </button>
            </div>
            <p className="text-3xl font-bold text-dash-dark">
              {(stat.value ?? 0).toLocaleString()}
            </p>
            <p className="text-sm text-dash-muted mt-0.5">{stat.title}</p>
            <div className="flex items-center gap-1 mt-2">
              {stat.up ? (
                <ArrowUpRight className="w-3.5 h-3.5 text-emerald-500" />
              ) : (
                <ArrowDownRight className="w-3.5 h-3.5 text-red-500" />
              )}
              <span className={`text-xs font-semibold ${stat.up ? 'text-emerald-500' : 'text-red-500'}`}>
                {stat.change}
              </span>
            </div>
            {/* Accent bar at bottom */}
            <div className="absolute bottom-0 left-0 right-0 h-1 rounded-b-2xl" style={{ backgroundColor: stat.color, opacity: 0.6 }} />
          </div>
        ))}
      </motion.div>

      {/* ═══ Charts Row #1 — Area + Donut ═══ */}
      <div className="grid grid-cols-1 xl:grid-cols-3 gap-6">
        {/* Area Chart */}
        <motion.div variants={item} className="xl:col-span-2 card p-6">
          <div className="flex items-center justify-between mb-6">
            <div>
              <h3 className="font-semibold text-dash-dark">Patient Activity</h3>
              <p className="text-xs text-dash-muted mt-0.5">Monthly patient flow trends</p>
            </div>
          </div>
          <div className="flex items-center gap-5 mb-4">
            <div className="flex items-center gap-2"><span className="w-3 h-3 rounded-full" style={{ backgroundColor: '#6366F1' }} /><span className="text-xs text-dash-muted">New Patients</span></div>
            <div className="flex items-center gap-2"><span className="w-3 h-3 rounded-full" style={{ backgroundColor: '#C6E94B' }} /><span className="text-xs text-dash-muted">Tests Completed</span></div>
          </div>
          <ResponsiveContainer width="100%" height={240}>
            <AreaChart data={areaData}>
              <defs>
                <linearGradient id="gNew" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stopColor="#6366F1" stopOpacity={0.15} /><stop offset="100%" stopColor="#6366F1" stopOpacity={0} /></linearGradient>
                <linearGradient id="gDischarged" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stopColor="#C6E94B" stopOpacity={0.15} /><stop offset="100%" stopColor="#C6E94B" stopOpacity={0} /></linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="#ECEDF2" vertical={false} />
              <XAxis dataKey="month" fontSize={11} tick={{ fill: '#8B8FA8' }} axisLine={false} tickLine={false} />
              <YAxis fontSize={11} tick={{ fill: '#8B8FA8' }} axisLine={false} tickLine={false} />
              <Tooltip content={<CustomTooltip />} />
              <Area type="monotone" dataKey="newPatients" stroke="#6366F1" strokeWidth={2} fill="url(#gNew)" name="New Patients" />
              <Area type="monotone" dataKey="discharged" stroke="#C6E94B" strokeWidth={2} fill="url(#gDischarged)" name="Tests Completed" />
            </AreaChart>
          </ResponsiveContainer>
        </motion.div>

        {/* Donut — Tests By Category */}
        <motion.div variants={item} className="card p-6">
          <div className="flex items-center justify-between mb-4">
            <h3 className="font-semibold text-dash-dark">By Assessment</h3>
            <span className="text-xs text-dash-muted">{totalTests} total</span>
          </div>
          <ResponsiveContainer width="100%" height={180}>
            <PieChart>
              <Pie data={donutData} cx="50%" cy="50%" innerRadius={50} outerRadius={75}
                paddingAngle={3} dataKey="value" startAngle={90} endAngle={450}>
                {donutData.map((entry: any, i: number) => (
                  <Cell key={i} fill={entry.color} strokeWidth={0} />
                ))}
              </Pie>
              <Tooltip content={<CustomTooltip />} />
            </PieChart>
          </ResponsiveContainer>
          <div className="text-center -mt-2 mb-3">
            <p className="text-2xl font-bold text-dash-dark">{totalTests}</p>
            <p className="text-xs text-dash-muted">Total Tests</p>
          </div>
          <div className="grid grid-cols-2 gap-x-4 gap-y-2">
            {donutData.map((d: any) => (
              <div key={d.name} className="flex items-center gap-2">
                <span className="w-2 h-2 rounded-full flex-shrink-0" style={{ backgroundColor: d.color }} />
                <span className="text-xs text-dash-muted truncate">{d.name}</span>
                <span className="text-xs font-semibold text-dash-dark ml-auto">{d.value}</span>
              </div>
            ))}
          </div>
        </motion.div>
      </div>

      {/* ═══ Charts Row #2 — Weekly Visits (multi-color) + Risk Distribution + Diagnostics ═══ */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Weekly Visits — multi-color bars */}
        <motion.div variants={item} className="card p-6">
          <div className="flex items-center justify-between mb-5">
            <h3 className="font-semibold text-dash-dark">Weekly Visits</h3>
            <span className="text-xs text-dash-muted">{weeklyTotal} total</span>
          </div>
          <ResponsiveContainer width="100%" height={200}>
            <BarChart data={weeklyData} barSize={28}>
              <XAxis dataKey="day" fontSize={11} tick={{ fill: '#8B8FA8' }} axisLine={false} tickLine={false} />
              <YAxis hide />
              <Tooltip content={<CustomTooltip />} cursor={{ fill: 'rgba(0,0,0,0.03)', radius: 8 }} />
              <Bar dataKey="visits" name="Visits" radius={[8, 8, 2, 2]}
                shape={(props: any) => {
                  const idx = weeklyData.findIndex((d: any) => d.day === props.payload.day);
                  return (
                    <rect x={props.x} y={props.y} width={props.width} height={props.height}
                      rx={8} ry={8} fill={BAR_COLORS[idx % BAR_COLORS.length]} />
                  );
                }}
              />
            </BarChart>
          </ResponsiveContainer>
        </motion.div>

        {/* Risk Distribution — horizontal bar */}
        <motion.div variants={item} className="card p-6">
          <div className="flex items-center justify-between mb-5">
            <h3 className="font-semibold text-dash-dark">Risk Distribution</h3>
            <Brain className="w-4 h-4 text-dash-muted" />
          </div>
          <div className="space-y-5 mt-2">
            {riskData.map((r: any) => {
              const total = riskData.reduce((a: number, d: any) => a + d.count, 0) || 1;
              const pct = Math.round((r.count / total) * 100);
              return (
                <div key={r.level}>
                  <div className="flex items-center justify-between mb-2">
                    <div className="flex items-center gap-2">
                      <span className="w-2.5 h-2.5 rounded-full" style={{ backgroundColor: r.color }} />
                      <span className="text-sm font-medium text-dash-dark">{r.level} Risk</span>
                    </div>
                    <div className="flex items-center gap-2">
                      <span className="text-sm font-bold text-dash-dark">{r.count}</span>
                      <span className="text-xs text-dash-muted">({pct}%)</span>
                    </div>
                  </div>
                  <div className="w-full h-3 rounded-full bg-dash-bg overflow-hidden">
                    <motion.div
                      initial={{ width: 0 }}
                      animate={{ width: `${pct}%` }}
                      transition={{ duration: 0.8, delay: 0.2 }}
                      className="h-full rounded-full"
                      style={{ backgroundColor: r.color }}
                    />
                  </div>
                </div>
              );
            })}
          </div>
          <div className="mt-5 pt-4 border-t border-dash-border">
            <div className="flex items-center justify-between">
              <span className="text-xs text-dash-muted">Total Patients Assessed</span>
              <span className="text-sm font-bold text-dash-dark">{riskData.reduce((a: number, d: any) => a + d.count, 0)}</span>
            </div>
          </div>
        </motion.div>

        {/* Pending Diagnostics */}
        <motion.div variants={item} className="card p-6">
          <div className="flex items-center justify-between mb-4">
            <h3 className="font-semibold text-dash-dark">Pending Diagnostics</h3>
            <span className="badge-accent">{diagnostics.length}</span>
          </div>
          {diagnostics.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-8 text-center">
              <ClipboardCheck className="w-8 h-8 text-dash-border mb-2" />
              <p className="text-sm text-dash-muted">No pending diagnostics</p>
              <p className="text-xs text-dash-muted mt-0.5">All caught up!</p>
            </div>
          ) : (
            <div className="space-y-3">
              {diagnostics.slice(0, 5).map((d: any) => (
                <div key={d.id} className="flex items-center gap-3 p-3 rounded-xl bg-dash-bg/50 hover:bg-dash-bg transition-colors">
                  <div className="w-8 h-8 rounded-lg flex items-center justify-center text-white text-xs font-bold"
                    style={{ backgroundColor: BAR_COLORS[['cognitive','speech','motor','gait','facial'].indexOf(d.test_category) % BAR_COLORS.length] || '#8B8FA8' }}>
                    {d.test_category?.[0]?.toUpperCase() || '?'}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium text-dash-dark truncate">{d.patient_name}</p>
                    <p className="text-xs text-dash-muted capitalize">{d.test_category} · {d.completed_at ? new Date(d.completed_at).toLocaleDateString() : 'Pending'}</p>
                  </div>
                  <Link href={`/dashboard/patients/${d.patient_id}`} className="text-xs text-accent-dark font-medium hover:underline flex-shrink-0">
                    Review
                  </Link>
                </div>
              ))}
            </div>
          )}
        </motion.div>
      </div>

      {/* ═══ Recent Patients Table ═══ */}
      <motion.div variants={item} className="card overflow-hidden">
        <div className="flex items-center justify-between px-6 py-4 border-b border-dash-border">
          <div className="flex items-center gap-3">
            <h3 className="font-semibold text-dash-dark">Recent Patients</h3>
            <span className="text-xs text-dash-muted bg-dash-bg px-2 py-0.5 rounded-md">{patients.length}</span>
          </div>
          <Link href="/dashboard/patients" className="text-xs text-accent-dark font-medium hover:underline flex items-center gap-1">
            View All <ChevronRight className="w-3 h-3" />
          </Link>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="bg-gray-50/50">
                <th className="table-header table-cell text-left">Patient</th>
                <th className="table-header table-cell text-left">Risk Level</th>
                <th className="table-header table-cell text-left">AD Risk</th>
                <th className="table-header table-cell text-left">PD Risk</th>
                <th className="table-header table-cell text-left">Last Test</th>
                <th className="table-header table-cell text-right">Action</th>
              </tr>
            </thead>
            <tbody>
              {patients.length === 0 ? (
                <tr>
                  <td colSpan={6} className="py-12 text-center">
                    <Users className="w-8 h-8 text-dash-border mx-auto mb-2" />
                    <p className="text-sm text-dash-muted">No recent patients</p>
                  </td>
                </tr>
              ) : (
                patients.map((p: any) => {
                  const riskLevel = p.risk_level || (Math.max(p.ad_risk_score, p.pd_risk_score) >= 70 ? 'High' : Math.max(p.ad_risk_score, p.pd_risk_score) >= 40 ? 'Moderate' : 'Low');
                  return (
                    <tr key={p.id} className="table-row">
                      <td className="table-cell">
                        <div className="flex items-center gap-3">
                          <div className="w-9 h-9 rounded-full bg-dash-bg text-dash-dark flex items-center justify-center text-xs font-semibold">
                            {p.name.split(' ').filter(Boolean).map((n: string) => n[0]).join('').slice(0, 2)}
                          </div>
                          <div>
                            <span className="font-medium text-dash-dark">{p.name}</span>
                            <p className="text-2xs text-dash-muted">{p.age}y{p.gender ? ` · ${p.gender}` : ''}</p>
                          </div>
                        </div>
                      </td>
                      <td className="table-cell">
                        <span className={`text-xs font-medium px-2.5 py-1 rounded-lg
                          ${riskLevel === 'High' ? 'bg-[#E8637A]/12 text-[#E8637A]' :
                            riskLevel === 'Moderate' ? 'bg-[#F5A623]/12 text-[#F5A623]' :
                            'bg-[#2AC9A0]/12 text-[#2AC9A0]'}`}>
                          {riskLevel}
                        </span>
                      </td>
                      <td className="table-cell">
                        <div className="flex items-center gap-2">
                          <div className="w-14 h-1.5 rounded-full bg-dash-bg">
                            <div className="h-full rounded-full transition-all"
                              style={{
                                width: `${Math.min(p.ad_risk_score, 100)}%`,
                                backgroundColor: p.ad_risk_score >= 70 ? '#E8637A' : p.ad_risk_score >= 40 ? '#F5A623' : '#2AC9A0',
                              }} />
                          </div>
                          <span className="text-xs font-semibold text-dash-dark">{p.ad_risk_score}%</span>
                        </div>
                      </td>
                      <td className="table-cell">
                        <div className="flex items-center gap-2">
                          <div className="w-14 h-1.5 rounded-full bg-dash-bg">
                            <div className="h-full rounded-full transition-all"
                              style={{
                                width: `${Math.min(p.pd_risk_score, 100)}%`,
                                backgroundColor: p.pd_risk_score >= 70 ? '#E8637A' : p.pd_risk_score >= 40 ? '#F5A623' : '#2AC9A0',
                              }} />
                          </div>
                          <span className="text-xs font-semibold text-dash-dark">{p.pd_risk_score}%</span>
                        </div>
                      </td>
                      <td className="table-cell text-dash-muted text-xs">
                        {p.last_test_category ? (
                          <span className="capitalize">{p.last_test_category}</span>
                        ) : (
                          <span className="text-dash-border">—</span>
                        )}
                      </td>
                      <td className="table-cell text-right">
                        <Link href={`/dashboard/patients/${p.id}`}
                          className="text-dash-muted hover:text-accent-dark text-xs font-medium transition-colors">
                          View Details
                        </Link>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
        {patients.length > 0 && (
          <div className="px-6 py-3 border-t border-dash-border flex items-center justify-between">
            <p className="text-xs text-dash-muted">Showing {patients.length} recent patients</p>
            <Link href="/dashboard/patients" className="text-xs text-accent-dark font-medium hover:underline flex items-center gap-1">
              View All <ChevronRight className="w-3 h-3" />
            </Link>
          </div>
        )}
      </motion.div>
    </motion.div>
  );
}

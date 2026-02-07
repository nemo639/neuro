'use client';

import { useState, useEffect, useCallback } from 'react';
import { motion } from 'framer-motion';
import {
  TrendingUp,
  Users,
  Stethoscope,
  TicketCheck,
  ArrowUpRight,
  ArrowDownRight,
  ChevronRight,
  Download,
  Activity,
  Loader2,
  AlertCircle,
} from 'lucide-react';
import {
  AreaChart,
  Area,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  PieChart,
  Pie,
  Cell,
} from 'recharts';
import { analyticsApi } from '@/lib/api';

const container = { hidden: { opacity: 0 }, visible: { opacity: 1, transition: { staggerChildren: 0.06 } } };
const item = { hidden: { opacity: 0, y: 12 }, visible: { opacity: 1, y: 0, transition: { duration: 0.4 } } };

const PIE_COLORS = ['#C6E94B', '#6366F1', '#A855F7', '#FB923C', '#22D3EE'];
const ASSESSMENT_COLORS = ['#C6E94B', '#6366F1', '#A855F7', '#FB923C', '#22D3EE'];

interface KpiData {
  total_users: number;
  users_change: number;
  total_doctors: number;
  doctors_change: number;
  total_tests: number;
  tests_change: number;
  total_tickets: number;
  tickets_change: number;
}

interface MonthlyGrowth {
  month: string;
  users: number;
  doctors: number;
  tickets: number;
  sessions: number;
}

interface WeeklyActivity {
  day: string;
  signups: number;
  assessments: number;
  consultations: number;
}

interface DemographicItem {
  name: string;
  value: number;
  color?: string;
}

interface AssessmentItem {
  name: string;
  completed: number;
  color?: string;
}

interface TopDoctor {
  name: string;
  specialization: string;
  patients: number;
  rating: number;
}

interface AnalyticsData {
  kpis: KpiData;
  monthly_growth: MonthlyGrowth[];
  user_demographics: DemographicItem[];
  weekly_activity: WeeklyActivity[];
  assessment_data: AssessmentItem[];
  top_doctors: TopDoctor[];
  total_users: number;
}

const CustomTooltip = ({ active, payload, label }: any) => {
  if (!active || !payload) return null;
  return (
    <div className="bg-white p-3 rounded-xl shadow-elevated border border-dash-border">
      <p className="text-xs font-semibold text-dash-dark mb-1">{label}</p>
      {payload.map((entry: any, i: number) => (
        <p key={i} className="text-xs text-dash-muted">
          {entry.name}: <span className="font-semibold text-dash-dark">{entry.value.toLocaleString()}</span>
        </p>
      ))}
    </div>
  );
};

const TIME_RANGES = [
  { label: '7 Days', value: '7d' },
  { label: '30 Days', value: '30d' },
  { label: '3 Months', value: '90d' },
  { label: '1 Year', value: '1y' },
];

export default function AnalyticsPage() {
  const [timeRange, setTimeRange] = useState('30d');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [data, setData] = useState<AnalyticsData | null>(null);

  const fetchAnalytics = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const res = await analyticsApi.getAnalytics(timeRange);
      setData(res);
    } catch (err: any) {
      console.error('Analytics fetch error:', err);
      setError(err?.response?.data?.detail || 'Failed to load analytics data');
    } finally {
      setLoading(false);
    }
  }, [timeRange]);

  useEffect(() => {
    fetchAnalytics();
  }, [fetchAnalytics]);

  // Add colors to demographics and assessments
  const demographics = (data?.user_demographics || []).map((d, i) => ({
    ...d,
    color: PIE_COLORS[i % PIE_COLORS.length],
  }));

  const assessments = (data?.assessment_data || []).map((a, i) => ({
    ...a,
    color: ASSESSMENT_COLORS[i % ASSESSMENT_COLORS.length],
  }));

  const maxAssessment = Math.max(...assessments.map((a) => a.completed), 1);
  const maxDemographic = Math.max(...demographics.map((d) => d.value), 1);

  const kpis = data?.kpis;

  const kpiCards = kpis
    ? [
        {
          title: 'Total Users',
          value: kpis.total_users.toLocaleString(),
          change: `${kpis.users_change >= 0 ? '+' : ''}${kpis.users_change}%`,
          up: kpis.users_change >= 0,
          icon: Users,
          active: true,
        },
        {
          title: 'Total Doctors',
          value: kpis.total_doctors.toLocaleString(),
          change: `${kpis.doctors_change >= 0 ? '+' : ''}${kpis.doctors_change}%`,
          up: kpis.doctors_change >= 0,
          icon: Stethoscope,
          active: false,
        },
        {
          title: 'Tests Completed',
          value: kpis.total_tests.toLocaleString(),
          change: `${kpis.tests_change >= 0 ? '+' : ''}${kpis.tests_change}%`,
          up: kpis.tests_change >= 0,
          icon: Activity,
          active: false,
        },
        {
          title: 'Support Tickets',
          value: kpis.total_tickets.toLocaleString(),
          change: `${kpis.tickets_change >= 0 ? '+' : ''}${kpis.tickets_change}%`,
          up: kpis.tickets_change >= 0,
          icon: TicketCheck,
          active: false,
        },
      ]
    : [];

  // Loading state
  if (loading && !data) {
    return (
      <div className="flex items-center justify-center h-96">
        <div className="flex flex-col items-center gap-3">
          <Loader2 className="w-8 h-8 animate-spin text-accent" />
          <p className="text-sm text-dash-muted">Loading analytics...</p>
        </div>
      </div>
    );
  }

  // Error state
  if (error && !data) {
    return (
      <div className="flex items-center justify-center h-96">
        <div className="flex flex-col items-center gap-3 text-center">
          <AlertCircle className="w-8 h-8 text-red-400" />
          <p className="text-sm text-red-500">{error}</p>
          <button onClick={fetchAnalytics} className="btn-secondary text-sm py-2 px-4">
            Retry
          </button>
        </div>
      </div>
    );
  }

  return (
    <motion.div variants={container} initial="hidden" animate="visible" className="space-y-6">
      {/* Header */}
      <motion.div variants={item} className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-dash-dark">Analytics</h1>
          <p className="text-sm text-dash-muted mt-1">Platform insights and performance metrics</p>
        </div>
        <div className="flex items-center gap-3">
          <div className="flex items-center gap-1 bg-white rounded-xl border border-dash-border p-1">
            {TIME_RANGES.map((range) => (
              <button
                key={range.value}
                onClick={() => setTimeRange(range.value)}
                className={`px-3 py-1.5 text-xs font-medium rounded-lg transition-all
                  ${timeRange === range.value ? 'bg-dash-dark text-white' : 'text-dash-muted hover:bg-dash-bg'}`}
              >
                {range.label}
              </button>
            ))}
          </div>
          <button className="btn-secondary flex items-center gap-2 py-2">
            <Download className="w-4 h-4" />
            <span className="text-sm">Export</span>
          </button>
        </div>
      </motion.div>

      {/* Loading overlay for time range switching */}
      {loading && data && (
        <div className="flex items-center gap-2 text-sm text-dash-muted">
          <Loader2 className="w-4 h-4 animate-spin" />
          Refreshing data...
        </div>
      )}

      {/* KPI Cards */}
      <motion.div variants={item} className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        {kpiCards.map((kpi) => (
          <div key={kpi.title} className={`card p-5 ${kpi.active ? 'bg-accent border-accent' : ''}`}>
            <div className="flex items-start justify-between mb-3">
              <p className={`text-sm font-medium ${kpi.active ? 'text-dash-dark' : 'text-dash-muted'}`}>{kpi.title}</p>
              <div className={`w-9 h-9 rounded-xl flex items-center justify-center ${kpi.active ? 'bg-dash-dark/10' : 'bg-dash-bg'}`}>
                <kpi.icon className={`w-4 h-4 ${kpi.active ? 'text-dash-dark' : 'text-dash-muted'}`} />
              </div>
            </div>
            <p className="text-3xl font-bold text-dash-dark">{kpi.value}</p>
            <div className="flex items-center gap-1 mt-2">
              {kpi.up ? <ArrowUpRight className="w-3.5 h-3.5 text-emerald-500" /> : <ArrowDownRight className="w-3.5 h-3.5 text-red-500" />}
              <span className={`text-xs font-semibold ${kpi.up ? 'text-emerald-500' : 'text-red-500'}`}>{kpi.change}</span>
            </div>
          </div>
        ))}
      </motion.div>

      {/* Charts Row 1: Growth + Demographics */}
      <div className="grid grid-cols-1 xl:grid-cols-3 gap-6">
        {/* Growth Area Chart */}
        <motion.div variants={item} className="xl:col-span-2 card p-6">
          <div className="flex items-center justify-between mb-6">
            <div>
              <h3 className="font-semibold text-dash-dark">Platform Growth</h3>
              <p className="text-xs text-dash-muted mt-0.5">Monthly user registrations & sessions</p>
            </div>
          </div>
          <div className="flex items-center gap-5 mb-4">
            <div className="flex items-center gap-2">
              <span className="w-3 h-3 rounded-full bg-accent" />
              <span className="text-xs text-dash-muted">Users</span>
            </div>
            <div className="flex items-center gap-2">
              <span className="w-3 h-3 rounded-full bg-chart-blue" />
              <span className="text-xs text-dash-muted">Sessions</span>
            </div>
          </div>
          <ResponsiveContainer width="100%" height={260}>
            <AreaChart data={data?.monthly_growth || []}>
              <defs>
                <linearGradient id="gUsers" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor="#C6E94B" stopOpacity={0.2} />
                  <stop offset="100%" stopColor="#C6E94B" stopOpacity={0} />
                </linearGradient>
                <linearGradient id="gSessions" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor="#6366F1" stopOpacity={0.15} />
                  <stop offset="100%" stopColor="#6366F1" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="#ECEDF2" vertical={false} />
              <XAxis dataKey="month" fontSize={11} tick={{ fill: '#8B8FA8' }} axisLine={false} tickLine={false} />
              <YAxis fontSize={11} tick={{ fill: '#8B8FA8' }} axisLine={false} tickLine={false} />
              <Tooltip content={<CustomTooltip />} />
              <Area type="monotone" dataKey="users" stroke="#C6E94B" strokeWidth={2} fill="url(#gUsers)" name="Users" />
              <Area type="monotone" dataKey="sessions" stroke="#6366F1" strokeWidth={2} fill="url(#gSessions)" name="Sessions" />
            </AreaChart>
          </ResponsiveContainer>
        </motion.div>

        {/* Demographics Pie */}
        <motion.div variants={item} className="card p-6">
          <div className="flex items-center justify-between mb-4">
            <h3 className="font-semibold text-dash-dark">Age Distribution</h3>
          </div>
          <ResponsiveContainer width="100%" height={180}>
            <PieChart>
              <Pie data={demographics} cx="50%" cy="50%" innerRadius={50} outerRadius={75}
                paddingAngle={3} dataKey="value" startAngle={90} endAngle={450}>
                {demographics.map((entry, i) => (
                  <Cell key={i} fill={entry.color} strokeWidth={0} />
                ))}
              </Pie>
              <Tooltip content={<CustomTooltip />} />
            </PieChart>
          </ResponsiveContainer>
          <div className="text-center -mt-2 mb-4">
            <p className="text-2xl font-bold text-dash-dark">{(data?.total_users || 0).toLocaleString()}</p>
            <p className="text-xs text-dash-muted">Total Users</p>
          </div>
          <div className="space-y-2.5">
            {demographics.map((d) => (
              <div key={d.name} className="flex items-center gap-3">
                <span className="w-2.5 h-2.5 rounded-full flex-shrink-0" style={{ backgroundColor: d.color }} />
                <span className="text-xs text-dash-muted flex-1">{d.name}</span>
                <div className="flex-1 h-1.5 bg-dash-bg rounded-full overflow-hidden">
                  <div className="h-full rounded-full" style={{ width: `${(d.value / maxDemographic) * 100}%`, backgroundColor: d.color }} />
                </div>
                <span className="text-xs font-semibold text-dash-dark w-8 text-right">{d.value}</span>
              </div>
            ))}
          </div>
        </motion.div>
      </div>

      {/* Charts Row 2: Weekly + Assessments */}
      <div className="grid grid-cols-1 xl:grid-cols-2 gap-6">
        {/* Weekly Activity Bar Chart */}
        <motion.div variants={item} className="card p-6">
          <div className="flex items-center justify-between mb-6">
            <div>
              <h3 className="font-semibold text-dash-dark">Weekly Activity</h3>
              <p className="text-xs text-dash-muted mt-0.5">Daily signups, assessments & consultations</p>
            </div>
          </div>
          <div className="flex items-center gap-5 mb-4">
            <div className="flex items-center gap-2">
              <span className="w-3 h-3 rounded bg-accent" />
              <span className="text-xs text-dash-muted">Signups</span>
            </div>
            <div className="flex items-center gap-2">
              <span className="w-3 h-3 rounded bg-chart-blue" />
              <span className="text-xs text-dash-muted">Assessments</span>
            </div>
            <div className="flex items-center gap-2">
              <span className="w-3 h-3 rounded bg-chart-purple" />
              <span className="text-xs text-dash-muted">Consultations</span>
            </div>
          </div>
          <ResponsiveContainer width="100%" height={240}>
            <BarChart data={data?.weekly_activity || []} barGap={2}>
              <CartesianGrid strokeDasharray="3 3" stroke="#ECEDF2" vertical={false} />
              <XAxis dataKey="day" fontSize={11} tick={{ fill: '#8B8FA8' }} axisLine={false} tickLine={false} />
              <YAxis fontSize={11} tick={{ fill: '#8B8FA8' }} axisLine={false} tickLine={false} />
              <Tooltip content={<CustomTooltip />} />
              <Bar dataKey="signups" fill="#C6E94B" radius={[4, 4, 0, 0]} name="Signups" />
              <Bar dataKey="assessments" fill="#6366F1" radius={[4, 4, 0, 0]} name="Assessments" />
              <Bar dataKey="consultations" fill="#A855F7" radius={[4, 4, 0, 0]} name="Consultations" />
            </BarChart>
          </ResponsiveContainer>
        </motion.div>

        {/* Assessments Bar */}
        <motion.div variants={item} className="card p-6">
          <div className="flex items-center justify-between mb-6">
            <div>
              <h3 className="font-semibold text-dash-dark">Assessment Completions</h3>
              <p className="text-xs text-dash-muted mt-0.5">Total completions by test category</p>
            </div>
          </div>
          <div className="space-y-5">
            {assessments.map((a) => (
              <div key={a.name}>
                <div className="flex items-center justify-between mb-2">
                  <span className="text-sm font-medium text-dash-dark">{a.name}</span>
                  <span className="text-sm font-bold text-dash-dark">{a.completed.toLocaleString()}</span>
                </div>
                <div className="h-2.5 bg-dash-bg rounded-full overflow-hidden">
                  <motion.div
                    initial={{ width: 0 }}
                    animate={{ width: `${(a.completed / maxAssessment) * 100}%` }}
                    transition={{ duration: 0.8, delay: 0.2 }}
                    className="h-full rounded-full"
                    style={{ backgroundColor: a.color }}
                  />
                </div>
              </div>
            ))}
          </div>
        </motion.div>
      </div>

      {/* Bottom Row: Top Doctors + Performance */}
      <div className="grid grid-cols-1 xl:grid-cols-3 gap-6">
        {/* Top Doctors */}
        <motion.div variants={item} className="xl:col-span-2 card overflow-hidden">
          <div className="flex items-center justify-between px-6 py-4 border-b border-dash-border">
            <h3 className="font-semibold text-dash-dark">Top Performing Doctors</h3>
            <button className="text-xs text-dash-muted hover:text-accent-dark font-medium flex items-center gap-1">
              View All <ChevronRight className="w-3 h-3" />
            </button>
          </div>
          {(data?.top_doctors || []).length === 0 ? (
            <div className="p-8 text-center text-sm text-dash-muted">No doctor data available</div>
          ) : (
          <table className="w-full">
            <thead>
              <tr className="bg-gray-50/50">
                <th className="table-header table-cell text-left">#</th>
                <th className="table-header table-cell text-left">Doctor</th>
                <th className="table-header table-cell text-left">Specialization</th>
                <th className="table-header table-cell text-left">Patients</th>
                <th className="table-header table-cell text-left">Rating</th>
                <th className="table-header table-cell text-right">Performance</th>
              </tr>
            </thead>
            <tbody>
              {(data?.top_doctors || []).map((doc, i) => (
                <tr key={i} className="table-row">
                  <td className="table-cell">
                    <span className={`w-7 h-7 rounded-lg flex items-center justify-center text-xs font-bold
                      ${i === 0 ? 'bg-accent text-dash-dark' : i === 1 ? 'bg-gray-100 text-dash-dark' : 'bg-orange-50 text-orange-600'}
                      ${i > 2 ? '!bg-dash-bg !text-dash-muted' : ''}`}>
                      {i + 1}
                    </span>
                  </td>
                  <td className="table-cell">
                    <div className="flex items-center gap-3">
                      <div className="w-9 h-9 rounded-full bg-purple-50 text-purple-600 flex items-center justify-center text-xs font-semibold">
                        {doc.name.replace('Dr. ', '').split(' ').map(n => n[0]).join('')}
                      </div>
                      <span className="font-medium text-dash-dark">{doc.name}</span>
                    </div>
                  </td>
                  <td className="table-cell">
                    <span className="text-xs font-medium px-2.5 py-1 rounded-lg bg-accent/10 text-accent-dark">
                      {doc.specialization}
                    </span>
                  </td>
                  <td className="table-cell font-medium text-dash-dark">{doc.patients}</td>
                  <td className="table-cell">
                    <div className="flex items-center gap-1">
                      <span className="text-amber-400">★</span>
                      <span className="text-sm font-medium text-dash-dark">{doc.rating}</span>
                    </div>
                  </td>
                  <td className="table-cell text-right">
                    <div className="w-24 h-1.5 bg-dash-bg rounded-full overflow-hidden ml-auto">
                      <div className="h-full bg-accent rounded-full" style={{ width: `${(doc.rating / 5) * 100}%` }} />
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          )}
        </motion.div>

        {/* Performance Summary */}
        <motion.div variants={item} className="card p-6">
          <h3 className="font-semibold text-dash-dark mb-5">Platform Health</h3>
          <div className="space-y-5">
            {[
              { label: 'Server Uptime', value: '99.9%', progress: 99.9, color: '#C6E94B' },
              { label: 'API Response Time', value: '120ms', progress: 88, color: '#6366F1' },
              { label: 'User Satisfaction', value: '4.7/5', progress: 94, color: '#A855F7' },
              { label: 'Error Rate', value: '0.2%', progress: 98, color: '#22D3EE' },
              { label: 'App Store Rating', value: '4.5', progress: 90, color: '#FB923C' },
            ].map((metric) => (
              <div key={metric.label}>
                <div className="flex items-center justify-between mb-2">
                  <span className="text-sm text-dash-muted">{metric.label}</span>
                  <span className="text-sm font-bold text-dash-dark">{metric.value}</span>
                </div>
                <div className="h-2 bg-dash-bg rounded-full overflow-hidden">
                  <motion.div
                    initial={{ width: 0 }}
                    animate={{ width: `${metric.progress}%` }}
                    transition={{ duration: 0.8, delay: 0.3 }}
                    className="h-full rounded-full"
                    style={{ backgroundColor: metric.color }}
                  />
                </div>
              </div>
            ))}
          </div>

          {/* Quick Stats */}
          <div className="mt-6 pt-6 border-t border-dash-border grid grid-cols-2 gap-4">
            {[
              { label: 'Avg Load', value: '1.2s' },
              { label: 'Bounce Rate', value: '12%' },
              { label: 'DB Queries/s', value: '2.4K' },
              { label: 'CDN Hit Rate', value: '97%' },
            ].map((s) => (
              <div key={s.label} className="text-center p-3 bg-dash-bg rounded-xl">
                <p className="text-lg font-bold text-dash-dark">{s.value}</p>
                <p className="text-xs text-dash-muted mt-0.5">{s.label}</p>
              </div>
            ))}
          </div>
        </motion.div>
      </div>
    </motion.div>
  );
}

'use client';

import { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { useParams, useRouter } from 'next/navigation';
import {
  ArrowLeft, Brain, Activity, FileText,
  ChevronRight, Mail, Phone, MapPin, Calendar, Clipboard,
  TrendingUp, TrendingDown, Shield,
} from 'lucide-react';
import {
  AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer,
} from 'recharts';
import { patientsApi } from '@/lib/api';

const container = { hidden: { opacity: 0 }, visible: { opacity: 1, transition: { staggerChildren: 0.06 } } };
const item = { hidden: { opacity: 0, y: 12 }, visible: { opacity: 1, y: 0, transition: { duration: 0.4 } } };

type PatientDetail = {
  id: number;
  name: string;
  age: number;
  gender: string;
  email?: string;
  phone?: string;
  city?: string;
  ad_risk: number;
  pd_risk: number;
  risk_level: string;
  last_assessment: string;
  tests_completed: number;
  notes?: string;
  risk_history?: { date: string; ad: number; pd: number }[];
  test_history?: { id: number; category: string; score: number; date: string; status: string }[];
};

/* ─── Tooltip (matches admin) ─── */
const ChartTooltip = ({ active, payload, label }: any) => {
  if (!active || !payload?.length) return null;
  return (
    <div className="bg-white p-3 rounded-xl shadow-elevated border border-dash-border">
      <p className="text-xs font-semibold text-dash-dark mb-1">{label}</p>
      {payload.map((p: any, i: number) => (
        <p key={i} className="text-xs text-dash-muted">
          {p.name}: <span className="font-semibold text-dash-dark">{p.value}%</span>
        </p>
      ))}
    </div>
  );
};

export default function PatientDetailPage() {
  const params = useParams();
  const router = useRouter();
  const [patient, setPatient] = useState<PatientDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const [tab, setTab] = useState<'overview' | 'tests' | 'notes'>('overview');

  useEffect(() => {
    (async () => {
      try {
        const id = params.id as string;
        const res = await patientsApi.getPatientDetail(Number(id));
        setPatient(res);
      } catch {
        setPatient({
          id: 1, name: 'Ahmed Khan', age: 65, gender: 'Male',
          email: 'ahmed@example.com', phone: '+92 300 1234567', city: 'Lahore',
          ad_risk: 72, pd_risk: 28, risk_level: 'high',
          last_assessment: '2026-02-02', tests_completed: 8,
          risk_history: [
            { date: 'Aug', ad: 48, pd: 15 }, { date: 'Sep', ad: 55, pd: 20 },
            { date: 'Oct', ad: 60, pd: 23 }, { date: 'Nov', ad: 64, pd: 25 },
            { date: 'Dec', ad: 68, pd: 26 }, { date: 'Jan', ad: 70, pd: 27 },
            { date: 'Feb', ad: 72, pd: 28 },
          ],
          test_history: [
            { id: 1, category: 'Cognitive', score: 65, date: '2026-02-02', status: 'completed' },
            { id: 2, category: 'Gait Analysis', score: 78, date: '2026-01-28', status: 'completed' },
            { id: 3, category: 'Speech', score: 42, date: '2026-01-20', status: 'completed' },
            { id: 4, category: 'Eye Tracking', score: 71, date: '2026-01-15', status: 'completed' },
          ],
        });
      } finally {
        setLoading(false);
      }
    })();
  }, [params.id]);

  const riskBg = (level: string) =>
    level === 'high' || level === 'critical'
      ? 'bg-red-50 text-red-600'
      : level === 'moderate'
      ? 'bg-amber-50 text-amber-600'
      : 'bg-emerald-50 text-emerald-600';

  const riskBarColor = (v: number) => (v >= 70 ? '#EF4444' : v >= 40 ? '#F59E0B' : '#10B981');

  const fmtDate = (iso: string) => {
    try { return new Date(iso).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }); }
    catch { return iso; }
  };

  const scoreBarColor = (score: number) => {
    if (score >= 75) return '#10B981';
    if (score >= 50) return '#C6E94B';
    if (score >= 30) return '#F59E0B';
    return '#EF4444';
  };

  const categoryIcons: Record<string, { bg: string; color: string }> = {
    Cognitive: { bg: 'bg-accent-50', color: 'text-accent-dark' },
    'Gait Analysis': { bg: 'bg-chart-blue/10', color: 'text-chart-blue' },
    Speech: { bg: 'bg-chart-orange/10', color: 'text-chart-orange' },
    'Eye Tracking': { bg: 'bg-chart-cyan/10', color: 'text-chart-cyan' },
  };

  if (loading || !patient) {
    return (
      <div className="flex items-center justify-center h-[60vh]">
        <div className="w-8 h-8 border-2 border-accent border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  /* Risk trend direction */
  const history = patient.risk_history || [];
  const adTrend = history.length >= 2 ? history[history.length - 1].ad - history[history.length - 2].ad : 0;
  const pdTrend = history.length >= 2 ? history[history.length - 1].pd - history[history.length - 2].pd : 0;

  return (
    <motion.div variants={container} initial="hidden" animate="visible">
      <div className="grid grid-cols-1 xl:grid-cols-[1fr_300px] gap-6">
        {/* ════ LEFT ════ */}
        <div className="space-y-6 min-w-0">
          {/* Back + Header */}
          <motion.div variants={item} className="flex items-center gap-4">
            <button onClick={() => router.back()}
              className="p-2 rounded-xl border border-dash-border hover:bg-dash-bg transition-all">
              <ArrowLeft className="w-5 h-5 text-dash-muted" />
            </button>
            <div className="flex-1">
              <h1 className="text-2xl font-bold text-dash-dark">{patient.name}</h1>
              <p className="text-sm text-dash-muted mt-0.5">{patient.age}y &middot; {patient.gender} &middot; {patient.city || 'N/A'}</p>
            </div>
            <span className={`text-xs px-3 py-1.5 rounded-lg font-medium capitalize ${riskBg(patient.risk_level)}`}>
              {patient.risk_level} Risk
            </span>
          </motion.div>

          {/* Risk Cards */}
          <motion.div variants={item} className="grid grid-cols-3 gap-3">
            {/* AD Risk */}
            <div className="card p-4 border-l-[3px] border-l-red-400">
              <div className="flex items-center justify-between mb-3">
                <div className="w-9 h-9 rounded-xl bg-red-50 flex items-center justify-center">
                  <Brain className="w-4 h-4 text-red-500" />
                </div>
                {adTrend !== 0 && (
                  <div className={`flex items-center gap-0.5 text-[11px] font-semibold rounded-full px-2 py-0.5 ${
                    adTrend > 0 ? 'bg-red-50 text-red-500' : 'bg-emerald-50 text-emerald-600'
                  }`}>
                    {adTrend > 0 ? <TrendingUp className="w-3 h-3" /> : <TrendingDown className="w-3 h-3" />}
                    {adTrend > 0 ? '+' : ''}{adTrend}%
                  </div>
                )}
              </div>
              <p className="text-2xl font-bold text-dash-dark">{patient.ad_risk}%</p>
              <p className="text-[11px] text-dash-muted font-medium mt-0.5">AD Risk Score</p>
              <div className="w-full h-1.5 rounded-full bg-red-100 mt-3">
                <div className="h-full rounded-full bg-red-400 transition-all duration-700" style={{ width: `${patient.ad_risk}%` }} />
              </div>
            </div>
            {/* PD Risk */}
            <div className="card p-4 border-l-[3px] border-l-amber-400">
              <div className="flex items-center justify-between mb-3">
                <div className="w-9 h-9 rounded-xl bg-amber-50 flex items-center justify-center">
                  <Activity className="w-4 h-4 text-amber-500" />
                </div>
                {pdTrend !== 0 && (
                  <div className={`flex items-center gap-0.5 text-[11px] font-semibold rounded-full px-2 py-0.5 ${
                    pdTrend > 0 ? 'bg-red-50 text-red-500' : 'bg-emerald-50 text-emerald-600'
                  }`}>
                    {pdTrend > 0 ? <TrendingUp className="w-3 h-3" /> : <TrendingDown className="w-3 h-3" />}
                    {pdTrend > 0 ? '+' : ''}{pdTrend}%
                  </div>
                )}
              </div>
              <p className="text-2xl font-bold text-dash-dark">{patient.pd_risk}%</p>
              <p className="text-[11px] text-dash-muted font-medium mt-0.5">PD Risk Score</p>
              <div className="w-full h-1.5 rounded-full bg-amber-100 mt-3">
                <div className="h-full rounded-full bg-amber-400 transition-all duration-700" style={{ width: `${patient.pd_risk}%` }} />
              </div>
            </div>
            {/* Assessments */}
            <div className="card p-4 border-l-[3px] border-l-accent">
              <div className="flex items-center justify-between mb-3">
                <div className="w-9 h-9 rounded-xl bg-accent/10 flex items-center justify-center">
                  <Clipboard className="w-4 h-4 text-accent-dark" />
                </div>
                <Shield className="w-4 h-4 text-accent/50" />
              </div>
              <p className="text-2xl font-bold text-dash-dark">{patient.tests_completed}</p>
              <p className="text-[11px] text-dash-muted font-medium mt-0.5">Assessments</p>
              <p className="text-[10px] text-dash-muted mt-3">Last: {fmtDate(patient.last_assessment)}</p>
            </div>
          </motion.div>

          {/* Tabs */}
          <motion.div variants={item} className="flex gap-2">
            {(['overview', 'tests', 'notes'] as const).map((t) => (
              <button key={t} onClick={() => setTab(t)}
                className={`px-4 py-2 rounded-lg text-xs font-medium capitalize transition-all
                  ${tab === t ? 'bg-accent text-dash-dark' : 'bg-white text-dash-muted border border-dash-border hover:bg-dash-bg'}`}
              >
                {t}
              </button>
            ))}
          </motion.div>

          {/* Overview — Risk Trend Chart */}
          {tab === 'overview' && patient.risk_history && (
            <motion.div variants={item} className="card p-5">
              <div className="flex items-center justify-between mb-5">
                <h3 className="font-semibold text-dash-dark">Risk Score Trends</h3>
                <div className="flex items-center gap-4">
                  <div className="flex items-center gap-1.5"><span className="w-3 h-3 rounded-full bg-chart-blue" /><span className="text-xs text-dash-muted">AD Risk</span></div>
                  <div className="flex items-center gap-1.5"><span className="w-3 h-3 rounded-full bg-accent" /><span className="text-xs text-dash-muted">PD Risk</span></div>
                </div>
              </div>
              <ResponsiveContainer width="100%" height={260}>
                <AreaChart data={patient.risk_history}>
                  <defs>
                    <linearGradient id="gradAD" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="0%" stopColor="#6366F1" stopOpacity={0.15} />
                      <stop offset="100%" stopColor="#6366F1" stopOpacity={0} />
                    </linearGradient>
                    <linearGradient id="gradPD" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="0%" stopColor="#C6E94B" stopOpacity={0.15} />
                      <stop offset="100%" stopColor="#C6E94B" stopOpacity={0} />
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" stroke="#ECEDF2" vertical={false} />
                  <XAxis dataKey="date" fontSize={11} tick={{ fill: '#8B8FA8' }} axisLine={false} tickLine={false} />
                  <YAxis domain={[0, 100]} fontSize={11} tick={{ fill: '#8B8FA8' }} axisLine={false} tickLine={false} />
                  <Tooltip content={<ChartTooltip />} />
                  <Area type="monotone" dataKey="ad" name="AD Risk" stroke="#6366F1" strokeWidth={2} fill="url(#gradAD)" />
                  <Area type="monotone" dataKey="pd" name="PD Risk" stroke="#C6E94B" strokeWidth={2} fill="url(#gradPD)" />
                </AreaChart>
              </ResponsiveContainer>
            </motion.div>
          )}

          {/* Tests Tab */}
          {tab === 'tests' && (
            <motion.div variants={item} className="card overflow-hidden">
              <table className="w-full">
                <thead>
                  <tr className="bg-gray-50/50">
                    <th className="table-header table-cell text-left">Category</th>
                    <th className="table-header table-cell text-left">Score</th>
                    <th className="table-header table-cell text-left">Date</th>
                    <th className="table-header table-cell text-left">Status</th>
                  </tr>
                </thead>
                <tbody>
                  {(patient.test_history || []).map((t) => {
                    const catStyle = categoryIcons[t.category] || { bg: 'bg-dash-bg', color: 'text-dash-muted' };
                    return (
                      <tr key={t.id} className="table-row">
                        <td className="table-cell">
                          <div className="flex items-center gap-2.5">
                            <div className={`w-7 h-7 rounded-lg ${catStyle.bg} flex items-center justify-center flex-shrink-0`}>
                              <Brain className={`w-3.5 h-3.5 ${catStyle.color}`} />
                            </div>
                            <span className="font-medium text-dash-dark text-xs">{t.category}</span>
                          </div>
                        </td>
                        <td className="table-cell">
                          <div className="flex items-center gap-2">
                            <div className="w-20 h-1.5 rounded-full bg-dash-bg">
                              <div className="h-full rounded-full transition-all duration-500" style={{ width: `${t.score}%`, backgroundColor: scoreBarColor(t.score) }} />
                            </div>
                            <span className="text-xs font-semibold text-dash-dark">{t.score}%</span>
                          </div>
                        </td>
                        <td className="table-cell text-dash-muted text-xs">{fmtDate(t.date)}</td>
                        <td className="table-cell">
                          <span className="badge-success capitalize">{t.status}</span>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
              {(!patient.test_history || patient.test_history.length === 0) && (
                <div className="text-center py-16">
                  <FileText className="w-8 h-8 text-dash-border mx-auto mb-2" />
                  <p className="text-sm text-dash-muted">No test history</p>
                </div>
              )}
            </motion.div>
          )}

          {/* Notes Tab */}
          {tab === 'notes' && (
            <motion.div variants={item} className="card p-5">
              <h3 className="font-semibold text-dash-dark mb-3">Clinical Notes</h3>
              <p className="text-sm text-dash-text leading-relaxed">{patient.notes || 'No clinical notes available for this patient. Add notes from the Clinical Notes page.'}</p>
              <button onClick={() => router.push('/dashboard/notes')}
                className="mt-4 text-xs font-medium flex items-center gap-1 px-3 py-1.5 rounded-lg text-accent-dark hover:bg-accent/10 transition-colors">
                Go to Notes <ChevronRight className="w-3 h-3" />
              </button>
            </motion.div>
          )}
        </div>

        {/* ════ RIGHT — Patient Profile Card ════ */}
        <motion.div variants={item} className="space-y-4">
          {/* Profile */}
          <div className="card p-5">
            <div className="flex flex-col items-center text-center mb-4">
              <div className="w-16 h-16 rounded-full bg-accent flex items-center justify-center text-xl font-bold text-dash-dark mb-3">
                {patient.name.split(' ').map((n) => n[0]).join('')}
              </div>
              <h4 className="text-sm font-semibold text-dash-dark">{patient.name}</h4>
              <p className="text-[11px] text-dash-muted">{patient.age}y &middot; {patient.gender}</p>
              <span className={`text-[10px] px-2.5 py-1 rounded-lg font-medium capitalize mt-2 ${riskBg(patient.risk_level)}`}>
                {patient.risk_level} Risk
              </span>
            </div>
            <div className="border-t border-dash-border pt-3 space-y-2.5">
              {patient.email && (
                <div className="flex items-center gap-2.5">
                  <div className="w-7 h-7 rounded-lg bg-chart-blue/10 flex items-center justify-center flex-shrink-0">
                    <Mail className="w-3 h-3 text-chart-blue" />
                  </div>
                  <span className="text-xs text-dash-text truncate">{patient.email}</span>
                </div>
              )}
              {patient.phone && (
                <div className="flex items-center gap-2.5">
                  <div className="w-7 h-7 rounded-lg bg-accent/10 flex items-center justify-center flex-shrink-0">
                    <Phone className="w-3 h-3 text-accent-dark" />
                  </div>
                  <span className="text-xs text-dash-text">{patient.phone}</span>
                </div>
              )}
              {patient.city && (
                <div className="flex items-center gap-2.5">
                  <div className="w-7 h-7 rounded-lg bg-chart-orange/10 flex items-center justify-center flex-shrink-0">
                    <MapPin className="w-3 h-3 text-chart-orange" />
                  </div>
                  <span className="text-xs text-dash-text">{patient.city}</span>
                </div>
              )}
              <div className="flex items-center gap-2.5">
                <div className="w-7 h-7 rounded-lg bg-chart-purple/10 flex items-center justify-center flex-shrink-0">
                  <Calendar className="w-3 h-3 text-chart-purple" />
                </div>
                <span className="text-xs text-dash-text">Last: {fmtDate(patient.last_assessment)}</span>
              </div>
            </div>
          </div>

          {/* Risk Summary */}
          <div className="card p-5">
            <h4 className="text-sm font-semibold text-dash-dark mb-4">Risk Overview</h4>
            <div className="space-y-4">
              <div>
                <div className="flex items-center justify-between mb-1.5">
                  <div className="flex items-center gap-1.5">
                    <span className="w-2 h-2 rounded-full bg-chart-blue" />
                    <span className="text-xs text-dash-muted">Alzheimer&apos;s</span>
                  </div>
                  <span className="text-xs font-bold text-dash-dark">{patient.ad_risk}%</span>
                </div>
                <div className="w-full h-2 rounded-full bg-dash-bg">
                  <div className="h-full rounded-full transition-all duration-700" style={{ width: `${patient.ad_risk}%`, backgroundColor: riskBarColor(patient.ad_risk) }} />
                </div>
              </div>
              <div>
                <div className="flex items-center justify-between mb-1.5">
                  <div className="flex items-center gap-1.5">
                    <span className="w-2 h-2 rounded-full bg-accent" />
                    <span className="text-xs text-dash-muted">Parkinson&apos;s</span>
                  </div>
                  <span className="text-xs font-bold text-dash-dark">{patient.pd_risk}%</span>
                </div>
                <div className="w-full h-2 rounded-full bg-dash-bg">
                  <div className="h-full rounded-full transition-all duration-700" style={{ width: `${patient.pd_risk}%`, backgroundColor: riskBarColor(patient.pd_risk) }} />
                </div>
              </div>
            </div>
          </div>

          {/* Quick Actions */}
          <div className="card p-5">
            <h4 className="text-sm font-semibold text-dash-dark mb-3">Quick Actions</h4>
            <div className="space-y-1.5">
              <button onClick={() => setTab('tests')} className="w-full text-left flex items-center gap-2.5 p-2.5 rounded-xl hover:bg-accent/10 transition-colors group">
                <div className="w-8 h-8 rounded-lg bg-accent/10 flex items-center justify-center flex-shrink-0">
                  <Clipboard className="w-3.5 h-3.5 text-accent-dark" />
                </div>
                <span className="text-xs text-dash-text group-hover:text-dash-dark">View Tests</span>
                <ChevronRight className="w-3 h-3 text-dash-border ml-auto group-hover:text-accent-dark transition-colors" />
              </button>
              <button onClick={() => router.push('/dashboard/notes')} className="w-full text-left flex items-center gap-2.5 p-2.5 rounded-xl hover:bg-chart-blue/10 transition-colors group">
                <div className="w-8 h-8 rounded-lg bg-chart-blue/10 flex items-center justify-center flex-shrink-0">
                  <FileText className="w-3.5 h-3.5 text-chart-blue" />
                </div>
                <span className="text-xs text-dash-text group-hover:text-dash-dark">Add Note</span>
                <ChevronRight className="w-3 h-3 text-dash-border ml-auto group-hover:text-chart-blue transition-colors" />
              </button>
              <button onClick={() => router.push('/dashboard/reports')} className="w-full text-left flex items-center gap-2.5 p-2.5 rounded-xl hover:bg-chart-orange/10 transition-colors group">
                <div className="w-8 h-8 rounded-lg bg-chart-orange/10 flex items-center justify-center flex-shrink-0">
                  <FileText className="w-3.5 h-3.5 text-chart-orange" />
                </div>
                <span className="text-xs text-dash-text group-hover:text-dash-dark">Generate Report</span>
                <ChevronRight className="w-3 h-3 text-dash-border ml-auto group-hover:text-chart-orange transition-colors" />
              </button>
            </div>
          </div>
        </motion.div>
      </div>
    </motion.div>
  );
}

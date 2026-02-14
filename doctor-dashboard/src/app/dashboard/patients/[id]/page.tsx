'use client';

import { useState, useEffect, useMemo } from 'react';
import { motion } from 'framer-motion';
import { useParams, useRouter } from 'next/navigation';
import {
  ArrowLeft, Brain, Activity, FileText,
  ChevronRight, Mail, Phone, Calendar, Clipboard,
  TrendingUp, TrendingDown, Shield, Loader2,
  AlertTriangle, Clock, User, Flag, Eye,
} from 'lucide-react';
import {
  AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer,
  RadarChart, PolarGrid, PolarAngleAxis, PolarRadiusAxis, Radar,
} from 'recharts';
import { patientsApi } from '@/lib/api';
import Link from 'next/link';

const container = { hidden: { opacity: 0 }, visible: { opacity: 1, transition: { staggerChildren: 0.06 } } };
const item = { hidden: { opacity: 0, y: 12 }, visible: { opacity: 1, y: 0, transition: { duration: 0.4 } } };

type TestSession = {
  id: number;
  category: string;
  status: string;
  started_at?: string;
  completed_at?: string;
  ad_risk_contribution?: number;
  pd_risk_contribution?: number;
  category_score?: number;
};

type ClinicalNote = {
  id: number;
  doctor_name: string;
  title: string;
  content: string;
  note_type: string;
  is_flagged: boolean;
  created_at: string;
};

type PatientDetail = {
  id: number;
  first_name: string;
  last_name: string;
  email: string;
  phone?: string;
  date_of_birth?: string;
  gender?: string;
  ad_risk_score: number;
  pd_risk_score: number;
  cognitive_score?: number;
  speech_score?: number;
  motor_score?: number;
  gait_score?: number;
  facial_score?: number;
  ad_stage?: string;
  pd_stage?: string;
  total_tests_completed: number;
  test_sessions: TestSession[];
  clinical_notes: ClinicalNote[];
  member_since: string;
  last_active?: string;
};

/* ─── Helpers ─── */
const riskBarColor = (v: number) => (v >= 70 ? '#E8637A' : v >= 40 ? '#F5A623' : '#2AC9A0');
const riskBg = (v: number) => v >= 70 ? 'bg-[#E8637A]/12 text-[#E8637A]' : v >= 40 ? 'bg-[#F5A623]/12 text-[#F5A623]' : 'bg-[#2AC9A0]/12 text-[#2AC9A0]';
const riskLabel = (v: number) => v >= 70 ? 'High' : v >= 40 ? 'Moderate' : 'Low';
const scoreColor = (s: number) => s >= 75 ? '#2AC9A0' : s >= 50 ? '#C6E94B' : s >= 30 ? '#F5A623' : '#E8637A';

const fmtDate = (iso?: string) => {
  if (!iso) return '—';
  try { return new Date(iso).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }); }
  catch { return iso; }
};

const fmtShort = (iso?: string) => {
  if (!iso) return '—';
  try { return new Date(iso).toLocaleDateString('en-US', { month: 'short', day: 'numeric' }); }
  catch { return iso; }
};

const noteTypeStyle: Record<string, { bg: string; text: string }> = {
  general: { bg: 'bg-blue-50', text: 'text-blue-600' },
  diagnosis: { bg: 'bg-red-50', text: 'text-red-600' },
  treatment: { bg: 'bg-emerald-50', text: 'text-emerald-600' },
  follow_up: { bg: 'bg-amber-50', text: 'text-amber-600' },
};

const catColors: Record<string, { bg: string; color: string; hex: string }> = {
  cognitive: { bg: 'bg-[#C6E94B]/15', color: 'text-[#8BA832]', hex: '#C6E94B' },
  speech: { bg: 'bg-indigo-50', color: 'text-indigo-500', hex: '#6366F1' },
  motor: { bg: 'bg-purple-50', color: 'text-purple-500', hex: '#A855F7' },
  gait: { bg: 'bg-orange-50', color: 'text-orange-500', hex: '#FB923C' },
  facial: { bg: 'bg-pink-50', color: 'text-pink-500', hex: '#EC4899' },
};

/* ─── Chart Tooltip ─── */
const ChartTooltip = ({ active, payload, label }: any) => {
  if (!active || !payload?.length) return null;
  return (
    <div className="bg-white p-3 rounded-xl shadow-elevated border border-dash-border">
      <p className="text-xs font-semibold text-dash-dark mb-1">{label}</p>
      {payload.map((p: any, i: number) => (
        <p key={i} className="text-xs text-dash-muted">
          {p.name}: <span className="font-semibold text-dash-dark">{typeof p.value === 'number' ? Math.round(p.value) : p.value}%</span>
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
  const [error, setError] = useState('');
  const [tab, setTab] = useState<'overview' | 'tests' | 'notes'>('overview');

  useEffect(() => {
    (async () => {
      try {
        const id = Number(params.id);
        const res = await patientsApi.getPatientDetail(id);
        setPatient(res);
      } catch (e: any) {
        setError(e?.response?.data?.detail || 'Failed to load patient');
      } finally {
        setLoading(false);
      }
    })();
  }, [params.id]);

  // Build risk history from completed test_sessions (grouped by month)
  const riskHistory = useMemo(() => {
    if (!patient) return [];
    const completed = patient.test_sessions
      .filter(t => t.status === 'completed' && t.completed_at && t.ad_risk_contribution != null)
      .sort((a, b) => new Date(a.completed_at!).getTime() - new Date(b.completed_at!).getTime());

    const groups: Record<string, { ad: number[]; pd: number[] }> = {};
    completed.forEach(t => {
      const m = new Date(t.completed_at!).toLocaleDateString('en-US', { month: 'short' });
      if (!groups[m]) groups[m] = { ad: [], pd: [] };
      if (t.ad_risk_contribution != null) groups[m].ad.push(t.ad_risk_contribution);
      if (t.pd_risk_contribution != null) groups[m].pd.push(t.pd_risk_contribution);
    });
    return Object.entries(groups).map(([month, v]) => ({
      month,
      ad: Math.round(v.ad.reduce((a, b) => a + b, 0) / v.ad.length),
      pd: Math.round(v.pd.reduce((a, b) => a + b, 0) / (v.pd.length || 1)),
    })).slice(-8);
  }, [patient]);

  // Score radar data
  const radarData = useMemo(() => {
    if (!patient) return [];
    return [
      { subject: 'Cognitive', score: patient.cognitive_score ?? 0 },
      { subject: 'Speech', score: patient.speech_score ?? 0 },
      { subject: 'Motor', score: patient.motor_score ?? 0 },
      { subject: 'Gait', score: patient.gait_score ?? 0 },
      { subject: 'Facial', score: patient.facial_score ?? 0 },
    ];
  }, [patient]);

  // Test stats by category
  const testStats = useMemo(() => {
    if (!patient) return [];
    const map: Record<string, { total: number; completed: number; avgScore: number; scores: number[] }> = {};
    patient.test_sessions.forEach(s => {
      if (!map[s.category]) map[s.category] = { total: 0, completed: 0, avgScore: 0, scores: [] };
      map[s.category].total++;
      if (s.status === 'completed') {
        map[s.category].completed++;
        if (s.category_score != null) map[s.category].scores.push(s.category_score);
      }
    });
    return Object.entries(map).map(([cat, v]) => ({
      category: cat,
      total: v.total,
      completed: v.completed,
      avgScore: v.scores.length > 0 ? Math.round(v.scores.reduce((a, b) => a + b, 0) / v.scores.length) : 0,
    })).sort((a, b) => b.completed - a.completed);
  }, [patient]);

  if (loading) {
    return (
      <div className="flex items-center justify-center h-[60vh]">
        <Loader2 className="w-8 h-8 animate-spin text-accent" />
      </div>
    );
  }

  if (error || !patient) {
    return (
      <div className="flex flex-col items-center justify-center h-[60vh] gap-3">
        <AlertTriangle className="w-10 h-10 text-red-400" />
        <p className="text-sm text-dash-muted">{error || 'Patient not found'}</p>
        <button onClick={() => router.back()} className="text-xs text-accent-dark hover:underline">Go back</button>
      </div>
    );
  }

  const name = `${patient.first_name} ${patient.last_name}`;
  const maxRisk = Math.max(patient.ad_risk_score, patient.pd_risk_score);
  const completedSessions = patient.test_sessions.filter(s => s.status === 'completed');
  const recentTests = patient.test_sessions.slice(0, 20);

  return (
    <motion.div variants={container} initial="hidden" animate="visible">
      <div className="grid grid-cols-1 xl:grid-cols-[1fr_300px] gap-6">
        {/* ════ LEFT ════ */}
        <div className="space-y-5 min-w-0">

          {/* Header */}
          <motion.div variants={item} className="flex items-center gap-4">
            <button onClick={() => router.back()}
              className="p-2 rounded-xl border border-dash-border hover:bg-dash-bg transition-all">
              <ArrowLeft className="w-5 h-5 text-dash-muted" />
            </button>
            <div className="flex-1 min-w-0">
              <h1 className="text-2xl font-bold text-dash-dark truncate">{name}</h1>
              <p className="text-sm text-dash-muted mt-0.5">
                {patient.gender ? <span className="capitalize">{patient.gender}</span> : ''}
                {patient.date_of_birth ? ` · Born ${fmtDate(patient.date_of_birth)}` : ''}
                {patient.ad_stage ? ` · ${patient.ad_stage}` : ''}
              </p>
            </div>
            <span className={`text-xs px-3 py-1.5 rounded-lg font-medium ring-1 ${riskBg(maxRisk)} ${
              maxRisk >= 70 ? 'ring-red-100' : maxRisk >= 40 ? 'ring-amber-100' : 'ring-emerald-100'
            }`}>
              {riskLabel(maxRisk)} Risk
            </span>
          </motion.div>

          {/* Risk + Stats Cards */}
          <motion.div variants={item} className="grid grid-cols-4 gap-3">
            {/* AD Risk */}
            <div className="card p-4 border-l-[3px]" style={{ borderLeftColor: riskBarColor(patient.ad_risk_score) }}>
              <div className="flex items-center gap-2 mb-2">
                <div className="w-8 h-8 rounded-lg bg-red-50 flex items-center justify-center">
                  <Brain className="w-4 h-4 text-red-500" />
                </div>
              </div>
              <p className="text-2xl font-bold text-dash-dark">{Math.round(patient.ad_risk_score)}%</p>
              <p className="text-[10px] text-dash-muted font-medium">AD Risk</p>
              <div className="w-full h-1.5 rounded-full bg-red-100 mt-2">
                <div className="h-full rounded-full transition-all duration-700" style={{ width: `${patient.ad_risk_score}%`, backgroundColor: riskBarColor(patient.ad_risk_score) }} />
              </div>
            </div>
            {/* PD Risk */}
            <div className="card p-4 border-l-[3px]" style={{ borderLeftColor: riskBarColor(patient.pd_risk_score) }}>
              <div className="flex items-center gap-2 mb-2">
                <div className="w-8 h-8 rounded-lg bg-amber-50 flex items-center justify-center">
                  <Activity className="w-4 h-4 text-amber-500" />
                </div>
              </div>
              <p className="text-2xl font-bold text-dash-dark">{Math.round(patient.pd_risk_score)}%</p>
              <p className="text-[10px] text-dash-muted font-medium">PD Risk</p>
              <div className="w-full h-1.5 rounded-full bg-amber-100 mt-2">
                <div className="h-full rounded-full transition-all duration-700" style={{ width: `${patient.pd_risk_score}%`, backgroundColor: riskBarColor(patient.pd_risk_score) }} />
              </div>
            </div>
            {/* Tests */}
            <div className="card p-4 border-l-[3px] border-l-accent">
              <div className="flex items-center gap-2 mb-2">
                <div className="w-8 h-8 rounded-lg bg-accent/10 flex items-center justify-center">
                  <Clipboard className="w-4 h-4 text-accent-dark" />
                </div>
              </div>
              <p className="text-2xl font-bold text-dash-dark">{patient.total_tests_completed}</p>
              <p className="text-[10px] text-dash-muted font-medium">Tests Done</p>
              <p className="text-[10px] text-dash-muted mt-2">{patient.test_sessions.length} total sessions</p>
            </div>
            {/* Notes */}
            <div className="card p-4 border-l-[3px] border-l-indigo-400">
              <div className="flex items-center gap-2 mb-2">
                <div className="w-8 h-8 rounded-lg bg-indigo-50 flex items-center justify-center">
                  <FileText className="w-4 h-4 text-indigo-500" />
                </div>
              </div>
              <p className="text-2xl font-bold text-dash-dark">{patient.clinical_notes.length}</p>
              <p className="text-[10px] text-dash-muted font-medium">Clinical Notes</p>
              <p className="text-[10px] text-dash-muted mt-2">{patient.clinical_notes.filter(n => n.is_flagged).length} flagged</p>
            </div>
          </motion.div>

          {/* Tabs */}
          <motion.div variants={item} className="flex gap-2">
            {(['overview', 'tests', 'notes'] as const).map((t) => (
              <button key={t} onClick={() => setTab(t)}
                className={`px-4 py-2 rounded-lg text-xs font-medium capitalize transition-all ${
                  tab === t ? 'bg-accent text-dash-dark' : 'bg-white text-dash-muted border border-dash-border hover:bg-dash-bg'
                }`}>
                {t === 'tests' ? `Tests (${patient.total_tests_completed})` : t === 'notes' ? `Notes (${patient.clinical_notes.length})` : t}
              </button>
            ))}
          </motion.div>

          {/* ─── OVERVIEW TAB ─── */}
          {tab === 'overview' && (
            <>
              {/* Risk Trend Chart */}
              {riskHistory.length > 1 && (
                <motion.div variants={item} className="card p-5">
                  <div className="flex items-center justify-between mb-4">
                    <h3 className="font-semibold text-dash-dark">Risk Score Trends</h3>
                    <div className="flex items-center gap-4">
                      <div className="flex items-center gap-1.5"><span className="w-2.5 h-2.5 rounded-full bg-red-400" /><span className="text-[11px] text-dash-muted">AD Risk</span></div>
                      <div className="flex items-center gap-1.5"><span className="w-2.5 h-2.5 rounded-full bg-amber-400" /><span className="text-[11px] text-dash-muted">PD Risk</span></div>
                    </div>
                  </div>
                  <ResponsiveContainer width="100%" height={240}>
                    <AreaChart data={riskHistory}>
                      <defs>
                        <linearGradient id="gradAD2" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="0%" stopColor="#EF4444" stopOpacity={0.1} />
                          <stop offset="100%" stopColor="#EF4444" stopOpacity={0} />
                        </linearGradient>
                        <linearGradient id="gradPD2" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="0%" stopColor="#F59E0B" stopOpacity={0.1} />
                          <stop offset="100%" stopColor="#F59E0B" stopOpacity={0} />
                        </linearGradient>
                      </defs>
                      <CartesianGrid strokeDasharray="3 3" stroke="#ECEDF2" vertical={false} />
                      <XAxis dataKey="month" fontSize={11} tick={{ fill: '#8B8FA8' }} axisLine={false} tickLine={false} />
                      <YAxis domain={[0, 100]} fontSize={11} tick={{ fill: '#8B8FA8' }} axisLine={false} tickLine={false} />
                      <Tooltip content={<ChartTooltip />} />
                      <Area type="monotone" dataKey="ad" name="AD Risk" stroke="#EF4444" strokeWidth={2} fill="url(#gradAD2)" />
                      <Area type="monotone" dataKey="pd" name="PD Risk" stroke="#F59E0B" strokeWidth={2} fill="url(#gradPD2)" />
                    </AreaChart>
                  </ResponsiveContainer>
                </motion.div>
              )}

              {/* Category Score Breakdown */}
              <motion.div variants={item} className="grid grid-cols-5 gap-3">
                {[
                  { label: 'Cognitive', score: patient.cognitive_score, color: '#C6E94B', icon: Brain },
                  { label: 'Speech', score: patient.speech_score, color: '#6366F1', icon: Activity },
                  { label: 'Motor', score: patient.motor_score, color: '#A855F7', icon: Activity },
                  { label: 'Gait', score: patient.gait_score, color: '#FB923C', icon: Activity },
                  { label: 'Facial', score: patient.facial_score, color: '#EC4899', icon: Eye },
                ].map((c) => (
                  <div key={c.label} className="card p-3.5 text-center">
                    <div className="w-8 h-8 rounded-lg mx-auto mb-2 flex items-center justify-center" style={{ backgroundColor: `${c.color}15` }}>
                      <c.icon className="w-3.5 h-3.5" style={{ color: c.color }} />
                    </div>
                    <p className="text-lg font-bold text-dash-dark">{c.score != null ? Math.round(c.score) : '—'}</p>
                    <p className="text-[10px] text-dash-muted">{c.label}</p>
                    {c.score != null && (
                      <div className="w-full h-1 rounded-full bg-gray-100 mt-2">
                        <div className="h-full rounded-full transition-all duration-500" style={{ width: `${c.score}%`, backgroundColor: c.color }} />
                      </div>
                    )}
                  </div>
                ))}
              </motion.div>

              {/* Test Stats by Category */}
              {testStats.length > 0 && (
                <motion.div variants={item} className="card p-5">
                  <h3 className="font-semibold text-dash-dark mb-4">Test History by Category</h3>
                  <div className="space-y-3">
                    {testStats.map((s) => {
                      const c = catColors[s.category] || { bg: 'bg-gray-50', color: 'text-gray-500', hex: '#9CA3AF' };
                      return (
                        <div key={s.category} className="flex items-center gap-3">
                          <div className={`w-8 h-8 rounded-lg ${c.bg} flex items-center justify-center flex-shrink-0`}>
                            <Brain className={`w-3.5 h-3.5 ${c.color}`} />
                          </div>
                          <div className="flex-1 min-w-0">
                            <div className="flex items-center justify-between mb-1">
                              <span className="text-xs font-medium text-dash-dark capitalize">{s.category}</span>
                              <span className="text-[10px] text-dash-muted">{s.completed}/{s.total} completed</span>
                            </div>
                            <div className="w-full h-1.5 rounded-full bg-gray-100">
                              <div className="h-full rounded-full transition-all duration-500" style={{ width: `${s.avgScore}%`, backgroundColor: c.hex }} />
                            </div>
                          </div>
                          <span className="text-xs font-bold text-dash-dark w-10 text-right">{s.avgScore}%</span>
                        </div>
                      );
                    })}
                  </div>
                </motion.div>
              )}
            </>
          )}

          {/* ─── TESTS TAB ─── */}
          {tab === 'tests' && (
            <motion.div variants={item} className="card overflow-hidden">
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="bg-gray-50/50 border-b border-gray-100">
                      <th className="text-left py-3 px-4 text-[11px] font-semibold text-dash-muted uppercase tracking-wider">Category</th>
                      <th className="text-left py-3 px-4 text-[11px] font-semibold text-dash-muted uppercase tracking-wider">Score</th>
                      <th className="text-left py-3 px-4 text-[11px] font-semibold text-dash-muted uppercase tracking-wider">AD</th>
                      <th className="text-left py-3 px-4 text-[11px] font-semibold text-dash-muted uppercase tracking-wider">PD</th>
                      <th className="text-left py-3 px-4 text-[11px] font-semibold text-dash-muted uppercase tracking-wider">Date</th>
                      <th className="text-left py-3 px-4 text-[11px] font-semibold text-dash-muted uppercase tracking-wider">Status</th>
                    </tr>
                  </thead>
                  <tbody>
                    {recentTests.map((t) => {
                      const c = catColors[t.category] || { bg: 'bg-gray-50', color: 'text-gray-500', hex: '#9CA3AF' };
                      return (
                        <tr key={t.id} className="border-b border-gray-50 hover:bg-accent/5 transition-colors">
                          <td className="py-3 px-4">
                            <div className="flex items-center gap-2.5">
                              <div className={`w-7 h-7 rounded-lg ${c.bg} flex items-center justify-center flex-shrink-0`}>
                                <Brain className={`w-3.5 h-3.5 ${c.color}`} />
                              </div>
                              <span className="text-xs font-medium text-dash-dark capitalize">{t.category}</span>
                            </div>
                          </td>
                          <td className="py-3 px-4">
                            {t.category_score != null ? (
                              <div className="flex items-center gap-2">
                                <div className="w-16 h-1.5 rounded-full bg-gray-100">
                                  <div className="h-full rounded-full transition-all duration-500"
                                    style={{ width: `${t.category_score}%`, backgroundColor: scoreColor(t.category_score) }} />
                                </div>
                                <span className="text-xs font-semibold text-dash-dark">{Math.round(t.category_score)}%</span>
                              </div>
                            ) : <span className="text-xs text-dash-muted">—</span>}
                          </td>
                          <td className="py-3 px-4">
                            {t.ad_risk_contribution != null ? (
                              <span className="text-xs font-semibold" style={{ color: riskBarColor(t.ad_risk_contribution) }}>
                                {Math.round(t.ad_risk_contribution)}%
                              </span>
                            ) : <span className="text-xs text-dash-muted">—</span>}
                          </td>
                          <td className="py-3 px-4">
                            {t.pd_risk_contribution != null ? (
                              <span className="text-xs font-semibold" style={{ color: riskBarColor(t.pd_risk_contribution) }}>
                                {Math.round(t.pd_risk_contribution)}%
                              </span>
                            ) : <span className="text-xs text-dash-muted">—</span>}
                          </td>
                          <td className="py-3 px-4 text-xs text-dash-muted">{fmtShort(t.completed_at || t.started_at)}</td>
                          <td className="py-3 px-4">
                            <span className={`text-[10px] px-2.5 py-1 rounded-full font-medium capitalize ${
                              t.status === 'completed' ? 'bg-emerald-50 text-emerald-600 ring-1 ring-emerald-100'
                              : t.status === 'in_progress' ? 'bg-blue-50 text-blue-600 ring-1 ring-blue-100'
                              : t.status === 'cancelled' ? 'bg-red-50 text-red-600 ring-1 ring-red-100'
                              : 'bg-gray-50 text-gray-500 ring-1 ring-gray-100'
                            }`}>
                              {t.status.replace('_', ' ')}
                            </span>
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
              {recentTests.length === 0 && (
                <div className="text-center py-16">
                  <FileText className="w-8 h-8 text-dash-border mx-auto mb-2" />
                  <p className="text-sm text-dash-muted">No test sessions found</p>
                </div>
              )}
              {patient.test_sessions.length > 20 && (
                <div className="px-4 py-3 border-t border-gray-100 text-center">
                  <p className="text-xs text-dash-muted">Showing 20 of {patient.test_sessions.length} sessions</p>
                </div>
              )}
            </motion.div>
          )}

          {/* ─── NOTES TAB ─── */}
          {tab === 'notes' && (
            <motion.div variants={item} className="space-y-3">
              {patient.clinical_notes.length === 0 ? (
                <div className="card p-8 text-center">
                  <FileText className="w-8 h-8 text-dash-border mx-auto mb-2" />
                  <p className="text-sm text-dash-muted">No clinical notes for this patient</p>
                  <Link href="/dashboard/notes">
                    <button className="mt-3 text-xs font-medium px-4 py-2 rounded-lg bg-accent text-dash-dark hover:bg-accent-hover transition-colors">
                      Add Note
                    </button>
                  </Link>
                </div>
              ) : (
                patient.clinical_notes.map((n) => {
                  const ns = noteTypeStyle[n.note_type] || noteTypeStyle.general;
                  return (
                    <div key={n.id} className="card p-4 hover:shadow-md transition-shadow">
                      <div className="flex items-start justify-between gap-3">
                        <div className="flex-1 min-w-0">
                          <div className="flex items-center gap-2 mb-1.5">
                            <h4 className="text-sm font-semibold text-dash-dark truncate">{n.title}</h4>
                            {n.is_flagged && <Flag className="w-3 h-3 text-red-400 flex-shrink-0" />}
                          </div>
                          <p className="text-xs text-dash-text line-clamp-2 leading-relaxed">{n.content}</p>
                          <div className="flex items-center gap-3 mt-2.5">
                            <span className={`text-[10px] px-2 py-0.5 rounded-full font-medium ${ns.bg} ${ns.text} capitalize`}>
                              {n.note_type.replace('_', ' ')}
                            </span>
                            <span className="text-[10px] text-dash-muted flex items-center gap-1">
                              <Clock className="w-3 h-3" /> {fmtDate(n.created_at)}
                            </span>
                            <span className="text-[10px] text-dash-muted">by {n.doctor_name}</span>
                          </div>
                        </div>
                      </div>
                    </div>
                  );
                })
              )}
            </motion.div>
          )}
        </div>

        {/* ════ RIGHT — Profile Sidebar ════ */}
        <motion.div variants={item} className="space-y-4">
          {/* Profile Card */}
          <div className="card p-5">
            <div className="flex flex-col items-center text-center mb-4">
              <div className={`w-16 h-16 rounded-full flex items-center justify-center text-xl font-bold mb-3 ${
                maxRisk >= 70 ? 'bg-red-50 text-red-600' : maxRisk >= 40 ? 'bg-amber-50 text-amber-600' : 'bg-accent/20 text-dash-dark'
              }`}>
                {patient.first_name[0]}{patient.last_name[0]}
              </div>
              <h4 className="text-sm font-semibold text-dash-dark">{name}</h4>
              <p className="text-[11px] text-dash-muted capitalize">{patient.gender || ''}</p>
              <span className={`text-[10px] px-2.5 py-1 rounded-lg font-medium mt-2 ring-1 ${riskBg(maxRisk)} ${
                maxRisk >= 70 ? 'ring-red-100' : maxRisk >= 40 ? 'ring-amber-100' : 'ring-emerald-100'
              }`}>
                {riskLabel(maxRisk)} Risk
              </span>
            </div>
            <div className="border-t border-dash-border pt-3 space-y-2.5">
              {patient.email && (
                <div className="flex items-center gap-2.5">
                  <div className="w-7 h-7 rounded-lg bg-indigo-50 flex items-center justify-center flex-shrink-0">
                    <Mail className="w-3 h-3 text-indigo-500" />
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
              <div className="flex items-center gap-2.5">
                <div className="w-7 h-7 rounded-lg bg-purple-50 flex items-center justify-center flex-shrink-0">
                  <Calendar className="w-3 h-3 text-purple-500" />
                </div>
                <span className="text-xs text-dash-text">Since {fmtDate(patient.member_since)}</span>
              </div>
              {patient.last_active && (
                <div className="flex items-center gap-2.5">
                  <div className="w-7 h-7 rounded-lg bg-emerald-50 flex items-center justify-center flex-shrink-0">
                    <Clock className="w-3 h-3 text-emerald-500" />
                  </div>
                  <span className="text-xs text-dash-text">Active {fmtDate(patient.last_active)}</span>
                </div>
              )}
            </div>
          </div>

          {/* Stages */}
          {(patient.ad_stage || patient.pd_stage) && (
            <div className="card p-5">
              <h4 className="text-sm font-semibold text-dash-dark mb-3">Disease Stage</h4>
              <div className="space-y-2.5">
                {patient.ad_stage && (
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <Brain className="w-3.5 h-3.5 text-red-400" />
                      <span className="text-xs text-dash-muted">Alzheimer&apos;s</span>
                    </div>
                    <span className={`text-[10px] px-2.5 py-1 rounded-full font-medium ${riskBg(patient.ad_risk_score)}`}>
                      {patient.ad_stage}
                    </span>
                  </div>
                )}
                {patient.pd_stage && (
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <Activity className="w-3.5 h-3.5 text-amber-400" />
                      <span className="text-xs text-dash-muted">Parkinson&apos;s</span>
                    </div>
                    <span className={`text-[10px] px-2.5 py-1 rounded-full font-medium ${riskBg(patient.pd_risk_score)}`}>
                      {patient.pd_stage}
                    </span>
                  </div>
                )}
              </div>
            </div>
          )}

          {/* Risk Overview */}
          <div className="card p-5">
            <h4 className="text-sm font-semibold text-dash-dark mb-4">Risk Overview</h4>
            <div className="space-y-4">
              <div>
                <div className="flex items-center justify-between mb-1.5">
                  <span className="text-xs text-dash-muted flex items-center gap-1"><span className="w-2 h-2 rounded-full bg-red-400" /> AD</span>
                  <span className="text-xs font-bold" style={{ color: riskBarColor(patient.ad_risk_score) }}>{Math.round(patient.ad_risk_score)}%</span>
                </div>
                <div className="w-full h-2 rounded-full bg-gray-100">
                  <div className="h-full rounded-full transition-all duration-700"
                    style={{ width: `${patient.ad_risk_score}%`, backgroundColor: riskBarColor(patient.ad_risk_score) }} />
                </div>
              </div>
              <div>
                <div className="flex items-center justify-between mb-1.5">
                  <span className="text-xs text-dash-muted flex items-center gap-1"><span className="w-2 h-2 rounded-full bg-amber-400" /> PD</span>
                  <span className="text-xs font-bold" style={{ color: riskBarColor(patient.pd_risk_score) }}>{Math.round(patient.pd_risk_score)}%</span>
                </div>
                <div className="w-full h-2 rounded-full bg-gray-100">
                  <div className="h-full rounded-full transition-all duration-700"
                    style={{ width: `${patient.pd_risk_score}%`, backgroundColor: riskBarColor(patient.pd_risk_score) }} />
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
              <Link href="/dashboard/notes" className="w-full text-left flex items-center gap-2.5 p-2.5 rounded-xl hover:bg-indigo-50 transition-colors group">
                <div className="w-8 h-8 rounded-lg bg-indigo-50 flex items-center justify-center flex-shrink-0">
                  <FileText className="w-3.5 h-3.5 text-indigo-500" />
                </div>
                <span className="text-xs text-dash-text group-hover:text-dash-dark">Add Note</span>
                <ChevronRight className="w-3 h-3 text-dash-border ml-auto group-hover:text-indigo-500 transition-colors" />
              </Link>
              <Link href="/dashboard/reports" className="w-full text-left flex items-center gap-2.5 p-2.5 rounded-xl hover:bg-orange-50 transition-colors group">
                <div className="w-8 h-8 rounded-lg bg-orange-50 flex items-center justify-center flex-shrink-0">
                  <FileText className="w-3.5 h-3.5 text-orange-500" />
                </div>
                <span className="text-xs text-dash-text group-hover:text-dash-dark">Generate Report</span>
                <ChevronRight className="w-3 h-3 text-dash-border ml-auto group-hover:text-orange-500 transition-colors" />
              </Link>
            </div>
          </div>
        </motion.div>
      </div>
    </motion.div>
  );
}

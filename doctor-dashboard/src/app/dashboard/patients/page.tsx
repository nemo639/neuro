'use client';

import { useState, useEffect, useCallback } from 'react';
import { motion } from 'framer-motion';
import {
  Search, Users, Brain, ChevronRight, ChevronLeft, X,
  Activity, AlertTriangle, ArrowUpDown, Filter,
  Loader2, UserCheck, TrendingUp, Eye,
} from 'lucide-react';
import { patientsApi } from '@/lib/api';
import Link from 'next/link';

const cv = { hidden: { opacity: 0 }, visible: { opacity: 1, transition: { staggerChildren: 0.05 } } };
const iv = { hidden: { opacity: 0, y: 12 }, visible: { opacity: 1, y: 0, transition: { duration: 0.4 } } };

type Patient = {
  id: number;
  name: string;
  age: number;
  gender?: string;
  risk_level: string;
  ad_risk_score: number;
  pd_risk_score: number;
  last_test_date?: string;
  last_test_category?: string;
};

const riskBadge = (level: string) => {
  if (level === 'High') return 'bg-[#E8637A]/12 text-[#E8637A] ring-1 ring-[#E8637A]/20';
  if (level === 'Moderate') return 'bg-[#F5A623]/12 text-[#F5A623] ring-1 ring-[#F5A623]/20';
  return 'bg-[#2AC9A0]/12 text-[#2AC9A0] ring-1 ring-[#2AC9A0]/20';
};

const riskBarColor = (score: number) => {
  if (score >= 70) return '#E8637A';
  if (score >= 40) return '#F5A623';
  return '#2AC9A0';
};

const fmtDate = (iso?: string) => {
  if (!iso) return '—';
  try { return new Date(iso).toLocaleDateString('en-US', { month: 'short', day: 'numeric' }); }
  catch { return '—'; }
};

export default function PatientsPage() {
  const [patients, setPatients] = useState<Patient[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [debouncedSearch, setDebouncedSearch] = useState('');
  const [riskFilter, setRiskFilter] = useState('');
  const [sortBy, setSortBy] = useState('last_test_date');
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [totalPages, setTotalPages] = useState(1);
  const [highCount, setHighCount] = useState(0);
  const [modCount, setModCount] = useState(0);
  const [lowCount, setLowCount] = useState(0);
  const [selected, setSelected] = useState<Patient | null>(null);
  const limit = 15;

  // Debounce search
  useEffect(() => {
    const t = setTimeout(() => { setDebouncedSearch(search); setPage(1); }, 400);
    return () => clearTimeout(t);
  }, [search]);

  // Reset page on filter change
  useEffect(() => { setPage(1); }, [riskFilter, sortBy]);

  const fetchPatients = useCallback(async () => {
    setLoading(true);
    try {
      const res = await patientsApi.getPatients({
        search: debouncedSearch || undefined,
        risk_level: riskFilter || undefined,
        page,
        limit,
      });
      setPatients(res.patients || []);
      setTotal(res.total || 0);
      setTotalPages(res.total_pages || 1);
      setHighCount(res.high_risk_count || 0);
      setModCount(res.moderate_risk_count || 0);
      setLowCount(res.low_risk_count || 0);
    } catch {
      setPatients([]);
    } finally {
      setLoading(false);
    }
  }, [debouncedSearch, riskFilter, sortBy, page]);

  useEffect(() => { fetchPatients(); }, [fetchPatients]);

  return (
    <motion.div variants={cv} initial="hidden" animate="visible">
      <div className="grid grid-cols-1 xl:grid-cols-[1fr_320px] gap-6">
        {/* ════ MAIN ════ */}
        <div className="space-y-5 min-w-0">

          {/* Header */}
          <motion.div variants={iv} className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
            <div>
              <h1 className="text-2xl font-bold text-dash-dark">Patients</h1>
              <p className="text-sm text-dash-muted mt-0.5">{total} patients registered</p>
            </div>
          </motion.div>

          {/* Stat Cards */}
          <motion.div variants={iv} className="grid grid-cols-4 gap-3">
            {[
              { label: 'Total', value: total, icon: Users, bg: 'bg-accent/10', color: '#C6E94B' },
              { label: 'High Risk', value: highCount, icon: AlertTriangle, bg: 'bg-[#FDEEF0]', color: '#E8637A' },
              { label: 'Moderate', value: modCount, icon: Activity, bg: 'bg-[#FEF3E0]', color: '#F5A623' },
              { label: 'Low Risk', value: lowCount, icon: UserCheck, bg: 'bg-[#E6F9F4]', color: '#2AC9A0' },
            ].map((s) => (
              <div key={s.label} className={`${s.bg} rounded-2xl p-4 flex items-center gap-3`}>
                <div className="w-10 h-10 rounded-xl bg-white/70 flex items-center justify-center flex-shrink-0">
                  <s.icon className="w-5 h-5" style={{ color: s.color }} />
                </div>
                <div>
                  <p className="text-lg font-bold text-dash-dark">{s.value}</p>
                  <p className="text-[11px] text-dash-muted">{s.label}</p>
                </div>
              </div>
            ))}
          </motion.div>

          {/* Search + Filters */}
          <motion.div variants={iv} className="flex flex-col sm:flex-row gap-3">
            <div className="relative flex-1">
              <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
              <input
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder="Search by name or email..."
                className="input pl-10"
              />
              {search && (
                <button onClick={() => setSearch('')} className="absolute right-3 top-1/2 -translate-y-1/2">
                  <X className="w-3.5 h-3.5 text-gray-400 hover:text-gray-600" />
                </button>
              )}
            </div>
            <div className="flex gap-2">
              <select value={riskFilter} onChange={(e) => setRiskFilter(e.target.value)} className="input w-auto min-w-[140px]">
                <option value="">All Risk Levels</option>
                <option value="high">High Risk</option>
                <option value="moderate">Moderate</option>
                <option value="low">Low Risk</option>
              </select>
              <select value={sortBy} onChange={(e) => setSortBy(e.target.value)} className="input w-auto min-w-[140px]">
                <option value="last_test_date">Recent Activity</option>
                <option value="risk_score">Risk Score</option>
                <option value="name">Name</option>
              </select>
            </div>
          </motion.div>

          {/* Patient Table */}
          <motion.div variants={iv} className="card overflow-hidden">
            {loading ? (
              <div className="flex items-center justify-center py-20">
                <Loader2 className="w-6 h-6 animate-spin text-accent" />
              </div>
            ) : (
              <>
                <div className="overflow-x-auto">
                  <table className="w-full text-sm">
                    <thead>
                      <tr className="border-b border-gray-100 bg-gray-50/50">
                        <th className="text-left py-3 px-4 text-[11px] font-semibold text-dash-muted uppercase tracking-wider">Patient</th>
                        <th className="text-left py-3 px-4 text-[11px] font-semibold text-dash-muted uppercase tracking-wider">Age</th>
                        <th className="text-left py-3 px-4 text-[11px] font-semibold text-dash-muted uppercase tracking-wider">AD Risk</th>
                        <th className="text-left py-3 px-4 text-[11px] font-semibold text-dash-muted uppercase tracking-wider">PD Risk</th>
                        <th className="text-left py-3 px-4 text-[11px] font-semibold text-dash-muted uppercase tracking-wider">Last Test</th>
                        <th className="text-left py-3 px-4 text-[11px] font-semibold text-dash-muted uppercase tracking-wider">Status</th>
                        <th className="py-3 px-4"></th>
                      </tr>
                    </thead>
                    <tbody>
                      {patients.map((p) => {
                        const maxRisk = Math.max(p.ad_risk_score, p.pd_risk_score);
                        return (
                          <tr key={p.id} onClick={() => setSelected(p)}
                            className={`border-b border-gray-50 hover:bg-accent/5 cursor-pointer transition-colors ${selected?.id === p.id ? 'bg-accent/5' : ''}`}>
                            <td className="py-3.5 px-4">
                              <div className="flex items-center gap-3">
                                <div className={`w-9 h-9 rounded-full flex items-center justify-center text-[11px] font-bold flex-shrink-0 ${
                                  maxRisk >= 70 ? 'bg-[#E8637A]/12 text-[#E8637A]' : maxRisk >= 40 ? 'bg-[#F5A623]/12 text-[#F5A623]' : 'bg-accent/20 text-dash-dark'
                                }`}>
                                  {p.name.split(' ').map(n => n[0]).join('').slice(0, 2)}
                                </div>
                                <div className="min-w-0">
                                  <p className="font-medium text-dash-dark truncate">{p.name}</p>
                                  <p className="text-[10px] text-dash-muted capitalize">{p.gender || '—'}</p>
                                </div>
                              </div>
                            </td>
                            <td className="py-3.5 px-4 text-dash-text">{p.age || '—'}y</td>
                            <td className="py-3.5 px-4">
                              <div className="flex items-center gap-2">
                                <div className="w-16 h-1.5 rounded-full bg-gray-100">
                                  <div className="h-full rounded-full transition-all duration-500"
                                    style={{ width: `${Math.min(p.ad_risk_score, 100)}%`, backgroundColor: riskBarColor(p.ad_risk_score) }} />
                                </div>
                                <span className="text-xs font-semibold text-dash-dark w-10">{Math.round(p.ad_risk_score)}%</span>
                              </div>
                            </td>
                            <td className="py-3.5 px-4">
                              <div className="flex items-center gap-2">
                                <div className="w-16 h-1.5 rounded-full bg-gray-100">
                                  <div className="h-full rounded-full transition-all duration-500"
                                    style={{ width: `${Math.min(p.pd_risk_score, 100)}%`, backgroundColor: riskBarColor(p.pd_risk_score) }} />
                                </div>
                                <span className="text-xs font-semibold text-dash-dark w-10">{Math.round(p.pd_risk_score)}%</span>
                              </div>
                            </td>
                            <td className="py-3.5 px-4">
                              <div>
                                <p className="text-xs text-dash-text">{fmtDate(p.last_test_date)}</p>
                                {p.last_test_category && (
                                  <p className="text-[10px] text-dash-muted capitalize">{p.last_test_category}</p>
                                )}
                              </div>
                            </td>
                            <td className="py-3.5 px-4">
                              <span className={`text-[10px] px-2.5 py-1 rounded-full font-medium ${riskBadge(p.risk_level)}`}>
                                {p.risk_level}
                              </span>
                            </td>
                            <td className="py-3.5 px-4 text-right">
                              <Link href={`/dashboard/patients/${p.id}`} onClick={(e) => e.stopPropagation()}>
                                <ChevronRight className="w-4 h-4 text-gray-300 hover:text-accent inline-block transition-colors" />
                              </Link>
                            </td>
                          </tr>
                        );
                      })}
                    </tbody>
                  </table>
                </div>

                {patients.length === 0 && (
                  <div className="text-center py-16">
                    <Users className="w-8 h-8 text-dash-border mx-auto mb-2" />
                    <p className="text-sm text-dash-muted">No patients found</p>
                    <p className="text-xs text-dash-muted mt-1">Try adjusting your filters</p>
                  </div>
                )}

                {/* Pagination */}
                {totalPages > 1 && (
                  <div className="flex items-center justify-between px-4 py-3 border-t border-gray-100">
                    <p className="text-xs text-dash-muted">
                      Page {page} of {totalPages} &middot; {total} patients
                    </p>
                    <div className="flex items-center gap-1.5">
                      <button onClick={() => setPage(p => Math.max(1, p - 1))} disabled={page <= 1}
                        className="p-1.5 rounded-lg border border-dash-border hover:bg-dash-bg disabled:opacity-30 disabled:cursor-not-allowed transition-colors">
                        <ChevronLeft className="w-3.5 h-3.5 text-dash-muted" />
                      </button>
                      {Array.from({ length: Math.min(5, totalPages) }, (_, i) => {
                        const start = Math.max(1, Math.min(page - 2, totalPages - 4));
                        const num = start + i;
                        if (num > totalPages) return null;
                        return (
                          <button key={num} onClick={() => setPage(num)}
                            className={`w-8 h-8 rounded-lg text-xs font-medium transition-colors ${
                              num === page ? 'bg-accent text-dash-dark' : 'hover:bg-dash-bg text-dash-muted'
                            }`}>
                            {num}
                          </button>
                        );
                      })}
                      <button onClick={() => setPage(p => Math.min(totalPages, p + 1))} disabled={page >= totalPages}
                        className="p-1.5 rounded-lg border border-dash-border hover:bg-dash-bg disabled:opacity-30 disabled:cursor-not-allowed transition-colors">
                        <ChevronRight className="w-3.5 h-3.5 text-dash-muted" />
                      </button>
                    </div>
                  </div>
                )}
              </>
            )}
          </motion.div>
        </div>

        {/* ════ RIGHT — Quick Preview ════ */}
        <motion.div variants={iv} className="space-y-4">
          {selected ? (
            <>
              {/* Profile Card */}
              <div className="card p-5 text-center">
                <div className={`w-16 h-16 rounded-full flex items-center justify-center text-xl font-bold mx-auto mb-3 ${
                  Math.max(selected.ad_risk_score, selected.pd_risk_score) >= 70 ? 'bg-red-50 text-red-600'
                    : Math.max(selected.ad_risk_score, selected.pd_risk_score) >= 40 ? 'bg-amber-50 text-amber-600'
                    : 'bg-accent/20 text-dash-dark'
                }`}>
                  {selected.name.split(' ').map(n => n[0]).join('').slice(0, 2)}
                </div>
                <h3 className="text-base font-bold text-dash-dark">{selected.name}</h3>
                <p className="text-xs text-dash-muted mt-0.5">
                  {selected.age ? `${selected.age} yrs` : ''}
                  {selected.gender ? ` · ${selected.gender}` : ''}
                </p>
                <span className={`inline-block text-[10px] px-2.5 py-1 rounded-full font-medium mt-2 ${riskBadge(selected.risk_level)}`}>
                  {selected.risk_level} Risk
                </span>

                <div className="flex gap-2 mt-4">
                  <Link href={`/dashboard/patients/${selected.id}`} className="flex-1">
                    <button className="w-full py-2.5 rounded-xl bg-accent text-dash-dark text-sm font-medium hover:bg-accent-hover transition-colors flex items-center justify-center gap-1.5">
                      <Eye className="w-3.5 h-3.5" /> View Profile
                    </button>
                  </Link>
                  <button onClick={() => setSelected(null)}
                    className="py-2.5 px-3 rounded-xl border border-dash-border text-sm text-dash-text hover:bg-dash-bg transition-colors">
                    <X className="w-4 h-4" />
                  </button>
                </div>
              </div>

              {/* Risk Scores */}
              <div className="card p-5">
                <h4 className="text-sm font-semibold text-dash-dark mb-4">Risk Scores</h4>
                <div className="space-y-4">
                  <div>
                    <div className="flex items-center justify-between mb-1.5">
                      <div className="flex items-center gap-1.5">
                        <Brain className="w-3 h-3 text-red-400" />
                        <span className="text-xs text-dash-muted">AD Risk</span>
                      </div>
                      <span className="text-xs font-bold" style={{ color: riskBarColor(selected.ad_risk_score) }}>
                        {Math.round(selected.ad_risk_score)}%
                      </span>
                    </div>
                    <div className="w-full h-2 rounded-full bg-gray-100">
                      <div className="h-full rounded-full transition-all duration-700"
                        style={{ width: `${Math.min(selected.ad_risk_score, 100)}%`, backgroundColor: riskBarColor(selected.ad_risk_score) }} />
                    </div>
                  </div>
                  <div>
                    <div className="flex items-center justify-between mb-1.5">
                      <div className="flex items-center gap-1.5">
                        <Activity className="w-3 h-3 text-blue-400" />
                        <span className="text-xs text-dash-muted">PD Risk</span>
                      </div>
                      <span className="text-xs font-bold" style={{ color: riskBarColor(selected.pd_risk_score) }}>
                        {Math.round(selected.pd_risk_score)}%
                      </span>
                    </div>
                    <div className="w-full h-2 rounded-full bg-gray-100">
                      <div className="h-full rounded-full transition-all duration-700"
                        style={{ width: `${Math.min(selected.pd_risk_score, 100)}%`, backgroundColor: riskBarColor(selected.pd_risk_score) }} />
                    </div>
                  </div>
                </div>

                {/* Max Risk Visual */}
                <div className="mt-5 pt-4 border-t border-gray-100">
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-xs text-dash-muted">Overall Risk</span>
                    <span className={`text-[10px] px-2 py-0.5 rounded-full font-medium ${riskBadge(selected.risk_level)}`}>
                      {selected.risk_level}
                    </span>
                  </div>
                  <div className="relative w-full h-3 rounded-full bg-gradient-to-r from-emerald-100 via-amber-100 to-red-100 overflow-hidden">
                    <div className="absolute top-0 h-full w-1 bg-dash-dark rounded-full transition-all duration-700"
                      style={{ left: `${Math.min(Math.max(selected.ad_risk_score, selected.pd_risk_score), 100)}%` }} />
                  </div>
                  <div className="flex justify-between mt-1">
                    <span className="text-[9px] text-emerald-500">Low</span>
                    <span className="text-[9px] text-amber-500">Moderate</span>
                    <span className="text-[9px] text-red-500">High</span>
                  </div>
                </div>
              </div>

              {/* Last Activity */}
              {selected.last_test_date && (
                <div className="card p-5">
                  <h4 className="text-sm font-semibold text-dash-dark mb-3">Last Activity</h4>
                  <div className="flex items-center gap-3">
                    <div className="w-9 h-9 rounded-xl bg-accent/10 flex items-center justify-center">
                      <TrendingUp className="w-4 h-4 text-accent-dark" />
                    </div>
                    <div>
                      <p className="text-xs font-medium text-dash-dark">{fmtDate(selected.last_test_date)}</p>
                      {selected.last_test_category && (
                        <p className="text-[10px] text-dash-muted capitalize">{selected.last_test_category} test</p>
                      )}
                    </div>
                  </div>
                </div>
              )}
            </>
          ) : (
            <div className="card p-8 text-center">
              <div className="w-12 h-12 rounded-2xl bg-accent/10 flex items-center justify-center mx-auto mb-3">
                <Users className="w-5 h-5 text-accent-dark" />
              </div>
              <p className="text-sm font-medium text-dash-dark">Select a Patient</p>
              <p className="text-xs text-dash-muted mt-1">Click on a patient row to view quick details</p>
            </div>
          )}
        </motion.div>
      </div>
    </motion.div>
  );
}

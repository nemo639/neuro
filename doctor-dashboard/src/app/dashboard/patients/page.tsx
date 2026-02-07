'use client';

import { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import {
  Search,
  Users,
  Brain,
  ChevronRight,
  X,
  FileText,
  Phone,
  Mail,
  MapPin,
  Activity,
  MoreVertical,
} from 'lucide-react';
import { patientsApi } from '@/lib/api';
import Link from 'next/link';

const cv = { hidden: { opacity: 0 }, visible: { opacity: 1, transition: { staggerChildren: 0.05 } } };
const iv = { hidden: { opacity: 0, y: 12 }, visible: { opacity: 1, y: 0, transition: { duration: 0.4 } } };

type Patient = {
  id: number;
  first_name: string;
  last_name: string;
  email: string;
  age?: number;
  gender?: string;
  ad_risk_score: number;
  pd_risk_score: number;
  total_tests: number;
  created_at: string;
  last_active?: string;
};

const riskLevel = (score: number) => {
  if (score >= 70) return { label: 'High', bg: 'bg-red-100 text-red-700' };
  if (score >= 40) return { label: 'Moderate', bg: 'bg-amber-100 text-amber-700' };
  return { label: 'Low', bg: 'bg-emerald-100 text-emerald-700' };
};

export default function PatientsPage() {
  const [patients, setPatients] = useState<Patient[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [riskFilter, setRiskFilter] = useState('all');
  const [selected, setSelected] = useState<Patient | null>(null);

  useEffect(() => {
    (async () => {
      try {
        const res = await patientsApi.getPatients();
        setPatients(res.patients || []);
      } catch {
        setPatients([
          { id: 1, first_name: 'Ahmed', last_name: 'Khan', email: 'ahmed@test.com', age: 68, gender: 'male', ad_risk_score: 78, pd_risk_score: 45, total_tests: 12, created_at: '2025-06-01', last_active: '2026-02-05' },
          { id: 2, first_name: 'Fatima', last_name: 'Ali', email: 'fatima@test.com', age: 55, gender: 'female', ad_risk_score: 52, pd_risk_score: 38, total_tests: 8, created_at: '2025-07-15', last_active: '2026-02-04' },
          { id: 3, first_name: 'Usman', last_name: 'Raza', email: 'usman@test.com', age: 72, gender: 'male', ad_risk_score: 25, pd_risk_score: 18, total_tests: 5, created_at: '2025-08-20', last_active: '2026-02-03' },
          { id: 4, first_name: 'Sara', last_name: 'Qureshi', email: 'sara@test.com', age: 61, gender: 'female', ad_risk_score: 88, pd_risk_score: 65, total_tests: 15, created_at: '2025-05-10', last_active: '2026-02-06' },
          { id: 5, first_name: 'Bilal', last_name: 'Hassan', email: 'bilal@test.com', age: 45, gender: 'male', ad_risk_score: 35, pd_risk_score: 22, total_tests: 3, created_at: '2025-09-01', last_active: '2026-01-30' },
          { id: 6, first_name: 'Maryam', last_name: 'Noor', email: 'maryam@test.com', age: 58, gender: 'female', ad_risk_score: 62, pd_risk_score: 71, total_tests: 10, created_at: '2025-04-12', last_active: '2026-02-05' },
        ]);
      } finally {
        setLoading(false);
      }
    })();
  }, []);

  const filtered = patients.filter((p) => {
    const q = search.toLowerCase();
    const nameMatch = `${p.first_name} ${p.last_name}`.toLowerCase().includes(q) || p.email.toLowerCase().includes(q);
    if (!nameMatch) return false;
    if (riskFilter === 'high') return Math.max(p.ad_risk_score, p.pd_risk_score) >= 70;
    if (riskFilter === 'moderate') { const m = Math.max(p.ad_risk_score, p.pd_risk_score); return m >= 40 && m < 70; }
    if (riskFilter === 'low') return Math.max(p.ad_risk_score, p.pd_risk_score) < 40;
    return true;
  });

  const highCount = patients.filter(p => Math.max(p.ad_risk_score, p.pd_risk_score) >= 70).length;
  const modCount = patients.filter(p => { const m = Math.max(p.ad_risk_score, p.pd_risk_score); return m >= 40 && m < 70; }).length;

  if (loading) {
    return (
      <div className="flex items-center justify-center h-[60vh]">
        <div className="w-8 h-8 border-2 border-accent border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  return (
    <motion.div variants={cv} initial="hidden" animate="visible">
      <div className="grid grid-cols-1 xl:grid-cols-[1fr_320px] gap-6">
        {/* ════ LEFT ════ */}
        <div className="space-y-6 min-w-0">
          {/* Header */}
          <motion.div variants={iv} className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
            <div>
              <h1 className="text-2xl font-bold text-dash-dark">Patients</h1>
              <p className="text-sm text-dash-muted mt-0.5">{patients.length} patients registered</p>
            </div>
          </motion.div>

          {/* Stat Pills */}
          <motion.div variants={iv} className="grid grid-cols-3 gap-3">
            {[
              { label: 'Total', value: patients.length, bg: 'bg-accent/10', color: '#C6E94B', icon: Users },
              { label: 'High Risk', value: highCount, bg: 'bg-red-50', color: '#EF4444', icon: Activity },
              { label: 'Moderate', value: modCount, bg: 'bg-amber-50', color: '#F59E0B', icon: Brain },
            ].map((s) => (
              <div key={s.label} className={`${s.bg} rounded-2xl p-4 flex items-center gap-3`}>
                <div className="w-10 h-10 rounded-xl bg-white/70 flex items-center justify-center">
                  <s.icon className="w-5 h-5" style={{ color: s.color }} />
                </div>
                <div>
                  <p className="text-lg font-bold text-dash-dark">{s.value}</p>
                  <p className="text-[11px] text-dash-muted">{s.label}</p>
                </div>
              </div>
            ))}
          </motion.div>

          {/* Search + Filter */}
          <motion.div variants={iv} className="flex flex-col sm:flex-row gap-3">
            <div className="relative flex-1">
              <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
              <input
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder="Search by name or email..."
                className="input pl-10"
              />
            </div>
            <select
              value={riskFilter}
              onChange={(e) => setRiskFilter(e.target.value)}
              className="input w-auto min-w-[140px]"
            >
              <option value="all">All Risk Levels</option>
              <option value="high">High Risk</option>
              <option value="moderate">Moderate</option>
              <option value="low">Low Risk</option>
            </select>
          </motion.div>

          {/* Patient Table Card */}
          <motion.div variants={iv} className="card overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-gray-100 bg-gray-50/50">
                    <th className="table-header table-cell text-left">Patient</th>
                    <th className="table-header table-cell text-left">Age/Gender</th>
                    <th className="table-header table-cell text-left">AD Risk</th>
                    <th className="table-header table-cell text-left">PD Risk</th>
                    <th className="table-header table-cell text-left">Tests</th>
                    <th className="table-header table-cell text-left">Status</th>
                    <th className="table-header table-cell text-right"></th>
                  </tr>
                </thead>
                <tbody>
                  {filtered.map((p) => {
                    const risk = riskLevel(Math.max(p.ad_risk_score, p.pd_risk_score));
                    return (
                      <tr
                        key={p.id}
                        onClick={() => setSelected(p)}
                        className="table-row cursor-pointer"
                      >
                        <td className="py-3 px-4">
                          <div className="flex items-center gap-3">
                            <div className="w-9 h-9 rounded-full bg-dash-bg flex items-center justify-center text-[11px] font-bold text-dash-dark flex-shrink-0">
                              {p.first_name[0]}{p.last_name[0]}
                            </div>
                            <div className="min-w-0">
                              <p className="font-medium text-dash-dark truncate">{p.first_name} {p.last_name}</p>
                              <p className="text-[11px] text-dash-muted truncate">{p.email}</p>
                            </div>
                          </div>
                        </td>
                        <td className="table-cell text-dash-text">
                          {p.age || '—'}y &middot; <span className="capitalize">{p.gender || '—'}</span>
                        </td>
                        <td className="py-3 px-4">
                          <div className="flex items-center gap-2">
                            <div className="w-12 h-1.5 rounded-full bg-gray-100">
                              <div className="h-full rounded-full bg-emerald-500" style={{ width: `${p.ad_risk_score}%` }} />
                            </div>
                            <span className="font-semibold text-dash-dark">{p.ad_risk_score}%</span>
                          </div>
                        </td>
                        <td className="py-3 px-4">
                          <div className="flex items-center gap-2">
                            <div className="w-12 h-1.5 rounded-full bg-gray-100">
                              <div className="h-full rounded-full bg-blue-500" style={{ width: `${p.pd_risk_score}%` }} />
                            </div>
                            <span className="font-semibold text-dash-dark">{p.pd_risk_score}%</span>
                          </div>
                        </td>
                        <td className="table-cell text-dash-text">{p.total_tests}</td>
                        <td className="py-3 px-4">
                          <span className={`text-[10px] px-2.5 py-1 rounded-full font-medium ${risk.bg}`}>
                            {risk.label}
                          </span>
                        </td>
                        <td className="py-3 px-4 text-right">
                          <Link href={`/dashboard/patients/${p.id}`} onClick={(e) => e.stopPropagation()}>
                            <ChevronRight className="w-4 h-4 text-gray-300 inline-block" />
                          </Link>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>

            {filtered.length === 0 && (
              <div className="text-center py-16">
                <Users className="w-8 h-8 text-dash-border mx-auto mb-2" />
                <p className="text-sm text-dash-muted">No patients found</p>
              </div>
            )}
          </motion.div>
        </div>

        {/* ════ RIGHT — Selected Patient ════ */}
        <motion.div variants={iv} className="space-y-4">
          {selected ? (
            <>
              {/* Profile */}
              <div className="card p-5 text-center">
                <div className="w-16 h-16 rounded-full bg-accent flex items-center justify-center text-xl font-bold text-dash-dark mx-auto mb-3">
                  {selected.first_name[0]}{selected.last_name[0]}
                </div>
                <h3 className="text-base font-bold text-dash-dark">{selected.first_name} {selected.last_name}</h3>
                <p className="text-xs text-dash-muted">{selected.age ? `${selected.age} yrs` : ''}{selected.gender ? ` · ${selected.gender}` : ''}</p>

                <div className="flex gap-2 mt-4">
                  <Link href={`/dashboard/patients/${selected.id}`} className="flex-1">
                    <button className="w-full py-2 rounded-xl bg-accent text-dash-dark text-sm font-medium hover:bg-accent-hover transition-colors">
                      View Profile
                    </button>
                  </Link>
                  <button
                    onClick={() => setSelected(null)}
                    className="py-2 px-3 rounded-xl border border-dash-border text-sm text-dash-text hover:bg-dash-bg transition-colors"
                  >
                    <X className="w-4 h-4" />
                  </button>
                </div>
              </div>

              {/* About */}
              <div className="card p-5">
                <h4 className="text-sm font-semibold text-dash-dark mb-3">About</h4>
                <div className="space-y-2.5">
                  {[
                    { icon: Mail, label: 'Email', value: selected.email },
                    { icon: Users, label: 'Gender', value: selected.gender || 'N/A' },
                    { icon: Activity, label: 'Tests', value: `${selected.total_tests} completed` },
                  ].map((item) => (
                    <div key={item.label} className="flex items-center gap-3">
                      <item.icon className="w-3.5 h-3.5 text-gray-400 flex-shrink-0" />
                      <span className="text-[11px] text-gray-400 w-12 flex-shrink-0">{item.label}</span>
                      <span className="text-xs font-medium text-gray-700 capitalize">{item.value}</span>
                    </div>
                  ))}
                </div>
              </div>

              {/* Risk Scores */}
              <div className="card p-5">
                <h4 className="text-sm font-semibold text-dash-dark mb-3">Risk Scores</h4>
                <div className="space-y-3">
                  <div>
                    <div className="flex items-center justify-between text-xs mb-1">
                      <span className="text-gray-500 flex items-center gap-1"><Brain className="w-3 h-3" /> AD Risk</span>
                      <span className="font-bold text-gray-800">{selected.ad_risk_score}%</span>
                    </div>
                    <div className="w-full h-2 rounded-full bg-gray-100">
                      <div className="h-full rounded-full bg-emerald-500 transition-all" style={{ width: `${selected.ad_risk_score}%` }} />
                    </div>
                  </div>
                  <div>
                    <div className="flex items-center justify-between text-xs mb-1">
                      <span className="text-gray-500 flex items-center gap-1"><Activity className="w-3 h-3" /> PD Risk</span>
                      <span className="font-bold text-gray-800">{selected.pd_risk_score}%</span>
                    </div>
                    <div className="w-full h-2 rounded-full bg-gray-100">
                      <div className="h-full rounded-full bg-blue-500 transition-all" style={{ width: `${selected.pd_risk_score}%` }} />
                    </div>
                  </div>
                </div>
              </div>
            </>
          ) : (
            <div className="card p-8 text-center">
              <Users className="w-8 h-8 text-dash-border mx-auto mb-2" />
              <p className="text-sm text-dash-muted">Select a patient to view details</p>
            </div>
          )}
        </motion.div>
      </div>
    </motion.div>
  );
}

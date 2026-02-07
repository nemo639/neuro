'use client';

import { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import {
  FileText, Download, Search, Eye, Brain, Activity,
  BarChart3, MoreVertical, TrendingUp,
} from 'lucide-react';
import { reportsApi } from '@/lib/api';

const cv = { hidden: { opacity: 0 }, visible: { opacity: 1, transition: { staggerChildren: 0.05 } } };
const iv = { hidden: { opacity: 0, y: 12 }, visible: { opacity: 1, y: 0, transition: { duration: 0.4 } } };

type Report = {
  id: string;
  patient_name: string;
  patient_id: number;
  report_type: string;
  ad_risk: number;
  pd_risk: number;
  generated_at: string;
  status: string;
};

const typeBadge: Record<string, { bg: string; text: string }> = {
  comprehensive: { bg: 'bg-purple-100', text: 'text-purple-700' },
  progress: { bg: 'bg-blue-100', text: 'text-blue-700' },
  screening: { bg: 'bg-emerald-100', text: 'text-emerald-700' },
};

export default function ReportsPage() {
  const [reports, setReports] = useState<Report[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [typeFilter, setTypeFilter] = useState('all');

  useEffect(() => {
    (async () => {
      try {
        const res = await reportsApi.getExportHistory();
        setReports(res.reports || res || []);
      } catch {
        setReports([
          { id: '1', patient_name: 'Ahmed Khan', patient_id: 1, report_type: 'comprehensive', ad_risk: 72, pd_risk: 28, generated_at: '2026-02-02T09:00:00Z', status: 'ready' },
          { id: '2', patient_name: 'Fatima Ali', patient_id: 2, report_type: 'progress', ad_risk: 35, pd_risk: 65, generated_at: '2026-02-01T14:30:00Z', status: 'ready' },
          { id: '3', patient_name: 'Bilal Hassan', patient_id: 3, report_type: 'screening', ad_risk: 45, pd_risk: 22, generated_at: '2026-01-30T11:00:00Z', status: 'ready' },
          { id: '4', patient_name: 'Sara Qureshi', patient_id: 4, report_type: 'comprehensive', ad_risk: 88, pd_risk: 42, generated_at: '2026-01-28T16:00:00Z', status: 'processing' },
          { id: '5', patient_name: 'Maryam Noor', patient_id: 5, report_type: 'progress', ad_risk: 61, pd_risk: 35, generated_at: '2026-01-25T09:45:00Z', status: 'ready' },
        ]);
      } finally {
        setLoading(false);
      }
    })();
  }, []);

  const fmtDate = (iso: string) => {
    try { return new Date(iso).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }); }
    catch { return iso; }
  };

  const riskColor = (v: number) => v >= 70 ? 'text-red-600' : v >= 40 ? 'text-amber-600' : 'text-emerald-600';

  const filtered = reports.filter((r) => {
    if (search && !r.patient_name.toLowerCase().includes(search.toLowerCase())) return false;
    if (typeFilter !== 'all' && r.report_type !== typeFilter) return false;
    return true;
  });

  const totalReady = reports.filter((r) => r.status === 'ready').length;
  const avgAD = reports.length ? Math.round(reports.reduce((a, r) => a + r.ad_risk, 0) / reports.length) : 0;
  const avgPD = reports.length ? Math.round(reports.reduce((a, r) => a + r.pd_risk, 0) / reports.length) : 0;

  if (loading) {
    return (
      <div className="flex items-center justify-center h-[60vh]">
        <div className="w-8 h-8 border-2 border-accent border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  return (
    <motion.div variants={cv} initial="hidden" animate="visible">
      <div className="grid grid-cols-1 xl:grid-cols-[1fr_280px] gap-6">
        {/* ════ LEFT ════ */}
        <div className="space-y-6 min-w-0">
          {/* Header */}
          <motion.div variants={iv}>
            <h1 className="text-2xl font-bold text-dash-dark">Reports</h1>
            <p className="text-sm text-dash-muted mt-0.5">View and export patient assessment reports</p>
          </motion.div>

          {/* Stats */}
          <motion.div variants={iv} className="grid grid-cols-3 gap-3">
            {[
              { label: 'Total Reports', value: reports.length, bg: 'bg-accent/10', color: '#C6E94B', icon: FileText },
              { label: 'Avg AD Risk', value: `${avgAD}%`, bg: 'bg-red-50', color: '#EF4444', icon: Brain },
              { label: 'Avg PD Risk', value: `${avgPD}%`, bg: 'bg-amber-50', color: '#F59E0B', icon: Activity },
            ].map((s) => (
              <div key={s.label} className={`${s.bg} rounded-2xl p-4`}>
                <div className="flex items-center gap-2 mb-2">
                  <div className="w-8 h-8 rounded-lg bg-white/70 flex items-center justify-center">
                    <s.icon className="w-4 h-4" style={{ color: s.color }} />
                  </div>
                </div>
                <p className="text-lg font-bold text-dash-dark">{s.value}</p>
                <p className="text-[11px] text-dash-muted">{s.label}</p>
              </div>
            ))}
          </motion.div>

          {/* Filter Pills + Search */}
          <motion.div variants={iv} className="flex flex-col sm:flex-row gap-3">
            <div className="flex flex-wrap gap-2">
              {['all', 'comprehensive', 'progress', 'screening'].map((t) => (
                <button
                  key={t}
                  onClick={() => setTypeFilter(t)}
                  className={`px-3.5 py-1.5 rounded-full text-xs font-medium transition-all capitalize
                    ${typeFilter === t ? 'bg-dash-dark text-white' : 'bg-white text-dash-muted border border-dash-border hover:bg-dash-bg'}`}
                >
                  {t === 'all' ? 'All Types' : t}
                </button>
              ))}
            </div>
            <div className="relative flex-1">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
              <input
                className="input pl-10"
                placeholder="Search reports..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
              />
            </div>
          </motion.div>

          {/* Reports Table */}
          <motion.div variants={iv} className="card overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-gray-100 bg-gray-50/50">
                    <th className="table-header table-cell text-left">Patient</th>
                    <th className="table-header table-cell text-left">Type</th>
                    <th className="table-header table-cell text-left">AD Risk</th>
                    <th className="table-header table-cell text-left">PD Risk</th>
                    <th className="table-header table-cell text-left">Date</th>
                    <th className="table-header table-cell text-left">Status</th>
                    <th className="table-header table-cell text-right">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {filtered.map((r) => {
                    const badge = typeBadge[r.report_type] || { bg: 'bg-gray-100', text: 'text-gray-600' };
                    return (
                      <tr key={r.id} className="table-row">
                        <td className="py-3 px-4">
                          <div className="flex items-center gap-3">
                              <div className="w-8 h-8 rounded-full bg-dash-bg flex items-center justify-center text-[10px] font-bold text-dash-dark">
                              {r.patient_name.split(' ').map((n) => n[0]).join('')}
                            </div>
                            <span className="font-medium text-dash-dark">{r.patient_name}</span>
                          </div>
                        </td>
                        <td className="py-3 px-4">
                          <span className={`text-[10px] px-2.5 py-1 rounded-full capitalize font-medium ${badge.bg} ${badge.text}`}>
                            {r.report_type}
                          </span>
                        </td>
                        <td className={`py-3 px-4 font-semibold ${riskColor(r.ad_risk)}`}>{r.ad_risk}%</td>
                        <td className={`py-3 px-4 font-semibold ${riskColor(r.pd_risk)}`}>{r.pd_risk}%</td>
                        <td className="py-3 px-4 text-gray-500">{fmtDate(r.generated_at)}</td>
                        <td className="py-3 px-4">
                          <div className="flex items-center gap-1.5">
                            <span className={`w-2 h-2 rounded-full ${r.status === 'ready' ? 'bg-emerald-500' : r.status === 'processing' ? 'bg-amber-500 animate-pulse' : 'bg-gray-400'}`} />
                            <span className="capitalize text-gray-600">{r.status}</span>
                          </div>
                        </td>
                        <td className="py-3 px-4">
                          <div className="flex items-center justify-end gap-1">
                            <button className="p-1.5 hover:bg-gray-100 rounded-lg" title="View">
                              <Eye className="w-3.5 h-3.5 text-gray-400" />
                            </button>
                            <button className="p-1.5 hover:bg-gray-100 rounded-lg" title="Download">
                              <Download className="w-3.5 h-3.5 text-gray-400" />
                            </button>
                          </div>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>

            {filtered.length === 0 && (
              <div className="text-center py-16">
                <BarChart3 className="w-8 h-8 text-dash-border mx-auto mb-2" />
                <p className="text-sm text-dash-muted">No reports found</p>
              </div>
            )}
          </motion.div>
        </div>

        {/* ════ RIGHT — Summary ════ */}
        <motion.div variants={iv} className="space-y-4">
          <div className="card p-5">
            <h4 className="text-sm font-semibold text-dash-dark mb-4">Quick Stats</h4>
            <div className="space-y-3">
              <div className="flex items-center justify-between p-3 rounded-xl bg-accent/10">
                <span className="text-xs text-gray-600">Ready</span>
                <span className="text-lg font-bold text-accent-dark">{totalReady}</span>
              </div>
              <div className="flex items-center justify-between p-3 rounded-xl bg-amber-50">
                <span className="text-xs text-gray-600">Processing</span>
                <span className="text-lg font-bold text-amber-600">{reports.length - totalReady}</span>
              </div>
            </div>
          </div>

          <div className="card p-5">
            <h4 className="text-sm font-semibold text-dash-dark mb-3">Recent</h4>
            <div className="space-y-2">
              {reports.slice(0, 4).map((r) => (
                <div key={r.id} className="flex items-center gap-2.5 py-2 border-b border-gray-50 last:border-0">
                  <div className="w-8 h-8 rounded-lg bg-[#F5F6FA] flex items-center justify-center flex-shrink-0">
                    <FileText className="w-3.5 h-3.5 text-gray-400" />
                  </div>
                  <div className="min-w-0 flex-1">
                    <p className="text-xs font-medium text-gray-700 truncate">{r.patient_name}</p>
                    <p className="text-[10px] text-gray-400 capitalize">{r.report_type}</p>
                  </div>
                  <span className={`w-1.5 h-1.5 rounded-full flex-shrink-0 ${r.status === 'ready' ? 'bg-emerald-500' : 'bg-amber-500'}`} />
                </div>
              ))}
            </div>
          </div>
        </motion.div>
      </div>
    </motion.div>
  );
}

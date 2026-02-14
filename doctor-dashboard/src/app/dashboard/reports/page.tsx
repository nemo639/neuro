'use client';

import { useState, useEffect, useCallback } from 'react';
import { motion } from 'framer-motion';
import {
  FileText, Download, Search, Eye, Brain, Activity,
  BarChart3, RefreshCw, Plus, X,
  Loader2, CheckCircle, ChevronLeft, ChevronRight,
} from 'lucide-react';
import { reportsApi, patientsApi } from '@/lib/api';

const API_BASE = process.env.NEXT_PUBLIC_API_URL || 'http://10.54.16.25:8000';

const cv = { hidden: { opacity: 0 }, visible: { opacity: 1, transition: { staggerChildren: 0.05 } } };
const iv = { hidden: { opacity: 0, y: 12 }, visible: { opacity: 1, y: 0, transition: { duration: 0.4 } } };

type Report = {
  id: string;
  patient_name: string;
  patient_id: number;
  report_type: string;
  title: string;
  ad_risk: number;
  pd_risk: number;
  cognitive_score: number | null;
  speech_score: number | null;
  motor_score: number | null;
  gait_score: number | null;
  facial_score: number | null;
  ad_stage: string | null;
  pd_stage: string | null;
  tests_count: number;
  generated_at: string;
  status: string;
  has_pdf: boolean;
};

const typeBadge: Record<string, { bg: string; text: string }> = {
  comprehensive: { bg: 'bg-purple-100', text: 'text-purple-700' },
  progress: { bg: 'bg-blue-100', text: 'text-blue-700' },
  screening: { bg: 'bg-emerald-100', text: 'text-emerald-700' },
  summary: { bg: 'bg-amber-100', text: 'text-amber-700' },
  speech_cognitive: { bg: 'bg-indigo-100', text: 'text-indigo-700' },
  motor_gait: { bg: 'bg-teal-100', text: 'text-teal-700' },
};

export default function ReportsPage() {
  const [reports, setReports] = useState<Report[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [typeFilter, setTypeFilter] = useState('all');

  /* ── Generate Modal ── */
  const [showGenerate, setShowGenerate] = useState(false);
  const [generating, setGenerating] = useState(false);
  const [genSuccess, setGenSuccess] = useState<string | null>(null);
  const [genPatientSearch, setGenPatientSearch] = useState('');
  const [genPatients, setGenPatients] = useState<{ id: number; name: string }[]>([]);
  const [genSelectedPatient, setGenSelectedPatient] = useState<{ id: number; name: string } | null>(null);
  const [genReportType, setGenReportType] = useState('comprehensive');

  /* ── Preview Modal ── */
  const [previewReport, setPreviewReport] = useState<Report | null>(null);

  const LIMIT = 15;
  const totalPages = Math.ceil(total / LIMIT);

  const fetchReports = useCallback(async () => {
    setLoading(true);
    try {
      const res = await reportsApi.getExportHistory({ page, limit: LIMIT });
      setReports(res.reports || []);
      setTotal(res.total || 0);
    } catch {
      setReports([]);
    } finally {
      setLoading(false);
    }
  }, [page]);

  useEffect(() => { fetchReports(); }, [fetchReports]);

  /* ── Patient search for generate ── */
  useEffect(() => {
    if (!genPatientSearch || genPatientSearch.length < 2) { setGenPatients([]); return; }
    const t = setTimeout(async () => {
      try {
        const res = await patientsApi.getPatients({ search: genPatientSearch, limit: 8 });
        setGenPatients((res.patients || []).map((p: any) => ({ id: p.id, name: p.name })));
      } catch { setGenPatients([]); }
    }, 300);
    return () => clearTimeout(t);
  }, [genPatientSearch]);

  /* ── Generate report ── */
  const handleGenerate = async () => {
    if (!genSelectedPatient) return;
    setGenerating(true);
    setGenSuccess(null);
    try {
      const res = await reportsApi.exportReport({
        patient_id: genSelectedPatient.id,
        report_type: genReportType,
      });
      setGenSuccess(res.download_url);
      fetchReports();
    } catch (err: any) {
      alert(err?.response?.data?.detail || 'Failed to generate report');
    } finally {
      setGenerating(false);
    }
  };

  /* ── Download ── */
  const handleDownload = (report: Report) => {
    if (report.has_pdf) {
      const url = reportsApi.downloadReport(Number(report.id));
      const a = document.createElement('a');
      a.href = url;
      a.target = '_blank';
      a.click();
    }
  };

  /* ── Helpers ── */
  const fmtDate = (iso: string) => {
    try { return new Date(iso).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }); }
    catch { return iso; }
  };
  const riskColor = (v: number) => v >= 70 ? 'text-[#E8637A]' : v >= 40 ? 'text-[#F5A623]' : 'text-[#2AC9A0]';

  const filtered = reports.filter((r) => {
    if (search && !r.patient_name.toLowerCase().includes(search.toLowerCase())) return false;
    if (typeFilter !== 'all' && r.report_type !== typeFilter) return false;
    return true;
  });

  const totalReady = reports.filter((r) => r.status === 'ready').length;
  const avgAD = reports.length ? Math.round(reports.reduce((a, r) => a + r.ad_risk, 0) / reports.length) : 0;
  const avgPD = reports.length ? Math.round(reports.reduce((a, r) => a + r.pd_risk, 0) / reports.length) : 0;

  /* Types for filter */
  const typeSet = Array.from(new Set(reports.map(r => r.report_type)));
  const allTypes = ['all', ...typeSet];

  if (loading && reports.length === 0) {
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
          <motion.div variants={iv} className="flex items-center justify-between">
            <div>
              <h1 className="text-2xl font-bold text-dash-dark">Reports</h1>
              <p className="text-sm text-dash-muted mt-0.5">View, generate, and download patient assessment reports</p>
            </div>
            <div className="flex gap-2">
              <button onClick={fetchReports} className="p-2 rounded-xl border border-dash-border hover:bg-dash-bg transition-colors" title="Refresh">
                <RefreshCw className={`w-4 h-4 text-dash-muted ${loading ? 'animate-spin' : ''}`} />
              </button>
              <button onClick={() => { setShowGenerate(true); setGenSuccess(null); setGenSelectedPatient(null); setGenPatientSearch(''); }}
                className="btn-primary flex items-center gap-2 text-sm">
                <Plus className="w-4 h-4" /> Generate Report
              </button>
            </div>
          </motion.div>

          {/* Stats */}
          <motion.div variants={iv} className="grid grid-cols-4 gap-3">
            {[
              { label: 'Total Reports', value: total, bg: 'bg-accent/10', color: '#C6E94B', icon: FileText },
              { label: 'Ready', value: totalReady, bg: 'bg-[#E6F9F4]', color: '#2AC9A0', icon: CheckCircle },
              { label: 'Avg AD Risk', value: `${avgAD}%`, bg: 'bg-[#FDEEF0]', color: '#E8637A', icon: Brain },
              { label: 'Avg PD Risk', value: `${avgPD}%`, bg: 'bg-[#FEF3E0]', color: '#F5A623', icon: Activity },
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
              {allTypes.map((t) => {
                const count = t === 'all' ? reports.length : reports.filter(r => r.report_type === t).length;
                return (
                  <button
                    key={t}
                    onClick={() => setTypeFilter(t)}
                    className={`px-3.5 py-1.5 rounded-full text-xs font-medium transition-all capitalize
                      ${typeFilter === t ? 'bg-dash-dark text-white' : 'bg-white text-dash-muted border border-dash-border hover:bg-dash-bg'}`}
                  >
                    {t === 'all' ? 'All Types' : t.replace('_', ' ')} ({count})
                  </button>
                );
              })}
            </div>
            <div className="relative flex-1">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
              <input
                className="input pl-10"
                placeholder="Search by patient name..."
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
                    <th className="py-3 px-4 text-left text-xs font-semibold text-gray-500 uppercase">Patient</th>
                    <th className="py-3 px-4 text-left text-xs font-semibold text-gray-500 uppercase">Type</th>
                    <th className="py-3 px-4 text-left text-xs font-semibold text-gray-500 uppercase">AD Risk</th>
                    <th className="py-3 px-4 text-left text-xs font-semibold text-gray-500 uppercase">PD Risk</th>
                    <th className="py-3 px-4 text-left text-xs font-semibold text-gray-500 uppercase">Tests</th>
                    <th className="py-3 px-4 text-left text-xs font-semibold text-gray-500 uppercase">Date</th>
                    <th className="py-3 px-4 text-left text-xs font-semibold text-gray-500 uppercase">Status</th>
                    <th className="py-3 px-4 text-right text-xs font-semibold text-gray-500 uppercase">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {filtered.map((r) => {
                    const badge = typeBadge[r.report_type] || { bg: 'bg-gray-100', text: 'text-gray-600' };
                    return (
                      <tr key={r.id} className="border-b border-gray-50 hover:bg-gray-50/50 transition-colors">
                        <td className="py-3 px-4">
                          <div className="flex items-center gap-3">
                            <div className="w-8 h-8 rounded-full bg-dash-bg flex items-center justify-center text-[10px] font-bold text-dash-dark">
                              {r.patient_name.split(' ').map((n) => n[0]).join('').slice(0, 2)}
                            </div>
                            <div>
                              <span className="font-medium text-dash-dark">{r.patient_name}</span>
                              <p className="text-[10px] text-dash-muted">ID: {r.patient_id}</p>
                            </div>
                          </div>
                        </td>
                        <td className="py-3 px-4">
                          <span className={`text-[10px] px-2.5 py-1 rounded-full capitalize font-medium ${badge.bg} ${badge.text}`}>
                            {r.report_type.replace('_', ' ')}
                          </span>
                        </td>
                        <td className={`py-3 px-4 font-semibold ${riskColor(r.ad_risk)}`}>{r.ad_risk}%</td>
                        <td className={`py-3 px-4 font-semibold ${riskColor(r.pd_risk)}`}>{r.pd_risk}%</td>
                        <td className="py-3 px-4 text-gray-500">{r.tests_count}</td>
                        <td className="py-3 px-4 text-gray-500">{fmtDate(r.generated_at)}</td>
                        <td className="py-3 px-4">
                          <div className="flex items-center gap-1.5">
                            <span className={`w-2 h-2 rounded-full ${r.status === 'ready' ? 'bg-emerald-500' : r.status === 'processing' ? 'bg-amber-500 animate-pulse' : 'bg-gray-400'}`} />
                            <span className="capitalize text-gray-600">{r.status}</span>
                          </div>
                        </td>
                        <td className="py-3 px-4">
                          <div className="flex items-center justify-end gap-1">
                            <button onClick={() => setPreviewReport(r)} className="p-1.5 hover:bg-gray-100 rounded-lg" title="View Details">
                              <Eye className="w-3.5 h-3.5 text-gray-400" />
                            </button>
                            {r.has_pdf && (
                              <button onClick={() => handleDownload(r)} className="p-1.5 hover:bg-accent/20 rounded-lg" title="Download PDF">
                                <Download className="w-3.5 h-3.5 text-accent-dark" />
                              </button>
                            )}
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
                <p className="text-xs text-dash-muted mt-1">Generate a report to get started</p>
              </div>
            )}

            {/* Pagination */}
            {totalPages > 1 && (
              <div className="flex items-center justify-between px-4 py-3 border-t border-gray-100">
                <p className="text-xs text-dash-muted">
                  Showing {(page - 1) * LIMIT + 1}–{Math.min(page * LIMIT, total)} of {total}
                </p>
                <div className="flex gap-1">
                  <button onClick={() => setPage(p => Math.max(1, p - 1))} disabled={page === 1}
                    className="p-1.5 rounded-lg border border-dash-border hover:bg-dash-bg disabled:opacity-40">
                    <ChevronLeft className="w-3.5 h-3.5" />
                  </button>
                  {Array.from({ length: Math.min(totalPages, 5) }, (_, i) => i + 1).map((p) => (
                    <button key={p} onClick={() => setPage(p)}
                      className={`w-8 h-8 rounded-lg text-xs font-medium ${p === page ? 'bg-dash-dark text-white' : 'hover:bg-dash-bg text-dash-muted'}`}>
                      {p}
                    </button>
                  ))}
                  <button onClick={() => setPage(p => Math.min(totalPages, p + 1))} disabled={page === totalPages}
                    className="p-1.5 rounded-lg border border-dash-border hover:bg-dash-bg disabled:opacity-40">
                    <ChevronRight className="w-3.5 h-3.5" />
                  </button>
                </div>
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

          {/* By Type Breakdown */}
          <div className="card p-5">
            <h4 className="text-sm font-semibold text-dash-dark mb-3">Reports by Type</h4>
            <div className="space-y-2">
              {typeSet.map((t) => {
                const count = reports.filter(r => r.report_type === t).length;
                const pct = reports.length ? Math.round((count / reports.length) * 100) : 0;
                return (
                  <div key={t} className="space-y-1">
                    <div className="flex items-center justify-between">
                      <span className="text-xs text-gray-600 capitalize">{t.replace('_', ' ')}</span>
                      <span className="text-xs font-semibold text-dash-dark">{count}</span>
                    </div>
                    <div className="h-1.5 bg-gray-100 rounded-full overflow-hidden">
                      <div className="h-full bg-accent rounded-full transition-all" style={{ width: `${pct}%` }} />
                    </div>
                  </div>
                );
              })}
              {typeSet.length === 0 && <p className="text-xs text-dash-muted">No reports yet</p>}
            </div>
          </div>

          {/* Recent */}
          <div className="card p-5">
            <h4 className="text-sm font-semibold text-dash-dark mb-3">Recent Reports</h4>
            <div className="space-y-2">
              {reports.slice(0, 5).map((r) => (
                <div key={r.id} className="flex items-center gap-2.5 py-2 border-b border-gray-50 last:border-0">
                  <div className="w-8 h-8 rounded-lg bg-[#F5F6FA] flex items-center justify-center flex-shrink-0">
                    <FileText className="w-3.5 h-3.5 text-gray-400" />
                  </div>
                  <div className="min-w-0 flex-1">
                    <p className="text-xs font-medium text-gray-700 truncate">{r.patient_name}</p>
                    <p className="text-[10px] text-gray-400 capitalize">{r.report_type.replace('_', ' ')}</p>
                  </div>
                  <span className={`w-1.5 h-1.5 rounded-full flex-shrink-0 ${r.status === 'ready' ? 'bg-emerald-500' : 'bg-amber-500'}`} />
                </div>
              ))}
              {reports.length === 0 && <p className="text-xs text-dash-muted">No reports yet</p>}
            </div>
          </div>
        </motion.div>
      </div>

      {/* ════ Generate Report Modal ════ */}
      {showGenerate && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm">
          <motion.div initial={{ opacity: 0, scale: 0.95 }} animate={{ opacity: 1, scale: 1 }}
            className="bg-white rounded-2xl shadow-xl w-full max-w-lg mx-4 overflow-hidden">
            <div className="flex items-center justify-between px-6 py-4 border-b border-gray-100">
              <h3 className="font-semibold text-dash-dark">Generate PDF Report</h3>
              <button onClick={() => setShowGenerate(false)} className="p-1 hover:bg-gray-100 rounded-lg">
                <X className="w-4 h-4" />
              </button>
            </div>
            <div className="p-6 space-y-5">
              {genSuccess ? (
                <div className="text-center py-6">
                  <CheckCircle className="w-12 h-12 text-emerald-500 mx-auto mb-3" />
                  <p className="font-semibold text-dash-dark mb-1">Report Generated!</p>
                  <p className="text-sm text-dash-muted mb-4">Your PDF report is ready for download.</p>
                  <button onClick={() => {
                    const a = document.createElement('a');
                    a.href = `${API_BASE}${genSuccess}`;
                    a.target = '_blank';
                    a.download = 'report.pdf';
                    a.click();
                  }} className="btn-primary inline-flex items-center gap-2">
                    <Download className="w-4 h-4" /> Download PDF
                  </button>
                </div>
              ) : (
                <>
                  {/* Patient search */}
                  <div>
                    <label className="block text-sm font-medium text-dash-dark mb-2">Patient</label>
                    {genSelectedPatient ? (
                      <div className="flex items-center gap-2 p-3 rounded-xl bg-accent/10">
                        <div className="w-8 h-8 rounded-full bg-accent flex items-center justify-center text-[10px] font-bold text-dash-dark">
                          {genSelectedPatient.name.split(' ').map(n => n[0]).join('').slice(0, 2)}
                        </div>
                        <div className="flex-1">
                          <p className="text-sm font-medium text-dash-dark">{genSelectedPatient.name}</p>
                          <p className="text-[10px] text-dash-muted">ID: {genSelectedPatient.id}</p>
                        </div>
                        <button onClick={() => { setGenSelectedPatient(null); setGenPatientSearch(''); }}
                          className="p-1 hover:bg-white/60 rounded-lg">
                          <X className="w-3.5 h-3.5 text-dash-muted" />
                        </button>
                      </div>
                    ) : (
                      <div className="relative">
                        <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
                        <input className="input pl-10" placeholder="Search patient by name..."
                          value={genPatientSearch} onChange={(e) => setGenPatientSearch(e.target.value)} autoFocus />
                        {genPatients.length > 0 && (
                          <div className="absolute z-10 top-full mt-1 w-full bg-white border border-dash-border rounded-xl shadow-lg max-h-48 overflow-y-auto">
                            {genPatients.map((p) => (
                              <button key={p.id} onClick={() => { setGenSelectedPatient(p); setGenPatients([]); }}
                                className="w-full text-left px-4 py-2.5 hover:bg-dash-bg text-sm flex items-center gap-2">
                                <div className="w-6 h-6 rounded-full bg-accent/20 flex items-center justify-center text-[9px] font-bold text-accent-dark">
                                  {p.name.split(' ').map(n => n[0]).join('').slice(0, 2)}
                                </div>
                                <span className="text-dash-dark">{p.name}</span>
                                <span className="text-dash-muted text-xs ml-auto">#{p.id}</span>
                              </button>
                            ))}
                          </div>
                        )}
                      </div>
                    )}
                  </div>

                  {/* Report Type */}
                  <div>
                    <label className="block text-sm font-medium text-dash-dark mb-2">Report Type</label>
                    <select className="input" value={genReportType} onChange={(e) => setGenReportType(e.target.value)}>
                      <option value="comprehensive">Comprehensive Assessment</option>
                      <option value="progress">Progress Report</option>
                      <option value="screening">Screening Report</option>
                      <option value="summary">Summary Report</option>
                      <option value="speech_cognitive">Speech &amp; Cognitive</option>
                      <option value="motor_gait">Motor &amp; Gait</option>
                    </select>
                  </div>

                  <button onClick={handleGenerate} disabled={!genSelectedPatient || generating}
                    className="btn-primary w-full flex items-center justify-center gap-2">
                    {generating ? <Loader2 className="w-4 h-4 animate-spin" /> : <FileText className="w-4 h-4" />}
                    {generating ? 'Generating PDF...' : 'Generate Report'}
                  </button>
                </>
              )}
            </div>
          </motion.div>
        </div>
      )}

      {/* ════ Preview Modal ════ */}
      {previewReport && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm">
          <motion.div initial={{ opacity: 0, scale: 0.95 }} animate={{ opacity: 1, scale: 1 }}
            className="bg-white rounded-2xl shadow-xl w-full max-w-2xl mx-4 overflow-hidden max-h-[85vh] overflow-y-auto">
            <div className="flex items-center justify-between px-6 py-4 border-b border-gray-100 sticky top-0 bg-white z-10">
              <div>
                <h3 className="font-semibold text-dash-dark">Report Details</h3>
                <p className="text-xs text-dash-muted">{previewReport.patient_name} — {previewReport.report_type.replace('_', ' ')}</p>
              </div>
              <button onClick={() => setPreviewReport(null)} className="p-1 hover:bg-gray-100 rounded-lg">
                <X className="w-4 h-4" />
              </button>
            </div>
            <div className="p-6 space-y-6">
              {/* Patient Info */}
              <div className="flex items-center gap-4">
                <div className="w-14 h-14 rounded-2xl bg-accent/20 flex items-center justify-center text-xl font-bold text-accent-dark">
                  {previewReport.patient_name.split(' ').map(n => n[0]).join('').slice(0, 2)}
                </div>
                <div>
                  <h4 className="font-semibold text-dash-dark text-lg">{previewReport.patient_name}</h4>
                  <p className="text-sm text-dash-muted">ID: {previewReport.patient_id} · Tests: {previewReport.tests_count} · {fmtDate(previewReport.generated_at)}</p>
                </div>
              </div>

              {/* Risk Scores */}
              <div className="grid grid-cols-2 gap-4">
                <div className="p-4 rounded-xl bg-red-50">
                  <p className="text-xs text-gray-500 mb-1">Alzheimer&apos;s Risk</p>
                  <p className={`text-2xl font-bold ${riskColor(previewReport.ad_risk)}`}>{previewReport.ad_risk}%</p>
                  {previewReport.ad_stage && <p className="text-xs text-gray-500 mt-0.5">Stage: {previewReport.ad_stage}</p>}
                </div>
                <div className="p-4 rounded-xl bg-amber-50">
                  <p className="text-xs text-gray-500 mb-1">Parkinson&apos;s Risk</p>
                  <p className={`text-2xl font-bold ${riskColor(previewReport.pd_risk)}`}>{previewReport.pd_risk}%</p>
                  {previewReport.pd_stage && <p className="text-xs text-gray-500 mt-0.5">Stage: {previewReport.pd_stage}</p>}
                </div>
              </div>

              {/* Category Scores */}
              <div>
                <h5 className="text-sm font-semibold text-dash-dark mb-3">Category Scores</h5>
                <div className="grid grid-cols-5 gap-2">
                  {[
                    { label: 'Cognitive', value: previewReport.cognitive_score },
                    { label: 'Speech', value: previewReport.speech_score },
                    { label: 'Motor', value: previewReport.motor_score },
                    { label: 'Gait', value: previewReport.gait_score },
                    { label: 'Facial', value: previewReport.facial_score },
                  ].map((c) => (
                    <div key={c.label} className="text-center p-3 rounded-xl bg-dash-bg">
                      <p className="text-lg font-bold text-dash-dark">{c.value != null ? `${Math.round(c.value)}%` : '—'}</p>
                      <p className="text-[10px] text-dash-muted">{c.label}</p>
                    </div>
                  ))}
                </div>
              </div>

              {/* Download */}
              {previewReport.has_pdf && (
                <button onClick={() => handleDownload(previewReport)}
                  className="btn-primary w-full flex items-center justify-center gap-2">
                  <Download className="w-4 h-4" /> Download PDF Report
                </button>
              )}
            </div>
          </motion.div>
        </div>
      )}
    </motion.div>
  );
}

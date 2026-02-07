'use client';

import { useState, useEffect, useCallback, useRef } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
  Stethoscope,
  Search,
  Filter,
  Download,
  MoreHorizontal,
  ChevronLeft,
  ChevronRight,
  CheckCircle2,
  XCircle,
  Clock,
  Eye,
  Star,
  ArrowUpRight,
  ArrowDownRight,
  Shield,
  BadgeCheck,
  AlertCircle,
  X,
  FileText,
  MapPin,
  GraduationCap,
  Building2,
  Users,
  Loader2,
} from 'lucide-react';
import { doctorsApi } from '@/lib/api';

const container = { hidden: { opacity: 0 }, visible: { opacity: 1, transition: { staggerChildren: 0.06 } } };
const item = { hidden: { opacity: 0, y: 12 }, visible: { opacity: 1, y: 0, transition: { duration: 0.4 } } };

type DoctorSummary = {
  id: number;
  email: string;
  first_name: string;
  last_name: string;
  specialization: string;
  hospital_affiliation?: string;
  status: string;
  is_verified: boolean;
  total_patients_viewed: number;
  created_at: string;
};

// Backend statuses: active, inactive, suspended, pending_verification
const STATUS_MAP: Record<string, string> = {
  active: 'active',
  inactive: 'inactive',
  suspended: 'suspended',
  pending_verification: 'pending',
};

function getDisplayStatus(backendStatus: string): string {
  return STATUS_MAP[backendStatus] || backendStatus;
}

function tabToBackendStatus(tab: string): string | undefined {
  const map: Record<string, string> = {
    Active: 'active',
    Pending: 'pending_verification',
    Inactive: 'inactive',
  };
  return map[tab];
}

function formatDate(dateStr: string) {
  try {
    return new Date(dateStr).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
  } catch { return dateStr; }
}

function getInitials(first: string, last: string) {
  return ((first?.[0] || '') + (last?.[0] || '')).toUpperCase() || '?';
}

function formatSpecialization(spec: string) {
  return spec.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
}

const ITEMS_PER_PAGE = 20;

export default function DoctorsPage() {
  const [isLoading, setIsLoading] = useState(true);
  const [doctors, setDoctors] = useState<DoctorSummary[]>([]);
  const [total, setTotal] = useState(0);
  const [search, setSearch] = useState('');
  const [activeTab, setActiveTab] = useState('All');
  const [selectedDoctor, setSelectedDoctor] = useState<DoctorSummary | null>(null);
  const [verifyAction, setVerifyAction] = useState<{ doctor: DoctorSummary; action: 'approve' | 'reject' } | null>(null);
  const [verifyLoading, setVerifyLoading] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [tableLoading, setTableLoading] = useState(false);
  const searchTimeout = useRef<NodeJS.Timeout | null>(null);

  const tabs = ['All', 'Active', 'Pending', 'Inactive'];

  // Fetch doctors from API
  const fetchDoctors = useCallback(async (page: number, searchTerm: string, tab: string) => {
    setTableLoading(true);
    try {
      const params: any = { page, limit: ITEMS_PER_PAGE };
      if (searchTerm.trim()) params.search = searchTerm.trim();
      const backendStatus = tabToBackendStatus(tab);
      if (backendStatus) params.status = backendStatus;
      const data = await doctorsApi.getDoctors(params);
      setDoctors(data.doctors || []);
      setTotal(data.total || 0);
    } catch (err) {
      console.error('Failed to fetch doctors:', err);
      setDoctors([]);
      setTotal(0);
    } finally {
      setTableLoading(false);
      setIsLoading(false);
    }
  }, []);

  // Initial load
  useEffect(() => {
    fetchDoctors(1, '', 'All');
  }, [fetchDoctors]);

  // Tab change
  const handleTabChange = (tab: string) => {
    setActiveTab(tab);
    setCurrentPage(1);
    fetchDoctors(1, search, tab);
  };

  // Debounced search
  const handleSearchChange = (value: string) => {
    setSearch(value);
    if (searchTimeout.current) clearTimeout(searchTimeout.current);
    searchTimeout.current = setTimeout(() => {
      setCurrentPage(1);
      fetchDoctors(1, value, activeTab);
    }, 400);
  };

  // Page change
  const handlePageChange = (page: number) => {
    setCurrentPage(page);
    fetchDoctors(page, search, activeTab);
  };

  const totalPages = Math.max(1, Math.ceil(total / ITEMS_PER_PAGE));
  const pageButtons = (() => {
    const pages: number[] = [];
    const maxShow = 5;
    let start = Math.max(1, currentPage - Math.floor(maxShow / 2));
    let end = Math.min(totalPages, start + maxShow - 1);
    if (end - start + 1 < maxShow) start = Math.max(1, end - maxShow + 1);
    for (let i = start; i <= end; i++) pages.push(i);
    return pages;
  })();

  // Verify / Reject doctor
  const handleVerify = async (doctorId: number, approve: boolean) => {
    setVerifyLoading(true);
    try {
      await doctorsApi.verifyDoctor(doctorId, approve);
      fetchDoctors(currentPage, search, activeTab);
    } catch (err) {
      console.error('Verify doctor failed:', err);
      setDoctors(prev => prev.map(d =>
        d.id === doctorId
          ? { ...d, status: approve ? 'active' : 'inactive', is_verified: approve }
          : d
      ));
    } finally {
      setVerifyLoading(false);
      setVerifyAction(null);
    }
  };

  // Stats from current data
  const activeCount = doctors.filter(d => d.status === 'active').length;
  const pendingCount = doctors.filter(d => d.status === 'pending_verification').length;
  const inactiveCount = doctors.filter(d => d.status === 'inactive' || d.status === 'suspended').length;

  const stats = [
    { title: 'Total Doctors', value: total.toLocaleString(), change: '+6%', up: true, icon: Stethoscope, active: true },
    { title: 'Active', value: activeTab === 'All' ? activeCount.toString() : total.toLocaleString(), change: '+12%', up: true, icon: BadgeCheck, active: false },
    { title: 'Pending Review', value: activeTab === 'All' ? pendingCount.toString() : (activeTab === 'Pending' ? total.toLocaleString() : pendingCount.toString()), change: pendingCount > 0 ? `+${pendingCount}` : '0', up: pendingCount > 0, icon: Clock, active: false },
    { title: 'Inactive', value: activeTab === 'All' ? inactiveCount.toString() : (activeTab === 'Inactive' ? total.toLocaleString() : inactiveCount.toString()), change: '0', up: false, icon: XCircle, active: false },
  ];

  const statusBadge = (status: string) => {
    const displayStatus = getDisplayStatus(status);
    const map: Record<string, { className: string; icon: typeof CheckCircle2; label: string }> = {
      active: { className: 'badge-success', icon: CheckCircle2, label: 'Active' },
      pending: { className: 'badge-warning', icon: Clock, label: 'Pending' },
      inactive: { className: 'badge-error', icon: XCircle, label: 'Inactive' },
      suspended: { className: 'badge-error', icon: AlertCircle, label: 'Suspended' },
    };
    return map[displayStatus] || { className: 'badge-info', icon: AlertCircle, label: displayStatus };
  };

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-[60vh]">
        <div className="w-8 h-8 border-2 border-accent border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  return (
    <motion.div variants={container} initial="hidden" animate="visible" className="space-y-6">
      {/* Header */}
      <motion.div variants={item} className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-dash-dark">Doctor Management</h1>
          <p className="text-sm text-dash-muted mt-1">Verify and manage healthcare professionals</p>
        </div>
        <div className="flex items-center gap-3">
          <button className="btn-secondary flex items-center gap-2 py-2">
            <Download className="w-4 h-4" />
            <span className="text-sm">Export</span>
          </button>
        </div>
      </motion.div>

      {/* Stat Cards */}
      <motion.div variants={item} className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        {stats.map((stat) => (
          <div key={stat.title} className={`card p-5 ${stat.active ? 'bg-accent border-accent' : ''}`}>
            <div className="flex items-start justify-between mb-3">
              <p className={`text-sm font-medium ${stat.active ? 'text-dash-dark' : 'text-dash-muted'}`}>{stat.title}</p>
              <div className={`w-9 h-9 rounded-xl flex items-center justify-center ${stat.active ? 'bg-dash-dark/10' : 'bg-dash-bg'}`}>
                <stat.icon className={`w-4 h-4 ${stat.active ? 'text-dash-dark' : 'text-dash-muted'}`} />
              </div>
            </div>
            <p className="text-3xl font-bold text-dash-dark">{stat.value}</p>
            <div className="flex items-center gap-1 mt-2">
              {stat.up ? <ArrowUpRight className="w-3.5 h-3.5 text-emerald-500" /> : <ArrowDownRight className="w-3.5 h-3.5 text-red-500" />}
              <span className={`text-xs font-semibold ${stat.up ? 'text-emerald-500' : 'text-red-500'}`}>{stat.change}</span>
            </div>
          </div>
        ))}
      </motion.div>

      {/* Filters & Table */}
      <motion.div variants={item} className="card overflow-hidden">
        <div className="px-6 py-4 border-b border-dash-border">
          <div className="flex items-center justify-between flex-wrap gap-4">
            <div className="flex items-center gap-2">
              {tabs.map((tab) => (
                <button
                  key={tab}
                  onClick={() => handleTabChange(tab)}
                  className={`px-3.5 py-1.5 text-xs font-medium rounded-lg transition-all
                    ${activeTab === tab ? 'bg-dash-dark text-white' : 'text-dash-muted hover:bg-dash-bg'}`}
                >
                  {tab}
                  {tab === 'Pending' && pendingCount > 0 && activeTab === 'All' && (
                    <span className="ml-1.5 bg-amber-500 text-white text-[10px] w-4 h-4 rounded-full inline-flex items-center justify-center">
                      {pendingCount}
                    </span>
                  )}
                </button>
              ))}
            </div>
            <div className="flex items-center gap-3">
              <div className="relative">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-dash-muted" />
                <input
                  type="text"
                  value={search}
                  onChange={(e) => handleSearchChange(e.target.value)}
                  placeholder="Search doctors..."
                  className="input pl-10 py-2 w-64"
                />
              </div>
            </div>
          </div>
        </div>

        {/* Table */}
        <div className="relative">
          {tableLoading && (
            <div className="absolute inset-0 bg-white/60 z-10 flex items-center justify-center">
              <Loader2 className="w-6 h-6 text-accent animate-spin" />
            </div>
          )}
          <table className="w-full">
            <thead>
              <tr className="bg-gray-50/50">
                <th className="table-header table-cell text-left">Doctor</th>
                <th className="table-header table-cell text-left">Specialization</th>
                <th className="table-header table-cell text-left">Hospital</th>
                <th className="table-header table-cell text-left">Patients</th>
                <th className="table-header table-cell text-left">Status</th>
                <th className="table-header table-cell text-left">Joined</th>
                <th className="table-header table-cell text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              {doctors.map((doctor) => {
                const badge = statusBadge(doctor.status);
                const fullName = `${doctor.first_name} ${doctor.last_name}`;
                return (
                  <tr key={doctor.id} className="table-row">
                    <td className="table-cell">
                      <div className="flex items-center gap-3">
                        <div className="w-9 h-9 rounded-full bg-purple-50 text-purple-600 flex items-center justify-center text-xs font-semibold flex-shrink-0">
                          {getInitials(doctor.first_name, doctor.last_name)}
                        </div>
                        <div>
                          <span className="font-medium text-dash-dark block">{fullName}</span>
                          <span className="text-xs text-dash-muted">{doctor.email}</span>
                        </div>
                      </div>
                    </td>
                    <td className="table-cell">
                      <span className="text-xs font-medium px-2.5 py-1 rounded-lg bg-accent/10 text-accent-dark">
                        {formatSpecialization(doctor.specialization)}
                      </span>
                    </td>
                    <td className="table-cell">
                      <span className="text-sm text-dash-muted truncate max-w-[160px] block">
                        {doctor.hospital_affiliation || '—'}
                      </span>
                    </td>
                    <td className="table-cell text-dash-dark font-medium">{doctor.total_patients_viewed}</td>
                    <td className="table-cell">
                      <span className={`${badge.className} capitalize inline-flex items-center gap-1`}>
                        <badge.icon className="w-3 h-3" />
                        {badge.label}
                      </span>
                    </td>
                    <td className="table-cell text-sm text-dash-muted">{formatDate(doctor.created_at)}</td>
                    <td className="table-cell text-right">
                      <div className="flex items-center justify-end gap-1">
                        {doctor.status === 'pending_verification' && (
                          <>
                            <button
                              onClick={() => setVerifyAction({ doctor, action: 'approve' })}
                              className="p-2 hover:bg-emerald-50 rounded-lg transition-colors"
                              title="Approve"
                            >
                              <CheckCircle2 className="w-4 h-4 text-emerald-500" />
                            </button>
                            <button
                              onClick={() => setVerifyAction({ doctor, action: 'reject' })}
                              className="p-2 hover:bg-red-50 rounded-lg transition-colors"
                              title="Reject"
                            >
                              <XCircle className="w-4 h-4 text-red-500" />
                            </button>
                          </>
                        )}
                        <button onClick={() => setSelectedDoctor(doctor)} className="p-2 hover:bg-dash-bg rounded-lg transition-colors" title="View">
                          <Eye className="w-4 h-4 text-dash-muted" />
                        </button>
                        <button className="p-2 hover:bg-dash-bg rounded-lg transition-colors" title="More">
                          <MoreHorizontal className="w-4 h-4 text-dash-muted" />
                        </button>
                      </div>
                    </td>
                  </tr>
                );
              })}
              {doctors.length === 0 && (
                <tr>
                  <td colSpan={7} className="py-16 text-center">
                    <Stethoscope className="w-10 h-10 text-dash-border mx-auto mb-3" />
                    <p className="text-sm font-medium text-dash-muted">No doctors found</p>
                    <p className="text-xs text-dash-muted/70 mt-1">Try adjusting your search or filters</p>
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination */}
        <div className="px-6 py-4 border-t border-dash-border flex items-center justify-between">
          <p className="text-xs text-dash-muted">
            {total > 0 ? `Showing ${(currentPage - 1) * ITEMS_PER_PAGE + 1}–${Math.min(currentPage * ITEMS_PER_PAGE, total)} of ${total} doctors` : 'No doctors'}
          </p>
          {totalPages > 1 && (
            <div className="flex items-center gap-1">
              <button
                onClick={() => handlePageChange(Math.max(1, currentPage - 1))}
                disabled={currentPage === 1}
                className="p-2 hover:bg-dash-bg rounded-lg transition-colors disabled:opacity-40"
              >
                <ChevronLeft className="w-4 h-4 text-dash-muted" />
              </button>
              {pageButtons[0] > 1 && (
                <>
                  <button onClick={() => handlePageChange(1)} className="w-8 h-8 flex items-center justify-center rounded-lg text-xs font-medium text-dash-muted hover:bg-dash-bg">1</button>
                  {pageButtons[0] > 2 && <span className="text-dash-muted text-xs px-1">…</span>}
                </>
              )}
              {pageButtons.map((page) => (
                <button
                  key={page}
                  onClick={() => handlePageChange(page)}
                  className={`w-8 h-8 flex items-center justify-center rounded-lg text-xs font-medium transition-all
                    ${currentPage === page ? 'bg-dash-dark text-white' : 'text-dash-muted hover:bg-dash-bg'}`}
                >
                  {page}
                </button>
              ))}
              {pageButtons[pageButtons.length - 1] < totalPages && (
                <>
                  {pageButtons[pageButtons.length - 1] < totalPages - 1 && <span className="text-dash-muted text-xs px-1">…</span>}
                  <button onClick={() => handlePageChange(totalPages)} className="w-8 h-8 flex items-center justify-center rounded-lg text-xs font-medium text-dash-muted hover:bg-dash-bg">{totalPages}</button>
                </>
              )}
              <button
                onClick={() => handlePageChange(Math.min(totalPages, currentPage + 1))}
                disabled={currentPage === totalPages}
                className="p-2 hover:bg-dash-bg rounded-lg transition-colors disabled:opacity-40"
              >
                <ChevronRight className="w-4 h-4 text-dash-muted" />
              </button>
            </div>
          )}
        </div>
      </motion.div>

      {/* Verification Confirmation Modal */}
      <AnimatePresence>
        {verifyAction && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-50 flex items-center justify-center p-4"
          >
            <div className="absolute inset-0 bg-black/20" onClick={() => !verifyLoading && setVerifyAction(null)} />
            <motion.div
              initial={{ scale: 0.95, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.95, opacity: 0 }}
              className="relative bg-white rounded-2xl shadow-elevated p-6 w-full max-w-sm"
            >
              <div className={`w-14 h-14 rounded-2xl flex items-center justify-center mx-auto mb-4
                ${verifyAction.action === 'approve' ? 'bg-emerald-50' : 'bg-red-50'}`}>
                {verifyAction.action === 'approve'
                  ? <CheckCircle2 className="w-7 h-7 text-emerald-500" />
                  : <XCircle className="w-7 h-7 text-red-500" />}
              </div>
              <h3 className="text-lg font-bold text-dash-dark text-center">
                {verifyAction.action === 'approve' ? 'Approve Doctor' : 'Reject Doctor'}
              </h3>
              <p className="text-sm text-dash-muted text-center mt-2">
                Are you sure you want to {verifyAction.action}{' '}
                <strong>{verifyAction.doctor.first_name} {verifyAction.doctor.last_name}</strong>?
              </p>
              <div className="flex items-center gap-3 mt-6">
                <button onClick={() => setVerifyAction(null)} disabled={verifyLoading} className="btn-secondary flex-1">
                  Cancel
                </button>
                <button
                  onClick={() => handleVerify(verifyAction.doctor.id, verifyAction.action === 'approve')}
                  disabled={verifyLoading}
                  className={`flex-1 px-5 py-2.5 rounded-xl text-sm font-semibold transition-all inline-flex items-center justify-center gap-2
                    ${verifyAction.action === 'approve'
                      ? 'bg-emerald-500 hover:bg-emerald-600 text-white'
                      : 'bg-red-500 hover:bg-red-600 text-white'}`}
                >
                  {verifyLoading && <Loader2 className="w-4 h-4 animate-spin" />}
                  {verifyAction.action === 'approve' ? 'Approve' : 'Reject'}
                </button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Doctor Detail Side Panel */}
      <AnimatePresence>
        {selectedDoctor && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-50 flex justify-end"
          >
            <div className="absolute inset-0 bg-black/20" onClick={() => setSelectedDoctor(null)} />
            <motion.div
              initial={{ x: 400 }}
              animate={{ x: 0 }}
              exit={{ x: 400 }}
              transition={{ type: 'spring', damping: 30, stiffness: 300 }}
              className="relative w-full max-w-md bg-white shadow-elevated h-full overflow-y-auto"
            >
              <div className="p-6">
                <div className="flex items-center justify-between mb-8">
                  <h2 className="text-lg font-bold text-dash-dark">Doctor Profile</h2>
                  <button onClick={() => setSelectedDoctor(null)} className="p-2 hover:bg-dash-bg rounded-lg transition-colors">
                    <X className="w-5 h-5 text-dash-muted" />
                  </button>
                </div>

                {/* Profile */}
                <div className="text-center mb-8">
                  <div className="w-20 h-20 rounded-full bg-purple-50 text-purple-600 flex items-center justify-center text-2xl font-bold mx-auto mb-4">
                    {getInitials(selectedDoctor.first_name, selectedDoctor.last_name)}
                  </div>
                  <h3 className="text-lg font-bold text-dash-dark">
                    {selectedDoctor.first_name} {selectedDoctor.last_name}
                  </h3>
                  <p className="text-sm text-dash-muted">{selectedDoctor.email}</p>
                  <div className="flex items-center justify-center gap-2 mt-2">
                    {(() => {
                      const badge = statusBadge(selectedDoctor.status);
                      return (
                        <span className={`${badge.className} capitalize inline-flex items-center gap-1`}>
                          {badge.label}
                        </span>
                      );
                    })()}
                    {selectedDoctor.is_verified && (
                      <span className="inline-flex items-center gap-1 text-xs font-medium bg-emerald-50 text-emerald-600 px-2.5 py-1 rounded-lg">
                        <BadgeCheck className="w-3 h-3" />
                        Verified
                      </span>
                    )}
                  </div>
                </div>

                {/* Info */}
                <div className="space-y-4">
                  {[
                    { icon: Stethoscope, label: 'Specialization', value: formatSpecialization(selectedDoctor.specialization) },
                    { icon: Building2, label: 'Hospital', value: selectedDoctor.hospital_affiliation || 'N/A' },
                    { icon: Users, label: 'Patients Viewed', value: selectedDoctor.total_patients_viewed.toString() },
                    { icon: GraduationCap, label: 'Joined', value: formatDate(selectedDoctor.created_at) },
                  ].map((field) => (
                    <div key={field.label} className="flex items-center gap-3 py-3 border-b border-dash-border">
                      <div className="w-8 h-8 rounded-lg bg-dash-bg flex items-center justify-center flex-shrink-0">
                        <field.icon className="w-4 h-4 text-dash-muted" />
                      </div>
                      <div className="flex-1">
                        <p className="text-xs text-dash-muted">{field.label}</p>
                        <p className="text-sm font-medium text-dash-dark">{field.value}</p>
                      </div>
                    </div>
                  ))}
                </div>

                {/* Actions */}
                <div className="mt-8 space-y-3">
                  {selectedDoctor.status === 'pending_verification' && (
                    <>
                      <button
                        onClick={() => { setSelectedDoctor(null); setVerifyAction({ doctor: selectedDoctor, action: 'approve' }); }}
                        className="w-full px-5 py-2.5 rounded-xl text-sm font-semibold bg-emerald-500 hover:bg-emerald-600 text-white transition-all"
                      >
                        Approve Doctor
                      </button>
                      <button
                        onClick={() => { setSelectedDoctor(null); setVerifyAction({ doctor: selectedDoctor, action: 'reject' }); }}
                        className="w-full px-5 py-2.5 rounded-xl text-sm font-semibold border border-red-200 text-red-600 hover:bg-red-50 transition-all"
                      >
                        Reject Doctor
                      </button>
                    </>
                  )}
                  <button className="btn-primary w-full">Send Message</button>
                  <button className="btn-secondary w-full">View Full Profile</button>
                </div>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </motion.div>
  );
}

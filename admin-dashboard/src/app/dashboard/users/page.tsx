'use client';

import { useState, useEffect, useCallback, useRef } from 'react';
import { motion } from 'framer-motion';
import {
  Users,
  Search,
  Filter,
  Download,
  MoreHorizontal,
  ChevronLeft,
  ChevronRight,
  UserPlus,
  UserCheck,
  UserX,
  Eye,
  Mail,
  Shield,
  ArrowUpRight,
  ArrowDownRight,
  Calendar,
  X,
  Activity,
  Brain,
  FlaskConical,
  Loader2,
} from 'lucide-react';
import { usersApi } from '@/lib/api';

const container = { hidden: { opacity: 0 }, visible: { opacity: 1, transition: { staggerChildren: 0.06 } } };
const item = { hidden: { opacity: 0, y: 12 }, visible: { opacity: 1, y: 0, transition: { duration: 0.4 } } };

type UserSummary = {
  id: number;
  email: string;
  first_name: string;
  last_name: string;
  is_verified: boolean;
  ad_risk_score: number;
  pd_risk_score: number;
  total_tests: number;
  created_at: string;
  last_active?: string;
};

function formatDate(dateStr: string) {
  try {
    return new Date(dateStr).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
  } catch { return dateStr; }
}

function formatLastActive(dateStr?: string) {
  if (!dateStr) return 'Never';
  try {
    const d = new Date(dateStr);
    const now = new Date();
    const diffMs = now.getTime() - d.getTime();
    const diffMin = Math.floor(diffMs / 60000);
    if (diffMin < 1) return 'Just now';
    if (diffMin < 60) return `${diffMin}m ago`;
    const diffH = Math.floor(diffMin / 60);
    if (diffH < 24) return `${diffH}h ago`;
    const diffD = Math.floor(diffH / 24);
    if (diffD < 7) return `${diffD}d ago`;
    if (diffD < 30) return `${Math.floor(diffD / 7)}w ago`;
    return formatDate(dateStr);
  } catch { return dateStr; }
}

function getInitials(first: string, last: string) {
  return ((first?.[0] || '') + (last?.[0] || '')).toUpperCase() || '?';
}

function getUserStatus(u: UserSummary): string {
  if (!u.is_verified) return 'unverified';
  if (u.last_active) {
    const diff = Date.now() - new Date(u.last_active).getTime();
    if (diff > 30 * 24 * 60 * 60 * 1000) return 'inactive';
  }
  return 'active';
}

const ITEMS_PER_PAGE = 20;

export default function UsersPage() {
  const [isLoading, setIsLoading] = useState(true);
  const [users, setUsers] = useState<UserSummary[]>([]);
  const [total, setTotal] = useState(0);
  const [search, setSearch] = useState('');
  const [activeTab, setActiveTab] = useState('All');
  const [verifiedFilter, setVerifiedFilter] = useState<boolean | undefined>(undefined);
  const [selectedUser, setSelectedUser] = useState<UserSummary | null>(null);
  const [currentPage, setCurrentPage] = useState(1);
  const [tableLoading, setTableLoading] = useState(false);
  const searchTimeout = useRef<NodeJS.Timeout | null>(null);

  const tabs = ['All', 'Verified', 'Unverified'];

  // Fetch users from API
  const fetchUsers = useCallback(async (page: number, searchTerm: string, isVerified?: boolean) => {
    setTableLoading(true);
    try {
      const params: any = { page, limit: ITEMS_PER_PAGE };
      if (searchTerm.trim()) params.search = searchTerm.trim();
      if (isVerified !== undefined) params.is_verified = isVerified;
      const data = await usersApi.getUsers(params);
      setUsers(data.users || []);
      setTotal(data.total || 0);
    } catch (err) {
      console.error('Failed to fetch users:', err);
      setUsers([]);
      setTotal(0);
    } finally {
      setTableLoading(false);
      setIsLoading(false);
    }
  }, []);

  // Initial load
  useEffect(() => {
    fetchUsers(1, '', undefined);
  }, [fetchUsers]);

  // Refetch on tab change
  const handleTabChange = (tab: string) => {
    setActiveTab(tab);
    setCurrentPage(1);
    const isVerified = tab === 'Verified' ? true : tab === 'Unverified' ? false : undefined;
    setVerifiedFilter(isVerified);
    fetchUsers(1, search, isVerified);
  };

  // Debounced search
  const handleSearchChange = (value: string) => {
    setSearch(value);
    if (searchTimeout.current) clearTimeout(searchTimeout.current);
    searchTimeout.current = setTimeout(() => {
      setCurrentPage(1);
      fetchUsers(1, value, verifiedFilter);
    }, 400);
  };

  // Page change
  const handlePageChange = (page: number) => {
    setCurrentPage(page);
    fetchUsers(page, search, verifiedFilter);
  };

  const totalPages = Math.max(1, Math.ceil(total / ITEMS_PER_PAGE));
  const startItem = (currentPage - 1) * ITEMS_PER_PAGE + 1;
  const endItem = Math.min(currentPage * ITEMS_PER_PAGE, total);

  // Compute page buttons
  const pageButtons = (() => {
    const pages: number[] = [];
    const maxShow = 5;
    let start = Math.max(1, currentPage - Math.floor(maxShow / 2));
    let end = Math.min(totalPages, start + maxShow - 1);
    if (end - start + 1 < maxShow) start = Math.max(1, end - maxShow + 1);
    for (let i = start; i <= end; i++) pages.push(i);
    return pages;
  })();

  // Stats derived from total + current page data
  const verifiedCount = users.filter(u => u.is_verified).length;
  const unverifiedCount = users.filter(u => !u.is_verified).length;
  const avgTests = users.length > 0 ? Math.round(users.reduce((s, u) => s + (u.total_tests || 0), 0) / users.length) : 0;

  const stats = [
    { title: 'Total Users', value: total.toLocaleString(), change: '+12%', up: true, icon: Users, active: true },
    { title: 'Verified', value: activeTab === 'All' ? verifiedCount.toString() : total.toLocaleString(), change: '+8.2%', up: true, icon: UserCheck, active: false },
    { title: 'Avg Tests', value: avgTests.toString(), change: '+18%', up: true, icon: FlaskConical, active: false },
    { title: 'Unverified', value: unverifiedCount.toString(), change: unverifiedCount > 0 ? `${unverifiedCount} pending` : '0', up: unverifiedCount === 0, icon: UserX, active: false },
  ];

  const statusBadge = (status: string) => {
    const map: Record<string, string> = {
      active: 'badge-success',
      verified: 'badge-success',
      unverified: 'badge-warning',
      inactive: 'badge-info',
    };
    return map[status] || 'badge-info';
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
          <h1 className="text-2xl font-bold text-dash-dark">User Management</h1>
          <p className="text-sm text-dash-muted mt-1">Manage all registered users on the platform</p>
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
            {/* Tabs */}
            <div className="flex items-center gap-2">
              {tabs.map((tab) => (
                <button
                  key={tab}
                  onClick={() => handleTabChange(tab)}
                  className={`px-3.5 py-1.5 text-xs font-medium rounded-lg transition-all
                    ${activeTab === tab ? 'bg-dash-dark text-white' : 'text-dash-muted hover:bg-dash-bg'}`}
                >
                  {tab}
                </button>
              ))}
            </div>
            {/* Search */}
            <div className="flex items-center gap-3">
              <div className="relative">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-dash-muted" />
                <input
                  type="text"
                  value={search}
                  onChange={(e) => handleSearchChange(e.target.value)}
                  placeholder="Search by name or email..."
                  className="input pl-10 py-2 w-64"
                />
                {search && (
                  <button
                    onClick={() => { setSearch(''); setCurrentPage(1); fetchUsers(1, '', verifiedFilter); }}
                    className="absolute right-3 top-1/2 -translate-y-1/2 p-0.5 hover:bg-dash-bg rounded"
                  >
                    <X className="w-3.5 h-3.5 text-dash-muted" />
                  </button>
                )}
              </div>
            </div>
          </div>
        </div>

        {/* Loading overlay */}
        {tableLoading && (
          <div className="flex items-center justify-center py-3 bg-accent/5">
            <Loader2 className="w-4 h-4 animate-spin text-accent-dark mr-2" />
            <span className="text-xs text-dash-muted">Loading...</span>
          </div>
        )}

        {/* Table */}
        <table className="w-full">
          <thead>
            <tr className="bg-gray-50/50">
              <th className="table-header table-cell text-left">
                <input type="checkbox" className="w-4 h-4 rounded border-dash-border accent-accent" />
              </th>
              <th className="table-header table-cell text-left">User</th>
              <th className="table-header table-cell text-left">Email</th>
              <th className="table-header table-cell text-left">Status</th>
              <th className="table-header table-cell text-left">Tests</th>
              <th className="table-header table-cell text-left">AD Risk</th>
              <th className="table-header table-cell text-left">PD Risk</th>
              <th className="table-header table-cell text-left">Joined</th>
              <th className="table-header table-cell text-left">Last Active</th>
              <th className="table-header table-cell text-right">Actions</th>
            </tr>
          </thead>
          <tbody>
            {users.map((user) => {
              const status = getUserStatus(user);
              const fullName = `${user.first_name || ''} ${user.last_name || ''}`.trim() || 'Unknown';
              return (
                <tr key={user.id} className="table-row">
                  <td className="table-cell">
                    <input type="checkbox" className="w-4 h-4 rounded border-dash-border accent-accent" />
                  </td>
                  <td className="table-cell">
                    <div className="flex items-center gap-3">
                      <div className="w-9 h-9 rounded-full bg-dash-bg text-dash-dark flex items-center justify-center text-xs font-semibold flex-shrink-0">
                        {getInitials(user.first_name, user.last_name)}
                      </div>
                      <span className="font-medium text-dash-dark">{fullName}</span>
                    </div>
                  </td>
                  <td className="table-cell text-dash-muted text-sm">{user.email}</td>
                  <td className="table-cell">
                    <span className={`${statusBadge(status)} capitalize`}>{status}</span>
                  </td>
                  <td className="table-cell">
                    <span className="text-sm font-medium text-dash-dark">{user.total_tests || 0}</span>
                  </td>
                  <td className="table-cell">
                    {user.ad_risk_score != null && user.ad_risk_score > 0 ? (
                      <span className={`text-xs font-semibold px-2 py-0.5 rounded-lg
                        ${user.ad_risk_score >= 70 ? 'bg-red-50 text-red-600' :
                          user.ad_risk_score >= 40 ? 'bg-amber-50 text-amber-600' :
                          'bg-emerald-50 text-emerald-600'}`}>
                        {user.ad_risk_score}%
                      </span>
                    ) : (
                      <span className="text-xs text-dash-muted">—</span>
                    )}
                  </td>
                  <td className="table-cell">
                    {user.pd_risk_score != null && user.pd_risk_score > 0 ? (
                      <span className={`text-xs font-semibold px-2 py-0.5 rounded-lg
                        ${user.pd_risk_score >= 70 ? 'bg-red-50 text-red-600' :
                          user.pd_risk_score >= 40 ? 'bg-amber-50 text-amber-600' :
                          'bg-emerald-50 text-emerald-600'}`}>
                        {user.pd_risk_score}%
                      </span>
                    ) : (
                      <span className="text-xs text-dash-muted">—</span>
                    )}
                  </td>
                  <td className="table-cell text-dash-muted text-sm">{formatDate(user.created_at)}</td>
                  <td className="table-cell text-dash-muted text-xs">{formatLastActive(user.last_active)}</td>
                  <td className="table-cell text-right">
                    <div className="flex items-center justify-end gap-1">
                      <button onClick={() => setSelectedUser(user)} className="p-2 hover:bg-dash-bg rounded-lg transition-colors" title="View Details">
                        <Eye className="w-4 h-4 text-dash-muted" />
                      </button>
                      <button className="p-2 hover:bg-dash-bg rounded-lg transition-colors" title="Email User">
                        <Mail className="w-4 h-4 text-dash-muted" />
                      </button>
                    </div>
                  </td>
                </tr>
              );
            })}
            {users.length === 0 && !tableLoading && (
              <tr>
                <td colSpan={10} className="py-16 text-center">
                  <Users className="w-10 h-10 text-dash-border mx-auto mb-3" />
                  <p className="text-sm font-medium text-dash-dark">No users found</p>
                  <p className="text-xs text-dash-muted mt-1">
                    {search ? 'Try a different search term' : 'No users registered yet'}
                  </p>
                </td>
              </tr>
            )}
          </tbody>
        </table>

        {/* Pagination */}
        {total > 0 && (
          <div className="px-6 py-4 border-t border-dash-border flex items-center justify-between">
            <p className="text-xs text-dash-muted">
              Showing {startItem}–{endItem} of {total.toLocaleString()} users
            </p>
            <div className="flex items-center gap-1">
              <button
                onClick={() => handlePageChange(Math.max(1, currentPage - 1))}
                disabled={currentPage <= 1}
                className="p-2 hover:bg-dash-bg rounded-lg transition-colors disabled:opacity-30"
              >
                <ChevronLeft className="w-4 h-4 text-dash-muted" />
              </button>
              {pageButtons[0] > 1 && (
                <>
                  <button onClick={() => handlePageChange(1)} className="w-8 h-8 flex items-center justify-center rounded-lg text-xs font-medium text-dash-muted hover:bg-dash-bg">1</button>
                  {pageButtons[0] > 2 && <span className="text-xs text-dash-muted px-1">…</span>}
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
                  {pageButtons[pageButtons.length - 1] < totalPages - 1 && <span className="text-xs text-dash-muted px-1">…</span>}
                  <button onClick={() => handlePageChange(totalPages)} className="w-8 h-8 flex items-center justify-center rounded-lg text-xs font-medium text-dash-muted hover:bg-dash-bg">{totalPages}</button>
                </>
              )}
              <button
                onClick={() => handlePageChange(Math.min(totalPages, currentPage + 1))}
                disabled={currentPage >= totalPages}
                className="p-2 hover:bg-dash-bg rounded-lg transition-colors disabled:opacity-30"
              >
                <ChevronRight className="w-4 h-4 text-dash-muted" />
              </button>
            </div>
          </div>
        )}
      </motion.div>

      {/* User Detail Side Panel */}
      {selectedUser && (() => {
        const u = selectedUser;
        const fullName = `${u.first_name || ''} ${u.last_name || ''}`.trim() || 'Unknown';
        const status = getUserStatus(u);
        return (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            className="fixed inset-0 z-50 flex justify-end"
          >
            <div className="absolute inset-0 bg-black/20" onClick={() => setSelectedUser(null)} />
            <motion.div
              initial={{ x: 400 }}
              animate={{ x: 0 }}
              transition={{ type: 'spring', damping: 30, stiffness: 300 }}
              className="relative w-full max-w-md bg-white shadow-elevated h-full overflow-y-auto"
            >
              <div className="p-6">
                <div className="flex items-center justify-between mb-8">
                  <h2 className="text-lg font-bold text-dash-dark">User Details</h2>
                  <button onClick={() => setSelectedUser(null)} className="p-2 hover:bg-dash-bg rounded-lg transition-colors">
                    <X className="w-5 h-5 text-dash-muted" />
                  </button>
                </div>

                {/* Profile */}
                <div className="text-center mb-8">
                  <div className="w-20 h-20 rounded-full bg-accent/20 text-dash-dark flex items-center justify-center text-2xl font-bold mx-auto mb-4">
                    {getInitials(u.first_name, u.last_name)}
                  </div>
                  <h3 className="text-lg font-bold text-dash-dark">{fullName}</h3>
                  <p className="text-sm text-dash-muted">{u.email}</p>
                  <span className={`inline-block mt-2 ${statusBadge(status)} capitalize`}>{status}</span>
                </div>

                {/* Info Grid */}
                <div className="space-y-0">
                  {[
                    { label: 'User ID', value: u.id },
                    { label: 'Verified', value: u.is_verified ? 'Yes' : 'No' },
                    { label: 'Joined', value: formatDate(u.created_at) },
                    { label: 'Last Active', value: formatLastActive(u.last_active) },
                    { label: 'Total Tests', value: (u.total_tests || 0).toString() },
                  ].map((field) => (
                    <div key={field.label} className="flex items-center justify-between py-3 border-b border-dash-border">
                      <span className="text-sm text-dash-muted">{field.label}</span>
                      <span className="text-sm font-medium text-dash-dark">{field.value}</span>
                    </div>
                  ))}
                </div>

                {/* Risk Scores */}
                <div className="mt-6 space-y-3">
                  <h4 className="text-sm font-semibold text-dash-dark">Risk Assessment</h4>
                  <div className="grid grid-cols-2 gap-3">
                    <div className="p-4 rounded-xl bg-dash-bg">
                      <div className="flex items-center gap-2 mb-2">
                        <Brain className="w-4 h-4 text-purple-500" />
                        <span className="text-xs text-dash-muted">AD Risk</span>
                      </div>
                      <p className={`text-2xl font-bold ${
                        (u.ad_risk_score || 0) >= 70 ? 'text-red-600' :
                        (u.ad_risk_score || 0) >= 40 ? 'text-amber-600' :
                        'text-emerald-600'
                      }`}>
                        {u.ad_risk_score != null ? `${u.ad_risk_score}%` : '—'}
                      </p>
                    </div>
                    <div className="p-4 rounded-xl bg-dash-bg">
                      <div className="flex items-center gap-2 mb-2">
                        <Activity className="w-4 h-4 text-blue-500" />
                        <span className="text-xs text-dash-muted">PD Risk</span>
                      </div>
                      <p className={`text-2xl font-bold ${
                        (u.pd_risk_score || 0) >= 70 ? 'text-red-600' :
                        (u.pd_risk_score || 0) >= 40 ? 'text-amber-600' :
                        'text-emerald-600'
                      }`}>
                        {u.pd_risk_score != null ? `${u.pd_risk_score}%` : '—'}
                      </p>
                    </div>
                  </div>
                </div>

                {/* Actions */}
                <div className="mt-8 space-y-3">
                  <button className="btn-primary w-full flex items-center justify-center gap-2">
                    <Mail className="w-4 h-4" />
                    Send Email
                  </button>
                  <button className="btn-secondary w-full flex items-center justify-center gap-2">
                    <Shield className="w-4 h-4" />
                    Manage Permissions
                  </button>
                </div>
              </div>
            </motion.div>
          </motion.div>
        );
      })()}
    </motion.div>
  );
}

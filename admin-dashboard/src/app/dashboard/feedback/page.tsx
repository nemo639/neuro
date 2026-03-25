'use client';

import { useState, useEffect, useCallback } from 'react';
import { motion } from 'framer-motion';
import {
  MessageSquareText,
  Search,
  Star,
  Clock,
  CheckCircle2,
  AlertCircle,
  Loader2,
  RefreshCw,
  Trash2,
  ChevronLeft,
  ChevronRight,
  User,
  Tag,
  StickyNote,
  Send,
} from 'lucide-react';
import { feedbackApi } from '@/lib/api';

const container = { hidden: { opacity: 0 }, visible: { opacity: 1, transition: { staggerChildren: 0.06 } } };
const item = { hidden: { opacity: 0, y: 12 }, visible: { opacity: 1, y: 0, transition: { duration: 0.4 } } };

type FeedbackItem = {
  id: number;
  user_id: number;
  category: string;
  rating: number | null;
  message: string;
  status: string;
  admin_notes: string | null;
  app_version: string | null;
  device_info: string | null;
  created_at: string;
  updated_at: string | null;
  resolved_at: string | null;
  user_email?: string;
  user_name?: string;
};

type FeedbackStats = {
  total_feedbacks: number;
  pending_count: number;
  resolved_count: number;
  average_rating: number | null;
  category_breakdown: Record<string, number>;
};

const statusColors: Record<string, string> = {
  pending: 'bg-amber-50 text-amber-700 border-amber-200',
  reviewed: 'bg-blue-50 text-blue-700 border-blue-200',
  in_progress: 'bg-purple-50 text-purple-700 border-purple-200',
  resolved: 'bg-emerald-50 text-emerald-700 border-emerald-200',
  closed: 'bg-gray-50 text-gray-600 border-gray-200',
};

const categoryLabels: Record<string, string> = {
  general: 'General',
  bug_report: 'Bug Report',
  feature_request: 'Feature Request',
  ui_ux: 'UI/UX',
  test_quality: 'Test Quality',
  performance: 'Performance',
  other: 'Other',
};

const statusOptions = ['pending', 'reviewed', 'in_progress', 'resolved', 'closed'];

export default function FeedbackPage() {
  const [isLoading, setIsLoading] = useState(true);
  const [feedbacks, setFeedbacks] = useState<FeedbackItem[]>([]);
  const [stats, setStats] = useState<FeedbackStats | null>(null);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const perPage = 15;

  const [activeTab, setActiveTab] = useState('All');
  const [categoryFilter, setCategoryFilter] = useState('');
  const [search, setSearch] = useState('');

  const [selectedFeedback, setSelectedFeedback] = useState<FeedbackItem | null>(null);
  const [adminNotes, setAdminNotes] = useState('');
  const [newStatus, setNewStatus] = useState('');
  const [updating, setUpdating] = useState(false);
  const [deleting, setDeleting] = useState(false);

  const tabs = ['All', 'Pending', 'Reviewed', 'In Progress', 'Resolved', 'Closed'];

  const loadFeedbacks = useCallback(async (statusFilter?: string, p = 1) => {
    setIsLoading(true);
    try {
      const params: Record<string, string | number> = { page: p, per_page: perPage };
      if (statusFilter && statusFilter !== 'All') {
        const map: Record<string, string> = {
          Pending: 'pending',
          Reviewed: 'reviewed',
          'In Progress': 'in_progress',
          Resolved: 'resolved',
          Closed: 'closed',
        };
        params.status = map[statusFilter] || '';
      }
      if (categoryFilter) params.category = categoryFilter;
      const data = await feedbackApi.getAll(params as any);
      setFeedbacks(data.feedbacks || []);
      setTotal(data.total || 0);
      setPage(data.page || 1);
      setTotalPages(data.total_pages || 1);
    } catch (err) {
      console.error('Failed to load feedbacks', err);
      setFeedbacks([]);
    } finally {
      setIsLoading(false);
    }
  }, [categoryFilter]);

  const loadStats = useCallback(async () => {
    try {
      const data = await feedbackApi.getStats();
      setStats(data);
    } catch (err) {
      console.error('Failed to load stats', err);
    }
  }, []);

  useEffect(() => {
    loadFeedbacks(activeTab, 1);
    loadStats();
  }, [activeTab, loadFeedbacks, loadStats]);

  const handleUpdate = async () => {
    if (!selectedFeedback) return;
    setUpdating(true);
    try {
      const updateData: Record<string, string> = {};
      if (newStatus && newStatus !== selectedFeedback.status) updateData.status = newStatus;
      if (adminNotes.trim()) updateData.admin_notes = adminNotes.trim();
      if (Object.keys(updateData).length === 0) {
        setUpdating(false);
        return;
      }
      await feedbackApi.update(selectedFeedback.id, updateData);
      setSelectedFeedback(null);
      setAdminNotes('');
      setNewStatus('');
      loadFeedbacks(activeTab, page);
      loadStats();
    } catch (err) {
      console.error('Failed to update feedback', err);
    } finally {
      setUpdating(false);
    }
  };

  const handleDelete = async (id: number) => {
    if (!confirm('Are you sure you want to delete this feedback?')) return;
    setDeleting(true);
    try {
      await feedbackApi.delete(id);
      setSelectedFeedback(null);
      loadFeedbacks(activeTab, page);
      loadStats();
    } catch (err) {
      console.error('Failed to delete feedback', err);
    } finally {
      setDeleting(false);
    }
  };

  const openDetail = (fb: FeedbackItem) => {
    setSelectedFeedback(fb);
    setAdminNotes(fb.admin_notes || '');
    setNewStatus(fb.status);
  };

  const filtered = search
    ? feedbacks.filter(
        (f) =>
          f.message.toLowerCase().includes(search.toLowerCase()) ||
          (f.user_email || '').toLowerCase().includes(search.toLowerCase()) ||
          (f.user_name || '').toLowerCase().includes(search.toLowerCase())
      )
    : feedbacks;

  const formatDate = (dateStr: string) => {
    const d = new Date(dateStr);
    return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Feedback Management</h1>
          <p className="text-sm text-gray-500 dark:text-gray-400 mt-1">
            Review and respond to user feedback ({total} total)
          </p>
        </div>
        <button
          onClick={() => { loadFeedbacks(activeTab, page); loadStats(); }}
          className="flex items-center gap-2 px-4 py-2 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-xl hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors text-sm font-medium text-gray-700 dark:text-gray-300"
        >
          <RefreshCw size={16} />
          Refresh
        </button>
      </div>

      {/* Stats Cards */}
      {stats && (
        <motion.div variants={container} initial="hidden" animate="visible" className="grid grid-cols-2 sm:grid-cols-4 gap-4">
          {[
            { label: 'Total', value: stats.total_feedbacks, icon: MessageSquareText, color: 'text-gray-700 dark:text-gray-300', bg: 'bg-gray-50 dark:bg-gray-800' },
            { label: 'Pending', value: stats.pending_count, icon: Clock, color: 'text-amber-600', bg: 'bg-amber-50 dark:bg-amber-900/20' },
            { label: 'Resolved', value: stats.resolved_count, icon: CheckCircle2, color: 'text-emerald-600', bg: 'bg-emerald-50 dark:bg-emerald-900/20' },
            { label: 'Avg Rating', value: stats.average_rating ? stats.average_rating.toFixed(1) : 'N/A', icon: Star, color: 'text-yellow-600', bg: 'bg-yellow-50 dark:bg-yellow-900/20' },
          ].map((s) => (
            <motion.div key={s.label} variants={item} className={`${s.bg} rounded-xl p-4 border border-gray-100 dark:border-gray-700`}>
              <div className="flex items-center gap-2 mb-2">
                <s.icon size={16} className={s.color} />
                <span className="text-xs font-medium text-gray-500 dark:text-gray-400">{s.label}</span>
              </div>
              <p className={`text-xl font-bold ${s.color}`}>{s.value}</p>
            </motion.div>
          ))}
        </motion.div>
      )}

      {/* Tabs + Search */}
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div className="flex gap-1 bg-gray-100 dark:bg-gray-800 rounded-xl p-1 overflow-x-auto">
          {tabs.map((tab) => (
            <button
              key={tab}
              onClick={() => { setActiveTab(tab); setPage(1); }}
              className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-all whitespace-nowrap ${
                activeTab === tab
                  ? 'bg-white dark:bg-gray-700 text-gray-900 dark:text-white shadow-sm'
                  : 'text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300'
              }`}
            >
              {tab}
            </button>
          ))}
        </div>
        <div className="relative w-full sm:w-72">
          <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
          <input
            type="text"
            placeholder="Search feedback..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-full pl-9 pr-4 py-2 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500/30"
          />
        </div>
      </div>

      {/* Content */}
      <div className="flex gap-6">
        {/* Feedback List */}
        <div className={`${selectedFeedback ? 'w-1/2' : 'w-full'} transition-all`}>
          {isLoading ? (
            <div className="flex items-center justify-center py-20">
              <Loader2 size={24} className="animate-spin text-gray-400" />
            </div>
          ) : filtered.length === 0 ? (
            <div className="text-center py-20 text-gray-400">
              <MessageSquareText size={48} className="mx-auto mb-4 opacity-30" />
              <p className="font-medium">No feedback found</p>
            </div>
          ) : (
            <motion.div variants={container} initial="hidden" animate="visible" className="space-y-3">
              {filtered.map((fb) => (
                <motion.div
                  key={fb.id}
                  variants={item}
                  onClick={() => openDetail(fb)}
                  className={`p-4 bg-white dark:bg-gray-800 rounded-xl border cursor-pointer transition-all hover:shadow-md ${
                    selectedFeedback?.id === fb.id
                      ? 'border-blue-400 dark:border-blue-500 ring-2 ring-blue-100 dark:ring-blue-900/30'
                      : 'border-gray-100 dark:border-gray-700'
                  }`}
                >
                  <div className="flex items-start justify-between gap-3">
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2 mb-1.5">
                        <User size={14} className="text-gray-400 flex-shrink-0" />
                        <span className="text-sm font-medium text-gray-900 dark:text-white truncate">
                          {fb.user_name || fb.user_email || `User #${fb.user_id}`}
                        </span>
                        <span className={`px-2 py-0.5 rounded-full text-[10px] font-semibold border ${statusColors[fb.status] || statusColors.pending}`}>
                          {fb.status.replace('_', ' ')}
                        </span>
                      </div>
                      <p className="text-sm text-gray-600 dark:text-gray-300 line-clamp-2">{fb.message}</p>
                      <div className="flex items-center gap-3 mt-2">
                        <span className="flex items-center gap-1 text-xs text-gray-400">
                          <Tag size={12} />
                          {categoryLabels[fb.category] || fb.category}
                        </span>
                        {fb.rating && (
                          <span className="flex items-center gap-1 text-xs text-yellow-500">
                            <Star size={12} fill="currentColor" />
                            {fb.rating}/5
                          </span>
                        )}
                        <span className="text-xs text-gray-400">{formatDate(fb.created_at)}</span>
                      </div>
                    </div>
                  </div>
                </motion.div>
              ))}
            </motion.div>
          )}

          {/* Pagination */}
          {totalPages > 1 && (
            <div className="flex items-center justify-center gap-3 mt-6">
              <button
                onClick={() => { setPage(Math.max(1, page - 1)); loadFeedbacks(activeTab, Math.max(1, page - 1)); }}
                disabled={page <= 1}
                className="p-2 rounded-lg border border-gray-200 dark:border-gray-700 disabled:opacity-30 hover:bg-gray-50 dark:hover:bg-gray-700"
              >
                <ChevronLeft size={16} />
              </button>
              <span className="text-sm text-gray-500 dark:text-gray-400">
                Page {page} of {totalPages}
              </span>
              <button
                onClick={() => { setPage(Math.min(totalPages, page + 1)); loadFeedbacks(activeTab, Math.min(totalPages, page + 1)); }}
                disabled={page >= totalPages}
                className="p-2 rounded-lg border border-gray-200 dark:border-gray-700 disabled:opacity-30 hover:bg-gray-50 dark:hover:bg-gray-700"
              >
                <ChevronRight size={16} />
              </button>
            </div>
          )}
        </div>

        {/* Detail Panel */}
        {selectedFeedback && (
          <motion.div
            initial={{ opacity: 0, x: 20 }}
            animate={{ opacity: 1, x: 0 }}
            className="w-1/2 bg-white dark:bg-gray-800 rounded-xl border border-gray-100 dark:border-gray-700 p-6 sticky top-6 max-h-[calc(100vh-200px)] overflow-y-auto"
          >
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-bold text-gray-900 dark:text-white">Feedback #{selectedFeedback.id}</h3>
              <div className="flex items-center gap-2">
                <button
                  onClick={() => handleDelete(selectedFeedback.id)}
                  disabled={deleting}
                  className="p-2 text-red-400 hover:text-red-600 hover:bg-red-50 dark:hover:bg-red-900/20 rounded-lg transition-colors"
                >
                  {deleting ? <Loader2 size={16} className="animate-spin" /> : <Trash2 size={16} />}
                </button>
                <button
                  onClick={() => setSelectedFeedback(null)}
                  className="p-2 text-gray-400 hover:text-gray-600 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-lg transition-colors"
                >
                  &times;
                </button>
              </div>
            </div>

            {/* User Info */}
            <div className="bg-gray-50 dark:bg-gray-700/50 rounded-lg p-3 mb-4">
              <div className="flex items-center gap-2 mb-1">
                <User size={14} className="text-gray-400" />
                <span className="text-sm font-medium text-gray-900 dark:text-white">
                  {selectedFeedback.user_name || `User #${selectedFeedback.user_id}`}
                </span>
              </div>
              {selectedFeedback.user_email && (
                <p className="text-xs text-gray-500 dark:text-gray-400 ml-5">{selectedFeedback.user_email}</p>
              )}
            </div>

            {/* Meta */}
            <div className="grid grid-cols-2 gap-3 mb-4">
              <div>
                <p className="text-xs text-gray-400 mb-1">Category</p>
                <span className="text-sm font-medium text-gray-700 dark:text-gray-300">
                  {categoryLabels[selectedFeedback.category] || selectedFeedback.category}
                </span>
              </div>
              <div>
                <p className="text-xs text-gray-400 mb-1">Rating</p>
                <div className="flex items-center gap-1">
                  {selectedFeedback.rating ? (
                    <>
                      {Array.from({ length: 5 }).map((_, i) => (
                        <Star
                          key={i}
                          size={14}
                          className={i < selectedFeedback.rating! ? 'text-yellow-400' : 'text-gray-200 dark:text-gray-600'}
                          fill={i < selectedFeedback.rating! ? 'currentColor' : 'none'}
                        />
                      ))}
                    </>
                  ) : (
                    <span className="text-sm text-gray-400">No rating</span>
                  )}
                </div>
              </div>
              <div>
                <p className="text-xs text-gray-400 mb-1">Submitted</p>
                <span className="text-sm text-gray-700 dark:text-gray-300">{formatDate(selectedFeedback.created_at)}</span>
              </div>
              <div>
                <p className="text-xs text-gray-400 mb-1">App Version</p>
                <span className="text-sm text-gray-700 dark:text-gray-300">{selectedFeedback.app_version || 'N/A'}</span>
              </div>
            </div>

            {/* Message */}
            <div className="mb-4">
              <p className="text-xs text-gray-400 mb-2">Message</p>
              <div className="bg-gray-50 dark:bg-gray-700/50 rounded-lg p-3">
                <p className="text-sm text-gray-700 dark:text-gray-300 whitespace-pre-wrap">{selectedFeedback.message}</p>
              </div>
            </div>

            {/* Status Update */}
            <div className="mb-4">
              <p className="text-xs text-gray-400 mb-2">Update Status</p>
              <div className="flex gap-2 flex-wrap">
                {statusOptions.map((s) => (
                  <button
                    key={s}
                    onClick={() => setNewStatus(s)}
                    className={`px-3 py-1.5 rounded-lg text-xs font-medium border transition-all ${
                      newStatus === s
                        ? 'bg-blue-50 dark:bg-blue-900/30 text-blue-700 dark:text-blue-300 border-blue-300 dark:border-blue-600'
                        : 'bg-white dark:bg-gray-800 text-gray-500 dark:text-gray-400 border-gray-200 dark:border-gray-600 hover:border-gray-300'
                    }`}
                  >
                    {s.replace('_', ' ')}
                  </button>
                ))}
              </div>
            </div>

            {/* Admin Notes */}
            <div className="mb-4">
              <p className="text-xs text-gray-400 mb-2 flex items-center gap-1">
                <StickyNote size={12} />
                Admin Notes
              </p>
              <textarea
                value={adminNotes}
                onChange={(e) => setAdminNotes(e.target.value)}
                placeholder="Add internal notes about this feedback..."
                rows={3}
                className="w-full px-3 py-2 bg-gray-50 dark:bg-gray-700/50 border border-gray-200 dark:border-gray-600 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500/30 resize-none"
              />
            </div>

            {/* Save Button */}
            <button
              onClick={handleUpdate}
              disabled={updating}
              className="w-full flex items-center justify-center gap-2 px-4 py-2.5 bg-blue-600 hover:bg-blue-700 text-white rounded-xl text-sm font-medium transition-colors disabled:opacity-50"
            >
              {updating ? <Loader2 size={16} className="animate-spin" /> : <Send size={16} />}
              Save Changes
            </button>
          </motion.div>
        )}
      </div>
    </div>
  );
}

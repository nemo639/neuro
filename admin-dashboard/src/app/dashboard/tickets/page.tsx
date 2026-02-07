'use client';

import { useState, useEffect, useRef, useCallback } from 'react';
import { motion } from 'framer-motion';
import {
  TicketCheck,
  Search,
  AlertTriangle,
  Clock,
  CheckCircle2,
  MessageSquare,
  Send,
  ArrowUpRight,
  User,
  Flag,
  Tag,
  Hash,
  Loader2,
  RefreshCw,
  UserCheck,
} from 'lucide-react';
import { ticketsApi } from '@/lib/api';

const container = { hidden: { opacity: 0 }, visible: { opacity: 1, transition: { staggerChildren: 0.06 } } };
const item = { hidden: { opacity: 0, y: 12 }, visible: { opacity: 1, y: 0, transition: { duration: 0.4 } } };

/* ─── Types matching backend schemas ─── */
type TicketSummary = {
  id: string;
  ticket_number: string;
  subject: string;
  user_name: string;
  user_email: string;
  priority: string;
  status: string;
  created_at: string;
};

type TicketMessage = {
  id: string;
  sender_type: string;
  sender_name: string;
  message: string;
  created_at: string;
};

type TicketDetail = {
  id: string;
  ticket_number: string;
  user_id: string | null;
  user_email: string;
  user_name: string | null;
  subject: string;
  description: string;
  category: string;
  priority: string;
  status: string;
  assigned_to: string | null;
  assigned_admin_name: string | null;
  resolution_notes: string | null;
  resolved_by: string | null;
  resolved_at: string | null;
  messages: TicketMessage[];
  created_at: string;
  updated_at: string | null;
};

export default function TicketsPage() {
  /* ─── State ─── */
  const [isLoading, setIsLoading] = useState(true);
  const [tickets, setTickets] = useState<TicketSummary[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [limit] = useState(20);

  const [search, setSearch] = useState('');
  const [activeTab, setActiveTab] = useState('All');

  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [detail, setDetail] = useState<TicketDetail | null>(null);
  const [detailLoading, setDetailLoading] = useState(false);

  const [replyText, setReplyText] = useState('');
  const [replySending, setReplySending] = useState(false);
  const [resolving, setResolving] = useState(false);
  const [assigning, setAssigning] = useState(false);

  const messagesEndRef = useRef<HTMLDivElement>(null);
  const tabs = ['All', 'Open', 'In Progress', 'Resolved'];

  /* ─── Load ticket list ─── */
  const loadTickets = useCallback(async (statusFilter?: string, p = 1) => {
    setIsLoading(true);
    try {
      const params: Record<string, string | number> = { page: p, limit };
      if (statusFilter && statusFilter !== 'All') {
        const map: Record<string, string> = {
          Open: 'open',
          'In Progress': 'in_progress',
          Resolved: 'resolved',
        };
        params.status = map[statusFilter] || '';
      }
      const data = await ticketsApi.getTickets(params as any);
      setTickets(data.tickets || []);
      setTotal(data.total || 0);
      setPage(data.page || 1);
    } catch (err) {
      console.error('Failed to load tickets', err);
      setTickets([]);
    } finally {
      setIsLoading(false);
    }
  }, [limit]);

  useEffect(() => {
    loadTickets(activeTab, 1);
  }, [activeTab, loadTickets]);

  /* ─── Load ticket detail ─── */
  const loadDetail = useCallback(async (ticketId: string) => {
    setDetailLoading(true);
    try {
      const data = await ticketsApi.getTicket(ticketId);
      setDetail(data);
    } catch (err) {
      console.error('Failed to load ticket detail', err);
      setDetail(null);
    } finally {
      setDetailLoading(false);
    }
  }, []);

  const selectTicket = (ticketId: string) => {
    setSelectedId(ticketId);
    loadDetail(ticketId);
  };

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [detail?.messages]);

  /* ─── Client-side search filter ─── */
  const filteredTickets = tickets.filter((t) => {
    const q = search.toLowerCase();
    return (
      t.subject.toLowerCase().includes(q) ||
      (t.user_name || '').toLowerCase().includes(q) ||
      t.ticket_number.toLowerCase().includes(q)
    );
  });

  /* ─── Reply ─── */
  const handleReply = async () => {
    if (!replyText.trim() || !detail) return;
    setReplySending(true);
    try {
      await ticketsApi.replyToTicket(detail.id, { message: replyText });
      setReplyText('');
      await loadDetail(detail.id);
    } catch (err) {
      console.error('Reply failed', err);
    } finally {
      setReplySending(false);
    }
  };

  /* ─── Resolve ─── */
  const handleResolve = async () => {
    if (!detail) return;
    setResolving(true);
    try {
      await ticketsApi.resolveTicket(detail.id, { resolution_notes: 'Resolved by admin' });
      setTickets((prev) => prev.map((t) => (t.id === detail.id ? { ...t, status: 'resolved' } : t)));
      await loadDetail(detail.id);
    } catch (err) {
      console.error('Resolve failed', err);
    } finally {
      setResolving(false);
    }
  };

  /* ─── Assign to self ─── */
  const handleAssign = async () => {
    if (!detail) return;
    setAssigning(true);
    try {
      await ticketsApi.assignTicket(detail.id);
      setTickets((prev) => prev.map((t) => (t.id === detail.id ? { ...t, status: 'in_progress' } : t)));
      await loadDetail(detail.id);
    } catch (err) {
      console.error('Assign failed', err);
    } finally {
      setAssigning(false);
    }
  };

  /* ─── Stats from loaded data ─── */
  const openCount = tickets.filter((t) => t.status === 'open').length;
  const inProgressCount = tickets.filter((t) => t.status === 'in_progress').length;
  const resolvedCount = tickets.filter((t) => t.status === 'resolved').length;

  const stats = [
    { title: 'Total Tickets', value: total.toString(), icon: TicketCheck, active: true },
    { title: 'Open', value: openCount.toString(), icon: AlertTriangle, active: false },
    { title: 'In Progress', value: inProgressCount.toString(), icon: Clock, active: false },
    { title: 'Resolved', value: resolvedCount.toString(), icon: CheckCircle2, active: false },
  ];

  /* ─── Helpers ─── */
  const priorityBadge = (priority: string) => {
    const map: Record<string, string> = {
      urgent: 'bg-red-50 text-red-600',
      high: 'bg-orange-50 text-orange-600',
      medium: 'bg-amber-50 text-amber-600',
      low: 'bg-blue-50 text-blue-600',
    };
    return map[priority] || 'bg-gray-50 text-gray-600';
  };

  const statusBadge = (status: string) => {
    const map: Record<string, string> = {
      open: 'badge-warning',
      in_progress: 'badge-info',
      resolved: 'badge-success',
      closed: 'badge-success',
    };
    return map[status] || 'badge-info';
  };

  const fmtTime = (iso: string) => {
    try {
      const d = new Date(iso);
      return d.toLocaleString('en-US', { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit', hour12: true });
    } catch {
      return iso;
    }
  };

  const totalPages = Math.max(1, Math.ceil(total / limit));

  /* ─── Loading state ─── */
  if (isLoading && tickets.length === 0) {
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
          <h1 className="text-2xl font-bold text-dash-dark">Support Tickets</h1>
          <p className="text-sm text-dash-muted mt-1">Manage and respond to user support requests</p>
        </div>
        <button
          onClick={() => loadTickets(activeTab, page)}
          className="btn-secondary flex items-center gap-2 text-xs"
        >
          <RefreshCw className="w-3.5 h-3.5" />
          Refresh
        </button>
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
          </div>
        ))}
      </motion.div>

      {/* Split Layout: Ticket List + Detail */}
      <motion.div variants={item} className="grid grid-cols-1 xl:grid-cols-5 gap-6">
        {/* ─── Ticket List ─── */}
        <div className="xl:col-span-2 card overflow-hidden flex flex-col" style={{ maxHeight: '680px' }}>
          <div className="px-5 py-4 border-b border-dash-border">
            <div className="flex items-center gap-2 mb-3">
              {tabs.map((tab) => (
                <button
                  key={tab}
                  onClick={() => { setActiveTab(tab); setSelectedId(null); setDetail(null); }}
                  className={`px-3 py-1.5 text-xs font-medium rounded-lg transition-all
                    ${activeTab === tab ? 'bg-dash-dark text-white' : 'text-dash-muted hover:bg-dash-bg'}`}
                >
                  {tab}
                </button>
              ))}
            </div>
            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-dash-muted" />
              <input
                type="text"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder="Search tickets..."
                className="input pl-10 py-2"
              />
            </div>
          </div>

          <div className="flex-1 overflow-y-auto">
            {isLoading ? (
              <div className="py-16 text-center">
                <Loader2 className="w-6 h-6 text-dash-muted mx-auto animate-spin" />
              </div>
            ) : filteredTickets.length === 0 ? (
              <div className="py-16 text-center">
                <TicketCheck className="w-10 h-10 text-dash-border mx-auto mb-3" />
                <p className="text-sm text-dash-muted">No tickets found</p>
              </div>
            ) : (
              filteredTickets.map((ticket) => (
                <button
                  key={ticket.id}
                  onClick={() => selectTicket(ticket.id)}
                  className={`w-full text-left px-5 py-4 border-b border-dash-border hover:bg-dash-bg/50 transition-colors
                    ${selectedId === ticket.id ? 'bg-accent/5 border-l-[3px] border-l-accent' : ''}`}
                >
                  <div className="flex items-start justify-between mb-1.5">
                    <h4 className="text-sm font-semibold text-dash-dark line-clamp-1 pr-2">{ticket.subject}</h4>
                    <span className={`text-[10px] font-semibold px-2 py-0.5 rounded-md flex-shrink-0 ${priorityBadge(ticket.priority)}`}>
                      {ticket.priority}
                    </span>
                  </div>
                  <div className="flex items-center gap-1.5 mb-2">
                    <span className="text-[10px] text-dash-muted font-mono">#{ticket.ticket_number}</span>
                    <span className="text-[10px] text-dash-muted">·</span>
                    <span className="text-xs text-dash-muted">{fmtTime(ticket.created_at)}</span>
                  </div>
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <div className="w-5 h-5 rounded-full bg-dash-bg text-dash-muted flex items-center justify-center text-[9px] font-semibold">
                        {(ticket.user_name || 'U').split(' ').map((n) => n[0]).join('').slice(0, 2)}
                      </div>
                      <span className="text-xs text-dash-muted">{ticket.user_name || 'Guest'}</span>
                    </div>
                    <span className={`${statusBadge(ticket.status)} capitalize text-[10px] py-0.5`}>
                      {ticket.status.replace('_', ' ')}
                    </span>
                  </div>
                </button>
              ))
            )}
          </div>

          {/* Pagination */}
          {totalPages > 1 && (
            <div className="px-5 py-3 border-t border-dash-border flex items-center justify-between">
              <span className="text-xs text-dash-muted">
                Page {page} of {totalPages} · {total} tickets
              </span>
              <div className="flex items-center gap-1">
                <button
                  disabled={page <= 1}
                  onClick={() => { setPage(page - 1); loadTickets(activeTab, page - 1); }}
                  className="px-2 py-1 text-xs rounded-lg border border-dash-border disabled:opacity-40"
                >
                  Prev
                </button>
                <button
                  disabled={page >= totalPages}
                  onClick={() => { setPage(page + 1); loadTickets(activeTab, page + 1); }}
                  className="px-2 py-1 text-xs rounded-lg border border-dash-border disabled:opacity-40"
                >
                  Next
                </button>
              </div>
            </div>
          )}
        </div>

        {/* ─── Ticket Detail ─── */}
        <div className="xl:col-span-3 card overflow-hidden flex flex-col" style={{ maxHeight: '680px' }}>
          {detailLoading ? (
            <div className="flex-1 flex items-center justify-center">
              <Loader2 className="w-6 h-6 text-dash-muted animate-spin" />
            </div>
          ) : detail ? (
            <>
              {/* Detail Header */}
              <div className="px-6 py-4 border-b border-dash-border">
                <div className="flex items-start justify-between">
                  <div className="flex-1 min-w-0">
                    <h3 className="font-bold text-dash-dark">{detail.subject}</h3>
                    <div className="flex flex-wrap items-center gap-3 mt-2">
                      <span className="text-xs text-dash-muted flex items-center gap-1">
                        <Hash className="w-3 h-3" /> {detail.ticket_number}
                      </span>
                      <span className="text-xs text-dash-muted flex items-center gap-1">
                        <User className="w-3 h-3" /> {detail.user_name || detail.user_email}
                      </span>
                      <span className="text-xs text-dash-muted flex items-center gap-1">
                        <Tag className="w-3 h-3" /> {detail.category}
                      </span>
                      <span className={`text-[10px] font-semibold px-2 py-0.5 rounded-md ${priorityBadge(detail.priority)}`}>
                        <Flag className="w-3 h-3 inline mr-0.5" />{detail.priority}
                      </span>
                      <span className={`${statusBadge(detail.status)} capitalize text-[10px] py-0.5`}>
                        {detail.status.replace('_', ' ')}
                      </span>
                    </div>
                    {detail.assigned_admin_name && (
                      <p className="text-xs text-dash-muted mt-1.5 flex items-center gap-1">
                        <UserCheck className="w-3 h-3" /> Assigned to {detail.assigned_admin_name}
                      </p>
                    )}
                  </div>
                  <div className="flex items-center gap-2 flex-shrink-0 ml-4">
                    {detail.status === 'open' && (
                      <button
                        onClick={handleAssign}
                        disabled={assigning}
                        className="btn-secondary flex items-center gap-1.5 py-2 text-xs"
                      >
                        {assigning ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <UserCheck className="w-3.5 h-3.5" />}
                        Assign to Me
                      </button>
                    )}
                    {detail.status !== 'resolved' && detail.status !== 'closed' && (
                      <button
                        onClick={handleResolve}
                        disabled={resolving}
                        className="btn-primary flex items-center gap-1.5 py-2 text-xs"
                      >
                        {resolving ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <CheckCircle2 className="w-3.5 h-3.5" />}
                        Mark Resolved
                      </button>
                    )}
                  </div>
                </div>
              </div>

              {/* Description */}
              <div className="px-6 py-3 border-b border-dash-border bg-dash-bg/30">
                <p className="text-sm text-dash-text">{detail.description}</p>
              </div>

              {/* Messages */}
              <div className="flex-1 overflow-y-auto p-6 space-y-4">
                {detail.messages.length === 0 ? (
                  <div className="py-8 text-center">
                    <MessageSquare className="w-8 h-8 text-dash-border mx-auto mb-2" />
                    <p className="text-xs text-dash-muted">No messages yet</p>
                  </div>
                ) : (
                  detail.messages.map((msg) => {
                    const isAdmin = msg.sender_type === 'admin';
                    return (
                      <div key={msg.id} className={`flex ${isAdmin ? 'justify-end' : 'justify-start'}`}>
                        <div className="max-w-[75%]">
                          <div className={`p-4 rounded-2xl ${isAdmin
                            ? 'bg-accent/10 border border-accent/20'
                            : 'bg-dash-bg'
                            }`}>
                            <p className="text-sm text-dash-dark">{msg.message}</p>
                          </div>
                          <div className={`flex items-center gap-2 mt-1.5 ${isAdmin ? 'justify-end' : ''}`}>
                            <span className="text-[10px] text-dash-muted font-medium">{msg.sender_name}</span>
                            <span className="text-[10px] text-dash-muted">· {fmtTime(msg.created_at)}</span>
                          </div>
                        </div>
                      </div>
                    );
                  })
                )}
                <div ref={messagesEndRef} />
              </div>

              {/* Resolution notes */}
              {detail.resolution_notes && (
                <div className="px-6 py-3 border-t border-dash-border bg-emerald-50/50">
                  <p className="text-xs text-emerald-700 flex items-center gap-1.5">
                    <CheckCircle2 className="w-3.5 h-3.5" />
                    <span className="font-semibold">Resolution:</span> {detail.resolution_notes}
                  </p>
                </div>
              )}

              {/* Reply Box */}
              {detail.status !== 'resolved' && detail.status !== 'closed' && (
                <div className="px-6 py-4 border-t border-dash-border">
                  <div className="flex items-end gap-3">
                    <div className="flex-1 relative">
                      <textarea
                        value={replyText}
                        onChange={(e) => setReplyText(e.target.value)}
                        onKeyDown={(e) => {
                          if (e.key === 'Enter' && !e.shiftKey) {
                            e.preventDefault();
                            handleReply();
                          }
                        }}
                        placeholder="Type your reply..."
                        className="input py-3 pr-10 resize-none"
                        rows={2}
                      />
                    </div>
                    <button
                      onClick={handleReply}
                      disabled={!replyText.trim() || replySending}
                      className="btn-primary p-3 disabled:opacity-40 disabled:cursor-not-allowed"
                    >
                      {replySending ? <Loader2 className="w-4 h-4 animate-spin" /> : <Send className="w-4 h-4" />}
                    </button>
                  </div>
                </div>
              )}
            </>
          ) : (
            <div className="flex-1 flex items-center justify-center">
              <div className="text-center">
                <div className="w-16 h-16 rounded-2xl bg-dash-bg flex items-center justify-center mx-auto mb-4">
                  <MessageSquare className="w-8 h-8 text-dash-border" />
                </div>
                <h3 className="text-lg font-semibold text-dash-dark mb-1">Select a ticket</h3>
                <p className="text-sm text-dash-muted">Choose a ticket from the list to view details and respond</p>
              </div>
            </div>
          )}
        </div>
      </motion.div>
    </motion.div>
  );
}

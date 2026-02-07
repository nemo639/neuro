'use client';

import { useState, useEffect, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/contexts/AuthContext';
import { dashboardApi, usersApi, doctorsApi, tasksApi } from '@/lib/api';
import {
  Users,
  Stethoscope,
  TicketCheck,
  TrendingUp,
  ArrowUpRight,
  ArrowDownRight,
  ChevronRight,
  UserCheck,
  AlertTriangle,
  Eye,
  CheckCircle2,
  MoreHorizontal,
  Calendar,
  Clock,
  Plus,
  X,
  Trash2,
  Loader2,
} from 'lucide-react';
import {
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  PieChart,
  Pie,
  Cell,
} from 'recharts';

const container = { hidden: { opacity: 0 }, visible: { opacity: 1, transition: { staggerChildren: 0.06 } } };
const item = { hidden: { opacity: 0, y: 12 }, visible: { opacity: 1, y: 0, transition: { duration: 0.4 } } };

const userGrowthData = [
  { month: '13 May', applied: 180, shortlisted: 100 },
  { month: '14 May', applied: 250, shortlisted: 160 },
  { month: '15 May', applied: 190, shortlisted: 120 },
  { month: '16 May', applied: 320, shortlisted: 200 },
  { month: '17 May', applied: 280, shortlisted: 170 },
  { month: '18 May', applied: 350, shortlisted: 220 },
  { month: '19 May', applied: 310, shortlisted: 190 },
];

const departmentData = [
  { name: 'Neurology', value: 120, color: '#C6E94B' },
  { name: 'Psychiatry', value: 110, color: '#6366F1' },
  { name: 'Psychology', value: 95, color: '#A855F7' },
  { name: 'Therapy', value: 85, color: '#FB923C' },
  { name: 'Surgery', value: 65, color: '#22D3EE' },
  { name: 'General', value: 50, color: '#EC4899' },
];

const CustomTooltip = ({ active, payload, label }: any) => {
  if (!active || !payload) return null;
  return (
    <div className="bg-white p-3 rounded-xl shadow-elevated border border-dash-border">
      <p className="text-xs font-semibold text-dash-dark mb-1">{label}</p>
      {payload.map((entry: any, i: number) => (
        <p key={i} className="text-xs text-dash-muted">
          {entry.name}: <span className="font-semibold text-dash-dark">{entry.value}</span>
        </p>
      ))}
    </div>
  );
};

type Task = {
  id: string;
  title: string;
  description?: string;
  category: string;
  due_date?: string;
  is_completed: boolean;
  created_at: string;
};

type DashboardUser = {
  id: number;
  email: string;
  first_name: string;
  last_name: string;
  is_verified: boolean;
  created_at: string;
  last_active?: string;
};

type DashboardDoctor = {
  id: number;
  email: string;
  first_name: string;
  last_name: string;
  specialization: string;
  status: string;
  is_verified: boolean;
  created_at: string;
};

const CATEGORY_OPTIONS = [
  { value: 'evaluation', label: 'Evaluation' },
  { value: 'engagement', label: 'Engagement' },
  { value: 'relationship', label: 'Relationship' },
  { value: 'selection', label: 'Selection' },
  { value: 'general', label: 'General' },
];

function formatDate(dateStr: string) {
  try {
    const d = new Date(dateStr);
    return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
  } catch {
    return dateStr;
  }
}

function formatDueDate(dateStr?: string) {
  if (!dateStr) return '';
  try {
    const d = new Date(dateStr);
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const due = new Date(d);
    due.setHours(0, 0, 0, 0);
    const diff = Math.ceil((due.getTime() - today.getTime()) / (1000 * 60 * 60 * 24));
    if (diff === 0) return 'Today';
    if (diff === 1) return 'Tomorrow';
    if (diff === -1) return 'Yesterday';
    if (diff < 0) return `${Math.abs(diff)}d overdue`;
    if (diff <= 7) return `In ${diff}d`;
    return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
  } catch {
    return '';
  }
}

export default function AdminDashboardPage() {
  const { admin } = useAuth();
  const router = useRouter();
  const [isLoading, setIsLoading] = useState(true);

  // Dashboard stats
  const [dashData, setDashData] = useState<any>(null);

  // Tasks
  const [tasks, setTasks] = useState<Task[]>([]);
  const [showAddTask, setShowAddTask] = useState(false);
  const [newTask, setNewTask] = useState({ title: '', description: '', category: 'general', due_date: '' });
  const [taskSaving, setTaskSaving] = useState(false);

  // Users table
  const [userTab, setUserTab] = useState<'all' | 'patients' | 'doctors'>('all');
  const [allUsers, setAllUsers] = useState<DashboardUser[]>([]);
  const [allDoctors, setAllDoctors] = useState<DashboardDoctor[]>([]);

  // Fetch dashboard data
  const fetchDashboard = useCallback(async () => {
    try {
      const data = await dashboardApi.getDashboard();
      setDashData(data);
    } catch (err) {
      console.error('Dashboard fetch failed:', err);
      setDashData({
        total_users: 0, total_doctors: 0, pending_verifications: 0, open_tickets: 0,
        recent_activities: [], pending_tickets: [],
      });
    }
  }, []);

  // Fetch tasks
  const fetchTasks = useCallback(async () => {
    try {
      const data = await tasksApi.getTasks(false);
      setTasks(data.tasks || []);
    } catch (err) {
      console.error('Tasks fetch failed:', err);
      setTasks([]);
    }
  }, []);

  // Fetch users
  const fetchUsers = useCallback(async () => {
    try {
      const data = await usersApi.getUsers({ limit: 10 });
      setAllUsers(data.users || []);
    } catch (err) {
      console.error('Users fetch failed:', err);
      setAllUsers([]);
    }
  }, []);

  // Fetch doctors
  const fetchDoctors = useCallback(async () => {
    try {
      const data = await doctorsApi.getDoctors({ limit: 10 });
      setAllDoctors(data.doctors || []);
    } catch (err) {
      console.error('Doctors fetch failed:', err);
      setAllDoctors([]);
    }
  }, []);

  // Initial load
  useEffect(() => {
    const loadAll = async () => {
      setIsLoading(true);
      await Promise.all([fetchDashboard(), fetchTasks(), fetchUsers(), fetchDoctors()]);
      setIsLoading(false);
    };
    loadAll();
  }, [fetchDashboard, fetchTasks, fetchUsers, fetchDoctors]);

  // --- Task Actions ---
  const handleCreateTask = async () => {
    if (!newTask.title.trim()) return;
    setTaskSaving(true);
    try {
      const created = await tasksApi.createTask({
        title: newTask.title,
        description: newTask.description || undefined,
        category: newTask.category,
        due_date: newTask.due_date || undefined,
      });
      setTasks(prev => [created, ...prev]);
      setNewTask({ title: '', description: '', category: 'general', due_date: '' });
      setShowAddTask(false);
    } catch {
      setTasks(prev => [{
        id: `local-${Date.now()}`, title: newTask.title, description: newTask.description,
        category: newTask.category, due_date: newTask.due_date, is_completed: false, created_at: new Date().toISOString(),
      }, ...prev]);
      setShowAddTask(false);
    }
    setTaskSaving(false);
  };

  const handleToggleTask = async (task: Task) => {
    const updated = { ...task, is_completed: !task.is_completed };
    setTasks(prev => prev.map(t => t.id === task.id ? updated : t));
    try {
      await tasksApi.updateTask(task.id, { is_completed: !task.is_completed });
      if (!task.is_completed) {
        setTimeout(() => {
          setTasks(prev => prev.filter(t => t.id !== task.id));
        }, 600);
      }
    } catch { /* keep local state */ }
  };

  const handleDeleteTask = async (taskId: string) => {
    setTasks(prev => prev.filter(t => t.id !== taskId));
    try {
      await tasksApi.deleteTask(taskId);
    } catch { /* keep local state */ }
  };

  // --- Users Table Data ---
  const tableData = (() => {
    if (userTab === 'patients') {
      return allUsers.map(u => ({
        id: u.id,
        name: `${u.first_name} ${u.last_name}`,
        role: 'Patient' as const,
        date: formatDate(u.created_at),
        rawDate: u.created_at,
        status: u.is_verified ? 'Active' : 'Pending',
        type: 'User',
        link: '/dashboard/users',
      }));
    }
    if (userTab === 'doctors') {
      return allDoctors.map(d => ({
        id: d.id,
        name: `Dr. ${d.first_name} ${d.last_name}`,
        role: 'Doctor' as const,
        date: formatDate(d.created_at),
        rawDate: d.created_at,
        status: d.is_verified ? 'Verified' : d.status === 'pending_verification' ? 'Pending' : (d.status || 'Active'),
        type: d.specialization || 'General',
        link: '/dashboard/doctors',
      }));
    }
    const merged = [
      ...allUsers.map(u => ({
        id: u.id,
        name: `${u.first_name} ${u.last_name}`,
        role: 'Patient' as const,
        date: formatDate(u.created_at),
        rawDate: u.created_at,
        status: u.is_verified ? 'Active' : 'Pending',
        type: 'User',
        link: '/dashboard/users',
      })),
      ...allDoctors.map(d => ({
        id: d.id,
        name: `Dr. ${d.first_name} ${d.last_name}`,
        role: 'Doctor' as const,
        date: formatDate(d.created_at),
        rawDate: d.created_at,
        status: d.is_verified ? 'Verified' : d.status === 'pending_verification' ? 'Pending' : (d.status || 'Active'),
        type: d.specialization || 'General',
        link: '/dashboard/doctors',
      })),
    ];
    merged.sort((a, b) => new Date(b.rawDate).getTime() - new Date(a.rawDate).getTime());
    return merged.slice(0, 8);
  })();

  const totalTableCount = allUsers.length + allDoctors.length;

  // --- Stats from real data ---
  const stats = dashData ? [
    { title: 'Total Users', value: (dashData.total_users || 0).toLocaleString(), change: '+14%', up: true, icon: Users, active: true },
    { title: 'Total Doctors', value: (dashData.total_doctors || 0).toLocaleString(), change: '+5.1%', up: true, icon: Stethoscope, active: false },
    { title: 'Pending Verifications', value: (dashData.pending_verifications || 0).toLocaleString(), change: dashData.pending_verifications > 0 ? `${dashData.pending_verifications} new` : '0', up: dashData.pending_verifications > 0, icon: UserCheck, active: false },
    { title: 'Open Tickets', value: (dashData.open_tickets || 0).toLocaleString(), change: dashData.open_tickets > 0 ? `${dashData.open_tickets} active` : '0', up: dashData.open_tickets > 0, icon: AlertTriangle, active: false },
  ] : [];

  // --- Activities from real data ---
  const activities = dashData?.recent_activities?.length
    ? dashData.recent_activities.map((a: any, i: number) => ({
        action: a.action || 'Activity',
        desc: a.details || '',
        time: a.time || '',
        dot: ['bg-emerald-500', 'bg-amber-500', 'bg-blue-500', 'bg-purple-500', 'bg-accent'][i % 5],
      }))
    : [
        { action: 'System Ready', desc: 'Dashboard loaded successfully', time: 'Just now', dot: 'bg-emerald-500' },
      ];

  // --- Schedule from pending tickets ---
  const schedule = dashData?.pending_tickets?.length
    ? dashData.pending_tickets.slice(0, 4).map((t: any, i: number) => ({
        time: t.created_at ? new Date(t.created_at).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' }) : '',
        title: t.subject || `Ticket ${t.ticket_number}`,
        tag: `${t.priority || 'medium'} · ${t.status || 'open'}`,
        color: ['bg-accent', 'bg-blue-500', 'bg-amber-500', 'bg-purple-500'][i % 4],
      }))
    : [];

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
          <h1 className="text-2xl font-bold text-dash-dark">Dashboard</h1>
        </div>
        <div className="flex items-center gap-2">
          <button className="btn-secondary flex items-center gap-2 py-2">
            <Calendar className="w-4 h-4" />
            <span className="text-sm">Today</span>
          </button>
        </div>
      </motion.div>

      {/* Stat Cards Row */}
      <motion.div variants={item} className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        {stats.map((stat) => (
          <div
            key={stat.title}
            className={`card p-5 relative overflow-hidden ${stat.active ? 'bg-accent border-accent' : ''}`}
          >
            <div className="flex items-start justify-between mb-3">
              <p className={`text-sm font-medium ${stat.active ? 'text-dash-dark' : 'text-dash-muted'}`}>
                {stat.title}
              </p>
              <button className="p-1 hover:bg-black/5 rounded-lg transition-colors">
                <MoreHorizontal className={`w-4 h-4 ${stat.active ? 'text-dash-dark/50' : 'text-dash-muted'}`} />
              </button>
            </div>
            <p className="text-3xl font-bold text-dash-dark">
              {stat.value}
            </p>
            <div className="flex items-center gap-1 mt-2">
              {stat.up ? (
                <ArrowUpRight className="w-3.5 h-3.5 text-emerald-500" />
              ) : (
                <ArrowDownRight className="w-3.5 h-3.5 text-red-500" />
              )}
              <span className={`text-xs font-semibold ${stat.up ? 'text-emerald-500' : 'text-red-500'}`}>
                {stat.change}
              </span>
            </div>
          </div>
        ))}
      </motion.div>

      {/* Charts Row */}
      <div className="grid grid-cols-1 xl:grid-cols-3 gap-6">
        {/* Area Chart */}
        <motion.div variants={item} className="xl:col-span-2 card p-6">
          <div className="flex items-center justify-between mb-6">
            <div>
              <h3 className="font-semibold text-dash-dark">Applications</h3>
              <p className="text-xs text-dash-muted mt-0.5">User registration & engagement trends</p>
            </div>
            <div className="flex items-center gap-1 bg-dash-bg rounded-lg p-1">
              <button className="px-3 py-1.5 text-xs font-medium rounded-md bg-white shadow-sm text-dash-dark">
                13-18 May
              </button>
            </div>
          </div>
          <div className="flex items-center gap-5 mb-4">
            <div className="flex items-center gap-2">
              <span className="w-3 h-3 rounded-full bg-chart-blue" />
              <span className="text-xs text-dash-muted">Applied</span>
            </div>
            <div className="flex items-center gap-2">
              <span className="w-3 h-3 rounded-full bg-accent" />
              <span className="text-xs text-dash-muted">Shortlisted</span>
            </div>
          </div>
          <ResponsiveContainer width="100%" height={240}>
            <AreaChart data={userGrowthData}>
              <defs>
                <linearGradient id="gApplied" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor="#6366F1" stopOpacity={0.15} />
                  <stop offset="100%" stopColor="#6366F1" stopOpacity={0} />
                </linearGradient>
                <linearGradient id="gShortlisted" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor="#C6E94B" stopOpacity={0.15} />
                  <stop offset="100%" stopColor="#C6E94B" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="#ECEDF2" vertical={false} />
              <XAxis dataKey="month" fontSize={11} tick={{ fill: '#8B8FA8' }} axisLine={false} tickLine={false} />
              <YAxis fontSize={11} tick={{ fill: '#8B8FA8' }} axisLine={false} tickLine={false} />
              <Tooltip content={<CustomTooltip />} />
              <Area type="monotone" dataKey="applied" stroke="#6366F1" strokeWidth={2} fill="url(#gApplied)" name="Applied" />
              <Area type="monotone" dataKey="shortlisted" stroke="#C6E94B" strokeWidth={2} fill="url(#gShortlisted)" name="Shortlisted" />
            </AreaChart>
          </ResponsiveContainer>
        </motion.div>

        {/* Pie Chart */}
        <motion.div variants={item} className="card p-6">
          <div className="flex items-center justify-between mb-4">
            <h3 className="font-semibold text-dash-dark">By Department</h3>
            <button className="text-xs text-dash-muted hover:text-dash-text flex items-center gap-1">
              Today <ChevronRight className="w-3 h-3" />
            </button>
          </div>
          <ResponsiveContainer width="100%" height={180}>
            <PieChart>
              <Pie data={departmentData} cx="50%" cy="50%" innerRadius={50} outerRadius={75}
                paddingAngle={3} dataKey="value" startAngle={90} endAngle={450}>
                {departmentData.map((entry, i) => (
                  <Cell key={i} fill={entry.color} strokeWidth={0} />
                ))}
              </Pie>
              <Tooltip content={<CustomTooltip />} />
            </PieChart>
          </ResponsiveContainer>
          <div className="text-center -mt-2 mb-3">
            <p className="text-2xl font-bold text-dash-dark">{dashData?.total_doctors || 0}</p>
            <p className="text-xs text-dash-muted">Total Doctors</p>
          </div>
          <div className="grid grid-cols-2 gap-x-4 gap-y-2">
            {departmentData.map((d) => (
              <div key={d.name} className="flex items-center gap-2">
                <span className="w-2 h-2 rounded-full flex-shrink-0" style={{ backgroundColor: d.color }} />
                <span className="text-xs text-dash-muted truncate">{d.name}</span>
                <span className="text-xs font-semibold text-dash-dark ml-auto">{d.value}</span>
              </div>
            ))}
          </div>
        </motion.div>
      </div>

      {/* Bottom Row */}
      <div className="grid grid-cols-1 xl:grid-cols-3 gap-6">
        {/* Tasks — DYNAMIC with CRUD */}
        <motion.div variants={item} className="card p-6">
          <div className="flex items-center justify-between mb-5">
            <h3 className="font-semibold text-dash-dark">Tasks</h3>
            <button
              onClick={() => setShowAddTask(true)}
              className="w-7 h-7 bg-accent rounded-lg flex items-center justify-center text-dash-dark font-bold text-sm hover:bg-accent-hover transition-colors"
            >
              <Plus className="w-4 h-4" />
            </button>
          </div>

          {/* Add Task Form */}
          <AnimatePresence>
            {showAddTask && (
              <motion.div
                initial={{ height: 0, opacity: 0 }}
                animate={{ height: 'auto', opacity: 1 }}
                exit={{ height: 0, opacity: 0 }}
                className="overflow-hidden mb-4"
              >
                <div className="p-4 bg-dash-bg rounded-xl space-y-3">
                  <input
                    type="text"
                    value={newTask.title}
                    onChange={(e) => setNewTask(p => ({ ...p, title: e.target.value }))}
                    onKeyDown={(e) => e.key === 'Enter' && handleCreateTask()}
                    placeholder="Task title..."
                    className="input py-2 text-sm"
                    autoFocus
                  />
                  <input
                    type="text"
                    value={newTask.description}
                    onChange={(e) => setNewTask(p => ({ ...p, description: e.target.value }))}
                    placeholder="Description (optional)"
                    className="input py-2 text-sm"
                  />
                  <div className="flex gap-2">
                    <select
                      value={newTask.category}
                      onChange={(e) => setNewTask(p => ({ ...p, category: e.target.value }))}
                      className="input py-2 text-sm flex-1"
                    >
                      {CATEGORY_OPTIONS.map(c => (
                        <option key={c.value} value={c.value}>{c.label}</option>
                      ))}
                    </select>
                    <input
                      type="date"
                      value={newTask.due_date}
                      onChange={(e) => setNewTask(p => ({ ...p, due_date: e.target.value }))}
                      className="input py-2 text-sm flex-1"
                    />
                  </div>
                  <div className="flex items-center gap-2">
                    <button
                      onClick={handleCreateTask}
                      disabled={!newTask.title.trim() || taskSaving}
                      className="btn-primary py-2 text-xs flex items-center gap-1.5 disabled:opacity-40"
                    >
                      {taskSaving && <Loader2 className="w-3 h-3 animate-spin" />}
                      Add Task
                    </button>
                    <button
                      onClick={() => { setShowAddTask(false); setNewTask({ title: '', description: '', category: 'general', due_date: '' }); }}
                      className="btn-ghost py-2 text-xs"
                    >
                      Cancel
                    </button>
                  </div>
                </div>
              </motion.div>
            )}
          </AnimatePresence>

          {/* Task List */}
          <div className="space-y-1">
            <AnimatePresence>
              {tasks.length === 0 && !showAddTask && (
                <motion.div
                  initial={{ opacity: 0 }}
                  animate={{ opacity: 1 }}
                  className="text-center py-8"
                >
                  <CheckCircle2 className="w-8 h-8 text-dash-border mx-auto mb-2" />
                  <p className="text-sm text-dash-muted">No pending tasks</p>
                  <button
                    onClick={() => setShowAddTask(true)}
                    className="text-xs text-accent-dark font-medium mt-2 hover:underline"
                  >
                    Create your first task
                  </button>
                </motion.div>
              )}
              {tasks.map((task) => (
                <motion.div
                  key={task.id}
                  layout
                  initial={{ opacity: 0, y: 8 }}
                  animate={{ opacity: task.is_completed ? 0.5 : 1, y: 0 }}
                  exit={{ opacity: 0, x: -100 }}
                  transition={{ duration: 0.25 }}
                  className="flex items-start gap-3 p-3 rounded-xl hover:bg-dash-bg transition-colors group"
                >
                  <button
                    onClick={() => handleToggleTask(task)}
                    className={`mt-0.5 w-5 h-5 rounded-full border-2 flex-shrink-0 flex items-center justify-center transition-all
                      ${task.is_completed ? 'bg-accent border-accent' : 'border-dash-border hover:border-accent'}`}
                  >
                    {task.is_completed && <CheckCircle2 className="w-3 h-3 text-dash-dark" />}
                  </button>
                  <div className="flex-1 min-w-0">
                    <p className={`text-sm font-medium ${task.is_completed ? 'line-through text-dash-muted' : 'text-dash-dark'}`}>
                      {task.title}
                    </p>
                    <p className="text-xs text-dash-muted mt-0.5">
                      {task.category.charAt(0).toUpperCase() + task.category.slice(1)}
                      {task.due_date ? ` · ${formatDueDate(task.due_date)}` : ''}
                    </p>
                  </div>
                  <button
                    onClick={() => handleDeleteTask(task.id)}
                    className="p-1 opacity-0 group-hover:opacity-100 hover:bg-red-50 rounded-lg transition-all"
                    title="Delete task"
                  >
                    <Trash2 className="w-3.5 h-3.5 text-red-400" />
                  </button>
                </motion.div>
              ))}
            </AnimatePresence>
          </div>
        </motion.div>

        {/* Users table — DYNAMIC with working tabs */}
        <motion.div variants={item} className="xl:col-span-2 card overflow-hidden">
          <div className="flex items-center justify-between px-6 py-4 border-b border-dash-border">
            <div className="flex items-center gap-3">
              <h3 className="font-semibold text-dash-dark">Recent Users</h3>
              <span className="text-xs text-dash-muted bg-dash-bg px-2 py-0.5 rounded-md">
                {totalTableCount.toLocaleString()}
              </span>
            </div>
            <div className="flex items-center gap-2">
              {([
                { key: 'all', label: 'All Users' },
                { key: 'patients', label: 'Patients' },
                { key: 'doctors', label: 'Doctors' },
              ] as const).map((tab) => (
                <button
                  key={tab.key}
                  onClick={() => setUserTab(tab.key)}
                  className={`px-3 py-1.5 text-xs font-medium rounded-lg transition-all
                    ${userTab === tab.key ? 'bg-dash-dark text-white' : 'text-dash-muted hover:bg-dash-bg'}`}
                >
                  {tab.label}
                </button>
              ))}
            </div>
          </div>
          <table className="w-full">
            <thead>
              <tr className="bg-gray-50/50">
                <th className="table-header table-cell text-left">Name</th>
                <th className="table-header table-cell text-left">Role</th>
                <th className="table-header table-cell text-left">Date</th>
                <th className="table-header table-cell text-left">Type</th>
                <th className="table-header table-cell text-left">Status</th>
                <th className="table-header table-cell text-right">Action</th>
              </tr>
            </thead>
            <tbody>
              {tableData.length === 0 ? (
                <tr>
                  <td colSpan={6} className="py-12 text-center">
                    <Users className="w-8 h-8 text-dash-border mx-auto mb-2" />
                    <p className="text-sm text-dash-muted">No {userTab === 'all' ? 'users' : userTab} found</p>
                  </td>
                </tr>
              ) : (
                tableData.map((user) => (
                  <tr key={`${user.role}-${user.id}`} className="table-row">
                    <td className="table-cell">
                      <div className="flex items-center gap-3">
                        <div className="w-8 h-8 rounded-full bg-dash-bg text-dash-dark flex items-center justify-center text-xs font-semibold">
                          {user.name.split(' ').filter(Boolean).map(n => n[0]).join('').slice(0, 2)}
                        </div>
                        <span className="font-medium text-dash-dark">{user.name}</span>
                      </div>
                    </td>
                    <td className="table-cell">
                      <span className={`text-xs font-medium px-2.5 py-1 rounded-lg
                        ${user.role === 'Doctor' ? 'bg-purple-50 text-purple-600' : 'bg-blue-50 text-blue-600'}`}>
                        {user.role}
                      </span>
                    </td>
                    <td className="table-cell text-dash-muted">{user.date}</td>
                    <td className="table-cell text-dash-muted capitalize">{user.type}</td>
                    <td className="table-cell">
                      <span className={`text-xs font-medium px-2.5 py-1 rounded-lg capitalize
                        ${user.status === 'Active' || user.status === 'active' ? 'bg-emerald-50 text-emerald-600' :
                          user.status === 'Verified' ? 'bg-blue-50 text-blue-600' :
                          user.status === 'Pending' || user.status === 'pending_verification' ? 'bg-amber-50 text-amber-600' :
                          'bg-gray-50 text-gray-600'}`}>
                        {user.status}
                      </span>
                    </td>
                    <td className="table-cell text-right">
                      <Link
                        href={user.link}
                        className="text-dash-muted hover:text-accent-dark text-xs font-medium transition-colors"
                      >
                        View Details
                      </Link>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
          {tableData.length > 0 && (
            <div className="px-6 py-3 border-t border-dash-border flex items-center justify-between">
              <p className="text-xs text-dash-muted">
                Showing {tableData.length} of {userTab === 'patients' ? allUsers.length : userTab === 'doctors' ? allDoctors.length : totalTableCount}
              </p>
              <Link
                href={userTab === 'doctors' ? '/dashboard/doctors' : '/dashboard/users'}
                className="text-xs text-accent-dark font-medium hover:underline flex items-center gap-1"
              >
                View All <ChevronRight className="w-3 h-3" />
              </Link>
            </div>
          )}
        </motion.div>
      </div>

      {/* Schedule Row */}
      <div className="grid grid-cols-1 xl:grid-cols-3 gap-6">
        {/* Schedule / Pending Tickets */}
        <motion.div variants={item} className="card p-6">
          <div className="flex items-center justify-between mb-5">
            <h3 className="font-semibold text-dash-dark">
              {schedule.length > 0 ? 'Pending Tickets' : 'Schedule'}
            </h3>
            <Link href="/dashboard/tickets" className="text-xs text-dash-muted hover:text-dash-text flex items-center gap-1">
              View All <ChevronRight className="w-3 h-3" />
            </Link>
          </div>
          <div className="space-y-4">
            {schedule.length === 0 ? (
              <div className="text-center py-8">
                <TicketCheck className="w-8 h-8 text-dash-border mx-auto mb-2" />
                <p className="text-sm text-dash-muted">No pending tickets</p>
              </div>
            ) : (
              schedule.map((s: any, i: number) => (
                <div key={i} className="flex gap-4">
                  <span className="text-xs text-dash-muted w-14 pt-0.5 flex-shrink-0">{s.time}</span>
                  <div className={`flex-1 p-3 rounded-xl ${s.color} ${s.color === 'bg-accent' ? 'text-dash-dark' : 'text-white'}`}>
                    <p className="text-sm font-medium line-clamp-1">{s.title}</p>
                    <p className={`text-xs mt-0.5 capitalize ${s.color === 'bg-accent' ? 'text-dash-dark/60' : 'text-white/70'}`}>
                      {s.tag}
                    </p>
                  </div>
                </div>
              ))
            )}
          </div>
        </motion.div>

        {/* Recent Activity — DYNAMIC */}
        <motion.div variants={item} className="xl:col-span-2 card p-6">
          <div className="flex items-center justify-between mb-5">
            <h3 className="font-semibold text-dash-dark">Recent Activity</h3>
            <Link href="/dashboard/analytics" className="text-xs text-dash-muted hover:text-accent-dark font-medium">
              See All
            </Link>
          </div>
          <div className="space-y-4">
            {activities.map((activity: any, i: number) => (
              <div key={i} className="flex items-start gap-4">
                <div className="relative mt-1">
                  <div className={`w-2.5 h-2.5 rounded-full ${activity.dot}`} />
                  {i < activities.length - 1 && (
                    <div className="absolute top-3 left-1/2 -translate-x-1/2 w-px h-8 bg-dash-border" />
                  )}
                </div>
                <div className="flex-1">
                  <p className="text-sm font-medium text-dash-dark">{activity.action}</p>
                  <p className="text-xs text-dash-muted mt-0.5">{activity.desc}</p>
                </div>
                <span className="text-[10px] text-dash-muted flex-shrink-0">{activity.time}</span>
              </div>
            ))}
          </div>
        </motion.div>
      </div>
    </motion.div>
  );
}

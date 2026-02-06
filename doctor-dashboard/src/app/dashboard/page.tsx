'use client';

import { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import {
  Users,
  FileCheck,
  AlertTriangle,
  TrendingUp,
  Brain,
  Activity,
  Clock,
  ArrowUpRight,
  ArrowDownRight,
  ChevronRight,
  Sparkles,
  Heart,
  Zap,
  Hand,
} from 'lucide-react';
import { dashboardApi } from '@/lib/api';
import { getRiskColor, formatTimeAgo } from '@/lib/utils';
import { CategoryIcon } from '@/components/CategoryIcon';
import {
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  BarChart,
  Bar,
  PieChart,
  Pie,
  Cell,
} from 'recharts';
import Link from 'next/link';
import { useAuth } from '@/contexts/AuthContext';

// Animation variants
const containerVariants = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: {
      staggerChildren: 0.1,
    },
  },
};

const itemVariants = {
  hidden: { opacity: 0, y: 20 },
  visible: {
    opacity: 1,
    y: 0,
    transition: {
      duration: 0.5,
      ease: 'easeOut',
    },
  },
};

// Sample data for charts
const riskTrendData = [
  { day: 'Mon', ad: 32, pd: 28 },
  { day: 'Tue', ad: 35, pd: 25 },
  { day: 'Wed', ad: 30, pd: 32 },
  { day: 'Thu', ad: 45, pd: 35 },
  { day: 'Fri', ad: 42, pd: 30 },
  { day: 'Sat', ad: 38, pd: 28 },
  { day: 'Sun', ad: 40, pd: 33 },
];

const categoryDistribution = [
  { name: 'Cognitive', value: 35, color: '#8B5CF6' },
  { name: 'Speech', value: 25, color: '#3B82F6' },
  { name: 'Motor', value: 20, color: '#10B981' },
  { name: 'Gait', value: 12, color: '#F97316' },
  { name: 'Facial', value: 8, color: '#EC4899' },
];

export default function DashboardPage() {
  const { doctor } = useAuth();
  const [dashboardData, setDashboardData] = useState<any>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    loadDashboard();
  }, []);

  const loadDashboard = async () => {
    try {
      // For demo, using mock data. In production, use:
      // const data = await dashboardApi.getDashboard();
      setDashboardData({
        doctor_name: `${doctor?.first_name || 'Sarah'} ${doctor?.last_name || 'Ahmed'}`,
        specialization: 'Neurologist',
        total_patients: 156,
        pending_reviews: 12,
        reports_today: 8,
        critical_alerts: 3,
        recent_patients: [
          { id: 1, name: 'Ahmed Khan', age: 68, gender: 'male', risk_level: 'High', ad_risk_score: 78, pd_risk_score: 45, last_test_date: new Date().toISOString() },
          { id: 2, name: 'Fatima Ali', age: 55, gender: 'female', risk_level: 'Moderate', ad_risk_score: 52, pd_risk_score: 38, last_test_date: new Date(Date.now() - 86400000).toISOString() },
          { id: 3, name: 'Muhammad Usman', age: 72, gender: 'male', risk_level: 'Low', ad_risk_score: 25, pd_risk_score: 18, last_test_date: new Date(Date.now() - 172800000).toISOString() },
          { id: 4, name: 'Ayesha Malik', age: 61, gender: 'female', risk_level: 'Moderate', ad_risk_score: 48, pd_risk_score: 55, last_test_date: new Date(Date.now() - 259200000).toISOString() },
        ],
        pending_diagnostics: [
          { id: 1, patient_name: 'Bilal Hassan', test_category: 'cognitive', test_name: 'SDMT Test', completed_at: new Date().toISOString() },
          { id: 2, patient_name: 'Sara Qureshi', test_category: 'speech', test_name: 'Story Recall', completed_at: new Date(Date.now() - 3600000).toISOString() },
          { id: 3, patient_name: 'Imran Shah', test_category: 'motor', test_name: 'Spiral Drawing', completed_at: new Date(Date.now() - 7200000).toISOString() },
        ],
      });
    } catch (error) {
      console.error('Failed to load dashboard:', error);
    } finally {
      setIsLoading(false);
    }
  };

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-[60vh]">
        <div className="flex flex-col items-center gap-4">
          <div className="w-12 h-12 border-4 border-neuro-mint border-t-neuro-purple rounded-full animate-spin" />
          <p className="text-neuro-dark/60">Loading dashboard...</p>
        </div>
      </div>
    );
  }

  const stats = [
    {
      title: 'Total Patients',
      value: dashboardData?.total_patients || 0,
      change: '+12%',
      isPositive: true,
      icon: Users,
      color: 'from-neuro-purple to-neuro-blue',
      bgColor: 'bg-neuro-lavender/50',
    },
    {
      title: 'Pending Reviews',
      value: dashboardData?.pending_reviews || 0,
      change: '-5%',
      isPositive: true,
      icon: FileCheck,
      color: 'from-neuro-orange to-neuro-yellow',
      bgColor: 'bg-neuro-beige/50',
    },
    {
      title: 'Reports Today',
      value: dashboardData?.reports_today || 0,
      change: '+18%',
      isPositive: true,
      icon: TrendingUp,
      color: 'from-neuro-green to-neuro-mint',
      bgColor: 'bg-neuro-mint/30',
    },
    {
      title: 'Critical Alerts',
      value: dashboardData?.critical_alerts || 0,
      change: '+2',
      isPositive: false,
      icon: AlertTriangle,
      color: 'from-neuro-red to-neuro-orange',
      bgColor: 'bg-neuro-red/10',
    },
  ];

  return (
    <motion.div
      variants={containerVariants}
      initial="hidden"
      animate="visible"
      className="space-y-6"
    >
      {/* Welcome Header */}
      <motion.div variants={itemVariants} className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-3">
            <h1 className="text-3xl font-bold text-neuro-dark">
              Welcome back, <span className="gradient-text">Dr. {doctor?.first_name || 'Doctor'}</span>
            </h1>
            <motion.div
              animate={{ rotate: [0, 14, -8, 14, -4, 10, 0] }}
              transition={{ duration: 1.5, repeat: Infinity, repeatDelay: 3 }}
            >
              <Hand className="w-8 h-8 text-neuro-orange" />
            </motion.div>
          </div>
          <p className="text-neuro-dark/60 mt-1">
            Here's what's happening with your patients today.
          </p>
        </div>
        <motion.button
          whileHover={{ scale: 1.02 }}
          whileTap={{ scale: 0.98 }}
          className="flex items-center gap-2 px-6 py-3 bg-gradient-to-r from-neuro-purple to-neuro-blue 
                     text-white font-semibold rounded-xl shadow-lg hover:shadow-neuro-glow transition-all"
        >
          <Sparkles className="w-5 h-5" />
          AI Insights
        </motion.button>
      </motion.div>

      {/* Stats Cards */}
      <motion.div variants={itemVariants} className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {stats.map((stat, index) => (
          <motion.div
            key={stat.title}
            whileHover={{ y: -4, boxShadow: '0 20px 40px rgba(0,0,0,0.1)' }}
            className={`relative overflow-hidden p-6 rounded-2xl ${stat.bgColor} 
                       border border-white/50 backdrop-blur-sm transition-all duration-300`}
          >
            {/* Background Gradient Circle */}
            <div className={`absolute -right-6 -top-6 w-24 h-24 rounded-full bg-gradient-to-br ${stat.color} opacity-20`} />
            
            <div className="relative">
              <div className="flex items-center justify-between mb-4">
                <div className={`p-3 rounded-xl bg-gradient-to-br ${stat.color}`}>
                  <stat.icon className="w-5 h-5 text-white" />
                </div>
                <div className={`flex items-center gap-1 text-sm font-medium
                  ${stat.isPositive ? 'text-neuro-green' : 'text-neuro-red'}`}
                >
                  {stat.isPositive ? <ArrowUpRight className="w-4 h-4" /> : <ArrowDownRight className="w-4 h-4" />}
                  {stat.change}
                </div>
              </div>
              <p className="text-3xl font-bold text-neuro-dark">{stat.value}</p>
              <p className="text-sm text-neuro-dark/60 mt-1">{stat.title}</p>
            </div>
          </motion.div>
        ))}
      </motion.div>

      {/* Charts Row */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Risk Trend Chart */}
        <motion.div
          variants={itemVariants}
          className="lg:col-span-2 bg-white/80 backdrop-blur-xl rounded-2xl p-6 border border-white/50 shadow-neuro"
        >
          <div className="flex items-center justify-between mb-6">
            <div>
              <h3 className="text-lg font-semibold text-neuro-dark">Risk Score Trends</h3>
              <p className="text-sm text-neuro-dark/60">Weekly average risk scores</p>
            </div>
            <div className="flex items-center gap-4">
              <div className="flex items-center gap-2">
                <div className="w-3 h-3 rounded-full bg-neuro-purple" />
                <span className="text-sm text-neuro-dark/60">AD Risk</span>
              </div>
              <div className="flex items-center gap-2">
                <div className="w-3 h-3 rounded-full bg-neuro-blue" />
                <span className="text-sm text-neuro-dark/60">PD Risk</span>
              </div>
            </div>
          </div>
          <div className="h-64">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={riskTrendData}>
                <defs>
                  <linearGradient id="adGradient" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#8B5CF6" stopOpacity={0.3} />
                    <stop offset="95%" stopColor="#8B5CF6" stopOpacity={0} />
                  </linearGradient>
                  <linearGradient id="pdGradient" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#3B82F6" stopOpacity={0.3} />
                    <stop offset="95%" stopColor="#3B82F6" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="#E5E7EB" />
                <XAxis dataKey="day" stroke="#9CA3AF" fontSize={12} />
                <YAxis stroke="#9CA3AF" fontSize={12} />
                <Tooltip
                  contentStyle={{
                    backgroundColor: 'rgba(255,255,255,0.9)',
                    border: 'none',
                    borderRadius: '12px',
                    boxShadow: '0 4px 20px rgba(0,0,0,0.1)',
                  }}
                />
                <Area
                  type="monotone"
                  dataKey="ad"
                  stroke="#8B5CF6"
                  strokeWidth={2}
                  fillOpacity={1}
                  fill="url(#adGradient)"
                />
                <Area
                  type="monotone"
                  dataKey="pd"
                  stroke="#3B82F6"
                  strokeWidth={2}
                  fillOpacity={1}
                  fill="url(#pdGradient)"
                />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </motion.div>

        {/* Category Distribution */}
        <motion.div
          variants={itemVariants}
          className="bg-white/80 backdrop-blur-xl rounded-2xl p-6 border border-white/50 shadow-neuro"
        >
          <h3 className="text-lg font-semibold text-neuro-dark mb-2">Test Categories</h3>
          <p className="text-sm text-neuro-dark/60 mb-4">Distribution by category</p>
          <div className="h-48">
            <ResponsiveContainer width="100%" height="100%">
              <PieChart>
                <Pie
                  data={categoryDistribution}
                  cx="50%"
                  cy="50%"
                  innerRadius={50}
                  outerRadius={70}
                  paddingAngle={5}
                  dataKey="value"
                >
                  {categoryDistribution.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={entry.color} />
                  ))}
                </Pie>
                <Tooltip />
              </PieChart>
            </ResponsiveContainer>
          </div>
          <div className="grid grid-cols-2 gap-2 mt-4">
            {categoryDistribution.map((cat) => (
              <div key={cat.name} className="flex items-center gap-2">
                <div className="w-2 h-2 rounded-full" style={{ backgroundColor: cat.color }} />
                <span className="text-xs text-neuro-dark/60">{cat.name}</span>
                <span className="text-xs font-medium text-neuro-dark ml-auto">{cat.value}%</span>
              </div>
            ))}
          </div>
        </motion.div>
      </div>

      {/* Recent Activity Row */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Recent Patients */}
        <motion.div
          variants={itemVariants}
          className="bg-white/80 backdrop-blur-xl rounded-2xl p-6 border border-white/50 shadow-neuro"
        >
          <div className="flex items-center justify-between mb-6">
            <div>
              <h3 className="text-lg font-semibold text-neuro-dark">Recent Patients</h3>
              <p className="text-sm text-neuro-dark/60">Latest patient activity</p>
            </div>
            <Link href="/dashboard/patients">
              <motion.button
                whileHover={{ x: 4 }}
                className="flex items-center gap-1 text-sm text-neuro-purple font-medium hover:underline"
              >
                View All
                <ChevronRight className="w-4 h-4" />
              </motion.button>
            </Link>
          </div>
          
          <div className="space-y-4">
            {dashboardData?.recent_patients?.map((patient: any, index: number) => (
              <motion.div
                key={patient.id}
                initial={{ opacity: 0, x: -20 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ delay: index * 0.1 }}
                whileHover={{ x: 4 }}
                className="flex items-center gap-4 p-4 bg-neuro-bg/50 rounded-xl hover:bg-neuro-lavender/30 
                         transition-all cursor-pointer border border-transparent hover:border-neuro-purple/20"
              >
                <div className={`w-12 h-12 rounded-xl flex items-center justify-center text-white font-semibold
                  ${patient.risk_level === 'High' ? 'bg-gradient-to-br from-neuro-red to-neuro-orange' :
                    patient.risk_level === 'Moderate' ? 'bg-gradient-to-br from-neuro-orange to-neuro-yellow' :
                    'bg-gradient-to-br from-neuro-green to-neuro-mint'}`}
                >
                  {patient.name.split(' ').map((n: string) => n[0]).join('')}
                </div>
                <div className="flex-1 min-w-0">
                  <p className="font-medium text-neuro-dark truncate">{patient.name}</p>
                  <p className="text-sm text-neuro-dark/60">
                    {patient.age} yrs • {patient.gender}
                  </p>
                </div>
                <div className="text-right">
                  <div className="flex items-center gap-2">
                    <span className="text-xs font-medium px-2 py-1 rounded-lg bg-neuro-purple/10 text-neuro-purple">
                      AD: {patient.ad_risk_score}
                    </span>
                    <span className="text-xs font-medium px-2 py-1 rounded-lg bg-neuro-blue/10 text-neuro-blue">
                      PD: {patient.pd_risk_score}
                    </span>
                  </div>
                  <p className="text-xs text-neuro-dark/50 mt-1">
                    {formatTimeAgo(patient.last_test_date)}
                  </p>
                </div>
              </motion.div>
            ))}
          </div>
        </motion.div>

        {/* Pending Diagnostics */}
        <motion.div
          variants={itemVariants}
          className="bg-white/80 backdrop-blur-xl rounded-2xl p-6 border border-white/50 shadow-neuro"
        >
          <div className="flex items-center justify-between mb-6">
            <div>
              <h3 className="text-lg font-semibold text-neuro-dark">Pending Reviews</h3>
              <p className="text-sm text-neuro-dark/60">Tests awaiting your review</p>
            </div>
            <span className="px-3 py-1 bg-neuro-orange/10 text-neuro-orange text-sm font-medium rounded-full">
              {dashboardData?.pending_diagnostics?.length || 0} Pending
            </span>
          </div>

          <div className="space-y-4">
            {dashboardData?.pending_diagnostics?.map((diag: any, index: number) => (
              <motion.div
                key={diag.id}
                initial={{ opacity: 0, x: -20 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ delay: index * 0.1 }}
                whileHover={{ scale: 1.02 }}
                className="p-4 bg-gradient-to-r from-neuro-beige/30 to-neuro-yellow/20 rounded-xl 
                         border border-neuro-orange/20 cursor-pointer hover:shadow-md transition-all"
              >
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-3">
                    <div className="p-2 rounded-lg bg-white/60">
                      <CategoryIcon category={diag.test_category} className="w-6 h-6 text-neuro-purple" />
                    </div>
                    <div>
                      <p className="font-medium text-neuro-dark">{diag.patient_name}</p>
                      <p className="text-sm text-neuro-dark/60">{diag.test_name}</p>
                    </div>
                  </div>
                  <div className="text-right">
                    <p className="text-xs text-neuro-dark/50">{formatTimeAgo(diag.completed_at)}</p>
                    <motion.button
                      whileHover={{ scale: 1.05 }}
                      whileTap={{ scale: 0.95 }}
                      className="mt-2 px-3 py-1 bg-neuro-purple text-white text-xs font-medium rounded-lg"
                    >
                      Review
                    </motion.button>
                  </div>
                </div>
              </motion.div>
            ))}
          </div>

          {/* Quick Actions */}
          <div className="mt-6 pt-6 border-t border-neuro-dark/10">
            <p className="text-sm font-medium text-neuro-dark/60 mb-3">Quick Actions</p>
            <div className="grid grid-cols-2 gap-3">
              <motion.button
                whileHover={{ scale: 1.02 }}
                whileTap={{ scale: 0.98 }}
                className="flex items-center gap-2 p-3 bg-neuro-mint/30 rounded-xl text-neuro-dark
                         hover:bg-neuro-mint/50 transition-colors"
              >
                <Brain className="w-5 h-5 text-neuro-green" />
                <span className="text-sm font-medium">AI Analysis</span>
              </motion.button>
              <motion.button
                whileHover={{ scale: 1.02 }}
                whileTap={{ scale: 0.98 }}
                className="flex items-center gap-2 p-3 bg-neuro-lavender/50 rounded-xl text-neuro-dark
                         hover:bg-neuro-lavender transition-colors"
              >
                <FileCheck className="w-5 h-5 text-neuro-purple" />
                <span className="text-sm font-medium">Export Report</span>
              </motion.button>
            </div>
          </div>
        </motion.div>
      </div>
    </motion.div>
  );
}

'use client';

import { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { useParams, useRouter } from 'next/navigation';
import {
  ArrowLeft,
  User,
  Calendar,
  Phone,
  MapPin,
  Brain,
  Activity,
  TrendingUp,
  TrendingDown,
  AlertTriangle,
  FileText,
  Plus,
  Clock,
  ChevronRight,
  ExternalLink,
} from 'lucide-react';
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Area,
  AreaChart,
} from 'recharts';

const containerVariants = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: { staggerChildren: 0.1 },
  },
};

const itemVariants = {
  hidden: { opacity: 0, y: 20 },
  visible: { opacity: 1, y: 0 },
};

// Mock patient data
const mockPatient = {
  id: 1,
  first_name: 'Ahmed',
  last_name: 'Khan',
  email: 'ahmed.khan@email.com',
  phone: '+92 300 1234567',
  date_of_birth: '1958-05-15',
  gender: 'male',
  address: 'Lahore, Pakistan',
  ad_risk_score: 72,
  pd_risk_score: 28,
  ad_stage: 'mci',
  pd_stage: 'normal',
  last_test_date: '2026-02-01',
  total_tests: 24,
  assigned_at: '2025-11-15',
};

// Mock test history
const mockTestHistory = [
  {
    id: 1,
    test_type: 'SDMT',
    category: 'cognitive',
    score: 45,
    max_score: 100,
    completed_at: '2026-02-01T10:30:00Z',
    status: 'completed',
  },
  {
    id: 2,
    test_type: 'Digital Clock',
    category: 'cognitive',
    score: 68,
    max_score: 100,
    completed_at: '2026-02-01T10:15:00Z',
    status: 'completed',
  },
  {
    id: 3,
    test_type: 'Spiral Drawing',
    category: 'motor',
    score: 82,
    max_score: 100,
    completed_at: '2026-01-30T14:20:00Z',
    status: 'completed',
  },
  {
    id: 4,
    test_type: 'Finger Tapping',
    category: 'motor',
    score: 75,
    max_score: 100,
    completed_at: '2026-01-30T14:00:00Z',
    status: 'completed',
  },
  {
    id: 5,
    test_type: 'Voice Analysis',
    category: 'speech',
    score: 58,
    max_score: 100,
    completed_at: '2026-01-28T09:30:00Z',
    status: 'completed',
  },
];

// Mock risk trend data
const mockRiskTrend = [
  { date: 'Nov', ad_risk: 55, pd_risk: 22 },
  { date: 'Dec', ad_risk: 62, pd_risk: 25 },
  { date: 'Jan', ad_risk: 68, pd_risk: 26 },
  { date: 'Feb', ad_risk: 72, pd_risk: 28 },
];

const categoryConfig: Record<string, { color: string; bg: string; icon: any }> = {
  cognitive: { color: 'text-neuro-purple', bg: 'bg-neuro-purple/10', icon: Brain },
  motor: { color: 'text-neuro-blue', bg: 'bg-neuro-blue/10', icon: Activity },
  speech: { color: 'text-neuro-green', bg: 'bg-neuro-green/10', icon: Activity },
};

const getRiskLevel = (score: number) => {
  if (score >= 70) return { level: 'High', color: 'text-neuro-red', bg: 'bg-neuro-red/10' };
  if (score >= 40) return { level: 'Moderate', color: 'text-neuro-orange', bg: 'bg-neuro-orange/10' };
  return { level: 'Low', color: 'text-neuro-green', bg: 'bg-neuro-green/10' };
};

const getStageLabel = (stage: string) => {
  const stages: Record<string, string> = {
    normal: 'Normal',
    mci: 'MCI',
    mild: 'Mild',
    moderate: 'Moderate',
    severe: 'Severe',
  };
  return stages[stage] || stage;
};

export default function PatientDetailPage() {
  const router = useRouter();
  const params = useParams();
  const [patient, setPatient] = useState(mockPatient);
  const [testHistory, setTestHistory] = useState(mockTestHistory);
  const [riskTrend, setRiskTrend] = useState(mockRiskTrend);

  const adRisk = getRiskLevel(patient.ad_risk_score);
  const pdRisk = getRiskLevel(patient.pd_risk_score);
  const age = Math.floor((new Date().getTime() - new Date(patient.date_of_birth).getTime()) / 31557600000);

  return (
    <motion.div
      variants={containerVariants}
      initial="hidden"
      animate="visible"
      className="space-y-6"
    >
      {/* Back Button */}
      <motion.button
        variants={itemVariants}
        whileHover={{ x: -4 }}
        onClick={() => router.back()}
        className="flex items-center gap-2 text-neuro-dark/60 hover:text-neuro-dark transition-colors"
      >
        <ArrowLeft className="w-5 h-5" />
        Back to Patients
      </motion.button>

      {/* Patient Header Card */}
      <motion.div
        variants={itemVariants}
        className="bg-white/80 backdrop-blur-xl rounded-2xl p-6 border border-white/50 shadow-neuro"
      >
        <div className="flex flex-col md:flex-row md:items-start justify-between gap-6">
          {/* Patient Info */}
          <div className="flex items-start gap-4">
            <div className="w-20 h-20 rounded-2xl bg-gradient-to-br from-neuro-purple to-neuro-blue 
                          flex items-center justify-center text-white text-2xl font-bold flex-shrink-0">
              {patient.first_name[0]}{patient.last_name[0]}
            </div>
            <div>
              <h1 className="text-2xl font-bold text-neuro-dark">
                {patient.first_name} {patient.last_name}
              </h1>
              <p className="text-neuro-dark/60 mt-1">
                {age} years old • {patient.gender.charAt(0).toUpperCase() + patient.gender.slice(1)}
              </p>
              <div className="flex flex-wrap items-center gap-4 mt-3 text-sm text-neuro-dark/60">
                <span className="flex items-center gap-1">
                  <Phone className="w-4 h-4" />
                  {patient.phone}
                </span>
                <span className="flex items-center gap-1">
                  <MapPin className="w-4 h-4" />
                  {patient.address}
                </span>
              </div>
            </div>
          </div>

          {/* Quick Actions */}
          <div className="flex gap-3">
            <motion.button
              whileHover={{ scale: 1.02 }}
              whileTap={{ scale: 0.98 }}
              className="flex items-center gap-2 px-4 py-2 bg-neuro-bg hover:bg-neuro-dark/10 
                       rounded-xl transition-all text-neuro-dark/70"
            >
              <FileText className="w-4 h-4" />
              Add Note
            </motion.button>
            <motion.button
              whileHover={{ scale: 1.02 }}
              whileTap={{ scale: 0.98 }}
              className="flex items-center gap-2 px-4 py-2 bg-gradient-to-r from-neuro-purple to-neuro-blue 
                       text-white rounded-xl shadow-md"
            >
              <ExternalLink className="w-4 h-4" />
              Full Report
            </motion.button>
          </div>
        </div>

        {/* Risk Scores */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mt-6 pt-6 border-t border-neuro-dark/10">
          <div className="text-center p-4 bg-neuro-bg/50 rounded-xl">
            <p className="text-sm text-neuro-dark/60 mb-1">AD Risk Score</p>
            <p className={`text-3xl font-bold ${adRisk.color}`}>{patient.ad_risk_score}%</p>
            <span className={`text-xs px-2 py-1 ${adRisk.bg} ${adRisk.color} rounded-full`}>
              {adRisk.level} Risk
            </span>
          </div>
          <div className="text-center p-4 bg-neuro-bg/50 rounded-xl">
            <p className="text-sm text-neuro-dark/60 mb-1">PD Risk Score</p>
            <p className={`text-3xl font-bold ${pdRisk.color}`}>{patient.pd_risk_score}%</p>
            <span className={`text-xs px-2 py-1 ${pdRisk.bg} ${pdRisk.color} rounded-full`}>
              {pdRisk.level} Risk
            </span>
          </div>
          <div className="text-center p-4 bg-neuro-bg/50 rounded-xl">
            <p className="text-sm text-neuro-dark/60 mb-1">AD Stage</p>
            <p className="text-2xl font-bold text-neuro-dark">{getStageLabel(patient.ad_stage)}</p>
          </div>
          <div className="text-center p-4 bg-neuro-bg/50 rounded-xl">
            <p className="text-sm text-neuro-dark/60 mb-1">PD Stage</p>
            <p className="text-2xl font-bold text-neuro-dark">{getStageLabel(patient.pd_stage)}</p>
          </div>
        </div>
      </motion.div>

      {/* Charts & History Row */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Risk Trend Chart */}
        <motion.div
          variants={itemVariants}
          className="bg-white/80 backdrop-blur-xl rounded-2xl p-6 border border-white/50 shadow-neuro"
        >
          <h2 className="text-lg font-semibold text-neuro-dark mb-4 flex items-center gap-2">
            <TrendingUp className="w-5 h-5 text-neuro-purple" />
            Risk Score Trend
          </h2>
          <ResponsiveContainer width="100%" height={250}>
            <AreaChart data={riskTrend}>
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
              <XAxis dataKey="date" stroke="#6B7280" fontSize={12} />
              <YAxis stroke="#6B7280" fontSize={12} domain={[0, 100]} />
              <Tooltip
                contentStyle={{
                  backgroundColor: 'rgba(255,255,255,0.95)',
                  borderRadius: '12px',
                  border: 'none',
                  boxShadow: '0 4px 20px rgba(0,0,0,0.1)',
                }}
              />
              <Area
                type="monotone"
                dataKey="ad_risk"
                stroke="#8B5CF6"
                strokeWidth={2}
                fill="url(#adGradient)"
                name="AD Risk"
              />
              <Area
                type="monotone"
                dataKey="pd_risk"
                stroke="#3B82F6"
                strokeWidth={2}
                fill="url(#pdGradient)"
                name="PD Risk"
              />
            </AreaChart>
          </ResponsiveContainer>
        </motion.div>

        {/* Stats Overview */}
        <motion.div
          variants={itemVariants}
          className="bg-white/80 backdrop-blur-xl rounded-2xl p-6 border border-white/50 shadow-neuro"
        >
          <h2 className="text-lg font-semibold text-neuro-dark mb-4 flex items-center gap-2">
            <Activity className="w-5 h-5 text-neuro-purple" />
            Overview
          </h2>
          <div className="space-y-4">
            <div className="flex items-center justify-between p-4 bg-neuro-bg/50 rounded-xl">
              <span className="text-neuro-dark/70">Total Tests Completed</span>
              <span className="text-xl font-bold text-neuro-dark">{patient.total_tests}</span>
            </div>
            <div className="flex items-center justify-between p-4 bg-neuro-bg/50 rounded-xl">
              <span className="text-neuro-dark/70">Last Test Date</span>
              <span className="text-xl font-bold text-neuro-dark">
                {new Date(patient.last_test_date).toLocaleDateString('en-US', {
                  month: 'short',
                  day: 'numeric',
                  year: 'numeric',
                })}
              </span>
            </div>
            <div className="flex items-center justify-between p-4 bg-neuro-bg/50 rounded-xl">
              <span className="text-neuro-dark/70">Patient Since</span>
              <span className="text-xl font-bold text-neuro-dark">
                {new Date(patient.assigned_at).toLocaleDateString('en-US', {
                  month: 'short',
                  year: 'numeric',
                })}
              </span>
            </div>
            {patient.ad_risk_score >= 70 && (
              <div className="flex items-center gap-3 p-4 bg-neuro-red/10 rounded-xl text-neuro-red">
                <AlertTriangle className="w-5 h-5 flex-shrink-0" />
                <span className="text-sm font-medium">High AD risk detected. Consider specialist referral.</span>
              </div>
            )}
          </div>
        </motion.div>
      </div>

      {/* Test History */}
      <motion.div
        variants={itemVariants}
        className="bg-white/80 backdrop-blur-xl rounded-2xl p-6 border border-white/50 shadow-neuro"
      >
        <div className="flex items-center justify-between mb-6">
          <h2 className="text-lg font-semibold text-neuro-dark flex items-center gap-2">
            <Clock className="w-5 h-5 text-neuro-purple" />
            Recent Test History
          </h2>
          <button className="text-neuro-purple hover:text-neuro-purple/80 text-sm font-medium">
            View All Tests →
          </button>
        </div>

        <div className="space-y-3">
          {testHistory.map((test, index) => {
            const config = categoryConfig[test.category];
            const Icon = config.icon;
            const scorePercent = (test.score / test.max_score) * 100;

            return (
              <motion.div
                key={test.id}
                initial={{ opacity: 0, x: -20 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ delay: index * 0.1 }}
                whileHover={{ x: 4 }}
                className="flex items-center gap-4 p-4 bg-neuro-bg/30 hover:bg-neuro-bg/50 
                         rounded-xl transition-all cursor-pointer"
              >
                <div className={`p-3 rounded-xl ${config.bg}`}>
                  <Icon className={`w-5 h-5 ${config.color}`} />
                </div>
                <div className="flex-1">
                  <div className="flex items-center gap-2">
                    <h3 className="font-medium text-neuro-dark">{test.test_type}</h3>
                    <span className={`text-xs px-2 py-0.5 ${config.bg} ${config.color} rounded-full capitalize`}>
                      {test.category}
                    </span>
                  </div>
                  <p className="text-sm text-neuro-dark/60">
                    {new Date(test.completed_at).toLocaleDateString('en-US', {
                      month: 'short',
                      day: 'numeric',
                      hour: '2-digit',
                      minute: '2-digit',
                    })}
                  </p>
                </div>
                <div className="text-right">
                  <p className="text-lg font-bold text-neuro-dark">{test.score}/{test.max_score}</p>
                  <div className="w-24 h-2 bg-neuro-dark/10 rounded-full overflow-hidden">
                    <div
                      className="h-full rounded-full bg-gradient-to-r from-neuro-purple to-neuro-blue"
                      style={{ width: `${scorePercent}%` }}
                    />
                  </div>
                </div>
                <ChevronRight className="w-5 h-5 text-neuro-dark/40" />
              </motion.div>
            );
          })}
        </div>
      </motion.div>
    </motion.div>
  );
}

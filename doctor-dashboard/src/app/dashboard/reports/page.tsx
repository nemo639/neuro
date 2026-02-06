'use client';

import { useState } from 'react';
import { motion } from 'framer-motion';
import {
  FileText,
  Download,
  Search,
  Calendar,
  User,
  Brain,
  Activity,
  Filter,
  ChevronDown,
  Eye,
  Share2,
} from 'lucide-react';

const containerVariants = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: { staggerChildren: 0.05 },
  },
};

const itemVariants = {
  hidden: { opacity: 0, y: 20 },
  visible: { opacity: 1, y: 0 },
};

// Mock reports data
const mockReports = [
  {
    id: 1,
    patient_name: 'Ahmed Khan',
    patient_id: 1,
    report_type: 'comprehensive',
    ad_risk: 72,
    pd_risk: 28,
    generated_at: '2026-02-02T09:00:00Z',
    status: 'ready',
  },
  {
    id: 2,
    patient_name: 'Fatima Ali',
    patient_id: 2,
    report_type: 'progress',
    ad_risk: 35,
    pd_risk: 65,
    generated_at: '2026-02-01T16:30:00Z',
    status: 'ready',
  },
  {
    id: 3,
    patient_name: 'Hassan Raza',
    patient_id: 5,
    report_type: 'comprehensive',
    ad_risk: 88,
    pd_risk: 42,
    generated_at: '2026-02-01T14:00:00Z',
    status: 'ready',
  },
  {
    id: 4,
    patient_name: 'Zainab Ahmed',
    patient_id: 6,
    report_type: 'monthly',
    ad_risk: 55,
    pd_risk: 72,
    generated_at: '2026-02-01T10:00:00Z',
    status: 'pending',
  },
];

const reportTypeConfig: Record<string, { label: string; color: string; bg: string }> = {
  comprehensive: { label: 'Comprehensive', color: 'text-neuro-purple', bg: 'bg-neuro-purple/10' },
  progress: { label: 'Progress', color: 'text-neuro-blue', bg: 'bg-neuro-blue/10' },
  monthly: { label: 'Monthly', color: 'text-neuro-green', bg: 'bg-neuro-green/10' },
  weekly: { label: 'Weekly', color: 'text-neuro-orange', bg: 'bg-neuro-orange/10' },
};

const getRiskColor = (score: number) => {
  if (score >= 70) return 'text-neuro-red';
  if (score >= 40) return 'text-neuro-orange';
  return 'text-neuro-green';
};

export default function ReportsPage() {
  const [searchQuery, setSearchQuery] = useState('');
  const [typeFilter, setTypeFilter] = useState('all');

  const filteredReports = mockReports.filter((report) => {
    const matchesSearch = report.patient_name.toLowerCase().includes(searchQuery.toLowerCase());
    const matchesType = typeFilter === 'all' || report.report_type === typeFilter;
    return matchesSearch && matchesType;
  });

  return (
    <motion.div
      variants={containerVariants}
      initial="hidden"
      animate="visible"
      className="space-y-6"
    >
      {/* Header */}
      <motion.div variants={itemVariants} className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold text-neuro-dark">Reports</h1>
          <p className="text-neuro-dark/60 mt-1">
            View and download patient diagnostic reports
          </p>
        </div>
        <motion.button
          whileHover={{ scale: 1.02 }}
          whileTap={{ scale: 0.98 }}
          className="flex items-center gap-2 px-6 py-3 bg-gradient-to-r from-neuro-purple to-neuro-blue 
                   text-white font-semibold rounded-xl shadow-lg hover:shadow-neuro-glow transition-all"
        >
          <FileText className="w-5 h-5" />
          Generate Report
        </motion.button>
      </motion.div>

      {/* Stats Cards */}
      <motion.div variants={itemVariants} className="grid grid-cols-1 md:grid-cols-4 gap-4">
        {[
          { label: 'Total Reports', value: 156, icon: FileText, color: 'neuro-purple' },
          { label: 'This Month', value: 24, icon: Calendar, color: 'neuro-blue' },
          { label: 'Pending', value: 3, icon: Activity, color: 'neuro-orange' },
          { label: 'High Risk', value: 8, icon: Brain, color: 'neuro-red' },
        ].map((stat, index) => (
          <div
            key={stat.label}
            className="bg-white/80 backdrop-blur-xl rounded-xl p-4 border border-white/50 shadow-neuro"
          >
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-neuro-dark/60">{stat.label}</p>
                <p className="text-2xl font-bold text-neuro-dark mt-1">{stat.value}</p>
              </div>
              <div className={`p-3 rounded-xl bg-${stat.color}/10`}>
                <stat.icon className={`w-5 h-5 text-${stat.color}`} />
              </div>
            </div>
          </div>
        ))}
      </motion.div>

      {/* Search & Filters */}
      <motion.div variants={itemVariants} className="flex flex-col md:flex-row gap-4">
        <div className="relative flex-1">
          <Search className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-neuro-dark/40" />
          <input
            type="text"
            placeholder="Search reports by patient name..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-12 pr-4 py-3 bg-white/80 backdrop-blur-sm border border-neuro-dark/10 rounded-xl
                     focus:outline-none focus:ring-2 focus:ring-neuro-purple/20 focus:border-neuro-purple/30
                     transition-all"
          />
        </div>

        <select
          value={typeFilter}
          onChange={(e) => setTypeFilter(e.target.value)}
          className="px-4 py-3 bg-white/80 backdrop-blur-sm border border-neuro-dark/10 rounded-xl
                   focus:outline-none focus:ring-2 focus:ring-neuro-purple/20 appearance-none cursor-pointer"
        >
          <option value="all">All Types</option>
          <option value="comprehensive">Comprehensive</option>
          <option value="progress">Progress</option>
          <option value="monthly">Monthly</option>
          <option value="weekly">Weekly</option>
        </select>
      </motion.div>

      {/* Reports Table */}
      <motion.div
        variants={itemVariants}
        className="bg-white/80 backdrop-blur-xl rounded-2xl border border-white/50 shadow-neuro overflow-hidden"
      >
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="bg-neuro-bg/50 border-b border-neuro-dark/10">
                <th className="text-left p-4 text-sm font-semibold text-neuro-dark/70">Patient</th>
                <th className="text-left p-4 text-sm font-semibold text-neuro-dark/70">Report Type</th>
                <th className="text-center p-4 text-sm font-semibold text-neuro-dark/70">AD Risk</th>
                <th className="text-center p-4 text-sm font-semibold text-neuro-dark/70">PD Risk</th>
                <th className="text-left p-4 text-sm font-semibold text-neuro-dark/70">Generated</th>
                <th className="text-left p-4 text-sm font-semibold text-neuro-dark/70">Status</th>
                <th className="text-right p-4 text-sm font-semibold text-neuro-dark/70">Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredReports.map((report, index) => {
                const typeConfig = reportTypeConfig[report.report_type];
                return (
                  <motion.tr
                    key={report.id}
                    initial={{ opacity: 0, y: 20 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ delay: index * 0.05 }}
                    className="border-b border-neuro-dark/5 hover:bg-neuro-bg/30 transition-colors"
                  >
                    <td className="p-4">
                      <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-neuro-purple to-neuro-blue 
                                      flex items-center justify-center text-white text-sm font-bold">
                          {report.patient_name.split(' ').map(n => n[0]).join('')}
                        </div>
                        <span className="font-medium text-neuro-dark">{report.patient_name}</span>
                      </div>
                    </td>
                    <td className="p-4">
                      <span className={`px-3 py-1 rounded-full text-xs font-medium ${typeConfig.color} ${typeConfig.bg}`}>
                        {typeConfig.label}
                      </span>
                    </td>
                    <td className="p-4 text-center">
                      <span className={`font-semibold ${getRiskColor(report.ad_risk)}`}>
                        {report.ad_risk}%
                      </span>
                    </td>
                    <td className="p-4 text-center">
                      <span className={`font-semibold ${getRiskColor(report.pd_risk)}`}>
                        {report.pd_risk}%
                      </span>
                    </td>
                    <td className="p-4 text-neuro-dark/70">
                      {new Date(report.generated_at).toLocaleDateString('en-US', {
                        month: 'short',
                        day: 'numeric',
                        year: 'numeric',
                      })}
                    </td>
                    <td className="p-4">
                      {report.status === 'ready' ? (
                        <span className="flex items-center gap-1 text-neuro-green text-sm">
                          <div className="w-2 h-2 bg-neuro-green rounded-full" />
                          Ready
                        </span>
                      ) : (
                        <span className="flex items-center gap-1 text-neuro-orange text-sm">
                          <div className="w-2 h-2 bg-neuro-orange rounded-full animate-pulse" />
                          Processing
                        </span>
                      )}
                    </td>
                    <td className="p-4">
                      <div className="flex items-center justify-end gap-2">
                        <motion.button
                          whileHover={{ scale: 1.1 }}
                          whileTap={{ scale: 0.9 }}
                          className="p-2 hover:bg-neuro-bg rounded-lg transition-colors"
                          title="View"
                        >
                          <Eye className="w-4 h-4 text-neuro-dark/60" />
                        </motion.button>
                        <motion.button
                          whileHover={{ scale: 1.1 }}
                          whileTap={{ scale: 0.9 }}
                          className="p-2 hover:bg-neuro-bg rounded-lg transition-colors"
                          title="Download"
                        >
                          <Download className="w-4 h-4 text-neuro-blue" />
                        </motion.button>
                        <motion.button
                          whileHover={{ scale: 1.1 }}
                          whileTap={{ scale: 0.9 }}
                          className="p-2 hover:bg-neuro-bg rounded-lg transition-colors"
                          title="Share"
                        >
                          <Share2 className="w-4 h-4 text-neuro-purple" />
                        </motion.button>
                      </div>
                    </td>
                  </motion.tr>
                );
              })}
            </tbody>
          </table>
        </div>

        {/* Empty State */}
        {filteredReports.length === 0 && (
          <div className="text-center py-16">
            <FileText className="w-16 h-16 text-neuro-dark/20 mx-auto mb-4" />
            <h3 className="text-xl font-semibold text-neuro-dark mb-2">No reports found</h3>
            <p className="text-neuro-dark/60">Try adjusting your search or filters</p>
          </div>
        )}
      </motion.div>
    </motion.div>
  );
}

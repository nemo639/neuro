'use client';

import { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
  Search,
  Filter,
  ChevronDown,
  ChevronRight,
  Brain,
  Activity,
  Users,
  AlertTriangle,
  TrendingUp,
  TrendingDown,
  Eye,
  FileText,
  Download,
  X,
} from 'lucide-react';
import { patientsApi } from '@/lib/api';
import { getRiskColor, formatDate, formatTimeAgo, getCategoryIcon, getCategoryColor } from '@/lib/utils';
import Link from 'next/link';

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

// Mock patient data
const mockPatients = [
  { id: 1, first_name: 'Ahmed', last_name: 'Khan', age: 68, gender: 'Male', email: 'ahmed@email.com', ad_risk_score: 78, pd_risk_score: 45, ad_stage: 'MCI', pd_stage: 'Normal', last_test: '2026-02-01', total_tests: 12 },
  { id: 2, first_name: 'Fatima', last_name: 'Ali', age: 55, gender: 'Female', email: 'fatima@email.com', ad_risk_score: 52, pd_risk_score: 38, ad_stage: 'CN', pd_stage: 'Normal', last_test: '2026-02-01', total_tests: 8 },
  { id: 3, first_name: 'Muhammad', last_name: 'Usman', age: 72, gender: 'Male', email: 'usman@email.com', ad_risk_score: 25, pd_risk_score: 18, ad_stage: 'CN', pd_stage: 'Normal', last_test: '2026-01-30', total_tests: 15 },
  { id: 4, first_name: 'Ayesha', last_name: 'Malik', age: 61, gender: 'Female', email: 'ayesha@email.com', ad_risk_score: 48, pd_risk_score: 65, ad_stage: 'CN', pd_stage: 'Early PD', last_test: '2026-01-29', total_tests: 6 },
  { id: 5, first_name: 'Hassan', last_name: 'Raza', age: 75, gender: 'Male', email: 'hassan@email.com', ad_risk_score: 85, pd_risk_score: 42, ad_stage: 'Mild AD', pd_stage: 'Normal', last_test: '2026-01-28', total_tests: 20 },
  { id: 6, first_name: 'Zainab', last_name: 'Ahmed', age: 58, gender: 'Female', email: 'zainab@email.com', ad_risk_score: 35, pd_risk_score: 72, ad_stage: 'CN', pd_stage: 'Moderate PD', last_test: '2026-01-27', total_tests: 10 },
];

export default function PatientsPage() {
  const [patients, setPatients] = useState(mockPatients);
  const [isLoading, setIsLoading] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [riskFilter, setRiskFilter] = useState<string>('all');
  const [sortBy, setSortBy] = useState<string>('last_test');
  const [selectedPatient, setSelectedPatient] = useState<any>(null);
  const [isFilterOpen, setIsFilterOpen] = useState(false);

  const filteredPatients = patients.filter((patient) => {
    const matchesSearch = 
      `${patient.first_name} ${patient.last_name}`.toLowerCase().includes(searchQuery.toLowerCase()) ||
      patient.email.toLowerCase().includes(searchQuery.toLowerCase());
    
    const maxRisk = Math.max(patient.ad_risk_score, patient.pd_risk_score);
    const matchesRisk = 
      riskFilter === 'all' ||
      (riskFilter === 'high' && maxRisk >= 70) ||
      (riskFilter === 'moderate' && maxRisk >= 40 && maxRisk < 70) ||
      (riskFilter === 'low' && maxRisk < 40);

    return matchesSearch && matchesRisk;
  });

  const getRiskLevel = (score: number) => {
    if (score >= 70) return { level: 'High', color: 'text-neuro-red bg-neuro-red/10' };
    if (score >= 40) return { level: 'Moderate', color: 'text-neuro-orange bg-neuro-orange/10' };
    return { level: 'Low', color: 'text-neuro-green bg-neuro-green/10' };
  };

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
          <h1 className="text-3xl font-bold text-neuro-dark">Patients</h1>
          <p className="text-neuro-dark/60 mt-1">
            Manage and monitor your patients' neurological health
          </p>
        </div>
        <div className="flex items-center gap-3">
          <span className="px-4 py-2 bg-neuro-lavender/30 rounded-xl text-neuro-purple font-medium">
            {filteredPatients.length} Patients
          </span>
        </div>
      </motion.div>

      {/* Search & Filters */}
      <motion.div variants={itemVariants} className="flex flex-col md:flex-row gap-4">
        {/* Search */}
        <div className="relative flex-1">
          <Search className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-neuro-dark/40" />
          <input
            type="text"
            placeholder="Search patients by name or email..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-12 pr-4 py-3 bg-white/80 backdrop-blur-sm border border-neuro-dark/10 rounded-xl
                     focus:outline-none focus:ring-2 focus:ring-neuro-purple/20 focus:border-neuro-purple/30
                     transition-all"
          />
        </div>

        {/* Risk Filter */}
        <div className="relative">
          <button
            onClick={() => setIsFilterOpen(!isFilterOpen)}
            className="flex items-center gap-2 px-4 py-3 bg-white/80 backdrop-blur-sm border border-neuro-dark/10 
                     rounded-xl hover:border-neuro-purple/30 transition-all min-w-[160px]"
          >
            <Filter className="w-5 h-5 text-neuro-dark/60" />
            <span className="text-neuro-dark capitalize">{riskFilter === 'all' ? 'All Risks' : `${riskFilter} Risk`}</span>
            <ChevronDown className={`w-4 h-4 text-neuro-dark/60 ml-auto transition-transform ${isFilterOpen ? 'rotate-180' : ''}`} />
          </button>

          <AnimatePresence>
            {isFilterOpen && (
              <motion.div
                initial={{ opacity: 0, y: -10 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -10 }}
                className="absolute top-full mt-2 right-0 w-full bg-white rounded-xl shadow-neuro-lg border border-neuro-dark/10 
                         overflow-hidden z-20"
              >
                {['all', 'high', 'moderate', 'low'].map((filter) => (
                  <button
                    key={filter}
                    onClick={() => { setRiskFilter(filter); setIsFilterOpen(false); }}
                    className={`w-full px-4 py-3 text-left hover:bg-neuro-bg transition-colors capitalize
                      ${riskFilter === filter ? 'bg-neuro-purple/10 text-neuro-purple' : 'text-neuro-dark'}`}
                  >
                    {filter === 'all' ? 'All Risks' : `${filter} Risk`}
                  </button>
                ))}
              </motion.div>
            )}
          </AnimatePresence>
        </div>
      </motion.div>

      {/* Patients Grid */}
      <motion.div variants={itemVariants} className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {filteredPatients.map((patient, index) => {
          const maxRisk = Math.max(patient.ad_risk_score, patient.pd_risk_score);
          const riskInfo = getRiskLevel(maxRisk);

          return (
            <motion.div
              key={patient.id}
              variants={itemVariants}
              whileHover={{ y: -4, boxShadow: '0 20px 40px rgba(0,0,0,0.1)' }}
              className="bg-white/80 backdrop-blur-xl rounded-2xl p-6 border border-white/50 
                       hover:border-neuro-purple/30 transition-all cursor-pointer"
              onClick={() => setSelectedPatient(patient)}
            >
              {/* Header */}
              <div className="flex items-start justify-between mb-4">
                <div className="flex items-center gap-3">
                  <div className={`w-12 h-12 rounded-xl flex items-center justify-center text-white font-bold
                    ${maxRisk >= 70 ? 'bg-gradient-to-br from-neuro-red to-neuro-orange' :
                      maxRisk >= 40 ? 'bg-gradient-to-br from-neuro-orange to-neuro-yellow' :
                      'bg-gradient-to-br from-neuro-green to-neuro-mint'}`}
                  >
                    {patient.first_name[0]}{patient.last_name[0]}
                  </div>
                  <div>
                    <h3 className="font-semibold text-neuro-dark">{patient.first_name} {patient.last_name}</h3>
                    <p className="text-sm text-neuro-dark/60">{patient.age} yrs • {patient.gender}</p>
                  </div>
                </div>
                <span className={`px-2 py-1 rounded-lg text-xs font-medium ${riskInfo.color}`}>
                  {riskInfo.level}
                </span>
              </div>

              {/* Risk Scores */}
              <div className="grid grid-cols-2 gap-3 mb-4">
                <div className="p-3 bg-neuro-purple/5 rounded-xl">
                  <div className="flex items-center gap-2 mb-1">
                    <Brain className="w-4 h-4 text-neuro-purple" />
                    <span className="text-xs text-neuro-dark/60">AD Risk</span>
                  </div>
                  <div className="flex items-baseline gap-1">
                    <span className="text-xl font-bold text-neuro-purple">{patient.ad_risk_score}</span>
                    <span className="text-xs text-neuro-dark/50">/100</span>
                  </div>
                  <p className="text-xs text-neuro-dark/60 mt-1">{patient.ad_stage}</p>
                </div>
                <div className="p-3 bg-neuro-blue/5 rounded-xl">
                  <div className="flex items-center gap-2 mb-1">
                    <Activity className="w-4 h-4 text-neuro-blue" />
                    <span className="text-xs text-neuro-dark/60">PD Risk</span>
                  </div>
                  <div className="flex items-baseline gap-1">
                    <span className="text-xl font-bold text-neuro-blue">{patient.pd_risk_score}</span>
                    <span className="text-xs text-neuro-dark/50">/100</span>
                  </div>
                  <p className="text-xs text-neuro-dark/60 mt-1">{patient.pd_stage}</p>
                </div>
              </div>

              {/* Footer */}
              <div className="flex items-center justify-between pt-4 border-t border-neuro-dark/5">
                <div className="text-sm text-neuro-dark/60">
                  <span className="font-medium text-neuro-dark">{patient.total_tests}</span> tests
                </div>
                <div className="text-sm text-neuro-dark/50">
                  Last: {formatDate(patient.last_test)}
                </div>
              </div>
            </motion.div>
          );
        })}
      </motion.div>

      {/* Patient Detail Modal */}
      <AnimatePresence>
        {selectedPatient && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4"
            onClick={() => setSelectedPatient(null)}
          >
            <motion.div
              initial={{ scale: 0.9, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.9, opacity: 0 }}
              className="bg-white rounded-3xl p-8 max-w-2xl w-full max-h-[90vh] overflow-y-auto"
              onClick={(e) => e.stopPropagation()}
            >
              {/* Modal Header */}
              <div className="flex items-start justify-between mb-6">
                <div className="flex items-center gap-4">
                  <div className={`w-16 h-16 rounded-2xl flex items-center justify-center text-white text-xl font-bold
                    ${Math.max(selectedPatient.ad_risk_score, selectedPatient.pd_risk_score) >= 70 
                      ? 'bg-gradient-to-br from-neuro-red to-neuro-orange' 
                      : Math.max(selectedPatient.ad_risk_score, selectedPatient.pd_risk_score) >= 40 
                        ? 'bg-gradient-to-br from-neuro-orange to-neuro-yellow'
                        : 'bg-gradient-to-br from-neuro-green to-neuro-mint'}`}
                  >
                    {selectedPatient.first_name[0]}{selectedPatient.last_name[0]}
                  </div>
                  <div>
                    <h2 className="text-2xl font-bold text-neuro-dark">
                      {selectedPatient.first_name} {selectedPatient.last_name}
                    </h2>
                    <p className="text-neuro-dark/60">
                      {selectedPatient.age} years • {selectedPatient.gender} • {selectedPatient.email}
                    </p>
                  </div>
                </div>
                <button
                  onClick={() => setSelectedPatient(null)}
                  className="p-2 hover:bg-neuro-bg rounded-xl transition-colors"
                >
                  <X className="w-6 h-6 text-neuro-dark/60" />
                </button>
              </div>

              {/* Risk Overview */}
              <div className="grid grid-cols-2 gap-4 mb-6">
                <div className="p-6 bg-gradient-to-br from-neuro-purple/10 to-neuro-lavender/30 rounded-2xl">
                  <div className="flex items-center gap-2 mb-2">
                    <Brain className="w-5 h-5 text-neuro-purple" />
                    <span className="font-medium text-neuro-dark">Alzheimer's Risk</span>
                  </div>
                  <div className="flex items-baseline gap-2">
                    <span className="text-4xl font-bold text-neuro-purple">{selectedPatient.ad_risk_score}</span>
                    <span className="text-neuro-dark/50">/100</span>
                  </div>
                  <p className="text-sm text-neuro-dark/60 mt-2">Stage: {selectedPatient.ad_stage}</p>
                </div>
                <div className="p-6 bg-gradient-to-br from-neuro-blue/10 to-neuro-mint/30 rounded-2xl">
                  <div className="flex items-center gap-2 mb-2">
                    <Activity className="w-5 h-5 text-neuro-blue" />
                    <span className="font-medium text-neuro-dark">Parkinson's Risk</span>
                  </div>
                  <div className="flex items-baseline gap-2">
                    <span className="text-4xl font-bold text-neuro-blue">{selectedPatient.pd_risk_score}</span>
                    <span className="text-neuro-dark/50">/100</span>
                  </div>
                  <p className="text-sm text-neuro-dark/60 mt-2">Stage: {selectedPatient.pd_stage}</p>
                </div>
              </div>

              {/* Actions */}
              <div className="grid grid-cols-3 gap-3">
                <motion.button
                  whileHover={{ scale: 1.02 }}
                  whileTap={{ scale: 0.98 }}
                  className="flex items-center justify-center gap-2 p-4 bg-neuro-purple text-white rounded-xl font-medium"
                >
                  <Eye className="w-5 h-5" />
                  View Details
                </motion.button>
                <motion.button
                  whileHover={{ scale: 1.02 }}
                  whileTap={{ scale: 0.98 }}
                  className="flex items-center justify-center gap-2 p-4 bg-neuro-mint/30 text-neuro-dark rounded-xl font-medium"
                >
                  <FileText className="w-5 h-5" />
                  Add Note
                </motion.button>
                <motion.button
                  whileHover={{ scale: 1.02 }}
                  whileTap={{ scale: 0.98 }}
                  className="flex items-center justify-center gap-2 p-4 bg-neuro-beige/50 text-neuro-dark rounded-xl font-medium"
                >
                  <Download className="w-5 h-5" />
                  Export
                </motion.button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </motion.div>
  );
}

'use client';

import { useState } from 'react';
import { motion } from 'framer-motion';
import {
  FileText,
  Plus,
  Search,
  Filter,
  ChevronDown,
  Calendar,
  User,
  Tag,
  Flag,
  MoreVertical,
  Edit,
  Trash2,
  Eye,
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

// Mock notes data
const mockNotes = [
  {
    id: 1,
    patient_name: 'Ahmed Khan',
    patient_id: 1,
    title: 'Initial Assessment - Cognitive Decline',
    content: 'Patient shows signs of mild cognitive impairment. Recommend follow-up SDMT test in 2 weeks.',
    note_type: 'diagnosis',
    is_flagged: true,
    created_at: '2026-02-01T10:30:00Z',
  },
  {
    id: 2,
    patient_name: 'Fatima Ali',
    patient_id: 2,
    title: 'Follow-up Review',
    content: 'Motor function improved after medication adjustment. Continue current treatment.',
    note_type: 'follow_up',
    is_flagged: false,
    created_at: '2026-02-01T09:15:00Z',
  },
  {
    id: 3,
    patient_name: 'Hassan Raza',
    patient_id: 5,
    title: 'Critical - High AD Risk',
    content: 'AD risk score increased significantly. Recommend immediate neurologist consultation.',
    note_type: 'observation',
    is_flagged: true,
    created_at: '2026-01-31T16:45:00Z',
  },
  {
    id: 4,
    patient_name: 'Zainab Ahmed',
    patient_id: 6,
    title: 'Treatment Plan Update',
    content: 'Started new medication regimen for PD symptoms. Monitor for side effects.',
    note_type: 'treatment',
    is_flagged: false,
    created_at: '2026-01-30T14:20:00Z',
  },
];

const noteTypeColors: Record<string, string> = {
  general: 'bg-neuro-dark/10 text-neuro-dark',
  diagnosis: 'bg-neuro-purple/10 text-neuro-purple',
  treatment: 'bg-neuro-green/10 text-neuro-green',
  follow_up: 'bg-neuro-blue/10 text-neuro-blue',
  observation: 'bg-neuro-orange/10 text-neuro-orange',
};

export default function NotesPage() {
  const [notes, setNotes] = useState(mockNotes);
  const [searchQuery, setSearchQuery] = useState('');
  const [typeFilter, setTypeFilter] = useState('all');
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);

  const filteredNotes = notes.filter((note) => {
    const matchesSearch = 
      note.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
      note.patient_name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      note.content.toLowerCase().includes(searchQuery.toLowerCase());
    
    const matchesType = typeFilter === 'all' || note.note_type === typeFilter;

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
          <h1 className="text-3xl font-bold text-neuro-dark">Clinical Notes</h1>
          <p className="text-neuro-dark/60 mt-1">
            Document and track patient observations
          </p>
        </div>
        <motion.button
          whileHover={{ scale: 1.02 }}
          whileTap={{ scale: 0.98 }}
          onClick={() => setIsCreateModalOpen(true)}
          className="flex items-center gap-2 px-6 py-3 bg-gradient-to-r from-neuro-purple to-neuro-blue 
                     text-white font-semibold rounded-xl shadow-lg hover:shadow-neuro-glow transition-all"
        >
          <Plus className="w-5 h-5" />
          New Note
        </motion.button>
      </motion.div>

      {/* Search & Filters */}
      <motion.div variants={itemVariants} className="flex flex-col md:flex-row gap-4">
        <div className="relative flex-1">
          <Search className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-neuro-dark/40" />
          <input
            type="text"
            placeholder="Search notes..."
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
          <option value="general">General</option>
          <option value="diagnosis">Diagnosis</option>
          <option value="treatment">Treatment</option>
          <option value="follow_up">Follow Up</option>
          <option value="observation">Observation</option>
        </select>
      </motion.div>

      {/* Notes List */}
      <motion.div variants={itemVariants} className="space-y-4">
        {filteredNotes.map((note, index) => (
          <motion.div
            key={note.id}
            variants={itemVariants}
            whileHover={{ x: 4 }}
            className="bg-white/80 backdrop-blur-xl rounded-2xl p-6 border border-white/50 
                     hover:border-neuro-purple/30 hover:shadow-neuro transition-all"
          >
            <div className="flex items-start justify-between gap-4">
              <div className="flex-1">
                {/* Header */}
                <div className="flex items-center gap-3 mb-3">
                  <span className={`px-3 py-1 rounded-full text-xs font-medium capitalize ${noteTypeColors[note.note_type]}`}>
                    {note.note_type.replace('_', ' ')}
                  </span>
                  {note.is_flagged && (
                    <span className="flex items-center gap-1 px-2 py-1 bg-neuro-red/10 text-neuro-red rounded-full text-xs">
                      <Flag className="w-3 h-3" />
                      Flagged
                    </span>
                  )}
                  <span className="text-xs text-neuro-dark/50">
                    {new Date(note.created_at).toLocaleDateString('en-US', {
                      month: 'short',
                      day: 'numeric',
                      hour: '2-digit',
                      minute: '2-digit',
                    })}
                  </span>
                </div>

                {/* Title & Patient */}
                <h3 className="text-lg font-semibold text-neuro-dark mb-1">{note.title}</h3>
                <div className="flex items-center gap-2 text-sm text-neuro-dark/60 mb-3">
                  <User className="w-4 h-4" />
                  <span>{note.patient_name}</span>
                </div>

                {/* Content Preview */}
                <p className="text-neuro-dark/70 line-clamp-2">{note.content}</p>
              </div>

              {/* Actions */}
              <div className="flex items-center gap-2">
                <motion.button
                  whileHover={{ scale: 1.1 }}
                  whileTap={{ scale: 0.9 }}
                  className="p-2 hover:bg-neuro-bg rounded-lg transition-colors"
                >
                  <Eye className="w-5 h-5 text-neuro-dark/60" />
                </motion.button>
                <motion.button
                  whileHover={{ scale: 1.1 }}
                  whileTap={{ scale: 0.9 }}
                  className="p-2 hover:bg-neuro-bg rounded-lg transition-colors"
                >
                  <Edit className="w-5 h-5 text-neuro-blue" />
                </motion.button>
                <motion.button
                  whileHover={{ scale: 1.1 }}
                  whileTap={{ scale: 0.9 }}
                  className="p-2 hover:bg-neuro-red/10 rounded-lg transition-colors"
                >
                  <Trash2 className="w-5 h-5 text-neuro-red/60" />
                </motion.button>
              </div>
            </div>
          </motion.div>
        ))}
      </motion.div>

      {/* Empty State */}
      {filteredNotes.length === 0 && (
        <motion.div
          variants={itemVariants}
          className="text-center py-16"
        >
          <FileText className="w-16 h-16 text-neuro-dark/20 mx-auto mb-4" />
          <h3 className="text-xl font-semibold text-neuro-dark mb-2">No notes found</h3>
          <p className="text-neuro-dark/60">Try adjusting your search or filters</p>
        </motion.div>
      )}
    </motion.div>
  );
}

'use client';

import { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import {
  Search,
  Plus,
  FileText,
  Flag,
  Trash2,
  Eye,
  X,
  Clock,
  Tag,
  ChevronRight,
  MoreVertical,
} from 'lucide-react';
import { notesApi } from '@/lib/api';

const cv = { hidden: { opacity: 0 }, visible: { opacity: 1, transition: { staggerChildren: 0.05 } } };
const iv = { hidden: { opacity: 0, y: 12 }, visible: { opacity: 1, y: 0, transition: { duration: 0.4 } } };

type Note = {
  id: number;
  patient_id: number;
  patient_name?: string;
  title: string;
  content: string;
  note_type: string;
  is_flagged: boolean;
  is_private: boolean;
  created_at: string;
  updated_at: string;
};

const typeStyle: Record<string, { bg: string; text: string }> = {
  general: { bg: 'bg-blue-100', text: 'text-blue-700' },
  diagnosis: { bg: 'bg-red-100', text: 'text-red-700' },
  treatment: { bg: 'bg-emerald-100', text: 'text-emerald-700' },
  follow_up: { bg: 'bg-amber-100', text: 'text-amber-700' },
  observation: { bg: 'bg-purple-100', text: 'text-purple-700' },
};

export default function NotesPage() {
  const [notes, setNotes] = useState<Note[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [typeFilter, setTypeFilter] = useState('all');
  const [showCreate, setShowCreate] = useState(false);
  const [viewNote, setViewNote] = useState<Note | null>(null);
  const [selectedNote, setSelectedNote] = useState<Note | null>(null);

  const [form, setForm] = useState({ patient_id: '', title: '', content: '', note_type: 'general', is_flagged: false });

  useEffect(() => { loadNotes(); }, []);

  const loadNotes = async () => {
    try {
      const res = await notesApi.getNotes();
      setNotes(res.notes || []);
    } catch {
      setNotes([
        { id: 1, patient_id: 1, patient_name: 'Ahmed Khan', title: 'Initial cognitive assessment', content: 'Patient shows mild cognitive decline in SDMT scores. Recommend follow-up in 3 months with additional language fluency tests.', note_type: 'diagnosis', is_flagged: true, is_private: false, created_at: '2026-02-05T10:00:00', updated_at: '2026-02-05T10:00:00' },
        { id: 2, patient_id: 2, patient_name: 'Fatima Ali', title: 'Treatment plan update', content: 'Adjusted medication dosage based on latest lab results. Patient tolerating well. Continue monitoring.', note_type: 'treatment', is_flagged: false, is_private: false, created_at: '2026-02-04T14:30:00', updated_at: '2026-02-04T14:30:00' },
        { id: 3, patient_id: 3, patient_name: 'Usman Raza', title: 'Follow-up visit notes', content: 'No significant changes since last visit. Motor function stable. Scheduled next visit in 6 weeks.', note_type: 'follow_up', is_flagged: false, is_private: false, created_at: '2026-02-03T09:15:00', updated_at: '2026-02-03T09:15:00' },
        { id: 4, patient_id: 4, patient_name: 'Sara Qureshi', title: 'Speech pattern observation', content: 'Noticed slight hesitation in speech during story recall test. Flagging for further evaluation by speech pathologist.', note_type: 'observation', is_flagged: true, is_private: true, created_at: '2026-02-02T16:00:00', updated_at: '2026-02-02T16:00:00' },
      ]);
    } finally {
      setLoading(false);
    }
  };

  const handleCreate = async () => {
    if (!form.title.trim() || !form.content.trim()) return;
    try {
      await notesApi.createNote({ patient_id: parseInt(form.patient_id) || 1, title: form.title, content: form.content, note_type: form.note_type, is_flagged: form.is_flagged });
      setShowCreate(false);
      setForm({ patient_id: '', title: '', content: '', note_type: 'general', is_flagged: false });
      loadNotes();
    } catch (e) { console.error('Create note failed', e); }
  };

  const handleDelete = async (id: number) => {
    try { await notesApi.deleteNote(id); } catch {}
    setNotes(notes.filter((n) => n.id !== id));
    if (selectedNote?.id === id) setSelectedNote(null);
  };

  const filtered = notes.filter((n) => {
    const q = search.toLowerCase();
    const textMatch = n.title.toLowerCase().includes(q) || (n.patient_name || '').toLowerCase().includes(q);
    if (!textMatch) return false;
    if (typeFilter !== 'all') return n.note_type === typeFilter;
    return true;
  });

  const fmtDate = (iso: string) => {
    try { return new Date(iso).toLocaleDateString('en-US', { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' }); }
    catch { return iso; }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-[60vh]">
        <div className="w-8 h-8 border-2 border-accent border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  return (
    <motion.div variants={cv} initial="hidden" animate="visible">
      <div className="grid grid-cols-1 xl:grid-cols-[1fr_320px] gap-6">
        {/* ════ LEFT ════ */}
        <div className="space-y-6 min-w-0">
          {/* Header */}
          <motion.div variants={iv} className="flex items-center justify-between">
            <div>
              <h1 className="text-2xl font-bold text-dash-dark">Clinical Notes</h1>
              <p className="text-sm text-dash-muted mt-0.5">{notes.length} notes written</p>
            </div>
            <button onClick={() => setShowCreate(true)} className="btn-primary flex items-center gap-2">
              <Plus className="w-4 h-4" /> New Note
            </button>
          </motion.div>

          {/* Type Filter Pills */}
          <motion.div variants={iv} className="flex flex-wrap gap-2">
            {['all', 'general', 'diagnosis', 'treatment', 'follow_up', 'observation'].map((t) => (
              <button
                key={t}
                onClick={() => setTypeFilter(t)}
                className={`px-3.5 py-1.5 rounded-full text-xs font-medium transition-all capitalize
                  ${typeFilter === t
                    ? 'bg-dash-dark text-white'
                    : 'bg-white text-dash-muted border border-dash-border hover:bg-dash-bg'
                  }`}
              >
                {t === 'all' ? 'All' : t.replace('_', ' ')}
              </button>
            ))}
          </motion.div>

          {/* Search */}
          <motion.div variants={iv}>
            <div className="relative">
              <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
              <input value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Search notes..." className="input pl-10" />
            </div>
          </motion.div>

          {/* Notes List */}
          <motion.div variants={iv} className="space-y-3">
            {filtered.map((note) => {
              const style = typeStyle[note.note_type] || typeStyle.general;
              return (
                <div
                  key={note.id}
                  onClick={() => setSelectedNote(note)}
                  className={`card p-4 hover:shadow-md transition-all cursor-pointer ${
                    selectedNote?.id === note.id ? 'ring-2 ring-accent/30 shadow-md' : ''
                  }`}
                >
                  <div className="flex items-start gap-3">
                    <div className={`w-10 h-10 rounded-xl ${style.bg} flex items-center justify-center flex-shrink-0`}>
                      <FileText className={`w-4 h-4 ${style.text}`} />
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2 mb-0.5">
                        <h4 className="font-semibold text-dash-dark text-sm truncate">{note.title}</h4>
                        {note.is_flagged && <Flag className="w-3 h-3 text-amber-500 flex-shrink-0" />}
                      </div>
                      <p className="text-xs text-gray-500 line-clamp-1 mb-1.5">{note.content}</p>
                      <div className="flex items-center gap-3 text-[11px] text-gray-400">
                        <span className={`px-2 py-0.5 rounded-full ${style.bg} ${style.text} text-[10px] font-medium capitalize`}>
                          {note.note_type.replace('_', ' ')}
                        </span>
                        {note.patient_name && <span>{note.patient_name}</span>}
                        <span className="flex items-center gap-0.5"><Clock className="w-2.5 h-2.5" />{fmtDate(note.created_at)}</span>
                      </div>
                    </div>
                    <div className="flex items-center gap-0.5 flex-shrink-0">
                      <button onClick={(e) => { e.stopPropagation(); setViewNote(note); }} className="p-1.5 hover:bg-gray-100 rounded-lg" title="View">
                        <Eye className="w-3.5 h-3.5 text-gray-400" />
                      </button>
                      <button onClick={(e) => { e.stopPropagation(); handleDelete(note.id); }} className="p-1.5 hover:bg-red-50 rounded-lg" title="Delete">
                        <Trash2 className="w-3.5 h-3.5 text-gray-400 hover:text-red-500" />
                      </button>
                    </div>
                  </div>
                </div>
              );
            })}
          </motion.div>

          {filtered.length === 0 && (
            <div className="text-center py-16">
              <FileText className="w-8 h-8 text-dash-border mx-auto mb-2" />
              <p className="text-sm text-dash-muted">No notes found</p>
            </div>
          )}
        </div>

        {/* ════ RIGHT — Selected Note Detail ════ */}
        <motion.div variants={iv} className="space-y-4">
          {selectedNote ? (
            <>
              <div className="card p-5">
                <div className="flex items-center justify-between mb-3">
                  <span className={`px-2.5 py-1 rounded-full text-[10px] font-medium capitalize ${(typeStyle[selectedNote.note_type] || typeStyle.general).bg} ${(typeStyle[selectedNote.note_type] || typeStyle.general).text}`}>
                    {selectedNote.note_type.replace('_', ' ')}
                  </span>
                  <div className="flex items-center gap-1">
                    {selectedNote.is_flagged && <Flag className="w-3.5 h-3.5 text-amber-500" />}
                    {selectedNote.is_private && <span className="text-[10px] bg-gray-100 text-gray-500 px-2 py-0.5 rounded-full">Private</span>}
                  </div>
                </div>
                <h3 className="text-base font-bold text-dash-dark mb-2">{selectedNote.title}</h3>
                {selectedNote.patient_name && (
                  <p className="text-xs text-gray-400 mb-3 flex items-center gap-1">
                    <Tag className="w-3 h-3" /> {selectedNote.patient_name}
                  </p>
                )}
                <p className="text-sm text-gray-600 leading-relaxed whitespace-pre-wrap">{selectedNote.content}</p>
                <div className="mt-4 pt-3 border-t border-gray-100 flex items-center gap-1 text-[11px] text-gray-400">
                  <Clock className="w-3 h-3" /> {fmtDate(selectedNote.created_at)}
                </div>
              </div>
            </>
          ) : (
            <div className="card p-8 text-center">
              <FileText className="w-8 h-8 text-dash-border mx-auto mb-2" />
              <p className="text-sm text-dash-muted">Select a note to view details</p>
            </div>
          )}
        </motion.div>
      </div>

      {/* ═══ Create Modal ═══ */}
      {showCreate && (
        <div className="fixed inset-0 bg-black/40 backdrop-blur-sm z-50 flex items-center justify-center p-4" onClick={() => setShowCreate(false)}>
          <motion.div initial={{ scale: 0.95, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} onClick={(e) => e.stopPropagation()}
            className="bg-white rounded-2xl w-full max-w-lg p-6 shadow-xl">
            <div className="flex items-center justify-between mb-5">
              <h3 className="text-lg font-bold text-dash-dark">New Clinical Note</h3>
              <button onClick={() => setShowCreate(false)} className="p-1 hover:bg-gray-100 rounded-lg"><X className="w-5 h-5 text-gray-500" /></button>
            </div>
            <div className="space-y-4">
              <div><label className="text-xs font-medium text-gray-600 block mb-1">Patient ID</label>
                <input value={form.patient_id} onChange={(e) => setForm({ ...form, patient_id: e.target.value })} className="input" placeholder="1" /></div>
              <div><label className="text-xs font-medium text-gray-600 block mb-1">Title</label>
                <input value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} className="input" placeholder="Note title" /></div>
              <div><label className="text-xs font-medium text-gray-600 block mb-1">Type</label>
                <select value={form.note_type} onChange={(e) => setForm({ ...form, note_type: e.target.value })} className="input">
                  <option value="general">General</option><option value="diagnosis">Diagnosis</option><option value="treatment">Treatment</option>
                  <option value="follow_up">Follow Up</option><option value="observation">Observation</option>
                </select></div>
              <div><label className="text-xs font-medium text-gray-600 block mb-1">Content</label>
                <textarea value={form.content} onChange={(e) => setForm({ ...form, content: e.target.value })} className="input min-h-[100px] resize-none" rows={4} placeholder="Write your note..." /></div>
              <label className="flex items-center gap-2">
                <input type="checkbox" checked={form.is_flagged} onChange={(e) => setForm({ ...form, is_flagged: e.target.checked })} className="rounded" />
                <span className="text-sm text-gray-600">Flag as important</span>
              </label>
              <div className="flex justify-end gap-3 pt-2">
                <button onClick={() => setShowCreate(false)} className="btn-secondary">Cancel</button>
                <button onClick={handleCreate} className="btn-primary">Create Note</button>
              </div>
            </div>
          </motion.div>
        </div>
      )}

      {/* ═══ View Modal ═══ */}
      {viewNote && (
        <div className="fixed inset-0 bg-black/40 backdrop-blur-sm z-50 flex items-center justify-center p-4" onClick={() => setViewNote(null)}>
          <motion.div initial={{ scale: 0.95, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} onClick={(e) => e.stopPropagation()}
            className="bg-white rounded-2xl w-full max-w-lg p-6 shadow-xl">
            <div className="flex items-center justify-between mb-4">
              <span className={`px-2.5 py-1 rounded-full text-xs font-medium capitalize ${(typeStyle[viewNote.note_type] || typeStyle.general).bg} ${(typeStyle[viewNote.note_type] || typeStyle.general).text}`}>
                {viewNote.note_type.replace('_', ' ')}
              </span>
              <button onClick={() => setViewNote(null)} className="p-1 hover:bg-gray-100 rounded-lg"><X className="w-5 h-5 text-gray-500" /></button>
            </div>
            <h3 className="text-lg font-bold text-dash-dark mb-2">{viewNote.title}</h3>
            {viewNote.patient_name && <p className="text-sm text-gray-500 mb-3">Patient: {viewNote.patient_name}</p>}
            <p className="text-sm text-gray-700 leading-relaxed whitespace-pre-wrap">{viewNote.content}</p>
            <p className="text-xs text-gray-400 mt-4">{fmtDate(viewNote.created_at)}</p>
          </motion.div>
        </div>
      )}
    </motion.div>
  );
}

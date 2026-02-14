'use client';

import { useState, useEffect, useCallback } from 'react';
import { motion } from 'framer-motion';
import {
  Search, Plus, FileText, Flag, Trash2, Eye, X,
  Clock, Tag, ChevronRight, ChevronLeft, Loader2,
  AlertTriangle, Edit3,
} from 'lucide-react';
import { notesApi, patientsApi } from '@/lib/api';
import Link from 'next/link';

const cv = { hidden: { opacity: 0 }, visible: { opacity: 1, transition: { staggerChildren: 0.05 } } };
const iv = { hidden: { opacity: 0, y: 12 }, visible: { opacity: 1, y: 0, transition: { duration: 0.4 } } };

type Note = {
  id: number;
  doctor_id: number;
  doctor_name: string;
  patient_id: number;
  patient_name?: string;
  title: string;
  content: string;
  note_type: string;
  is_private: boolean;
  is_flagged: boolean;
  created_at: string;
  updated_at?: string;
};

const typeStyle: Record<string, { bg: string; text: string; ring: string }> = {
  general: { bg: 'bg-blue-50', text: 'text-blue-600', ring: 'ring-blue-100' },
  diagnosis: { bg: 'bg-red-50', text: 'text-red-600', ring: 'ring-red-100' },
  treatment: { bg: 'bg-emerald-50', text: 'text-emerald-600', ring: 'ring-emerald-100' },
  follow_up: { bg: 'bg-amber-50', text: 'text-amber-600', ring: 'ring-amber-100' },
  observation: { bg: 'bg-purple-50', text: 'text-purple-600', ring: 'ring-purple-100' },
};

const fmtDate = (iso?: string) => {
  if (!iso) return '—';
  try { return new Date(iso).toLocaleDateString('en-US', { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' }); }
  catch { return iso; }
};

export default function NotesPage() {
  const [notes, setNotes] = useState<Note[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [search, setSearch] = useState('');
  const [typeFilter, setTypeFilter] = useState('all');
  const [flaggedOnly, setFlaggedOnly] = useState(false);
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [totalPages, setTotalPages] = useState(1);
  const limit = 20;

  const [showCreate, setShowCreate] = useState(false);
  const [creating, setCreating] = useState(false);
  const [selectedNote, setSelectedNote] = useState<Note | null>(null);
  const [viewNote, setViewNote] = useState<Note | null>(null);

  // Patient search for create modal
  const [patientSearch, setPatientSearch] = useState('');
  const [patientResults, setPatientResults] = useState<{ id: number; name: string }[]>([]);
  const [selectedPatient, setSelectedPatient] = useState<{ id: number; name: string } | null>(null);

  const [form, setForm] = useState({
    title: '', content: '', note_type: 'general', is_flagged: false,
  });

  const loadNotes = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const params: any = { page, limit };
      if (typeFilter !== 'all') params.note_type = typeFilter;
      if (flaggedOnly) params.flagged_only = true;
      const res = await notesApi.getNotes(undefined, page, limit);
      setNotes(res.notes || []);
      setTotal(res.total || 0);
      setTotalPages(Math.ceil((res.total || 0) / limit));
    } catch (e: any) {
      setError(e?.response?.data?.detail || 'Failed to load notes');
      setNotes([]);
    } finally {
      setLoading(false);
    }
  }, [page, typeFilter, flaggedOnly]);

  useEffect(() => { loadNotes(); }, [loadNotes]);

  // Search patients for create modal
  useEffect(() => {
    if (patientSearch.length < 2) { setPatientResults([]); return; }
    const t = setTimeout(async () => {
      try {
        const res = await patientsApi.getPatients({ search: patientSearch, limit: 5 });
        setPatientResults((res.patients || []).map((p: any) => ({ id: p.id, name: p.name })));
      } catch { setPatientResults([]); }
    }, 300);
    return () => clearTimeout(t);
  }, [patientSearch]);

  const handleCreate = async () => {
    if (!form.title.trim() || !form.content.trim() || !selectedPatient) return;
    setCreating(true);
    try {
      await notesApi.createNote({
        patient_id: selectedPatient.id,
        title: form.title,
        content: form.content,
        note_type: form.note_type,
        is_flagged: form.is_flagged,
      });
      setShowCreate(false);
      setForm({ title: '', content: '', note_type: 'general', is_flagged: false });
      setSelectedPatient(null);
      setPatientSearch('');
      loadNotes();
    } catch (e: any) {
      alert(e?.response?.data?.detail || 'Failed to create note');
    } finally {
      setCreating(false);
    }
  };

  const handleDelete = async (id: number) => {
    if (!confirm('Delete this note?')) return;
    try { await notesApi.deleteNote(id); } catch {}
    setNotes(notes.filter((n) => n.id !== id));
    if (selectedNote?.id === id) setSelectedNote(null);
  };

  const handleToggleFlag = async (note: Note) => {
    try {
      await notesApi.updateNote(note.id, { is_flagged: !note.is_flagged });
      setNotes(notes.map(n => n.id === note.id ? { ...n, is_flagged: !n.is_flagged } : n));
      if (selectedNote?.id === note.id) setSelectedNote({ ...note, is_flagged: !note.is_flagged });
    } catch {}
  };

  // Client-side search filter (server doesn't support text search on notes)
  const filtered = notes.filter((n) => {
    if (!search) return true;
    const q = search.toLowerCase();
    return n.title.toLowerCase().includes(q) || (n.patient_name || '').toLowerCase().includes(q) || n.content.toLowerCase().includes(q);
  });

  // Stats
  const flaggedCount = notes.filter(n => n.is_flagged).length;
  const typeBreakdown = notes.reduce<Record<string, number>>((acc, n) => {
    acc[n.note_type] = (acc[n.note_type] || 0) + 1;
    return acc;
  }, {});

  return (
    <motion.div variants={cv} initial="hidden" animate="visible">
      <div className="grid grid-cols-1 xl:grid-cols-[1fr_320px] gap-6">
        {/* ════ LEFT ════ */}
        <div className="space-y-5 min-w-0">
          {/* Header */}
          <motion.div variants={iv} className="flex items-center justify-between">
            <div>
              <h1 className="text-2xl font-bold text-dash-dark">Clinical Notes</h1>
              <p className="text-sm text-dash-muted mt-0.5">{total} notes total</p>
            </div>
            <button onClick={() => setShowCreate(true)} className="btn-primary flex items-center gap-2">
              <Plus className="w-4 h-4" /> New Note
            </button>
          </motion.div>

          {/* Stat Cards */}
          <motion.div variants={iv} className="grid grid-cols-4 gap-3">
            {[
              { label: 'Total Notes', value: total, bg: 'bg-accent/10', color: '#C6E94B', icon: FileText },
              { label: 'Flagged', value: flaggedCount, bg: 'bg-[#B54E4E]/10', color: '#B54E4E', icon: Flag },
              { label: 'This Page', value: notes.length, bg: 'bg-blue-50', color: '#3B82F6', icon: Eye },
              { label: 'Types', value: Object.keys(typeBreakdown).length, bg: 'bg-purple-50', color: '#A855F7', icon: Tag },
            ].map((s) => (
              <div key={s.label} className={`${s.bg} rounded-2xl p-3.5 flex items-center gap-3`}>
                <div className="w-9 h-9 rounded-xl bg-white/70 flex items-center justify-center flex-shrink-0">
                  <s.icon className="w-4 h-4" style={{ color: s.color }} />
                </div>
                <div>
                  <p className="text-lg font-bold text-dash-dark">{s.value}</p>
                  <p className="text-[10px] text-dash-muted">{s.label}</p>
                </div>
              </div>
            ))}
          </motion.div>

          {/* Type Filter Pills */}
          <motion.div variants={iv} className="flex flex-wrap gap-2">
            {['all', 'general', 'diagnosis', 'treatment', 'follow_up', 'observation'].map((t) => (
              <button key={t} onClick={() => { setTypeFilter(t); setPage(1); }}
                className={`px-3.5 py-1.5 rounded-full text-xs font-medium transition-all capitalize ${
                  typeFilter === t ? 'bg-dash-dark text-white' : 'bg-white text-dash-muted border border-dash-border hover:bg-dash-bg'
                }`}>
                {t === 'all' ? `All (${total})` : `${t.replace('_', ' ')}${typeBreakdown[t] ? ` (${typeBreakdown[t]})` : ''}`}
              </button>
            ))}
            <button onClick={() => { setFlaggedOnly(!flaggedOnly); setPage(1); }}
              className={`px-3.5 py-1.5 rounded-full text-xs font-medium transition-all flex items-center gap-1 ${
                flaggedOnly ? 'bg-red-500 text-white' : 'bg-white text-dash-muted border border-dash-border hover:bg-red-50'
              }`}>
              <Flag className="w-3 h-3" /> Flagged
            </button>
          </motion.div>

          {/* Search */}
          <motion.div variants={iv}>
            <div className="relative">
              <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
              <input value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Search notes by title, patient, or content..." className="input pl-10" />
              {search && (
                <button onClick={() => setSearch('')} className="absolute right-3 top-1/2 -translate-y-1/2">
                  <X className="w-3.5 h-3.5 text-gray-400 hover:text-gray-600" />
                </button>
              )}
            </div>
          </motion.div>

          {/* Notes List */}
          {loading ? (
            <div className="flex items-center justify-center py-20">
              <Loader2 className="w-6 h-6 animate-spin text-accent" />
            </div>
          ) : error ? (
            <div className="flex flex-col items-center justify-center py-16 gap-2">
              <AlertTriangle className="w-8 h-8 text-red-400" />
              <p className="text-sm text-dash-muted">{error}</p>
              <button onClick={loadNotes} className="text-xs text-accent-dark hover:underline">Retry</button>
            </div>
          ) : (
            <>
              <motion.div variants={iv} className="space-y-3">
                {filtered.map((note) => {
                  const style = typeStyle[note.note_type] || typeStyle.general;
                  return (
                    <div key={note.id} onClick={() => setSelectedNote(note)}
                      className={`card p-4 hover:shadow-md transition-all cursor-pointer ${
                        selectedNote?.id === note.id ? 'ring-2 ring-accent/30 shadow-md' : ''
                      }`}>
                      <div className="flex items-start gap-3">
                        <div className={`w-10 h-10 rounded-xl ${style.bg} flex items-center justify-center flex-shrink-0`}>
                          <FileText className={`w-4 h-4 ${style.text}`} />
                        </div>
                        <div className="flex-1 min-w-0">
                          <div className="flex items-center gap-2 mb-0.5">
                            <h4 className="font-semibold text-dash-dark text-sm truncate">{note.title}</h4>
                            {note.is_flagged && <Flag className="w-3 h-3 text-red-400 flex-shrink-0" />}
                            {note.is_private && <span className="text-[9px] bg-gray-100 text-gray-500 px-1.5 py-0.5 rounded-full">Private</span>}
                          </div>
                          <p className="text-xs text-gray-500 line-clamp-1 mb-1.5">{note.content}</p>
                          <div className="flex items-center gap-3 text-[11px] text-gray-400">
                            <span className={`px-2 py-0.5 rounded-full ring-1 ${style.bg} ${style.text} ${style.ring} text-[10px] font-medium capitalize`}>
                              {note.note_type.replace('_', ' ')}
                            </span>
                            {note.patient_name && (
                              <Link href={`/dashboard/patients/${note.patient_id}`} onClick={(e) => e.stopPropagation()}
                                className="hover:text-accent-dark transition-colors">
                                {note.patient_name}
                              </Link>
                            )}
                            <span className="flex items-center gap-0.5"><Clock className="w-2.5 h-2.5" />{fmtDate(note.created_at)}</span>
                            <span className="text-gray-300">by {note.doctor_name}</span>
                          </div>
                        </div>
                        <div className="flex items-center gap-0.5 flex-shrink-0">
                          <button onClick={(e) => { e.stopPropagation(); handleToggleFlag(note); }}
                            className={`p-1.5 rounded-lg transition-colors ${note.is_flagged ? 'bg-red-50 hover:bg-red-100' : 'hover:bg-gray-100'}`} title="Toggle flag">
                            <Flag className={`w-3.5 h-3.5 ${note.is_flagged ? 'text-red-400' : 'text-gray-300'}`} />
                          </button>
                          <button onClick={(e) => { e.stopPropagation(); setViewNote(note); }}
                            className="p-1.5 hover:bg-gray-100 rounded-lg" title="View">
                            <Eye className="w-3.5 h-3.5 text-gray-400" />
                          </button>
                          <button onClick={(e) => { e.stopPropagation(); handleDelete(note.id); }}
                            className="p-1.5 hover:bg-red-50 rounded-lg" title="Delete">
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
                  <p className="text-sm text-dash-muted">{search ? 'No notes match your search' : 'No clinical notes yet'}</p>
                  {!search && (
                    <button onClick={() => setShowCreate(true)} className="mt-3 text-xs font-medium px-4 py-2 rounded-lg bg-accent text-dash-dark hover:bg-accent-hover transition-colors">
                      Create First Note
                    </button>
                  )}
                </div>
              )}

              {/* Pagination */}
              {totalPages > 1 && (
                <div className="flex items-center justify-between pt-2">
                  <p className="text-xs text-dash-muted">
                    Page {page} of {totalPages} · {total} notes
                  </p>
                  <div className="flex items-center gap-1.5">
                    <button onClick={() => setPage(p => Math.max(1, p - 1))} disabled={page <= 1}
                      className="p-1.5 rounded-lg border border-dash-border hover:bg-dash-bg disabled:opacity-30 disabled:cursor-not-allowed transition-colors">
                      <ChevronLeft className="w-3.5 h-3.5 text-dash-muted" />
                    </button>
                    {Array.from({ length: Math.min(5, totalPages) }, (_, i) => {
                      const start = Math.max(1, Math.min(page - 2, totalPages - 4));
                      const num = start + i;
                      if (num > totalPages) return null;
                      return (
                        <button key={num} onClick={() => setPage(num)}
                          className={`w-8 h-8 rounded-lg text-xs font-medium transition-colors ${
                            num === page ? 'bg-accent text-dash-dark' : 'hover:bg-dash-bg text-dash-muted'
                          }`}>{num}</button>
                      );
                    })}
                    <button onClick={() => setPage(p => Math.min(totalPages, p + 1))} disabled={page >= totalPages}
                      className="p-1.5 rounded-lg border border-dash-border hover:bg-dash-bg disabled:opacity-30 disabled:cursor-not-allowed transition-colors">
                      <ChevronRight className="w-3.5 h-3.5 text-dash-muted" />
                    </button>
                  </div>
                </div>
              )}
            </>
          )}
        </div>

        {/* ════ RIGHT — Selected Note Detail ════ */}
        <motion.div variants={iv} className="space-y-4">
          {selectedNote ? (
            <>
              <div className="card p-5">
                <div className="flex items-center justify-between mb-3">
                  <span className={`px-2.5 py-1 rounded-full ring-1 text-[10px] font-medium capitalize ${(typeStyle[selectedNote.note_type] || typeStyle.general).bg} ${(typeStyle[selectedNote.note_type] || typeStyle.general).text} ${(typeStyle[selectedNote.note_type] || typeStyle.general).ring}`}>
                    {selectedNote.note_type.replace('_', ' ')}
                  </span>
                  <div className="flex items-center gap-1">
                    {selectedNote.is_flagged && <Flag className="w-3.5 h-3.5 text-red-400" />}
                    {selectedNote.is_private && <span className="text-[10px] bg-gray-100 text-gray-500 px-2 py-0.5 rounded-full">Private</span>}
                  </div>
                </div>
                <h3 className="text-base font-bold text-dash-dark mb-2">{selectedNote.title}</h3>
                {selectedNote.patient_name && (
                  <Link href={`/dashboard/patients/${selectedNote.patient_id}`}
                    className="text-xs text-gray-400 mb-3 flex items-center gap-1 hover:text-accent-dark transition-colors">
                    <Tag className="w-3 h-3" /> {selectedNote.patient_name}
                  </Link>
                )}
                <p className="text-sm text-gray-600 leading-relaxed whitespace-pre-wrap mt-2">{selectedNote.content}</p>
                <div className="mt-4 pt-3 border-t border-gray-100 space-y-1.5">
                  <div className="flex items-center gap-1 text-[11px] text-gray-400">
                    <Clock className="w-3 h-3" /> {fmtDate(selectedNote.created_at)}
                  </div>
                  <p className="text-[11px] text-gray-400">by {selectedNote.doctor_name}</p>
                </div>
              </div>
              <button onClick={() => setSelectedNote(null)}
                className="w-full py-2 rounded-xl border border-dash-border text-xs text-dash-muted hover:bg-dash-bg transition-colors">
                Clear Selection
              </button>
            </>
          ) : (
            <div className="card p-8 text-center">
              <FileText className="w-8 h-8 text-dash-border mx-auto mb-2" />
              <p className="text-sm text-dash-muted">Select a note to view details</p>
            </div>
          )}

          {/* Type Breakdown */}
          {Object.keys(typeBreakdown).length > 0 && (
            <div className="card p-5">
              <h4 className="text-sm font-semibold text-dash-dark mb-3">Notes by Type</h4>
              <div className="space-y-2.5">
                {Object.entries(typeBreakdown).map(([type, count]) => {
                  const style = typeStyle[type] || typeStyle.general;
                  const pct = total > 0 ? Math.round((count / notes.length) * 100) : 0;
                  return (
                    <div key={type}>
                      <div className="flex items-center justify-between mb-1">
                        <span className="text-xs text-dash-muted capitalize">{type.replace('_', ' ')}</span>
                        <span className="text-xs font-semibold text-dash-dark">{count}</span>
                      </div>
                      <div className="w-full h-1.5 rounded-full bg-gray-100">
                        <div className={`h-full rounded-full ${style.bg} transition-all duration-500`} style={{ width: `${pct}%` }} />
                      </div>
                    </div>
                  );
                })}
              </div>
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
              {/* Patient Search */}
              <div>
                <label className="text-xs font-medium text-gray-600 block mb-1">Patient</label>
                {selectedPatient ? (
                  <div className="flex items-center gap-2 p-2.5 bg-accent/10 rounded-xl">
                    <span className="text-sm font-medium text-dash-dark flex-1">{selectedPatient.name}</span>
                    <button onClick={() => { setSelectedPatient(null); setPatientSearch(''); }} className="p-1 hover:bg-white rounded-lg">
                      <X className="w-3.5 h-3.5 text-gray-400" />
                    </button>
                  </div>
                ) : (
                  <div className="relative">
                    <input value={patientSearch} onChange={(e) => setPatientSearch(e.target.value)}
                      className="input" placeholder="Search patient by name..." />
                    {patientResults.length > 0 && (
                      <div className="absolute top-full left-0 right-0 bg-white border border-dash-border rounded-xl mt-1 shadow-lg z-10 max-h-40 overflow-y-auto">
                        {patientResults.map((p) => (
                          <button key={p.id} onClick={() => { setSelectedPatient(p); setPatientSearch(''); setPatientResults([]); }}
                            className="w-full text-left px-3 py-2 text-sm hover:bg-accent/10 transition-colors">
                            {p.name}
                          </button>
                        ))}
                      </div>
                    )}
                  </div>
                )}
              </div>
              <div>
                <label className="text-xs font-medium text-gray-600 block mb-1">Title</label>
                <input value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} className="input" placeholder="Note title" />
              </div>
              <div>
                <label className="text-xs font-medium text-gray-600 block mb-1">Type</label>
                <select value={form.note_type} onChange={(e) => setForm({ ...form, note_type: e.target.value })} className="input">
                  <option value="general">General</option>
                  <option value="diagnosis">Diagnosis</option>
                  <option value="treatment">Treatment</option>
                  <option value="follow_up">Follow Up</option>
                  <option value="observation">Observation</option>
                </select>
              </div>
              <div>
                <label className="text-xs font-medium text-gray-600 block mb-1">Content</label>
                <textarea value={form.content} onChange={(e) => setForm({ ...form, content: e.target.value })}
                  className="input min-h-[120px] resize-none" rows={5} placeholder="Write your clinical note..." />
              </div>
              <label className="flex items-center gap-2">
                <input type="checkbox" checked={form.is_flagged} onChange={(e) => setForm({ ...form, is_flagged: e.target.checked })}
                  className="rounded border-gray-300 text-accent focus:ring-accent" />
                <span className="text-sm text-gray-600">Flag as important</span>
              </label>
              <div className="flex justify-end gap-3 pt-2">
                <button onClick={() => setShowCreate(false)} className="btn-secondary">Cancel</button>
                <button onClick={handleCreate} disabled={creating || !form.title.trim() || !form.content.trim() || !selectedPatient}
                  className="btn-primary disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2">
                  {creating && <Loader2 className="w-3.5 h-3.5 animate-spin" />}
                  Create Note
                </button>
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
              <div className="flex items-center gap-2">
                <span className={`px-2.5 py-1 rounded-full ring-1 text-xs font-medium capitalize ${(typeStyle[viewNote.note_type] || typeStyle.general).bg} ${(typeStyle[viewNote.note_type] || typeStyle.general).text} ${(typeStyle[viewNote.note_type] || typeStyle.general).ring}`}>
                  {viewNote.note_type.replace('_', ' ')}
                </span>
                {viewNote.is_flagged && <Flag className="w-3.5 h-3.5 text-red-400" />}
              </div>
              <button onClick={() => setViewNote(null)} className="p-1 hover:bg-gray-100 rounded-lg"><X className="w-5 h-5 text-gray-500" /></button>
            </div>
            <h3 className="text-lg font-bold text-dash-dark mb-2">{viewNote.title}</h3>
            {viewNote.patient_name && <p className="text-sm text-gray-500 mb-3">Patient: {viewNote.patient_name}</p>}
            <p className="text-sm text-gray-700 leading-relaxed whitespace-pre-wrap">{viewNote.content}</p>
            <div className="mt-4 pt-3 border-t border-gray-100 flex items-center justify-between">
              <p className="text-xs text-gray-400">{fmtDate(viewNote.created_at)}</p>
              <p className="text-xs text-gray-400">by {viewNote.doctor_name}</p>
            </div>
          </motion.div>
        </div>
      )}
    </motion.div>
  );
}

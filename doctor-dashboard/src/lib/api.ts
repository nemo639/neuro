import axios from 'axios';
import Cookies from 'js-cookie';

// API Base URL - Change this to your FastAPI backend
const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000';
const API_VERSION = '/api/v1';

// Create axios instance
const api = axios.create({
  baseURL: `${API_BASE_URL}${API_VERSION}`,
  headers: {
    'Content-Type': 'application/json',
    'ngrok-skip-browser-warning': 'true',
  },
});

// Request interceptor to add auth token
api.interceptors.request.use(
  (config) => {
    const token = Cookies.get('doctor_token');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => Promise.reject(error)
);

// Response interceptor for error handling
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      // Only clear cookies & redirect if NOT already on login page
      if (typeof window !== 'undefined' && !window.location.pathname.startsWith('/login')) {
        Cookies.remove('doctor_token');
        Cookies.remove('doctor_refresh_token');
        Cookies.remove('doctor_profile');
        window.location.href = '/login';
      }
    }
    return Promise.reject(error);
  }
);

// ==================== AUTH API ====================

export const authApi = {
  login: async (email: string, password: string) => {
    const response = await api.post('/doctors/login', { email, password });
    return response.data;
  },

  forgotPassword: async (email: string) => {
    const response = await api.post('/doctors/forgot-password', { email });
    return response.data;
  },

  resetPassword: async (email: string, otp: string, newPassword: string) => {
    const response = await api.post('/doctors/reset-password', {
      email,
      otp,
      new_password: newPassword,
    });
    return response.data;
  },

  getProfile: async () => {
    const response = await api.get('/doctors/me');
    return response.data;
  },

  updateProfile: async (data: any) => {
    const response = await api.patch('/doctors/me', data);
    return response.data;
  },
};

// ==================== DASHBOARD API ====================

export const dashboardApi = {
  getDashboard: async () => {
    const response = await api.get('/doctors/dashboard');
    return response.data;
  },

  getAlerts: async () => {
    const response = await api.get('/doctors/alerts');
    return response.data;
  },

  markAlertRead: async (alertId: string) => {
    const response = await api.post(`/doctors/alerts/${alertId}/read`);
    return response.data;
  },
};

// ==================== PATIENTS API ====================

export const patientsApi = {
  getPatients: async (params?: {
    search?: string;
    risk_level?: string;
    page?: number;
    limit?: number;
  }) => {
    const response = await api.get('/doctors/patients', { params });
    return response.data;
  },

  getPatientDetail: async (patientId: number) => {
    const response = await api.get(`/doctors/patients/${patientId}`);
    return response.data;
  },

  getPatientTestHistory: async (patientId: number) => {
    const response = await api.get(`/doctors/patients/${patientId}/tests`);
    return response.data;
  },

  getPatientReports: async (patientId: number) => {
    const response = await api.get(`/doctors/patients/${patientId}/reports`);
    return response.data;
  },
};

// ==================== CLINICAL NOTES API ====================

export const notesApi = {
  getNotes: async (patientId?: number, page?: number, limit?: number) => {
    const response = await api.get('/doctors/notes', {
      params: { patient_id: patientId, page, limit },
    });
    return response.data;
  },

  createNote: async (data: {
    patient_id: number;
    title: string;
    content: string;
    note_type?: string;
    is_private?: boolean;
    is_flagged?: boolean;
  }) => {
    const response = await api.post('/doctors/notes', data);
    return response.data;
  },

  updateNote: async (noteId: number, data: any) => {
    const response = await api.patch(`/doctors/notes/${noteId}`, data);
    return response.data;
  },

  deleteNote: async (noteId: number) => {
    const response = await api.delete(`/doctors/notes/${noteId}`);
    return response.data;
  },
};

// ==================== REPORTS API ====================

export const reportsApi = {
  exportReport: async (data: {
    patient_id: number;
    report_type?: string;
    include_xai?: boolean;
    format?: string;
  }) => {
    const response = await api.post('/doctors/reports/generate', data);
    return response.data;
  },

  getExportHistory: async (params?: { patient_id?: number; report_type?: string; page?: number; limit?: number }) => {
    const response = await api.get('/doctors/reports/exports', { params });
    return response.data;
  },

  downloadReport: (reportId: number) => {
    const token = Cookies.get('doctor_token');
    return `${API_BASE_URL}${API_VERSION}/doctors/reports/${reportId}/download?token=${token}`;
  },

  getDownloadUrl: (path: string) => `${API_BASE_URL}${path}`,

  sendReportToPatient: async (patientId: number, data: {
    report_type?: string;
    doctor_notes?: string;
    title?: string;
  }) => {
    const response = await api.post(`/doctors/patients/${patientId}/send-report`, data);
    return response.data;
  },
};

// ==================== PROFILE API ====================

export const profileApi = {
  uploadAvatar: async (file: File) => {
    const formData = new FormData();
    formData.append('file', file);
    const response = await api.post('/doctors/me/avatar', formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
    return response.data;
  },

  removeAvatar: async () => {
    const response = await api.delete('/doctors/me/avatar');
    return response.data;
  },

  changePassword: async (currentPassword: string, newPassword: string) => {
    const response = await api.post('/doctors/me/change-password', {
      current_password: currentPassword,
      new_password: newPassword,
    });
    return response.data;
  },
};

// ==================== DATASET API ====================

export const datasetApi = {
  requestDataset: async (data: {
    purpose: string;
    research_title?: string;
    institution?: string;
    data_types: string[];
    min_samples?: number;
  }) => {
    const response = await api.post('/doctors/dataset/request', data);
    return response.data;
  },

  getMyRequests: async () => {
    const response = await api.get('/doctors/dataset/requests');
    return response.data;
  },
};

export default api;

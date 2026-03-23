import axios from 'axios';
import Cookies from 'js-cookie';

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000';
const API_VERSION = '/api/v1';

// Create axios instance for admin
const api = axios.create({
  baseURL: `${API_BASE_URL}${API_VERSION}`,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request interceptor
api.interceptors.request.use(
  (config) => {
    const token = Cookies.get('admin_token');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => Promise.reject(error)
);

// Response interceptor
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      Cookies.remove('admin_token');
      Cookies.remove('admin_profile');
      window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);

// ==================== AUTH API ====================

export const authApi = {
  login: async (email: string, password: string) => {
    const response = await api.post('/admin/login', { email, password });
    return response.data;
  },

  forgotPassword: async (email: string) => {
    const response = await api.post('/admin/forgot-password', { email });
    return response.data;
  },

  resetPassword: async (email: string, otp: string, newPassword: string) => {
    const response = await api.post('/admin/reset-password', {
      email,
      otp,
      new_password: newPassword,
    });
    return response.data;
  },
};

// ==================== DASHBOARD API ====================

export const dashboardApi = {
  getDashboard: async () => {
    const response = await api.get('/admin/dashboard');
    return response.data;
  },
};

// ==================== USERS API ====================

export const usersApi = {
  getUsers: async (params?: {
    search?: string;
    status?: string;
    is_verified?: boolean;
    page?: number;
    limit?: number;
  }) => {
    const response = await api.get('/admin/users', { params });
    return response.data;
  },
};

// ==================== DOCTORS API ====================

export const doctorsApi = {
  getDoctors: async (params?: {
    search?: string;
    status?: string;
    page?: number;
    limit?: number;
  }) => {
    const response = await api.get('/admin/doctors', { params });
    return response.data;
  },

  verifyDoctor: async (doctorId: number, approve: boolean, rejectionReason?: string) => {
    const response = await api.post('/admin/doctors/verify', {
      doctor_id: doctorId,
      approve,
      rejection_reason: rejectionReason,
    });
    return response.data;
  },
};

// ==================== SUPPORT TICKETS API ====================

export const ticketsApi = {
  getTickets: async (params?: {
    status?: string;
    priority?: string;
    page?: number;
    limit?: number;
  }) => {
    const response = await api.get('/admin/tickets', { params });
    return response.data;
  },

  getTicket: async (ticketId: string) => {
    const response = await api.get(`/admin/tickets/${ticketId}`);
    return response.data;
  },

  replyToTicket: async (ticketId: string, data: { message: string }) => {
    const response = await api.post('/admin/tickets/reply', {
      ticket_id: ticketId,
      message: data.message,
    });
    return response.data;
  },

  assignTicket: async (ticketId: string, data?: { admin_id?: string }) => {
    const response = await api.post('/admin/tickets/assign', {
      ticket_id: ticketId,
      admin_id: data?.admin_id,
    });
    return response.data;
  },

  resolveTicket: async (ticketId: string, data: { resolution_notes: string }) => {
    const response = await api.post('/admin/tickets/resolve', {
      ticket_id: ticketId,
      resolution_notes: data.resolution_notes,
    });
    return response.data;
  },
};

// ==================== TASKS API ====================

export const tasksApi = {
  getTasks: async (showCompleted?: boolean) => {
    const response = await api.get('/admin/tasks', { params: { show_completed: showCompleted } });
    return response.data;
  },

  createTask: async (data: { title: string; description?: string; category?: string; due_date?: string }) => {
    const response = await api.post('/admin/tasks', data);
    return response.data;
  },

  updateTask: async (taskId: string, data: { title?: string; description?: string; category?: string; due_date?: string; is_completed?: boolean }) => {
    const response = await api.patch(`/admin/tasks/${taskId}`, data);
    return response.data;
  },

  deleteTask: async (taskId: string) => {
    const response = await api.delete(`/admin/tasks/${taskId}`);
    return response.data;
  },
};

// ==================== PERMISSIONS API ====================

export const permissionsApi = {
  getPermissions: async (params?: { admin_id?: number }) => {
    const response = await api.get('/admin/permissions', { params });
    return response.data;
  },

  updatePermissions: async (data: { admin_id: number; permissions: string[] }) => {
    const response = await api.post('/admin/permissions/update', data);
    return response.data;
  },

  updateRole: async (data: { admin_id: number; role: string }) => {
    const response = await api.post('/admin/permissions/role', data);
    return response.data;
  },
};

// ==================== ANALYTICS API ====================

export const analyticsApi = {
  getAnalytics: async (timeRange?: string) => {
    const response = await api.get('/admin/analytics', {
      params: { time_range: timeRange || '30d' },
    });
    return response.data;
  },
};

// ==================== SETTINGS API ====================

export const settingsApi = {
  getProfile: async () => {
    const response = await api.get('/admin/settings/profile');
    return response.data;
  },

  updateProfile: async (data: { first_name?: string; last_name?: string; phone?: string }) => {
    const response = await api.put('/admin/settings/profile', data);
    return response.data;
  },

  changePassword: async (data: { current_password: string; new_password: string }) => {
    const response = await api.post('/admin/settings/change-password', data);
    return response.data;
  },

  uploadAvatar: async (file: File) => {
    const formData = new FormData();
    formData.append('file', file);
    const response = await api.post('/admin/settings/avatar', formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
    return response.data;
  },

  deleteAvatar: async () => {
    const response = await api.delete('/admin/settings/avatar');
    return response.data;
  },
};

export default api;

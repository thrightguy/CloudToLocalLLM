import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import axios from 'axios';

export const useAuthStore = defineStore('auth', () => {
  // State
  const token = ref(localStorage.getItem('token') || '');
  const user = ref(JSON.parse(localStorage.getItem('user') || 'null'));
  const isLoading = ref(false);
  const error = ref(null);
  const users = ref([]);
  const stats = ref({});

  // Getters
  const isAuthenticated = computed(() => !!token.value);
  const currentUser = computed(() => user.value);
  const isAdmin = computed(() => user.value?.roles?.includes('admin'));

  // Actions
  async function login({ username, password }) {
    isLoading.value = true;
    error.value = null;
    try {
      const { data } = await axios.post('/api/auth/login', { username, password });
      token.value = data.token;
      user.value = data.user;
      localStorage.setItem('token', token.value);
      localStorage.setItem('user', JSON.stringify(user.value));
      return true;
    } catch (err) {
      error.value = err.response?.data?.message || 'Login failed';
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  async function register(userData) {
    isLoading.value = true;
    error.value = null;
    try {
      const response = await axios.post('/api/auth/register', userData);
      token.value = response.data.token;
      user.value = response.data.user;
      localStorage.setItem('token', token.value);
      localStorage.setItem('user', JSON.stringify(user.value));
      return true;
    } catch (err) {
      error.value = err.response?.data?.message || 'Registration failed';
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  function logout() {
    token.value = '';
    user.value = null;
    localStorage.removeItem('token');
    localStorage.removeItem('user');
  }

  async function fetchUsers() {
    isLoading.value = true;
    error.value = null;
    try {
      const response = await axios.get('/api/users', {
        headers: { Authorization: `Bearer ${token.value}` }
      });
      users.value = response.data.data;
      return users.value;
    } catch (err) {
      error.value = err.response?.data?.message || 'Failed to fetch users';
      return [];
    } finally {
      isLoading.value = false;
    }
  }

  async function fetchUserById(userId) {
    isLoading.value = true;
    error.value = null;
    try {
      const response = await axios.get(`/api/users/${userId}`, {
        headers: { Authorization: `Bearer ${token.value}` }
      });
      return response.data.data;
    } catch (err) {
      error.value = err.response?.data?.message || 'Failed to fetch user';
      return null;
    } finally {
      isLoading.value = false;
    }
  }

  async function fetchStats() {
    isLoading.value = true;
    error.value = null;
    try {
      const response = await axios.get('/api/users/stats/dashboard', {
        headers: { Authorization: `Bearer ${token.value}` }
      });
      stats.value = response.data.data;
      return stats.value;
    } catch (err) {
      error.value = err.response?.data?.message || 'Failed to fetch dashboard stats';
      return {};
    } finally {
      isLoading.value = false;
    }
  }

  return {
    // State
    token, user, isLoading, error, users, stats,
    // Getters
    isAuthenticated, currentUser, isAdmin,
    // Actions
    login, register, logout, fetchUsers, fetchUserById, fetchStats
  };
}); 
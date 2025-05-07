import axios from 'axios';

// Define Vuex store for the admin UI
const store = {
  state() {
    return {
      token: localStorage.getItem('token') || null,
      user: JSON.parse(localStorage.getItem('user')) || null,
      isLoading: false,
      error: null,
      users: [],
      stats: {}
    };
  },

  getters: {
    isAuthenticated(state) {
      return !!state.token;
    },
    currentUser(state) {
      return state.user;
    },
    hasRole: (state) => (roleName) => {
      return state.user && state.user.roles && state.user.roles.includes(roleName);
    },
    isAdmin(state, getters) {
      return getters.hasRole('admin');
    },
    isLoading(state) {
      return state.isLoading;
    },
    error(state) {
      return state.error;
    },
    users(state) {
      return state.users;
    },
    stats(state) {
      return state.stats;
    }
  },

  mutations: {
    SET_TOKEN(state, token) {
      state.token = token;
      localStorage.setItem('token', token);
    },
    SET_USER(state, user) {
      state.user = user;
      localStorage.setItem('user', JSON.stringify(user));
    },
    CLEAR_AUTH(state) {
      state.token = null;
      state.user = null;
      localStorage.removeItem('token');
      localStorage.removeItem('user');
    },
    SET_LOADING(state, isLoading) {
      state.isLoading = isLoading;
    },
    SET_ERROR(state, error) {
      state.error = error;
    },
    SET_USERS(state, users) {
      state.users = users;
    },
    SET_STATS(state, stats) {
      state.stats = stats;
    }
  },

  actions: {
    // Authentication actions
    async login({ commit }, credentials) {
      commit('SET_LOADING', true);
      commit('SET_ERROR', null);
      try {
        const response = await axios.post('/api/auth/login', credentials);
        commit('SET_TOKEN', response.data.token);
        commit('SET_USER', response.data.user);
        return true;
      } catch (error) {
        const errorMessage = error.response?.data?.message || 'Login failed';
        commit('SET_ERROR', errorMessage);
        return false;
      } finally {
        commit('SET_LOADING', false);
      }
    },

    async register({ commit }, userData) {
      commit('SET_LOADING', true);
      commit('SET_ERROR', null);
      try {
        const response = await axios.post('/api/auth/register', userData);
        commit('SET_TOKEN', response.data.token);
        commit('SET_USER', response.data.user);
        return true;
      } catch (error) {
        const errorMessage = error.response?.data?.message || 'Registration failed';
        commit('SET_ERROR', errorMessage);
        return false;
      } finally {
        commit('SET_LOADING', false);
      }
    },

    logout({ commit }) {
      commit('CLEAR_AUTH');
    },

    // User management actions
    async fetchUsers({ commit, state }) {
      commit('SET_LOADING', true);
      commit('SET_ERROR', null);
      try {
        const response = await axios.get('/api/users', {
          headers: { Authorization: `Bearer ${state.token}` }
        });
        commit('SET_USERS', response.data.data);
        return response.data.data;
      } catch (error) {
        const errorMessage = error.response?.data?.message || 'Failed to fetch users';
        commit('SET_ERROR', errorMessage);
        return [];
      } finally {
        commit('SET_LOADING', false);
      }
    },

    async fetchUserById({ commit, state }, userId) {
      commit('SET_LOADING', true);
      commit('SET_ERROR', null);
      try {
        const response = await axios.get(`/api/users/${userId}`, {
          headers: { Authorization: `Bearer ${state.token}` }
        });
        return response.data.data;
      } catch (error) {
        const errorMessage = error.response?.data?.message || 'Failed to fetch user';
        commit('SET_ERROR', errorMessage);
        return null;
      } finally {
        commit('SET_LOADING', false);
      }
    },

    // Dashboard stats
    async fetchStats({ commit, state }) {
      commit('SET_LOADING', true);
      commit('SET_ERROR', null);
      try {
        const response = await axios.get('/api/users/stats/dashboard', {
          headers: { Authorization: `Bearer ${state.token}` }
        });
        commit('SET_STATS', response.data.data);
        return response.data.data;
      } catch (error) {
        const errorMessage = error.response?.data?.message || 'Failed to fetch dashboard stats';
        commit('SET_ERROR', errorMessage);
        return {};
      } finally {
        commit('SET_LOADING', false);
      }
    }
  }
};

export default store; 
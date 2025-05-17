import { createRouter, createWebHistory } from 'vue-router';

// Route components
const CloudToLocalLLMHome = () => import('../views/Home.vue');

// Route configuration
const routes = [
  {
    path: '/',
    name: 'home',
    component: CloudToLocalLLMHome,
    meta: {
      title: 'Home - CloudToLocalLLM Admin'
    }
  },
  {
    path: '/login',
    name: 'UserLogin',
    component: () => import('../views/UserLogin.vue'),
    meta: { requiresAuth: false }
  },
  {
    path: '/dashboard',
    name: 'MainDashboard',
    component: () => import('../views/MainDashboard.vue'),
    meta: { requiresAuth: true }
  },
  {
    path: '/users',
    name: 'UserManagement',
    component: () => import('../views/UserManagement.vue'),
    meta: { requiresAuth: true, role: 'admin' }
  },
  {
    path: '/users/:id',
    name: 'UserDetail',
    component: () => import('../views/UserDetail.vue'),
    meta: { requiresAuth: true }
  },
  {
    path: '/profile',
    name: 'UserProfile',
    component: () => import('../views/UserProfile.vue'),
    meta: { requiresAuth: true }
  },
  {
    path: '/settings',
    name: 'AppSettings',
    component: () => import('../views/AppSettings.vue'),
    meta: { requiresAuth: true, role: 'admin' }
  },
  {
    path: '/:pathMatch(.*)*',
    name: 'NotFound',
    component: () => import('../views/NotFound.vue')
  }
];

// Router instance
const router = createRouter({
  history: createWebHistory(),
  routes,
  scrollBehavior(to, from, savedPosition) {
    if (savedPosition) {
      return savedPosition;
    }
    return { top: 0 };
  }
});

// Navigation guards
router.beforeEach((to, from, next) => {
  // Update page title
  document.title = to.meta.title || 'CloudToLocalLLM Admin';
  next();
});

export default router; 
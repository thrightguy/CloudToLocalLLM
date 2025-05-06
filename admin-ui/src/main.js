import { createApp } from 'vue';
import { createStore } from 'vuex';
import { createRouter, createWebHistory } from 'vue-router';
import PrimeVue from 'primevue/config';
import ToastService from 'primevue/toastservice';
import ConfirmationService from 'primevue/confirmationservice';

// PrimeVue styles
import 'primevue/resources/themes/lara-light-blue/theme.css';
import 'primevue/resources/primevue.min.css';
import 'primeicons/primeicons.css';

// App component and styles
import App from './App.vue';
import './assets/styles/main.scss';

// Import routes and store
import routes from './router';
import storeConfig from './store';

// Create router
const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: '/',
      component: () => import('./views/Home.vue')
    }
  ]
});

// Create store
const store = createStore(storeConfig);

// Add navigation guard
router.beforeEach((to, from, next) => {
  // Check if route requires auth
  if (to.matched.some(record => record.meta.requiresAuth)) {
    // Check if user is authenticated
    if (!store.getters.isAuthenticated) {
      // Redirect to login
      next({ name: 'Login', query: { redirect: to.fullPath } });
    } else {
      // Check if user has required role
      const requiredRole = to.meta.role;
      if (requiredRole && !store.getters.hasRole(requiredRole)) {
        // Redirect to dashboard if role doesn't match
        next({ name: 'Dashboard' });
      } else {
        next();
      }
    }
  } else {
    next();
  }
});

// Create app
const app = createApp(App);

// Use plugins
app.use(router);
app.use(store);
app.use(PrimeVue, { ripple: true });
app.use(ToastService);
app.use(ConfirmationService);

// Mount app
app.mount('#app'); 
import { createApp } from 'vue';
import { createRouter, createWebHistory } from 'vue-router';
import App from './App.vue';

// Import routes
const routes = [
  {
    path: '/',
    component: () => import('./views/Home.vue')
  }
];

// Create router
const router = createRouter({
  history: createWebHistory(),
  routes
});

// Create app
const app = createApp(App);

// Use plugins
app.use(router);

// Mount app
app.mount('#app'); 
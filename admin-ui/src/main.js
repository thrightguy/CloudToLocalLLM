import { createApp } from 'vue';
import { createRouter, createWebHistory } from 'vue-router';
import App from './App.vue';

// Route components
const HomeView = () => import('./views/Home.vue');

// Define routes
const routes = [
  {
    path: '/',
    name: 'home',
    component: HomeView
  }
];

// Create router instance
const router = createRouter({
  history: createWebHistory(),
  routes
});

// Create Vue app instance
const app = createApp(App);

// Register plugins
app.use(router);

// Mount the app
app.mount('#app'); 
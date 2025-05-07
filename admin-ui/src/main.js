import { createApp } from 'vue';
import App from './App.vue';
import router from './router';
import { createPinia } from 'pinia';
import ToastService from 'primevue/toastservice';
import Toast from 'primevue/toast';

// Create Vue app instance
const app = createApp(App);

// Register plugins
app.use(createPinia());
app.use(router);
app.use(ToastService);
app.component('Toast', Toast);

// Mount the app
app.mount('#app'); 
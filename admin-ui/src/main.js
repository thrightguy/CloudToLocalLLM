import { createApp } from 'vue';
import App from './App.vue';
import router from './router';

// Create Vue app instance
const app = createApp(App);

// Register plugins
app.use(router);

// Mount the app
app.mount('#app'); 
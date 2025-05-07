## Toast Notifications Setup

To use toast notifications (PrimeVue):

1. Register ToastService and the Toast component in `src/main.js`:
   ```js
   import ToastService from 'primevue/toastservice';
   import Toast from 'primevue/toast';
   app.use(ToastService);
   app.component('Toast', Toast);
   ```
2. Add `<Toast />` to the root `App.vue` template (outside of router-view) so notifications are globally available.

### Troubleshooting
- If you see errors like `No PrimeVue Toast provided!` or `Rollup failed to resolve import "primevue/usetoast"`, ensure you have registered ToastService and the Toast component as above, and that `<Toast />` is present in `App.vue`.
- Make sure your PrimeVue version is compatible with the usage of `useToast` (PrimeVue 4.x+). 
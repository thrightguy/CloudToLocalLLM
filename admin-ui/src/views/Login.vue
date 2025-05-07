<template>
  <div class="auth-container">
    <div class="auth-card">
      <header class="mb-4">
        <h1 class="text-center">CloudToLocalLLM Admin</h1>
        <p class="text-center">Please sign in to continue</p>
      </header>
      
      <form @submit.prevent="handleSubmit">
        <div class="mb-4">
          <label for="username">Username</label>
          <InputText id="username" v-model="username" class="w-full" 
                    :class="{ 'p-invalid': v$.username.$error }" />
          <small v-if="v$.username.$error" class="p-error">{{ v$.username.$errors[0].$message }}</small>
        </div>
        
        <div class="mb-4">
          <label for="password">Password</label>
          <Password id="password" v-model="password" class="w-full" toggleMask
                   :class="{ 'p-invalid': v$.password.$error }" :feedback="false" />
          <small v-if="v$.password.$error" class="p-error">{{ v$.password.$errors[0].$message }}</small>
        </div>
        
        <div v-if="error" class="p-message p-message-error mb-4">
          <i class="pi pi-exclamation-triangle"></i>
          <span>{{ error }}</span>
        </div>
        
        <div class="flex justify-between items-center">
          <Button type="submit" label="Sign In" class="p-button-primary" :loading="isLoading" />
          <router-link to="/register">Create account</router-link>
        </div>
      </form>
    </div>
  </div>
</template>

<script>
import { ref, computed } from 'vue';
import { useStore } from 'vuex';
import { useRouter, useRoute } from 'vue-router';
import { useToast } from 'primevue/usetoast';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';
import InputText from 'primevue/inputtext';
import Password from 'primevue/password';
import Button from 'primevue/button';

export default {
  name: 'Login',
  components: {
    InputText,
    Password,
    Button
  },
  setup() {
    const store = useStore();
    const router = useRouter();
    const route = useRoute();
    const toast = useToast();
    
    // Form state
    const username = ref('');
    const password = ref('');
    
    // Validation rules
    const rules = {
      username: { required, minLength: minLength(3) },
      password: { required, minLength: minLength(6) }
    };
    
    const v$ = useVuelidate(rules, { username, password });
    
    // Computed properties
    const isLoading = computed(() => store.getters.isLoading);
    const error = computed(() => store.getters.error);
    
    // Methods
    const handleSubmit = async () => {
      const isValid = await v$.value.$validate();
      if (!isValid) return;
      
      const credentials = {
        username: username.value,
        password: password.value
      };
      
      const success = await store.dispatch('login', credentials);
      
      if (success) {
        // Redirect to dashboard or previous page
        const redirectPath = route.query.redirect || '/dashboard';
        router.push(redirectPath);
        
        // Show success toast
        toast.add({
          severity: 'success',
          summary: 'Login Successful',
          detail: 'Welcome to CloudToLocalLLM Admin',
          life: 3000
        });
      }
    };
    
    return {
      username,
      password,
      v$,
      isLoading,
      error,
      handleSubmit
    };
  }
};
</script>

<style scoped>
.text-center {
  text-align: center;
}

.w-full {
  width: 100%;
}

label {
  display: block;
  margin-bottom: 0.5rem;
  font-weight: 500;
}

form {
  margin-top: 2rem;
}
</style> 
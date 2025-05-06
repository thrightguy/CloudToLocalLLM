<template>
  <div class="home-view">
    <h1 class="home-title">
      CloudToLocalLLM Admin
    </h1>
    <p class="home-welcome">
      Welcome to the admin dashboard!
    </p>
  </div>
</template>

<script>
export default {
  name: 'CloudToLocalLLMHome'
};
</script>

<style scoped>
.home-view {
  padding: 2rem;
  max-width: 800px;
  margin: 0 auto;
}

.home-title {
  color: #2c3e50;
  margin-bottom: 1rem;
}

.home-welcome {
  color: #666;
  font-size: 1.1rem;
}
</style> 
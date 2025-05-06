<template>
  <div class="app-container">
    <nav class="app-nav">
      <router-link
        to="/"
        class="nav-link"
      >
        Dashboard
      </router-link>
    </nav>
    <main class="app-main">
      <router-view />
    </main>
  </div>
</template>

<script>
export default {
  name: 'CloudToLocalLLMApp'
};
</script>

<style>
.app-container {
  font-family: Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  color: #2c3e50;
  margin: 0;
  padding: 0;
  min-height: 100vh;
  display: flex;
  flex-direction: column;
}

.app-nav {
  background-color: #42b983;
  padding: 1rem;
}

.nav-link {
  font-weight: bold;
  color: #ffffff;
  text-decoration: none;
  font-size: 1.1rem;
}

.nav-link.router-link-exact-active {
  color: #2c3e50;
}

.app-main {
  flex: 1;
  padding: 2rem;
}
</style> 
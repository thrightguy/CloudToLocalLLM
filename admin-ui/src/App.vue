<template>
  <div id="app">
    <nav>
      <router-link to="/">Dashboard</router-link>
    </nav>
    <main>
      <router-view></router-view>
    </main>
  </div>
</template>

<script>
export default {
  name: 'AppRoot'
}
</script>

<style>
#app {
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

nav {
  background-color: #42b983;
  padding: 1rem;
}

nav a {
  font-weight: bold;
  color: #ffffff;
  text-decoration: none;
  font-size: 1.1rem;
}

nav a.router-link-exact-active {
  color: #2c3e50;
}

main {
  flex: 1;
  padding: 2rem;
}
</style> 
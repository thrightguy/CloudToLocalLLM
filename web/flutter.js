// The value below is injected by flutter build, do not touch.
const serviceWorkerVersion = null;

// This script adds the flutter initialization JS code
importScripts('flutter.js');

// Initialize Auth0
const auth0 = new Auth0({
  domain: 'dev-xafu7oedkd5wlrbo.us.auth0.com',
  clientId: 'HlOeY1pG9e2g6MvFKPDFbJ3ASIhxDgNu',
  redirectUri: 'https://cloudtolocalllm.online/callback',
  audience: 'https://dev-xafu7oedkd5wlrbo.us.auth0.com/api/v2/',
  scope: 'openid profile email'
});

// Make auth0 available globally for Flutter web
window.auth0 = auth0; 
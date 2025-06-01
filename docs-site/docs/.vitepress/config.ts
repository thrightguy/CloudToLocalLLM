import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'CloudToLocalLLM',
  description: 'Secure bridge for local Ollama to cloud service',
  
  head: [
    ['link', { rel: 'icon', href: '/favicon.ico' }],
    ['meta', { name: 'theme-color', content: '#2563eb' }],
    ['meta', { property: 'og:type', content: 'website' }],
    ['meta', { property: 'og:locale', content: 'en' }],
    ['meta', { property: 'og:title', content: 'CloudToLocalLLM Documentation' }],
    ['meta', { property: 'og:site_name', content: 'CloudToLocalLLM' }],
    ['meta', { property: 'og:image', content: 'https://docs.cloudtolocalllm.online/og-image.png' }],
    ['meta', { property: 'og:url', content: 'https://docs.cloudtolocalllm.online/' }],
  ],

  themeConfig: {
    logo: '/logo.svg',
    
    nav: [
      { text: 'Home', link: '/' },
      { text: 'Guide', link: '/guide/getting-started' },
      { text: 'Installation', link: '/installation/' },
      { text: 'API', link: '/api/' },
      { text: 'Downloads', link: '/downloads/' },
      { 
        text: 'v1.0.0',
        items: [
          { text: 'Changelog', link: '/changelog' },
          { text: 'Contributing', link: '/contributing' }
        ]
      }
    ],

    sidebar: {
      '/guide/': [
        {
          text: 'Introduction',
          items: [
            { text: 'Getting Started', link: '/guide/getting-started' },
            { text: 'Architecture', link: '/guide/architecture' },
            { text: 'Features', link: '/guide/features' }
          ]
        },
        {
          text: 'Desktop Bridge',
          items: [
            { text: 'Overview', link: '/guide/desktop-bridge/' },
            { text: 'Authentication', link: '/guide/desktop-bridge/authentication' },
            { text: 'Configuration', link: '/guide/desktop-bridge/configuration' },
            { text: 'Troubleshooting', link: '/guide/desktop-bridge/troubleshooting' }
          ]
        },
        {
          text: 'Web Application',
          items: [
            { text: 'Overview', link: '/guide/web-app/' },
            { text: 'Chat Interface', link: '/guide/web-app/chat' },
            { text: 'Settings', link: '/guide/web-app/settings' }
          ]
        }
      ],
      '/installation/': [
        {
          text: 'Installation',
          items: [
            { text: 'Overview', link: '/installation/' },
            { text: 'System Requirements', link: '/installation/requirements' }
          ]
        },
        {
          text: 'Linux',
          items: [
            { text: 'Debian/Ubuntu (.deb)', link: '/installation/linux/debian' },
            { text: 'AppImage', link: '/installation/linux/appimage' },
            { text: 'Arch Linux (AUR)', link: '/installation/linux/arch' },
            { text: 'Manual Installation', link: '/installation/linux/manual' }
          ]
        },
        {
          text: 'Other Platforms',
          items: [
            { text: 'Windows (Coming Soon)', link: '/installation/windows' },
            { text: 'macOS (Coming Soon)', link: '/installation/macos' }
          ]
        }
      ],
      '/api/': [
        {
          text: 'API Reference',
          items: [
            { text: 'Overview', link: '/api/' },
            { text: 'Authentication', link: '/api/authentication' },
            { text: 'Bridge Endpoints', link: '/api/bridge' },
            { text: 'WebSocket Protocol', link: '/api/websocket' }
          ]
        },
        {
          text: 'Integration',
          items: [
            { text: 'Ollama Integration', link: '/api/ollama' },
            { text: 'Cloud Relay', link: '/api/cloud-relay' },
            { text: 'Error Handling', link: '/api/errors' }
          ]
        }
      ]
    },

    socialLinks: [
      { icon: 'github', link: 'https://github.com/imrightguy/CloudToLocalLLM' }
    ],

    footer: {
      message: 'Released under the MIT License.',
      copyright: 'Copyright © 2024 CloudToLocalLLM Team'
    },

    editLink: {
      pattern: 'https://github.com/imrightguy/CloudToLocalLLM/edit/main/docs-site/docs/:path',
      text: 'Edit this page on GitHub'
    },

    search: {
      provider: 'local'
    },

    lastUpdated: {
      text: 'Updated at',
      formatOptions: {
        dateStyle: 'full',
        timeStyle: 'medium'
      }
    }
  },

  markdown: {
    theme: {
      light: 'github-light',
      dark: 'github-dark'
    },
    lineNumbers: true
  },

  sitemap: {
    hostname: 'https://docs.cloudtolocalllm.online'
  }
})

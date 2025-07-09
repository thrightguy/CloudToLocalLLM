// CloudToLocalLLM v3.10.0 Playwright Configuration
// Optimized for authentication loop analysis and debugging

const { defineConfig, devices } = require('@playwright/test');

module.exports = defineConfig({
  // Test directory
  testDir: './tests/e2e',
  
  // Global test timeout
  timeout: 60000, // 60 seconds for complex auth flows
  
  // Expect timeout for assertions
  expect: {
    timeout: 10000, // 10 seconds for element assertions
  },
  
  // Fail the build on CI if you accidentally left test.only in the source code
  forbidOnly: !!process.env.CI,
  
  // Retry on CI only
  retries: process.env.CI ? 2 : 0,
  
  // Opt out of parallel tests for authentication analysis
  workers: 1,
  
  // Reporter configuration
  reporter: [
    ['html', { outputFolder: 'test-results/html-report' }],
    ['json', { outputFile: 'test-results/test-results.json' }],
    ['junit', { outputFile: 'test-results/junit.xml' }],
    ['list'],
  ],
  
  // Global test setup
  globalSetup: require.resolve('./tests/e2e/global-setup.js'),
  
  // Shared settings for all projects
  use: {
    // Base URL for tests
    baseURL: process.env.DEPLOYMENT_URL || 'https://your-vercel-app.vercel.app',
    
    // Collect trace when retrying the failed test
    trace: 'retain-on-failure',
    
    // Record video for failed tests
    video: 'retain-on-failure',
    
    // Take screenshot on failure
    screenshot: 'only-on-failure',
    
    // Browser context options
    viewport: { width: 1280, height: 720 },
    ignoreHTTPSErrors: true,
    
    // Extended timeouts for auth flows
    actionTimeout: 15000,
    navigationTimeout: 30000,
    
    // Additional context options for debugging
    recordHar: {
      mode: 'minimal',
      path: 'test-results/network.har',
    },
    
    // Permissions for potential popup handling
    permissions: ['notifications'],
    
    // User agent
    userAgent: 'CloudToLocalLLM-E2E-Test/3.10.0 (Playwright)',
  },

  // Test projects for different browsers
  projects: [
    {
      name: 'chromium-auth-analysis',
      use: { 
        ...devices['Desktop Chrome'],
        // Additional Chrome flags for debugging
        launchOptions: {
          args: [
            '--disable-web-security',
            '--disable-features=VizDisplayCompositor',
            '--enable-logging',
            '--v=1',
          ],
        },
      },
    },
    
    {
      name: 'firefox-auth-analysis',
      use: { 
        ...devices['Desktop Firefox'],
        // Firefox-specific settings
        launchOptions: {
          firefoxUserPrefs: {
            'dom.webnotifications.enabled': false,
            'dom.push.enabled': false,
          },
        },
      },
    },
    
    {
      name: 'webkit-auth-analysis',
      use: { 
        ...devices['Desktop Safari'],
      },
    },

    // Mobile testing (optional)
    {
      name: 'mobile-chrome-auth',
      use: { 
        ...devices['Pixel 5'],
      },
    },
    
    {
      name: 'mobile-safari-auth',
      use: { 
        ...devices['iPhone 12'],
      },
    },
  ],

  // Output directory for test artifacts
  outputDir: 'test-results/artifacts',
  
  // Web server configuration (for local testing)
  webServer: process.env.LOCAL_TEST ? {
    command: 'python -m http.server 8080 --directory build/web',
    port: 8080,
    reuseExistingServer: !process.env.CI,
    timeout: 120000,
  } : undefined,
});

// Environment-specific configurations
if (process.env.CI) {
  // CI-specific settings
  module.exports.use.headless = true;
  module.exports.workers = 1;
  module.exports.retries = 3;
} else {
  // Local development settings
  module.exports.use.headless = false;
  module.exports.use.slowMo = 500; // Slow down for debugging
}

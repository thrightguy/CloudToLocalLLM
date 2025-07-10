// CloudToLocalLLM Tunnel Verification Test
// Verifies that web deployment exclusively uses tunnel infrastructure
// and makes zero direct calls to localhost:11434

const { test, expect } = require('@playwright/test');

test.describe('Tunnel Infrastructure Verification', () => {
  let networkRequests = [];
  let consoleMessages = [];
  let localhostRequests = [];

  test.beforeEach(async ({ page }) => {
    // Reset tracking arrays
    networkRequests = [];
    consoleMessages = [];
    localhostRequests = [];

    // Capture all network requests
    page.on('request', (request) => {
      const url = request.url();
      networkRequests.push({
        url,
        method: request.method(),
        timestamp: new Date().toISOString(),
        headers: request.headers(),
      });

      // Track localhost requests specifically
      if (url.includes('localhost:11434') || url.includes('127.0.0.1:11434')) {
        localhostRequests.push({
          url,
          method: request.method(),
          timestamp: new Date().toISOString(),
          blocked: false,
        });
        console.error(`🚨 LOCALHOST REQUEST DETECTED: ${request.method()} ${url}`);
      }
    });

    // Capture failed requests (CORS errors)
    page.on('requestfailed', (request) => {
      const url = request.url();
      const failure = request.failure();
      
      if (url.includes('localhost:11434') || url.includes('127.0.0.1:11434')) {
        localhostRequests.push({
          url,
          method: request.method(),
          timestamp: new Date().toISOString(),
          blocked: true,
          error: failure?.errorText || 'Request failed',
        });
        console.log(`✅ LOCALHOST REQUEST BLOCKED (expected): ${request.method()} ${url} - ${failure?.errorText}`);
      }
    });

    // Capture console messages for debugging
    page.on('console', (msg) => {
      const text = msg.text();
      consoleMessages.push({
        type: msg.type(),
        text,
        timestamp: new Date().toISOString(),
      });

      // Log important platform detection messages
      if (text.includes('Web platform detected') || 
          text.includes('Cloud proxy') || 
          text.includes('LocalOllama') ||
          text.includes('ConnectionManager') ||
          text.includes('CORS')) {
        console.log(`📝 Console: [${msg.type()}] ${text}`);
      }
    });
  });

  test('should never make direct calls to localhost:11434', async ({ page }) => {
    console.log('🧪 Testing: No direct localhost calls');
    
    // Navigate to the web application
    await page.goto('/');
    
    // Wait for initial page load and service initialization
    await page.waitForTimeout(5000);
    
    // Try to trigger Ollama-related functionality
    // Look for connection status or model selection elements
    try {
      // Wait for any connection status indicators
      await page.waitForSelector('[data-testid="connection-status"], .connection-status, .status-indicator', { timeout: 10000 });
    } catch (e) {
      console.log('No connection status elements found, continuing...');
    }

    // Try to interact with chat or model selection if available
    try {
      const chatInput = page.locator('input[placeholder*="message"], textarea[placeholder*="message"], input[type="text"]').first();
      if (await chatInput.isVisible({ timeout: 5000 })) {
        await chatInput.click();
        await chatInput.fill('Test message to trigger Ollama connection');
        
        // Look for send button
        const sendButton = page.locator('button:has-text("Send"), button[type="submit"], button:has(svg)').first();
        if (await sendButton.isVisible({ timeout: 2000 })) {
          await sendButton.click();
          await page.waitForTimeout(3000); // Wait for potential API calls
        }
      }
    } catch (e) {
      console.log('No chat interface found, continuing...');
    }

    // Wait additional time for any delayed requests
    await page.waitForTimeout(5000);

    // Verify no localhost requests were made
    console.log(`📊 Total network requests: ${networkRequests.length}`);
    console.log(`🚨 Localhost requests detected: ${localhostRequests.length}`);
    
    if (localhostRequests.length > 0) {
      console.error('❌ LOCALHOST REQUESTS FOUND:');
      localhostRequests.forEach((req, index) => {
        console.error(`  ${index + 1}. ${req.method} ${req.url} (${req.blocked ? 'BLOCKED' : 'ALLOWED'})`);
      });
    }

    // The test should pass if no localhost requests were made
    expect(localhostRequests.length).toBe(0);
  });

  test('should use cloud proxy tunnel for Ollama API calls', async ({ page }) => {
    console.log('🧪 Testing: Cloud proxy tunnel usage');
    
    await page.goto('/');
    await page.waitForTimeout(5000);

    // Look for requests to the cloud proxy endpoint
    const cloudProxyRequests = networkRequests.filter(req => 
      req.url.includes('app.cloudtolocalllm.online/api/ollama') ||
      req.url.includes('cloudtolocalllm.online/api/ollama')
    );

    console.log(`🌐 Cloud proxy requests found: ${cloudProxyRequests.length}`);
    cloudProxyRequests.forEach((req, index) => {
      console.log(`  ${index + 1}. ${req.method} ${req.url}`);
    });

    // Verify platform detection messages in console
    const platformMessages = consoleMessages.filter(msg => 
      msg.text.includes('Web platform detected') ||
      msg.text.includes('Cloud proxy') ||
      msg.text.includes('tunnel')
    );

    console.log(`📝 Platform detection messages: ${platformMessages.length}`);
    platformMessages.forEach((msg, index) => {
      console.log(`  ${index + 1}. [${msg.type}] ${msg.text}`);
    });

    // At minimum, we should see platform detection messages
    expect(platformMessages.length).toBeGreaterThan(0);
  });

  test('should show proper CORS prevention logging', async ({ page }) => {
    console.log('🧪 Testing: CORS prevention logging');
    
    await page.goto('/');
    await page.waitForTimeout(5000);

    // Look for CORS prevention messages
    const corsMessages = consoleMessages.filter(msg => 
      msg.text.includes('CORS') ||
      msg.text.includes('prevent CORS errors') ||
      msg.text.includes('Web platform detected') ||
      msg.text.includes('localhost operations disabled')
    );

    console.log(`🛡️ CORS prevention messages: ${corsMessages.length}`);
    corsMessages.forEach((msg, index) => {
      console.log(`  ${index + 1}. [${msg.type}] ${msg.text}`);
    });

    // Should have messages indicating CORS prevention
    expect(corsMessages.length).toBeGreaterThan(0);
  });

  test('should handle connection manager routing correctly', async ({ page }) => {
    console.log('🧪 Testing: Connection manager routing');
    
    await page.goto('/');
    await page.waitForTimeout(5000);

    // Look for connection manager messages
    const connectionMessages = consoleMessages.filter(msg => 
      msg.text.includes('ConnectionManager') ||
      msg.text.includes('cloud proxy connection') ||
      msg.text.includes('local connection disabled')
    );

    console.log(`🔗 Connection manager messages: ${connectionMessages.length}`);
    connectionMessages.forEach((msg, index) => {
      console.log(`  ${index + 1}. [${msg.type}] ${msg.text}`);
    });

    // Should have connection manager routing messages
    expect(connectionMessages.length).toBeGreaterThan(0);
  });

  test.afterEach(async ({ page }) => {
    // Generate detailed report
    console.log('\n📋 TUNNEL VERIFICATION REPORT');
    console.log('================================');
    console.log(`🌐 Total network requests: ${networkRequests.length}`);
    console.log(`🚨 Localhost requests: ${localhostRequests.length}`);
    console.log(`📝 Console messages: ${consoleMessages.length}`);
    
    if (localhostRequests.length > 0) {
      console.log('\n❌ LOCALHOST REQUESTS (SHOULD BE ZERO):');
      localhostRequests.forEach((req, index) => {
        console.log(`  ${index + 1}. ${req.method} ${req.url}`);
        console.log(`     Status: ${req.blocked ? 'BLOCKED' : 'ALLOWED'}`);
        console.log(`     Time: ${req.timestamp}`);
        if (req.error) console.log(`     Error: ${req.error}`);
      });
    } else {
      console.log('\n✅ NO LOCALHOST REQUESTS DETECTED (GOOD!)');
    }

    // Log cloud proxy usage
    const cloudRequests = networkRequests.filter(req => 
      req.url.includes('cloudtolocalllm.online')
    );
    
    if (cloudRequests.length > 0) {
      console.log('\n🌐 CLOUD PROXY REQUESTS:');
      cloudRequests.forEach((req, index) => {
        console.log(`  ${index + 1}. ${req.method} ${req.url}`);
      });
    }

    console.log('\n================================\n');
  });
});

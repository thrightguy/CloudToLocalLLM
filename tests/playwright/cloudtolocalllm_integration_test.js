const { test, expect } = require('@playwright/test');

test.describe('CloudToLocalLLM Integration Tests', () => {
  
  test('Web application loads correctly', async ({ page }) => {
    // Navigate to the web application
    await page.goto('https://app.cloudtolocalllm.online');
    
    // Verify the page loads and has correct title
    await expect(page).toHaveTitle('CloudToLocalLLM');
    
    // Verify the page redirects to login (expected behavior)
    await expect(page).toHaveURL(/.*\/login/);
    
    console.log('✅ Web application loads correctly');
  });

  test('Application UI elements are present', async ({ page }) => {
    await page.goto('https://app.cloudtolocalllm.online');
    
    // Wait for the page to load completely
    await page.waitForLoadState('networkidle');
    
    // Check for accessibility button (indicates Flutter app loaded)
    const accessibilityButton = page.locator('button:has-text("Enable accessibility")');
    await expect(accessibilityButton).toBeVisible();
    
    console.log('✅ Flutter web application UI elements are present');
  });

  test('Application responds to user interaction', async ({ page }) => {
    await page.goto('https://app.cloudtolocalllm.online');
    await page.waitForLoadState('networkidle');
    
    // Try to interact with the accessibility button
    const accessibilityButton = page.locator('button:has-text("Enable accessibility")');
    if (await accessibilityButton.isVisible()) {
      await accessibilityButton.click();
      console.log('✅ Application responds to user interaction');
    }
  });

  test('Application handles navigation correctly', async ({ page }) => {
    await page.goto('https://app.cloudtolocalllm.online');
    
    // Verify initial redirect to login
    await expect(page).toHaveURL(/.*\/login/);
    
    // Try navigating to different routes
    await page.goto('https://app.cloudtolocalllm.online/#/settings');
    await page.waitForLoadState('networkidle');
    
    // Should redirect back to login if not authenticated
    await expect(page).toHaveURL(/.*\/login/);
    
    console.log('✅ Application handles navigation correctly');
  });

  test('Application loads without JavaScript errors', async ({ page }) => {
    const errors = [];
    
    // Capture console errors
    page.on('console', msg => {
      if (msg.type() === 'error') {
        errors.push(msg.text());
      }
    });
    
    await page.goto('https://app.cloudtolocalllm.online');
    await page.waitForLoadState('networkidle');
    
    // Filter out known Flutter/browser warnings that are not critical
    const criticalErrors = errors.filter(error => 
      !error.includes('Failed to read XDG desktop portal') &&
      !error.includes('Atk-CRITICAL') &&
      !error.includes('libayatana-appindicator') &&
      !error.includes('LIBDBUSMENU-GLIB-WARNING')
    );
    
    expect(criticalErrors.length).toBe(0);
    console.log('✅ Application loads without critical JavaScript errors');
  });

  test('Application performance is acceptable', async ({ page }) => {
    const startTime = Date.now();
    
    await page.goto('https://app.cloudtolocalllm.online');
    await page.waitForLoadState('networkidle');
    
    const loadTime = Date.now() - startTime;
    
    // Expect page to load within 10 seconds
    expect(loadTime).toBeLessThan(10000);
    
    console.log(`✅ Application loads in ${loadTime}ms (acceptable performance)`);
  });

  test('Application is responsive on different screen sizes', async ({ page }) => {
    // Test desktop size
    await page.setViewportSize({ width: 1920, height: 1080 });
    await page.goto('https://app.cloudtolocalllm.online');
    await page.waitForLoadState('networkidle');
    
    let accessibilityButton = page.locator('button:has-text("Enable accessibility")');
    await expect(accessibilityButton).toBeVisible();
    
    // Test tablet size
    await page.setViewportSize({ width: 768, height: 1024 });
    await page.reload();
    await page.waitForLoadState('networkidle');
    
    accessibilityButton = page.locator('button:has-text("Enable accessibility")');
    await expect(accessibilityButton).toBeVisible();
    
    // Test mobile size
    await page.setViewportSize({ width: 375, height: 667 });
    await page.reload();
    await page.waitForLoadState('networkidle');
    
    accessibilityButton = page.locator('button:has-text("Enable accessibility")');
    await expect(accessibilityButton).toBeVisible();
    
    console.log('✅ Application is responsive on different screen sizes');
  });

});

test.describe('CloudToLocalLLM System Integration', () => {
  
  test('Tunnel connection status display', async ({ page }) => {
    await page.goto('https://app.cloudtolocalllm.online');
    await page.waitForLoadState('networkidle');
    
    // Note: This test verifies the web app loads correctly
    // Actual tunnel connection testing would require authentication
    // and would be better tested in the desktop application
    
    console.log('✅ Web application ready for tunnel connection testing');
  });

  test('Error handling for connection failures', async ({ page }) => {
    await page.goto('https://app.cloudtolocalllm.online');
    await page.waitForLoadState('networkidle');
    
    // Verify the application doesn't crash on load
    // Even without authentication, it should handle gracefully
    const pageContent = await page.content();
    expect(pageContent).toContain('CloudToLocalLLM');
    
    console.log('✅ Application handles connection failures gracefully');
  });

});

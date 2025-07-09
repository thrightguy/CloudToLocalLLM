// CloudToLocalLLM v3.10.0 Global Test Setup
// Prepares environment for authentication loop analysis

const fs = require('fs');
const path = require('path');

async function globalSetup(config) {
  console.log('🚀 CloudToLocalLLM v3.10.0 Authentication Loop Analysis Setup');
  console.log('================================================================');
  
  // Create test results directory
  const testResultsDir = 'test-results';
  if (!fs.existsSync(testResultsDir)) {
    fs.mkdirSync(testResultsDir, { recursive: true });
  }
  
  // Create subdirectories for artifacts
  const subdirs = ['screenshots', 'videos', 'traces', 'reports', 'artifacts'];
  subdirs.forEach(subdir => {
    const dirPath = path.join(testResultsDir, subdir);
    if (!fs.existsSync(dirPath)) {
      fs.mkdirSync(dirPath, { recursive: true });
    }
  });
  
  // Validate environment variables
  const requiredEnvVars = ['DEPLOYMENT_URL'];
  const optionalEnvVars = ['AUTH0_TEST_EMAIL', 'AUTH0_TEST_PASSWORD'];
  
  console.log('\n📋 Environment Configuration:');
  console.log('==============================');
  
  requiredEnvVars.forEach(envVar => {
    if (process.env[envVar]) {
      console.log(`✅ ${envVar}: ${process.env[envVar]}`);
    } else {
      console.log(`❌ ${envVar}: NOT SET (required)`);
      throw new Error(`Required environment variable ${envVar} is not set`);
    }
  });
  
  optionalEnvVars.forEach(envVar => {
    if (process.env[envVar]) {
      console.log(`✅ ${envVar}: ****** (set)`);
    } else {
      console.log(`⚠️  ${envVar}: NOT SET (optional - will skip Auth0 form interaction)`);
    }
  });
  
  // Validate deployment URL accessibility
  console.log('\n🌐 Deployment Validation:');
  console.log('=========================');
  
  try {
    const deploymentUrl = process.env.DEPLOYMENT_URL;
    console.log(`Testing connectivity to: ${deploymentUrl}`);
    
    // Simple fetch to check if deployment is accessible
    const response = await fetch(deploymentUrl);
    if (response.ok) {
      console.log(`✅ Deployment accessible (HTTP ${response.status})`);
      
      // Check version endpoint
      try {
        const versionResponse = await fetch(`${deploymentUrl}/version.json`);
        if (versionResponse.ok) {
          const versionData = await versionResponse.json();
          console.log(`✅ Version endpoint accessible: v${versionData.version}`);
          
          if (versionData.version === '3.10.0') {
            console.log(`✅ Correct version deployed (3.10.0)`);
          } else {
            console.log(`⚠️  Unexpected version: ${versionData.version} (expected 3.10.0)`);
          }
        } else {
          console.log(`⚠️  Version endpoint not accessible (HTTP ${versionResponse.status})`);
        }
      } catch (error) {
        console.log(`⚠️  Version check failed: ${error.message}`);
      }
    } else {
      console.log(`❌ Deployment not accessible (HTTP ${response.status})`);
      throw new Error(`Deployment at ${deploymentUrl} is not accessible`);
    }
  } catch (error) {
    console.log(`❌ Deployment validation failed: ${error.message}`);
    throw new Error(`Cannot access deployment: ${error.message}`);
  }
  
  // Create test configuration summary
  const testConfig = {
    timestamp: new Date().toISOString(),
    version: '3.10.0',
    deploymentUrl: process.env.DEPLOYMENT_URL,
    hasAuth0Credentials: !!(process.env.AUTH0_TEST_EMAIL && process.env.AUTH0_TEST_PASSWORD),
    testEnvironment: process.env.CI ? 'CI' : 'LOCAL',
    browsers: config.projects.map(p => p.name),
    expectedFeatures: [
      'Login loop race condition fix',
      '100ms callback processing delay',
      'Enhanced authentication state synchronization',
      'Improved error handling',
      'Debug logging for authentication flow',
    ],
  };
  
  fs.writeFileSync(
    path.join(testResultsDir, 'test-config.json'),
    JSON.stringify(testConfig, null, 2)
  );
  
  console.log('\n🔧 Test Configuration:');
  console.log('======================');
  console.log(`Test Environment: ${testConfig.testEnvironment}`);
  console.log(`Auth0 Credentials: ${testConfig.hasAuth0Credentials ? 'Available' : 'Not Available'}`);
  console.log(`Browsers: ${testConfig.browsers.join(', ')}`);
  
  console.log('\n🎯 Test Objectives:');
  console.log('===================');
  console.log('1. Verify no infinite redirect loops between /login and /callback');
  console.log('2. Confirm 100ms delay implementation is working');
  console.log('3. Validate authentication state synchronization');
  console.log('4. Capture detailed debugging information');
  console.log('5. Analyze network requests and console logs');
  console.log('6. Generate comprehensive test report');
  
  console.log('\n🚨 Known Issues to Test:');
  console.log('========================');
  console.log('- Race condition between auth state setting and router checks');
  console.log('- Infinite loops: login → Auth0 → callback → login');
  console.log('- Authentication state not propagating before navigation');
  console.log('- Token exchange or profile loading failures');
  
  console.log('\n✅ Setup Complete - Ready to run authentication loop analysis');
  console.log('==============================================================\n');
}

module.exports = globalSetup;

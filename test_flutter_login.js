// Flutter web app testing script
// To use: Copy and paste into browser console on the CloudToLocalLLM website

// Find the Flutter canvas/glass pane
const glassPanes = document.querySelectorAll('flt-glass-pane');
console.log(`Found ${glassPanes.length} Flutter glass panes`);

if (glassPanes.length > 0) {
  const glassPane = glassPanes[0];
  
  // Get dimensions
  const width = glassPane.clientWidth;
  const height = glassPane.clientHeight;
  console.log(`Glass pane dimensions: ${width}x${height}`);
  
  // Top right corner (login button)
  const loginX = Math.floor(width * 0.9);
  const loginY = Math.floor(height * 0.05);
  console.log(`Testing login button at position: ${loginX}, ${loginY}`);
  
  // Simulate click on the login button area
  const event = new MouseEvent('click', {
    'view': window,
    'bubbles': true,
    'cancelable': true,
    'clientX': loginX,
    'clientY': loginY
  });
  glassPane.dispatchEvent(event);
  console.log('Click event dispatched to login area');
  
  // Wait to check if page changed
  setTimeout(() => {
    console.log('Current URL:', window.location.href);
    if (window.location.href.includes('/login')) {
      console.log('Login navigation successful!');
    } else {
      console.log('No navigation detected. Trying alternative method...');
      
      // Try to click center of the screen (login card)
      const centerX = Math.floor(width / 2);
      const centerY = Math.floor(height / 2);
      console.log(`Testing center click at position: ${centerX}, ${centerY}`);
      
      const centerEvent = new MouseEvent('click', {
        'view': window,
        'bubbles': true,
        'cancelable': true,
        'clientX': centerX,
        'clientY': centerY
      });
      glassPane.dispatchEvent(centerEvent);
      console.log('Click event dispatched to center area');
    }
  }, 2000);
} else {
  console.error('No Flutter glass pane found!');
} 
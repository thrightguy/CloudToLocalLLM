// JavaScript to click on the login button in top right corner
// IMPORTANT: This script needs to be executed in the browser console

(function() {
  // Find the Flutter glass pane element
  const glassPane = document.querySelector('flt-glass-pane');
  
  if (!glassPane) {
    console.error('No Flutter glass pane found!');
    return;
  }
  
  // Get dimensions of the glass pane
  const width = glassPane.clientWidth;
  const height = glassPane.clientHeight;
  
  // Calculate position for login button in top right
  const loginX = Math.floor(width * 0.9);  // 90% from left edge
  const loginY = Math.floor(height * 0.05); // 5% from top edge
  
  console.log(`Found glass pane with dimensions ${width}x${height}`);
  console.log(`Clicking at position: ${loginX},${loginY}`);
  
  // Create and dispatch a click event
  const event = new MouseEvent('click', {
    view: window,
    bubbles: true,
    cancelable: true,
    clientX: loginX,
    clientY: loginY
  });
  
  // Dispatch the event
  glassPane.dispatchEvent(event);
  
  console.log('Click event dispatched - check if navigation happened');
})(); 
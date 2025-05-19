from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.action_chains import ActionChains
import time
import sys

# Set up Chrome options - NOT headless for visual verification
options = Options()
# Remove headless mode for testing
# options.add_argument('--headless')
options.add_argument('--no-sandbox')
options.add_argument('--disable-dev-shm-usage')
options.add_argument('--ignore-certificate-errors')
options.add_argument('--allow-insecure-localhost')
options.add_argument('--window-size=1280,800')  # Set explicit window size

# URL to test
app_url = 'https://cloudtolocalllm.online'

# Create a new Chrome session
driver = webdriver.Chrome(options=options)

try:
    # Set a longer timeout for slow-loading pages
    driver.set_page_load_timeout(30)
    print(f'Navigating to {app_url}')
    
    # Get the page
    driver.get(app_url)
    time.sleep(5)  # Wait for page to fully load
    
    # Take a screenshot before any interaction
    driver.save_screenshot('1_initial_page.png')
    print('Screenshot saved as 1_initial_page.png')
    
    # Verify Flutter app is loaded
    flutter_elements = driver.find_elements(By.TAG_NAME, 'flt-glass-pane')
    if len(flutter_elements) == 0:
        print("Error: Flutter app not detected!")
        sys.exit(1)
    
    print("Flutter app detected successfully")
    
    # APPROACH 1: Use JavaScript to click the login button in the top right corner
    print("\nAttempting login using JavaScript injection...")
    
    # JavaScript to find the glass pane and click in the top right
    js_login_script = """
    // Find the Flutter canvas/glass pane
    const glassPanes = document.querySelectorAll('flt-glass-pane');
    if (glassPanes.length === 0) {
        return {success: false, message: 'No Flutter glass pane found'};
    }
    
    const glassPane = glassPanes[0];
    
    // Get dimensions
    const width = glassPane.clientWidth;
    const height = glassPane.clientHeight;
    
    // Click top right corner (login button)
    const loginX = Math.floor(width * 0.90);
    const loginY = Math.floor(height * 0.05);
    
    try {
        // Create and dispatch click event
        const event = new MouseEvent('click', {
            'view': window,
            'bubbles': true,
            'cancelable': true,
            'clientX': loginX,
            'clientY': loginY
        });
        glassPane.dispatchEvent(event);
        return {success: true, message: `Clicked at position ${loginX},${loginY}`};
    } catch (e) {
        return {success: false, message: 'Error clicking: ' + e.toString()};
    }
    """
    
    result = driver.execute_script(js_login_script)
    print(f"JavaScript click result: {result}")
    
    # Wait for navigation to login page
    time.sleep(3)
    
    # Take screenshot after login button click
    driver.save_screenshot('2_after_login_button_click.png')
    print('Screenshot saved as 2_after_login_button_click.png')
    
    # Check current URL
    current_url = driver.current_url
    print(f"Current URL: {current_url}")
    
    # If we detect login page, try to login
    if '/login' in current_url:
        print("Successfully navigated to login page")
        
        # Allow UI to stabilize
        time.sleep(2)
        
        # JavaScript to fill in login form and submit
        js_login_form_script = """
        // Find the Flutter canvas/glass pane
        const glassPanes = document.querySelectorAll('flt-glass-pane');
        if (glassPanes.length === 0) {
            return {success: false, message: 'No Flutter glass pane found'};
        }
        
        const glassPane = glassPanes[0];
        
        // Get dimensions
        const width = glassPane.clientWidth;
        const height = glassPane.clientHeight;
        
        // Click email field (40% down from top)
        const emailX = Math.floor(width * 0.5);
        const emailY = Math.floor(height * 0.4);
        
        let result = {
            emailClick: false,
            emailType: false,
            passwordClick: false,
            passwordType: false,
            loginClick: false
        };
        
        try {
            // Click email field
            const emailEvent = new MouseEvent('click', {
                'view': window,
                'bubbles': true,
                'cancelable': true,
                'clientX': emailX,
                'clientY': emailY
            });
            glassPane.dispatchEvent(emailEvent);
            result.emailClick = true;
            
            // Type in email (just dummy keyboard events)
            // In real world, we might need more complex implementations
            for (let char of 'test@example.com') {
                const keyEvent = new KeyboardEvent('keydown', {
                    key: char,
                    code: 'Key' + char.toUpperCase(),
                    charCode: char.charCodeAt(0),
                    keyCode: char.charCodeAt(0),
                    which: char.charCodeAt(0),
                    bubbles: true
                });
                glassPane.dispatchEvent(keyEvent);
            }
            result.emailType = true;
            
            // Click password field (50% down from top)
            const passwordX = Math.floor(width * 0.5);
            const passwordY = Math.floor(height * 0.5);
            
            const passwordEvent = new MouseEvent('click', {
                'view': window,
                'bubbles': true,
                'cancelable': true,
                'clientX': passwordX,
                'clientY': passwordY
            });
            glassPane.dispatchEvent(passwordEvent);
            result.passwordClick = true;
            
            // Type in password
            for (let char of 'password123') {
                const keyEvent = new KeyboardEvent('keydown', {
                    key: char,
                    code: 'Key' + char.toUpperCase(),
                    charCode: char.charCodeAt(0),
                    keyCode: char.charCodeAt(0),
                    which: char.charCodeAt(0),
                    bubbles: true
                });
                glassPane.dispatchEvent(keyEvent);
            }
            result.passwordType = true;
            
            // Click login button (60% down from top)
            const loginX = Math.floor(width * 0.5);
            const loginY = Math.floor(height * 0.6);
            
            const loginEvent = new MouseEvent('click', {
                'view': window,
                'bubbles': true,
                'cancelable': true,
                'clientX': loginX,
                'clientY': loginY
            });
            glassPane.dispatchEvent(loginEvent);
            result.loginClick = true;
            
            return {success: true, actions: result};
        } catch (e) {
            return {success: false, message: 'Error: ' + e.toString(), actions: result};
        }
        """
        
        form_result = driver.execute_script(js_login_form_script)
        print(f"Login form interaction result: {form_result}")
        
        # Wait for login process
        time.sleep(3)
        
        # Take screenshot after login attempt
        driver.save_screenshot('3_after_login_attempt.png')
        print('Screenshot saved as 3_after_login_attempt.png')
        
        # Check if we logged in successfully
        current_url = driver.current_url
        print(f"Current URL after login attempt: {current_url}")
        
        if '/chat' in current_url:
            print("SUCCESS: Login worked and redirected to chat page")
        else:
            print("Login might have failed, still on login page or redirected elsewhere")
    else:
        print("Did not navigate to login page. Trying alternative approach...")
        
        # APPROACH 2: Try clicking the login card on home page
        js_center_click = """
        // Find the Flutter canvas/glass pane
        const glassPanes = document.querySelectorAll('flt-glass-pane');
        if (glassPanes.length === 0) {
            return {success: false, message: 'No Flutter glass pane found'};
        }
        
        const glassPane = glassPanes[0];
        
        // Get dimensions
        const width = glassPane.clientWidth;
        const height = glassPane.clientHeight;
        
        // Click center of screen (login card)
        const centerX = Math.floor(width * 0.5);
        const centerY = Math.floor(height * 0.5);
        
        try {
            // Create and dispatch click event
            const event = new MouseEvent('click', {
                'view': window,
                'bubbles': true,
                'cancelable': true,
                'clientX': centerX,
                'clientY': centerY
            });
            glassPane.dispatchEvent(event);
            
            // Wait a moment and click the login button in card
            setTimeout(() => {
                const loginBtnY = Math.floor(height * 0.7);
                const btnEvent = new MouseEvent('click', {
                    'view': window,
                    'bubbles': true,
                    'cancelable': true,
                    'clientX': centerX,
                    'clientY': loginBtnY
                });
                glassPane.dispatchEvent(btnEvent);
            }, 500);
            
            return {success: true, message: `Clicked at center ${centerX},${centerY}`};
        } catch (e) {
            return {success: false, message: 'Error clicking: ' + e.toString()};
        }
        """
        
        center_result = driver.execute_script(js_center_click)
        print(f"Center click result: {center_result}")
        
        # Wait for potential navigation
        time.sleep(3)
        
        # Take screenshot after center clicks
        driver.save_screenshot('2_after_center_clicks.png')
        print('Screenshot saved as 2_after_center_clicks.png')
        
        current_url = driver.current_url
        print(f"Current URL after center clicks: {current_url}")
        
        if '/login' in current_url:
            print("SUCCESS: Center card click worked, navigated to login page")
        else:
            print("Center card click approach did not navigate to login page")
    
    # Final verification
    print("\nTEST SUMMARY:")
    current_url = driver.current_url
    print(f"Final URL: {current_url}")
    
    if '/chat' in current_url:
        print("✅ TEST PASSED: Successfully logged in and redirected to chat page")
    elif '/login' in current_url:
        print("⚠️ PARTIAL SUCCESS: Successfully navigated to login page but login failed")
    else:
        print("❌ TEST FAILED: Could not navigate to login page")
        
except Exception as e:
    print(f'Error occurred: {e}', file=sys.stderr)
    driver.save_screenshot('error_state.png')
    print('Error state screenshot saved as error_state.png')
finally:
    # Keep browser open for manual inspection
    print('\nBrowser will stay open for inspection. Press Enter to close...')
    input()
    driver.quit() 
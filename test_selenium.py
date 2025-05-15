from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.options import Options
import time
import sys
import json

# Set up Chrome options for headless mode
options = Options()
options.add_argument('--headless')
options.add_argument('--no-sandbox')
options.add_argument('--disable-dev-shm-usage')
options.add_argument('--ignore-certificate-errors')
options.add_argument('--allow-insecure-localhost')
options.add_argument('--disable-web-security')
options.add_argument('--disable-features=IsolateOrigins,site-per-process')
options.add_argument('--disable-site-isolation-trials')

# Add debugging preferences for JavaScript
options.add_experimental_option('prefs', {
    'devtools.console.stdout.content': True,
})

# URLs to test
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
    
    # Get basic info
    print('Page title:', driver.title)
    print('Page URL:', driver.current_url)
    
    # Check for CSP headers
    print('\nChecking meta tags:')
    meta_tags = driver.find_elements(By.TAG_NAME, 'meta')
    csp_found = False
    for meta in meta_tags:
        if meta.get_attribute('http-equiv') == 'Content-Security-Policy':
            csp_found = True
            print(f"CSP: {meta.get_attribute('content')}")
    
    if not csp_found:
        print("No CSP meta tag found!")
    
    # Check page structure
    html_elements = driver.find_elements(By.TAG_NAME, 'html')
    body_elements = driver.find_elements(By.TAG_NAME, 'body')
    
    print(f'\nHTML elements found: {len(html_elements)}')
    print(f'Body elements found: {len(body_elements)}')
    
    # Check for specific elements
    canvas_elements = driver.find_elements(By.TAG_NAME, 'canvas')
    flt_elements = driver.find_elements(By.TAG_NAME, 'flt-glass-pane')
    
    print(f'Canvas elements: {len(canvas_elements)}')
    print(f'Flutter glass pane elements: {len(flt_elements)}')
    
    # Check CSS loading
    print('\nChecking CSS:')
    link_elements = driver.find_elements(By.TAG_NAME, 'link')
    for link in link_elements:
        href = link.get_attribute('href')
        rel = link.get_attribute('rel')
        if href and 'css' in href or rel == 'stylesheet':
            print(f"Stylesheet: {href}")
    
    # Take a screenshot
    driver.save_screenshot('screenshot.png')
    print('\nScreenshot saved as screenshot.png')
    
    # Get JavaScript errors from console logs
    print('\nJavaScript errors:')
    logs = driver.get_log('browser')
    has_errors = False
    for log in logs:
        if log['level'] == 'SEVERE':
            has_errors = True
            print(f"Error: {log['message']}")
    
    if not has_errors:
        print("No JavaScript errors found")
    
    # Get page source for analysis
    page_source = driver.page_source
    print('\nPage source excerpt:')
    print(page_source[:1000] + '...')
    
    # Check background color of body
    bg_color = driver.execute_script(
        "return window.getComputedStyle(document.body).backgroundColor"
    )
    print(f'\nBody background color: {bg_color}')
    
except Exception as e:
    print(f'Error occurred: {e}', file=sys.stderr)
finally:
    # Close the browser
    print('\nClosing browser...')
    driver.quit() 
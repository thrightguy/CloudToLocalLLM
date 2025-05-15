from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.service import Service

# Connect to the Selenium server running in Docker
selenium_url = 'http://localhost:4444/wd/hub'

options = webdriver.ChromeOptions()
options.add_argument('--headless')
options.add_argument('--no-sandbox')
options.add_argument('--disable-dev-shm-usage')
options.add_argument('--ignore-certificate-errors')
options.add_argument('--allow-insecure-localhost')
options.add_argument('--ignore-ssl-errors')

# Use the actual self-serve app URL
app_url = 'https://cloudtolocalllm.online'

# Create a new Chrome session
with webdriver.Remote(
    command_executor=selenium_url,
    options=options
) as driver:
    driver.get(app_url)
    print('Page title is:', driver.title) 
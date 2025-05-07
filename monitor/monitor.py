#!/usr/bin/env python3
import os
import json
import time
import subprocess
import socket
import psutil
from datetime import datetime
from flask import Flask, render_template, jsonify, request, send_from_directory

app = Flask(__name__)

# Store monitoring data
status_data = {
    'services': {},
    'ssl': {},
    'nginx_config': {},
    'system': {},
    'last_check': None
}

def run_command(command):
    """Run shell command and return output"""
    try:
        result = subprocess.run(command, shell=True, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        return True, result.stdout
    except subprocess.CalledProcessError as e:
        return False, f"Error: {e.stderr}"

def check_service(service, host, port, path='/health'):
    """Check if a service is responding to HTTP requests"""
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(2)
        result = sock.connect_ex((host, port))
        sock.close()
        
        if result == 0:
            if path:
                status, output = run_command(f"curl -s -I http://{host}:{port}{path}")
                if status and "200 OK" in output:
                    return True, "Service is healthy (responded with 200 OK)"
                else:
                    return False, f"Service is running but health check failed: {output}"
            return True, "Service is running"
        else:
            return False, f"Service is not running on {host}:{port}"
    except Exception as e:
        return False, f"Error checking service: {str(e)}"

def update_system_stats():
    """Update system statistics"""
    status_data['system'] = {
        'cpu_percent': psutil.cpu_percent(interval=1),
        'memory_percent': psutil.virtual_memory().percent,
        'disk_percent': psutil.disk_usage('/').percent,
        'uptime': int(time.time() - psutil.boot_time())
    }

def load_service_status():
    """Load service status from data file"""
    status_file = '/app/logs/service_status.json'
    if os.path.exists(status_file):
        try:
            with open(status_file, 'r') as f:
                status_data['services'] = json.load(f)
        except Exception as e:
            print(f"Error loading service status: {e}")

def load_ssl_status():
    """Load SSL certificate status from data file"""
    status_file = '/app/logs/ssl_status.json'
    if os.path.exists(status_file):
        try:
            with open(status_file, 'r') as f:
                status_data['ssl'] = json.load(f)
        except Exception as e:
            print(f"Error loading SSL status: {e}")

def load_nginx_config_status():
    """Load Nginx configuration status from data file"""
    status_file = '/app/logs/nginx_config_status.json'
    if os.path.exists(status_file):
        try:
            with open(status_file, 'r') as f:
                status_data['nginx_config'] = json.load(f)
        except Exception as e:
            print(f"Error loading Nginx config status: {e}")

@app.route('/')
def home():
    """Render the main dashboard"""
    update_system_stats()
    load_service_status()
    load_ssl_status()
    load_nginx_config_status()
    status_data['last_check'] = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    
    # Get service status summaries
    services_ok = all(service.get('status', False) for service in status_data['services'].values())
    ssl_ok = status_data['ssl'].get('status', False)
    nginx_ok = status_data['nginx_config'].get('status', False)
    
    # Return JSON if requested
    if request.headers.get('Accept') == 'application/json':
        return jsonify(status_data)
        
    # Otherwise return HTML (you would need to create a template)
    return f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>CloudToLocalLLM Monitoring</title>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
            body {{ font-family: Arial, sans-serif; margin: 0; padding: 20px; }}
            .dashboard {{ max-width: 1200px; margin: 0 auto; }}
            .header {{ background-color: #2c3e50; color: white; padding: 20px; margin-bottom: 20px; border-radius: 5px; }}
            .status-card {{ background-color: white; border-radius: 5px; box-shadow: 0 2px 5px rgba(0,0,0,0.1); padding: 20px; margin-bottom: 20px; }}
            .status-indicator {{ display: inline-block; width: 10px; height: 10px; border-radius: 50%; margin-right: 10px; }}
            .status-ok {{ background-color: #2ecc71; }}
            .status-error {{ background-color: #e74c3c; }}
            .status-warning {{ background-color: #f39c12; }}
            .system-stats {{ display: flex; justify-content: space-between; flex-wrap: wrap; }}
            .stat-box {{ flex: 1; min-width: 200px; margin: 10px; padding: 15px; background-color: #f8f9fa; border-radius: 5px; }}
            .refresh-btn {{ background-color: #3498db; color: white; border: none; padding: 10px 15px; border-radius: 5px; cursor: pointer; }}
            table {{ width: 100%; border-collapse: collapse; }}
            th, td {{ text-align: left; padding: 12px; }}
            th {{ background-color: #f2f2f2; }}
            tr:nth-child(even) {{ background-color: #f9f9f9; }}
        </style>
    </head>
    <body>
        <div class="dashboard">
            <div class="header">
                <h1>CloudToLocalLLM Monitoring Dashboard</h1>
                <p>Last updated: {status_data['last_check']}</p>
                <button class="refresh-btn" onclick="window.location.reload()">Refresh</button>
            </div>
            
            <div class="status-card">
                <h2>System Overview</h2>
                <div class="system-stats">
                    <div class="stat-box">
                        <h3>CPU Usage</h3>
                        <p>{status_data['system'].get('cpu_percent', 'N/A')}%</p>
                    </div>
                    <div class="stat-box">
                        <h3>Memory Usage</h3>
                        <p>{status_data['system'].get('memory_percent', 'N/A')}%</p>
                    </div>
                    <div class="stat-box">
                        <h3>Disk Usage</h3>
                        <p>{status_data['system'].get('disk_percent', 'N/A')}%</p>
                    </div>
                    <div class="stat-box">
                        <h3>Uptime</h3>
                        <p>{int(status_data['system'].get('uptime', 0)/3600)} hours</p>
                    </div>
                </div>
            </div>
            
            <div class="status-card">
                <h2>Service Status</h2>
                <div>
                    <span class="status-indicator {'status-ok' if services_ok else 'status-error'}"></span>
                    <span>{services_ok and 'All services are running' or 'One or more services have issues'}</span>
                </div>
                <table>
                    <tr>
                        <th>Service</th>
                        <th>Status</th>
                        <th>Details</th>
                        <th>Last Check</th>
                    </tr>
                    {''.join([f"<tr><td>{service}</td><td>{'✅' if info.get('status', False) else '❌'}</td><td>{info.get('message', 'N/A')}</td><td>{info.get('timestamp', 'N/A')}</td></tr>" for service, info in status_data['services'].items()])}
                </table>
            </div>
            
            <div class="status-card">
                <h2>SSL Certificate Status</h2>
                <div>
                    <span class="status-indicator {'status-ok' if ssl_ok else 'status-error'}"></span>
                    <span>{ssl_ok and 'SSL certificates are valid' or 'SSL certificate issues detected'}</span>
                </div>
                <table>
                    <tr>
                        <th>Domain</th>
                        <th>Status</th>
                        <th>Expiry</th>
                        <th>Details</th>
                    </tr>
                    {''.join([f"<tr><td>{domain}</td><td>{'✅' if info.get('status', False) else '❌'}</td><td>{info.get('expiry', 'N/A')}</td><td>{info.get('message', 'N/A')}</td></tr>" for domain, info in status_data['ssl'].get('domains', {}).items()])}
                </table>
            </div>
            
            <div class="status-card">
                <h2>Nginx Configuration</h2>
                <div>
                    <span class="status-indicator {'status-ok' if nginx_ok else 'status-error'}"></span>
                    <span>{nginx_ok and 'Nginx configuration is valid' or 'Nginx configuration issues detected'}</span>
                </div>
                <pre>{status_data['nginx_config'].get('message', 'No data available')}</pre>
            </div>
        </div>
    </body>
    </html>
    """

@app.route('/api/status')
def api_status():
    """API endpoint for status data"""
    update_system_stats()
    load_service_status()
    load_ssl_status()
    load_nginx_config_status()
    status_data['last_check'] = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    return jsonify(status_data)

@app.route('/api/check/<service>')
def check_specific_service(service):
    """API endpoint to check a specific service"""
    services = {
        'webapp': ('webapp', 80, '/health'),
        'auth': ('auth', 8080, '/health'),
        'nginx': ('localhost', 80, '/health')
    }
    
    if service in services:
        host, port, path = services[service]
        status, message = check_service(service, host, port, path)
        return jsonify({
            'service': service,
            'status': status,
            'message': message,
            'timestamp': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        })
    else:
        return jsonify({'error': f'Service {service} not recognized'}), 404

if __name__ == '__main__':
    # Create logs directory if it doesn't exist
    os.makedirs('/app/logs', exist_ok=True)
    
    # Run Flask app
    app.run(host='0.0.0.0', port=5000) 
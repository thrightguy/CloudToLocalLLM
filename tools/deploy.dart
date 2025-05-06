// Deploy utility for CloudToLocalLLM
// Usage: dart tools/deploy.dart [command]
// Available commands: deploy, monitor, verify, update

import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:args/args.dart';

const String APP_NAME = 'CloudToLocalLLM';
const String DEFAULT_DOMAIN = 'cloudtolocalllm.online';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addCommand('deploy')
    ..addCommand('monitor')
    ..addCommand('verify')
    ..addCommand('update')
    ..addOption('domain', abbr: 'd', defaultsTo: DEFAULT_DOMAIN, help: 'Domain name to use')
    ..addFlag('beta', abbr: 'b', help: 'Include beta subdomain setup', defaultsTo: false)
    ..addFlag('monitoring', abbr: 'm', help: 'Include monitoring setup', defaultsTo: false)
    ..addFlag('help', abbr: 'h', help: 'Show this help message', negatable: false);

  try {
    final args = parser.parse(arguments);
    
    if (args['help']) {
      printHelp(parser);
      return;
    }

    if (args.command == null) {
      print('No command specified.');
      printHelp(parser);
      return;
    }

    final command = args.command!;
    final domain = args['domain'] as String;
    final includeBeta = args['beta'] as bool;
    final includeMonitoring = args['monitoring'] as bool;

    switch (command.name) {
      case 'deploy':
        await deploy(domain, includeBeta, includeMonitoring);
        break;
      case 'monitor':
        await setupMonitoring(domain);
        break;
      case 'verify':
        await verifyDeployment(domain, includeBeta);
        break;
      case 'update':
        await updateDeployment(domain);
        break;
      default:
        print('Unknown command: ${command.name}');
        printHelp(parser);
    }
  } catch (e) {
    print('Error: $e');
    printHelp(parser);
    exit(1);
  }
}

void printHelp(ArgParser parser) {
  print('Flutter $APP_NAME Deployment Tool');
  print('Usage: dart tools/deploy.dart [command] [options]');
  print('');
  print('Commands:');
  print('  deploy     Deploy the application to a server');
  print('  monitor    Set up monitoring for an existing deployment');
  print('  verify     Verify a deployment is working correctly');
  print('  update     Update an existing deployment');
  print('');
  print('Options:');
  print(parser.usage);
}

Future<void> deploy(String domain, bool includeBeta, bool includeMonitoring) async {
  print('Deploying $APP_NAME to $domain...');
  
  // Pull latest changes
  await gitPull();
  
  // Setup SSL certificates
  await setupSSL(domain, includeBeta);
  
  // Generate server configuration
  await generateServerConfig(domain, includeBeta, includeMonitoring);
  
  // Deploy with docker-compose
  final composeFile = includeMonitoring ? 'docker-compose.monitoring.yml' : 'docker-compose.web.yml';
  await runCommand('docker-compose', ['-f', composeFile, 'build']);
  await runCommand('docker-compose', ['-f', composeFile, 'up', '-d']);
  
  print('Deployment completed successfully!');
  print('Website is available at: https://$domain');
  if (includeBeta) {
    print('Beta site is available at: https://beta.$domain');
  }
  if (includeMonitoring) {
    print('Monitoring is available at: https://$domain/monitor/');
    print('Monitoring credentials: admin / cloudtolocalllm');
  }
}

Future<void> setupMonitoring(String domain) async {
  print('Setting up monitoring for $domain...');
  
  // Create htpasswd file
  await createHtpasswd();
  
  // Update server configuration for monitoring
  await updateServerConfigForMonitoring(domain);
  
  // Deploy netdata with docker-compose
  await runCommand('docker-compose', ['-f', 'docker-compose.monitor.yml', 'up', '-d']);
  
  print('Monitoring setup completed!');
  print('Monitoring dashboard is available at: https://$domain/monitor/');
  print('Monitoring credentials: admin / cloudtolocalllm');
}

Future<void> verifyDeployment(String domain, bool includeBeta) async {
  print('Verifying deployment on $domain...');
  
  // Check containers are running
  final result = await runCommand('docker', ['ps', '--format', '{{.Names}}'], true);
  
  if (result.contains('webapp')) {
    print('✓ Web application container is running');
  } else {
    print('✗ Web application container is not running');
  }
  
  if (includeBeta && result.contains('auth')) {
    print('✓ Auth service container is running');
  } else if (includeBeta) {
    print('✗ Auth service container is not running');
  }
  
  if (result.contains('cloudtolocalllm_monitor')) {
    print('✓ Monitoring container is running');
  }
  
  // Check SSL certificates
  await runCommand('docker', ['run', '--rm', '-v', '$(pwd)/certbot/conf:/etc/letsencrypt', 
      'certbot/certbot', 'certificates']);
  
  print('Verification completed!');
}

Future<void> updateDeployment(String domain) async {
  print('Updating deployment on $domain...');
  
  // Pull latest changes
  await gitPull();
  
  // Restart containers
  await runCommand('docker-compose', ['-f', 'docker-compose.web.yml', 'down']);
  await runCommand('docker-compose', ['-f', 'docker-compose.web.yml', 'build']);
  await runCommand('docker-compose', ['-f', 'docker-compose.web.yml', 'up', '-d']);
  
  print('Update completed!');
}

Future<void> gitPull() async {
  print('Pulling latest changes from Git...');
  
  if (await Directory('.git').exists()) {
    await runCommand('git', ['stash']);
    await runCommand('git', ['pull']);
    await runCommand('chmod', ['+x', '*.sh']);
  } else {
    print('Not a Git repository, skipping pull.');
  }
}

Future<void> setupSSL(String domain, bool includeBeta) async {
  print('Setting up SSL certificates...');
  
  final domains = [domain, 'www.$domain'];
  if (includeBeta) {
    domains.add('beta.$domain');
  }
  
  // Create certbot directories
  await Directory('certbot/conf').create(recursive: true);
  await Directory('certbot/www').create(recursive: true);
  
  // Get SSL certificates
  final args = [
    'run', '--rm', '-p', '80:80', '-p', '443:443',
    '-v', '$(pwd)/certbot/conf:/etc/letsencrypt',
    '-v', '$(pwd)/certbot/www:/var/www/certbot',
    'certbot/certbot', 'certonly', '--standalone',
    '--agree-tos', '--no-eff-email',
    '--email', 'admin@$domain'
  ];
  
  for (final d in domains) {
    args.addAll(['-d', d]);
  }
  
  await runCommand('docker', args);
}

Future<void> generateServerConfig(String domain, bool includeBeta, bool includeMonitoring) async {
  print('Generating server configuration...');
  
  final subdomains = includeBeta ? ' beta.$domain' : '';
  
  String config = '''
server {
    listen 80;
    server_name $domain www.$domain$subdomains;
    return 301 https://\$server_name\$request_uri;
}

# Main domain and www subdomain
server {
    listen 443 ssl http2;
    server_name $domain www.$domain;

    # SSL configuration
    ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    root /usr/share/nginx/html;
    index index.html;

    # Health check endpoint
    location = /health {
        return 200 'OK';
        add_header Content-Type text/plain;
    }
''';

  // Add monitoring location if requested
  if (includeMonitoring) {
    config += '''

    # Netdata monitoring dashboard
    location /monitor/ {
        proxy_pass http://netdata:19999/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # Basic authentication
        auth_basic "Monitoring Area";
        auth_basic_user_file /etc/nginx/.htpasswd;
    }
''';
  }

  config += '''

    # Handle SPA routing
    location / {
        try_files \$uri \$uri/ /index.html;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }

    # Proxy cloud service
    location /cloud/ {
        set \$upstream_cloud http://cloud:3456;
        proxy_pass \$upstream_cloud/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Static files caching
    location ~* \\.(jpg|jpeg|png|gif|ico|css|js)$ {
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }
}
''';

  // Add beta subdomain server block if requested
  if (includeBeta) {
    config += '''

# Beta subdomain with auth
server {
    listen 443 ssl http2;
    server_name beta.$domain;

    # SSL configuration
    ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    root /usr/share/nginx/html;
    index index.html;

    # Health check endpoint
    location = /health {
        set \$upstream_auth http://auth:8080;
        proxy_pass \$upstream_auth/health;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Handle SPA routing
    location / {
        try_files \$uri \$uri/ /index.html;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }

    # Proxy auth service
    location /auth/ {
        set \$upstream_auth http://auth:8080;
        proxy_pass \$upstream_auth/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Static files caching
    location ~* \\.(jpg|jpeg|png|gif|ico|css|js)$ {
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }
}
''';
  }

  await File('server.conf').writeAsString(config);
  print('Server configuration generated: server.conf');
}

Future<void> createHtpasswd() async {
  // Simple encoded password for example purposes
  // This is "admin:cloudtolocalllm" in htpasswd format
  await File('.htpasswd').writeAsString('admin:\$apr1\$zrXoWCvp\$AuERJYPWY9SAkmS22S6.I1');
  print('Created .htpasswd file with default credentials:');
  print('Username: admin');
  print('Password: cloudtolocalllm');
}

Future<void> updateServerConfigForMonitoring(String domain) async {
  // Check if server.conf exists
  final serverConf = File('server.conf');
  if (!await serverConf.exists()) {
    print('Error: server.conf not found! Run deploy first to create it.');
    exit(1);
  }
  
  // Create backup
  await serverConf.copy('server.conf.bak');
  
  // Read server.conf
  final content = await serverConf.readAsString();
  
  // Check if monitoring location already exists
  if (content.contains('location /monitor/')) {
    print('Monitoring configuration already exists in server.conf');
    return;
  }
  
  // Add monitoring location
  final updatedContent = content.replaceFirst(
    RegExp(r'# Health check endpoint.*?}', dotAll: true),
    '''# Health check endpoint
    location = /health {
        return 200 'OK';
        add_header Content-Type text/plain;
    }
    
    # Netdata monitoring dashboard
    location /monitor/ {
        proxy_pass http://netdata:19999/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # Basic authentication
        auth_basic "Monitoring Area";
        auth_basic_user_file /etc/nginx/.htpasswd;
    }'''
  );
  
  await serverConf.writeAsString(updatedContent);
  print('Added monitoring location to server.conf');
}

Future<String> runCommand(String command, List<String> arguments, [bool getOutput = false]) async {
  print('\$ $command ${arguments.join(' ')}');
  
  final result = await Process.run(command, arguments);
  
  if (result.stdout.toString().isNotEmpty) {
    print(result.stdout);
  }
  
  if (result.stderr.toString().isNotEmpty) {
    print(result.stderr);
  }
  
  if (result.exitCode != 0) {
    throw 'Command failed with exit code ${result.exitCode}';
  }
  
  if (getOutput) {
    return result.stdout.toString();
  }
  
  return '';
} 
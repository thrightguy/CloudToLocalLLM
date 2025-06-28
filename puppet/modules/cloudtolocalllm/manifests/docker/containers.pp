# CloudToLocalLLM Docker Container Management
# LIMITATION: Static container model conflicts with dynamic multi-tenant requirements

class cloudtolocalllm::docker::containers (
  String $version = $cloudtolocalllm_version,
  String $project_dir = '/opt/cloudtolocalllm',
) {

  # Basic Docker installation
  include docker

  # LIMITATION: Static image management only
  docker::image { 'cloudtolocalllm-webapp':
    ensure      => present,
    image_tag   => $version,
    docker_file => "${project_dir}/config/docker/Dockerfile.web",
    require     => Class['docker'],
  }

  docker::image { 'cloudtolocalllm-api-backend':
    ensure      => present,
    image_tag   => $version,
    docker_file => "${project_dir}/config/docker/Dockerfile.api-backend",
    require     => Class['docker'],
  }

  docker::image { 'cloudtolocalllm-streaming-proxy':
    ensure      => present,
    image_tag   => $version,
    docker_file => "${project_dir}/streaming-proxy/Dockerfile",
    require     => Class['docker'],
  }

  # MAJOR LIMITATION: Static container configuration
  # Cannot handle dynamic per-user streaming proxies
  
  docker::run { 'cloudtolocalllm-webapp':
    image   => "cloudtolocalllm-webapp:${version}",
    ports   => ['80:80', '443:443'],
    volumes => [
      "${project_dir}/ssl:/etc/nginx/ssl:ro",
      "${project_dir}/certbot/live/cloudtolocalllm.online:/etc/letsencrypt/live/cloudtolocalllm.online:ro",
    ],
    restart => 'unless-stopped',
    require => Docker::Image['cloudtolocalllm-webapp'],
  }

  docker::run { 'cloudtolocalllm-api-backend':
    image => "cloudtolocalllm-api-backend:${version}",
    ports => ['8080:8080'],
    env   => [
      'NODE_ENV=production',
      'AUTH0_DOMAIN=dev-xafu7oedkd5wlrbo.us.auth0.com',
      'AUTH0_AUDIENCE=https://cloudtolocalllm.online',
    ],
    volumes => ['/var/run/docker.sock:/var/run/docker.sock:ro'],
    restart => 'unless-stopped',
    require => Docker::Image['cloudtolocalllm-api-backend'],
  }

  # CRITICAL PROBLEM: Cannot handle dynamic streaming proxy creation
  # The multi-tenant architecture requires per-user containers with:
  # - Dynamic SHA256-based network names
  # - Per-user resource limits
  # - Automatic cleanup after inactivity
  # - JWT-based authentication per session
  
  # STATIC EXAMPLE (doesn't meet requirements):
  docker::run { 'cloudtolocalllm-streaming-proxy-static':
    image  => "cloudtolocalllm-streaming-proxy:${version}",
    ports  => ['8081:8080'],
    memory => '512m',
    cpus   => '0.5',
    env    => [
      'NODE_ENV=production',
      'LOG_LEVEL=info',
    ],
    user    => 'proxyuser',
    restart => 'unless-stopped',
    require => Docker::Image['cloudtolocalllm-streaming-proxy'],
  }

  # MISSING CAPABILITIES:
  # 1. Dynamic container creation per user
  # 2. SHA256-based network isolation
  # 3. Automatic cleanup after 10-minute inactivity
  # 4. JWT validation per session
  # 5. Resource limit enforcement per container
  # 6. Container lifecycle management based on user activity
  
  # WORKAROUND ATTEMPT (still inadequate):
  # Would require external scripts and complex exec resources
  exec { 'manage_dynamic_proxies':
    command => "${project_dir}/scripts/manage_streaming_proxies.sh",
    path    => $facts['path'],
    # PROBLEMS:
    # 1. Runs on Puppet schedule, not on-demand
    # 2. No integration with authentication system
    # 3. No real-time user activity monitoring
    # 4. Cannot handle rapid container creation/destruction
  }

  # FUNDAMENTAL ISSUES:
  # 1. Static resource model: Puppet defines fixed resources, not dynamic ones
  # 2. No event-driven architecture: Cannot respond to user authentication events
  # 3. Limited container orchestration: Basic Docker module functionality only
  # 4. No real-time management: Puppet runs on schedule, not on-demand
  # 5. Complex multi-tenant requirements: Beyond Puppet's design scope
}

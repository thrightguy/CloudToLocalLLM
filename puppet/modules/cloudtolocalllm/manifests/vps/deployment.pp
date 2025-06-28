# CloudToLocalLLM VPS Deployment Module
# LIMITATION: Pull-based model conflicts with push-based deployment needs

class cloudtolocalllm::vps::deployment (
  String $project_dir = '/opt/cloudtolocalllm',
  String $version = $cloudtolocalllm_version,
  String $vps_user = 'cloudllm',
  String $vps_host = 'cloudtolocalllm.online',
) {

  # FUNDAMENTAL PROBLEM: Puppet agent must be running on VPS
  # This conflicts with the current SSH-based deployment model

  # Basic directory structure
  file { $project_dir:
    ensure => directory,
    owner  => $vps_user,
    group  => $vps_user,
    mode   => '0755',
  }

  file { "${project_dir}/backups":
    ensure  => directory,
    owner   => $vps_user,
    group   => $vps_user,
    mode    => '0755',
    require => File[$project_dir],
  }

  # MAJOR LIMITATION: No way to coordinate with build completion
  # Puppet runs on schedule, not triggered by build completion
  
  # Git repository management (basic)
  vcsrepo { $project_dir:
    ensure   => present,
    provider => git,
    source   => 'https://github.com/imrightguy/CloudToLocalLLM.git',
    revision => 'master',
    owner    => $vps_user,
    group    => $vps_user,
    require  => File[$project_dir],
  }

  # ANTI-PATTERN: Using exec for deployment tasks
  exec { 'flutter_build_web':
    command => 'flutter build web --release --no-tree-shake-icons',
    cwd     => $project_dir,
    path    => $facts['path'],
    user    => $vps_user,
    require => Vcsrepo[$project_dir],
    # PROBLEM: No way to trigger this only when needed
  }

  # LIMITATION: Static Docker Compose management
  file { "${project_dir}/docker-compose.yml":
    ensure  => file,
    source  => 'puppet:///modules/cloudtolocalllm/docker-compose.yml',
    owner   => $vps_user,
    group   => $vps_user,
    mode    => '0644',
    require => Vcsrepo[$project_dir],
    notify  => Exec['restart_containers'],
  }

  # ANTI-PATTERN: Container management via exec
  exec { 'restart_containers':
    command     => 'docker compose down && docker compose up -d --build',
    cwd         => $project_dir,
    path        => $facts['path'],
    user        => $vps_user,
    refreshonly => true,
    timeout     => 600,
    # PROBLEMS:
    # 1. No health checks
    # 2. No rollback on failure
    # 3. No backup before deployment
    # 4. No coordination with build pipeline
  }

  # CRITICAL LIMITATIONS:
  # 1. Pull-based model: VPS pulls config instead of receiving deployment
  # 2. Timing issues: Can't coordinate with build completion
  # 3. No deployment pipeline: Each Puppet run is independent
  # 4. Limited error handling: Basic exec resource error handling only
  # 5. No backup/restore: Would require complex exec resources
  # 6. No health verification: Limited monitoring capabilities
  # 7. Agent dependency: Requires Puppet agent on VPS
}

# CloudToLocalLLM Puppet Site Manifest
# WARNING: This architecture demonstrates Puppet's limitations for CI/CD workflows

# Node classification for different environments
node 'build-windows' {
  include cloudtolocalllm::build::windows
  include cloudtolocalllm::version_manager
}

node 'build-linux' {
  include cloudtolocalllm::build::linux
  include cloudtolocalllm::version_manager
}

node 'cloudtolocalllm.online' {
  include cloudtolocalllm::vps::deployment
  include cloudtolocalllm::docker::containers
}

# Default node configuration
node default {
  # Determine role based on facts
  case $facts['kernel'] {
    'windows': {
      include cloudtolocalllm::build::windows
    }
    'Linux': {
      if $facts['wsl_distro_name'] {
        include cloudtolocalllm::build::wsl
      } else {
        include cloudtolocalllm::build::linux
      }
    }
    default: {
      fail("Unsupported operating system: ${facts['kernel']}")
    }
  }
}

# Global variables - NOTE: These are static, major limitation for dynamic versioning
$cloudtolocalllm_version = '3.6.4'  # STATIC - Cannot be dynamic in Puppet
$build_timestamp = '202501271430'   # STATIC - Cannot generate dynamically
$project_root = $facts['kernel'] ? {
  'windows' => 'C:\Users\chris\Dev\CloudToLocalLLM',
  default   => '/opt/cloudtolocalllm'
}

# Resource ordering for build pipeline
# NOTE: This is a workaround - Puppet isn't designed for sequential workflows
Class['cloudtolocalllm::version_manager'] ->
Class['cloudtolocalllm::build::flutter'] ->
Class['cloudtolocalllm::build::packages'] ->
Class['cloudtolocalllm::github::release'] ->
Class['cloudtolocalllm::vps::deployment']

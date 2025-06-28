# CloudToLocalLLM Version Management Module
# CRITICAL LIMITATION: Puppet cannot generate dynamic timestamps or increment versions

class cloudtolocalllm::version_manager (
  String $version = $cloudtolocalllm_version,
  String $build_number = $build_timestamp,
  String $project_root = $project_root,
) {

  # MAJOR LIMITATION: Static version management only
  # Puppet cannot dynamically increment versions or generate timestamps
  
  # Update pubspec.yaml
  file_line { 'pubspec_version':
    path  => "${project_root}/pubspec.yaml",
    line  => "version: ${version}+${build_number}",
    match => '^version:',
  }

  # Update version.json
  file { "${project_root}/assets/version.json":
    ensure  => file,
    content => epp('cloudtolocalllm/version.json.epp', {
      'version'      => $version,
      'build_number' => $build_number,
      'build_date'   => $facts['timestamp'],  # Limited to Puppet run time
    }),
    require => File_line['pubspec_version'],
  }

  # Update version.dart
  file_line { 'version_dart':
    path  => "${project_root}/lib/shared/lib/version.dart",
    line  => "const String appVersion = \"${version}\";",
    match => 'const String appVersion',
  }

  # Update app_config.dart
  file_line { 'app_config_version':
    path  => "${project_root}/lib/config/app_config.dart",
    line  => "  static const String version = \"${version}\";",
    match => 'static const String version',
  }

  # WORKAROUND: Use exec for dynamic version increment (ANTI-PATTERN)
  # This defeats the purpose of using Puppet
  exec { 'increment_version':
    command => $facts['kernel'] ? {
      'windows' => "powershell.exe -Command \"& '${project_root}/scripts/powershell/version_manager.ps1' increment minor\"",
      default   => "${project_root}/scripts/version_manager.sh increment minor",
    },
    onlyif  => $facts['kernel'] ? {
      'windows' => "powershell.exe -Command \"Test-Path '${project_root}/scripts/powershell/version_manager.ps1'\"",
      default   => "test -f '${project_root}/scripts/version_manager.sh'",
    },
    # This exec would run every time, making it non-idempotent
    refreshonly => false,
  }

  # Validation - limited compared to script-based approach
  exec { 'validate_version_consistency':
    command => $facts['kernel'] ? {
      'windows' => 'powershell.exe -Command "Write-Host \'Version validation not implemented\'"',
      default   => 'echo "Version validation not implemented"',
    },
    require => [
      File_line['pubspec_version'],
      File["${project_root}/assets/version.json"],
      File_line['version_dart'],
      File_line['app_config_version'],
    ],
  }
}

# CloudToLocalLLM Multi-Platform Ansible Architecture

## Overview

This document describes how the CloudToLocalLLM Ansible automation handles the complex multi-platform requirements including Windows PowerShell, WSL Ubuntu, and remote VPS deployment within a unified automation framework.

## Platform Architecture

### Supported Platforms

1. **Windows Native**: Direct Windows PowerShell execution
2. **WSL Ubuntu**: Windows Subsystem for Linux with Ubuntu distribution
3. **Linux Native**: Direct Linux execution (development/CI environments)
4. **Remote VPS**: SSH-based deployment to cloudllm@app.cloudtolocalllm.online

### Platform Detection Strategy

```yaml
# Automatic platform detection
- name: Detect execution environment
  set_fact:
    execution_platform: >-
      {%- if ansible_os_family == "Windows" -%}
      windows_native
      {%- elif ansible_env.WSL_DISTRO_NAME is defined -%}
      wsl_ubuntu
      {%- elif ansible_system == "Linux" -%}
      linux_native
      {%- else -%}
      unknown
      {%- endif -%}

- name: Set platform-specific variables
  include_vars: "platforms/{{ execution_platform }}.yml"
```

## Windows PowerShell Integration

### Native Windows Execution

**Use Cases:**
- Flutter Windows desktop builds
- Windows-specific package creation
- Local development on Windows machines

**Implementation:**
```yaml
- name: Build Flutter Windows application
  win_shell: |
    cd "{{ project_root }}"
    flutter clean
    flutter pub get
    flutter build windows --release
  register: windows_build_result
  when: execution_platform == "windows_native"
```

**Advantages:**
- Direct access to Windows APIs
- Native PowerShell module support
- Optimal performance for Windows builds
- Full Windows toolchain integration

**Considerations:**
- Requires Ansible for Windows setup
- PowerShell execution policy configuration
- Windows-specific error handling

### PowerShell Module Integration

```yaml
- name: Use PowerShell modules for Windows operations
  win_powershell:
    script: |
      Import-Module BuildEnvironmentUtilities
      Test-BuildDependencies -AutoInstall:${{ auto_install }}
    parameters:
      auto_install: "{{ auto_install | default(false) }}"
  when: ansible_os_family == "Windows"
```

## WSL Ubuntu Integration

### WSL Detection and Configuration

**WSL Environment Setup:**
```yaml
- name: Configure WSL environment
  block:
    - name: Detect WSL distribution
      shell: echo $WSL_DISTRO_NAME
      register: wsl_distro
      changed_when: false
    
    - name: Set WSL facts
      set_fact:
        wsl_distro_name: "{{ wsl_distro.stdout }}"
        wsl_project_path: "{{ ansible_env.PWD }}"
        windows_project_path: "{{ ansible_env.PWD | regex_replace('/mnt/([a-z])/', '\\1:/') }}"
  when: ansible_env.WSL_DISTRO_NAME is defined
```

### Cross-Platform Build Coordination

**Windows-Linux Build Bridge:**
```yaml
- name: Build Windows packages from WSL
  shell: |
    # Execute PowerShell commands from WSL
    powershell.exe -Command "
      cd '{{ windows_project_path }}'
      flutter build windows --release
    "
  register: wsl_windows_build
  when: execution_platform == "wsl_ubuntu"

- name: Build Linux packages in WSL
  shell: |
    cd "{{ wsl_project_path }}"
    flutter build linux --release
  register: wsl_linux_build
  when: execution_platform == "wsl_ubuntu"
```

### WSL-Specific Optimizations

**File System Handling:**
```yaml
- name: Handle WSL file system performance
  block:
    - name: Use Windows file system for Flutter builds
      set_fact:
        flutter_build_path: "{{ windows_project_path }}"
      when: build_target == "windows"
    
    - name: Use Linux file system for Linux builds
      set_fact:
        flutter_build_path: "{{ wsl_project_path }}"
      when: build_target == "linux"
```

## Remote VPS Deployment

### SSH Connection Management

**VPS Connection Configuration:**
```yaml
- name: Configure VPS connection
  add_host:
    name: cloudtolocalllm_vps
    ansible_host: app.cloudtolocalllm.online
    ansible_user: cloudllm
    ansible_ssh_private_key_file: "{{ ssh_key_path }}"
    ansible_ssh_common_args: "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
```

**Connection Testing:**
```yaml
- name: Test VPS connectivity
  ping:
  delegate_to: cloudtolocalllm_vps
  register: vps_connectivity
  retries: 3
  delay: 5
```

### Remote Execution Strategy

**Deployment Tasks:**
```yaml
- name: Deploy to VPS with error handling
  block:
    - name: Sync files to VPS
      synchronize:
        src: "{{ project_root }}/build/web/"
        dest: "{{ vps.project_dir }}/webapp/"
        delete: true
        rsync_opts:
          - "--exclude=.git"
          - "--exclude=node_modules"
      delegate_to: cloudtolocalllm_vps
    
    - name: Execute deployment commands
      shell: |
        cd "{{ vps.project_dir }}"
        docker compose down
        docker compose up -d --build
      delegate_to: cloudtolocalllm_vps
      register: vps_deployment
  rescue:
    - name: Handle deployment failure
      include_tasks: tasks/vps-rollback.yml
```

## Platform-Specific Task Organization

### Directory Structure

```
ansible/
├── playbooks/
│   ├── tasks/
│   │   ├── windows/
│   │   │   ├── build-flutter.yml
│   │   │   ├── create-zip.yml
│   │   │   └── install-deps.yml
│   │   ├── linux/
│   │   │   ├── build-aur.yml
│   │   │   ├── build-appimage.yml
│   │   │   └── build-deb.yml
│   │   ├── wsl/
│   │   │   ├── cross-platform.yml
│   │   │   └── file-sync.yml
│   │   └── vps/
│   │       ├── deploy.yml
│   │       ├── backup.yml
│   │       └── verify.yml
│   └── platforms/
│       ├── windows_native.yml
│       ├── wsl_ubuntu.yml
│       ├── linux_native.yml
│       └── vps_remote.yml
```

### Platform-Specific Variables

**Windows Native (`platforms/windows_native.yml`):**
```yaml
flutter_command: flutter.bat
build_output_dir: build\windows\x64\release\runner
package_extension: .zip
shell_type: powershell
path_separator: \
```

**WSL Ubuntu (`platforms/wsl_ubuntu.yml`):**
```yaml
flutter_command: flutter
build_output_dir: build/linux/x64/release/bundle
package_extension: .tar.gz
shell_type: bash
path_separator: /
windows_interop: true
```

**VPS Remote (`platforms/vps_remote.yml`):**
```yaml
deployment_method: ssh
docker_compose_file: docker-compose.multi.yml
backup_retention: 7
health_check_timeout: 60
```

## Conditional Task Execution

### Platform-Specific Task Selection

```yaml
- name: Execute platform-specific builds
  include_tasks: "tasks/{{ execution_platform }}/{{ item }}.yml"
  loop:
    - prepare-environment
    - build-application
    - create-packages
    - verify-output
  when: item in platform_capabilities[execution_platform]
```

### Cross-Platform Compatibility

```yaml
- name: Ensure cross-platform compatibility
  block:
    - name: Normalize file paths
      set_fact:
        normalized_path: "{{ file_path | regex_replace('\\\\', '/') }}"
      when: ansible_os_family == "Windows"
    
    - name: Handle line endings
      replace:
        path: "{{ item }}"
        regexp: '\r\n'
        replace: '\n'
      loop: "{{ text_files }}"
      when: execution_platform in ["wsl_ubuntu", "linux_native"]
```

## Error Handling and Fallbacks

### Platform-Specific Error Recovery

```yaml
- name: Handle platform-specific failures
  block:
    - name: Primary build method
      include_tasks: "tasks/{{ execution_platform }}/build.yml"
  rescue:
    - name: Fallback to alternative method
      include_tasks: "tasks/{{ execution_platform }}/build-fallback.yml"
      when: fallback_methods[execution_platform] is defined
    
    - name: Cross-platform fallback
      include_tasks: "tasks/universal/build-basic.yml"
      when: fallback_methods[execution_platform] is not defined
```

### Environment Validation

```yaml
- name: Validate platform requirements
  assert:
    that:
      - flutter_command is defined
      - build_output_dir is defined
      - required_tools | difference(available_tools) | length == 0
    fail_msg: "Platform {{ execution_platform }} missing required tools: {{ required_tools | difference(available_tools) }}"
```

## Performance Optimizations

### Platform-Specific Optimizations

**Windows Optimizations:**
```yaml
- name: Windows-specific optimizations
  block:
    - name: Use Windows file system for builds
      set_fact:
        build_cache_dir: "C:\\temp\\flutter_cache"
    
    - name: Enable Windows Defender exclusions
      win_shell: |
        Add-MpPreference -ExclusionPath "{{ project_root }}"
      ignore_errors: true
  when: execution_platform == "windows_native"
```

**WSL Optimizations:**
```yaml
- name: WSL-specific optimizations
  block:
    - name: Use Windows file system for performance
      set_fact:
        flutter_cache_dir: "/mnt/c/temp/flutter_cache"
    
    - name: Configure WSL memory limits
      lineinfile:
        path: /etc/wsl.conf
        line: "memory=8GB"
        create: true
      become: true
  when: execution_platform == "wsl_ubuntu"
```

## Security Considerations

### Platform-Specific Security

**Windows Security:**
```yaml
- name: Configure Windows security
  block:
    - name: Set execution policy
      win_shell: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
    
    - name: Validate code signing
      win_shell: Get-AuthenticodeSignature "{{ item }}"
      loop: "{{ executable_files }}"
      register: signature_check
```

**VPS Security:**
```yaml
- name: Configure VPS security
  block:
    - name: Use SSH key authentication only
      lineinfile:
        path: /etc/ssh/sshd_config
        line: "PasswordAuthentication no"
      become: true
      delegate_to: cloudtolocalllm_vps
    
    - name: Configure container security
      docker_container:
        name: "{{ item }}"
        security_opts:
          - no-new-privileges:true
        cap_drop:
          - ALL
      loop: "{{ container_names }}"
      delegate_to: cloudtolocalllm_vps
```

## Monitoring and Logging

### Platform-Specific Monitoring

```yaml
- name: Configure platform monitoring
  block:
    - name: Windows performance counters
      win_shell: |
        Get-Counter "\Process(flutter)\% Processor Time"
      register: windows_perf
      when: execution_platform == "windows_native"
    
    - name: Linux system metrics
      shell: |
        ps aux | grep flutter
        df -h
      register: linux_metrics
      when: execution_platform in ["wsl_ubuntu", "linux_native"]
    
    - name: VPS container metrics
      shell: |
        docker stats --no-stream
      register: vps_metrics
      delegate_to: cloudtolocalllm_vps
      when: execution_platform == "vps_remote"
```

## Conclusion

The multi-platform Ansible architecture provides a unified automation framework that seamlessly handles the complex requirements of Windows PowerShell, WSL Ubuntu, and remote VPS deployment. Through intelligent platform detection, conditional task execution, and platform-specific optimizations, the system maintains the flexibility and power of the original script-based approach while providing the benefits of centralized automation and consistent error handling.

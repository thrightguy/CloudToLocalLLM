# CloudToLocalLLM Administrator Installer

## About This Installer

This special version of the CloudToLocalLLM installer is designed for system administrators and IT departments. It requires administrator privileges and installs the application for all users on the system.

## Key Features

- **Administrator Privileges Required**: The installer will only run with administrator rights
- **All-Users Installation**: Application is installed for all users on the system
- **System-Wide Configuration**: Registry settings are stored in HKEY_LOCAL_MACHINE for global access
- **No Current-User Option**: The installer does not allow installation for the current user only
- **UAC Compatible**: Proper handling of Windows User Account Control
- **Consistent Experience**: All users on the system will have the same application settings

## Installation Requirements

- Windows 10/11 (64-bit)
- Administrator access to the computer
- 8GB RAM minimum (16GB recommended)
- 1GB free disk space for application
- Internet connection for license verification and model downloads

## Installation Instructions

1. Right-click the installer and select "Run as administrator"
2. Follow the prompts in the installation wizard
3. Select your preferred LLM provider (Ollama, existing Ollama, or LM Studio)
4. Complete the installation

## For IT Administrators

The installer can be run silently with the following command line parameters:

```
CloudToLocalLLM-Admin.exe /SILENT /SUPPRESSMSGBOXES
```

Additional parameters:

- `/DIR="x:\dirname"` - Override the default installation directory
- `/LOG="filename"` - Create a log file of the installation process
- `/NOICONS` - Do not create desktop or start menu icons

## Differences from Standard Installer

The standard CloudToLocalLLM installer allows installation for the current user only, which doesn't require administrator privileges. This admin installer offers the following advantages:

1. **Centralized Management**: All application settings and configurations are stored centrally
2. **Simplified Deployment**: Deploy once for all users on a computer
3. **Consistent Experience**: All users have the same application configuration

## Support

If you encounter any issues with this installer, please contact our support team at support@cloudtolocalllm.online or create an issue on our GitHub repository. 
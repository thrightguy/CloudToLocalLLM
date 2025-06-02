#!/usr/bin/env python3
"""
Build script for CloudToLocalLLM Tray Daemon

Creates standalone executables for all platforms using PyInstaller.
Supports cross-platform builds and CI/CD integration.
"""

import os
import sys
import subprocess
import platform
import shutil
from pathlib import Path


def get_platform_info():
    """Get current platform information"""
    system = platform.system().lower()
    machine = platform.machine().lower()
    
    if system == "windows":
        return "windows", "x64" if machine in ["amd64", "x86_64"] else "x86"
    elif system == "darwin":
        return "macos", "arm64" if machine == "arm64" else "x64"
    elif system == "linux":
        return "linux", "x64" if machine in ["amd64", "x86_64"] else machine
    else:
        return system, machine


def install_dependencies():
    """Install required dependencies"""
    print("Installing dependencies...")
    subprocess.check_call([
        sys.executable, "-m", "pip", "install", "-r", "requirements.txt"
    ])
    subprocess.check_call([
        sys.executable, "-m", "pip", "install", "pyinstaller"
    ])


def build_executable():
    """Build the executable using PyInstaller"""
    platform_name, arch = get_platform_info()
    
    # Output directory
    dist_dir = Path("dist") / f"{platform_name}-{arch}"
    dist_dir.mkdir(parents=True, exist_ok=True)
    
    # Executable name
    exe_name = "cloudtolocalllm-tray"
    if platform_name == "windows":
        exe_name += ".exe"
    
    # PyInstaller arguments
    args = [
        "pyinstaller",
        "--onefile",
        "--windowed" if platform_name != "linux" else "--console",
        "--name", exe_name.replace(".exe", ""),
        "--distpath", str(dist_dir),
        "--workpath", "build",
        "--specpath", "build",
        "--clean",
        "tray_daemon.py"
    ]
    
    # Add platform-specific options
    if platform_name == "windows":
        args.extend([
            "--add-data", "requirements.txt;.",
            "--hidden-import", "pystray._win32",
            "--hidden-import", "PIL._tkinter_finder"
        ])
    elif platform_name == "macos":
        args.extend([
            "--add-data", "requirements.txt:.",
            "--hidden-import", "pystray._darwin",
            "--osx-bundle-identifier", "com.cloudtolocalllm.tray"
        ])
    else:  # Linux
        args.extend([
            "--add-data", "requirements.txt:.",
            "--hidden-import", "pystray._xorg"
        ])
    
    print(f"Building executable for {platform_name}-{arch}...")
    print(f"Command: {' '.join(args)}")
    
    try:
        subprocess.check_call(args)
        
        # Verify the executable was created
        exe_path = dist_dir / exe_name
        if exe_path.exists():
            print(f"✓ Successfully built: {exe_path}")
            print(f"  Size: {exe_path.stat().st_size / 1024 / 1024:.1f} MB")
            return str(exe_path)
        else:
            print(f"✗ Executable not found at expected path: {exe_path}")
            return None
    except subprocess.CalledProcessError as e:
        print(f"✗ Build failed: {e}")
        return None


def test_executable(exe_path):
    """Test the built executable"""
    if not exe_path or not Path(exe_path).exists():
        print("✗ Cannot test: executable not found")
        return False
    
    print(f"Testing executable: {exe_path}")
    
    try:
        # Test version flag
        result = subprocess.run([exe_path, "--version"], 
                              capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            print(f"✓ Version test passed: {result.stdout.strip()}")
        else:
            print(f"✗ Version test failed: {result.stderr}")
            return False
        
        # Test help flag
        result = subprocess.run([exe_path, "--help"], 
                              capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            print("✓ Help test passed")
        else:
            print(f"✗ Help test failed: {result.stderr}")
            return False
        
        return True
    except subprocess.TimeoutExpired:
        print("✗ Test timed out")
        return False
    except Exception as e:
        print(f"✗ Test failed: {e}")
        return False


def clean_build_artifacts():
    """Clean up build artifacts"""
    print("Cleaning build artifacts...")
    
    for path in ["build", "__pycache__"]:
        if Path(path).exists():
            shutil.rmtree(path)
            print(f"  Removed: {path}")


def main():
    """Main build process"""
    print("CloudToLocalLLM Tray Daemon Build Script")
    print("=" * 50)
    
    # Change to script directory
    script_dir = Path(__file__).parent
    os.chdir(script_dir)
    
    platform_name, arch = get_platform_info()
    print(f"Building for: {platform_name}-{arch}")
    print(f"Python version: {sys.version}")
    print()
    
    try:
        # Install dependencies
        install_dependencies()
        print()
        
        # Build executable
        exe_path = build_executable()
        print()
        
        # Test executable
        if exe_path:
            test_executable(exe_path)
            print()
        
        # Clean up
        clean_build_artifacts()
        
        if exe_path:
            print(f"✓ Build completed successfully!")
            print(f"  Executable: {exe_path}")
            return 0
        else:
            print("✗ Build failed!")
            return 1
            
    except KeyboardInterrupt:
        print("\n✗ Build interrupted by user")
        return 1
    except Exception as e:
        print(f"✗ Build failed with error: {e}")
        return 1


if __name__ == "__main__":
    sys.exit(main())

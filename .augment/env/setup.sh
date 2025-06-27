#!/bin/bash
set -e

# CloudToLocalLLM Development Environment Setup
echo "Setting up CloudToLocalLLM development environment..."

# Update system packages
sudo apt-get update

# Install Flutter dependencies
sudo apt-get install -y curl git unzip xz-utils zip libglu1-mesa

# Install Node.js and npm for API backend
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install CMake and build tools for Linux native components
sudo apt-get install -y cmake build-essential pkg-config libgtk-3-dev

# Remove old Flutter installation if it exists
rm -rf $HOME/flutter

# Install latest Flutter SDK (stable channel)
echo "Installing latest Flutter SDK..."
cd $HOME
git clone https://github.com/flutter/flutter.git -b stable --depth 1

# Add Flutter to PATH in .profile
if ! grep -q "export PATH=\"\$HOME/flutter/bin:\$PATH\"" $HOME/.profile; then
    echo 'export PATH="$HOME/flutter/bin:$PATH"' >> $HOME/.profile
fi

# Source the profile to make flutter available in current session
export PATH="$HOME/flutter/bin:$PATH"

# Upgrade Flutter to latest stable
flutter upgrade

# Verify Flutter installation and check Dart SDK version
flutter --version

# Configure Flutter for Linux desktop development
flutter config --enable-linux-desktop

# Disable analytics to avoid prompts
flutter config --no-analytics

# Navigate to project directory
cd /mnt/persist/workspace

# Install Flutter dependencies for main app
echo "Installing Flutter dependencies for main app..."
flutter pub get

# Install Flutter dependencies for shared library
echo "Installing Flutter dependencies for shared library..."
cd lib/shared
flutter pub get
cd ../..

# Install Node.js dependencies for API backend
echo "Installing Node.js dependencies for API backend..."
cd api-backend
npm install
cd ..

# Install root-level Node.js dependencies (for documentation tools)
echo "Installing root-level Node.js dependencies..."
npm install

# Precache Flutter artifacts for faster builds
echo "Precaching Flutter artifacts..."
flutter precache --linux

# Run Flutter doctor to check setup
echo "Running Flutter doctor..."
flutter doctor

echo "Development environment setup complete!"
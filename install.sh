#!/bin/bash

# Display welcome message
echo "Hello from OmniCloud!"
echo "This script will install the Omni CLI tool to your system."
echo ""

# Define variables
LATEST_VERSION=$(curl -s https://api.github.com/repos/OmniCloudOrg/Omni-CLI/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
DOWNLOAD_URL="https://github.com/OmniCloudOrg/Omni-CLI/releases/download/${LATEST_VERSION}/omni-linux"
INSTALL_DIR="/usr/local/bin"
BINARY_NAME="omni"

# Check if the script is running with sudo
if [ "$EUID" -eq 0 ]; then
    echo "Running with sudo privileges."
    SUDO=""
else
    echo "Will require sudo privileges for installation."
    SUDO="sudo"
fi

# Create temporary directory
TEMP_DIR=$(mktemp -d)
echo "Created temporary directory: $TEMP_DIR"

# Download the binary
echo "Downloading Omni CLI from $DOWNLOAD_URL..."
if curl -L "$DOWNLOAD_URL" -o "$TEMP_DIR/$BINARY_NAME"; then
    echo "Download completed successfully."
else
    echo "Failed to download Omni CLI. Please check your internet connection and try again."
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Make binary executable
chmod +x "$TEMP_DIR/$BINARY_NAME"
echo "Made binary executable."

# Install to PATH
echo "Installing to $INSTALL_DIR/$BINARY_NAME"
echo "This requires sudo privileges. You may be prompted for your password."

if $SUDO mv "$TEMP_DIR/$BINARY_NAME" "$INSTALL_DIR/$BINARY_NAME"; then
    echo "Installed successfully to $INSTALL_DIR/$BINARY_NAME"
else
    echo "Installation failed. Please try running the script with sudo."
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Clean up
rm -rf "$TEMP_DIR"
echo "Cleaned up temporary files."

# Verify installation
if command -v $BINARY_NAME &> /dev/null; then
    echo ""
    echo "✅ Omni CLI has been successfully installed!"
    echo "You can now use the 'omni' command from your terminal."
    $BINARY_NAME || echo "Omni CLI is installed but may require additional setup."
else
    echo ""
    echo "⚠️ Omni CLI was installed to $INSTALL_DIR but might not be in your PATH."
    echo "You may need to restart your terminal or add $INSTALL_DIR to your PATH manually."
fi

#!/bin/bash

# Function to print colored text
print_colored() {
    local color=$1
    local message=$2
    
    case $color in
        "green") echo -e "\033[0;32m$message\033[0m" ;;
        "yellow") echo -e "\033[0;33m$message\033[0m" ;;
        "red") echo -e "\033[0;31m$message\033[0m" ;;
        "blue") echo -e "\033[0;34m$message\033[0m" ;;
        *) echo "$message" ;;
    esac
}

# Function to clear screen before showing verification results
clear_and_show_result() {
    clear
    print_colored "green" "✅ Omni CLI has been successfully installed!"
    print_colored "blue" "Version: $LATEST_VERSION"
    print_colored "blue" "Location: $INSTALL_DIR/$BINARY_NAME"
    echo ""
    print_colored "yellow" "To verify installation, run: omni --version"
    echo ""
}

# Display welcome message with better formatting
clear
print_colored "blue" "┌─────────────────────────────────────────┐"
print_colored "blue" "│        OmniCloud CLI Installer          │"
print_colored "blue" "└─────────────────────────────────────────┘"
echo ""
print_colored "green" "This script will install the Omni CLI tool to your system."
echo ""

# Define variables
print_colored "yellow" "⏳ Checking for latest version..."
LATEST_VERSION=$(curl -s https://api.github.com/repos/OmniCloudOrg/Omni-CLI/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
DOWNLOAD_URL="https://github.com/OmniCloudOrg/Omni-CLI/releases/download/${LATEST_VERSION}/omni-linux"
INSTALL_DIR="/usr/local/bin"
BINARY_NAME="omni"

print_colored "blue" "Latest version: $LATEST_VERSION"
echo ""

# Check if the script is running with sudo
if [ "$EUID" -eq 0 ]; then
    print_colored "green" "✓ Running with sudo privileges."
    SUDO=""
else
    print_colored "yellow" "ℹ Will require sudo privileges for installation."
    SUDO="sudo"
fi

# Create temporary directory
TEMP_DIR=$(mktemp -d)
print_colored "blue" "Created temporary directory: $TEMP_DIR"

# Download the binary
print_colored "yellow" "⏳ Downloading Omni CLI ${LATEST_VERSION}..."
if curl -L "$DOWNLOAD_URL" -o "$TEMP_DIR/$BINARY_NAME" --progress-bar; then
    print_colored "green" "✓ Download completed successfully."
else
    print_colored "red" "✗ Failed to download Omni CLI. Please check your internet connection and try again."
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Make binary executable
chmod +x "$TEMP_DIR/$BINARY_NAME"
print_colored "green" "✓ Made binary executable."

# Install to PATH
print_colored "yellow" "⏳ Installing to $INSTALL_DIR/$BINARY_NAME"
print_colored "blue" "This requires sudo privileges. You may be prompted for your password."
if $SUDO mv "$TEMP_DIR/$BINARY_NAME" "$INSTALL_DIR/$BINARY_NAME"; then
    print_colored "green" "✓ Installed successfully to $INSTALL_DIR/$BINARY_NAME"
else
    print_colored "red" "✗ Installation failed. Please try running the script with sudo."
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Clean up
rm -rf "$TEMP_DIR"
print_colored "green" "✓ Cleaned up temporary files."

# Ensure the binary is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    print_colored "yellow" "ℹ $INSTALL_DIR is not in your PATH. Adding temporarily for this session."
    export PATH="$PATH:$INSTALL_DIR"
    
    # Suggest permanent PATH addition
    print_colored "blue" "To add permanently to your PATH, run one of these commands:"
    print_colored "yellow" "For bash: echo 'export PATH=\"\$PATH:$INSTALL_DIR\"' >> ~/.bashrc"
    print_colored "yellow" "For zsh:  echo 'export PATH=\"\$PATH:$INSTALL_DIR\"' >> ~/.zshrc"
    echo ""
fi

# Verify installation
if command -v $BINARY_NAME &> /dev/null; then
    # Clear screen before showing verification
    clear_and_show_result
    
    # Offer to show help
    read -p "Would you like to see the Omni CLI help information? (y/n): " show_help
    if [[ "$show_help" =~ ^[Yy]$ ]]; then
        echo ""
        $BINARY_NAME --help
    fi
else
    print_colored "red" "⚠️ Omni CLI was installed to $INSTALL_DIR but might not be in your PATH."
    print_colored "yellow" "You may need to restart your terminal or add $INSTALL_DIR to your PATH manually:"
    print_colored "yellow" "For bash: echo 'export PATH=\"\$PATH:$INSTALL_DIR\"' >> ~/.bashrc"
    print_colored "yellow" "For zsh:  echo 'export PATH=\"\$PATH:$INSTALL_DIR\"' >> ~/.zshrc"
fi

echo ""
print_colored "green" "Thank you for installing OmniCloud CLI!"

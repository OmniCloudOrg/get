#!/bin/sh

# Function to print colored text
print_colored() {
    color=$1
    message=$2
    
    case $color in
        "green") printf "\033[0;32m%s\033[0m\n" "$message" ;;
        "yellow") printf "\033[0;33m%s\033[0m\n" "$message" ;;
        "red") printf "\033[0;31m%s\033[0m\n" "$message" ;;
        "blue") printf "\033[0;34m%s\033[0m\n" "$message" ;;
        *) printf "%s\n" "$message" ;;
    esac
}

# Display welcome message
clear
printf "\033[0;34m┌─────────────────────────────────────────┐\033[0m\n"
printf "\033[0;34m│        OmniCloud CLI Installer          │\033[0m\n"
printf "\033[0;34m└─────────────────────────────────────────┘\033[0m\n"
echo ""
print_colored "green" "This script will install the Omni CLI tool to your system."
echo ""

# Define variables
print_colored "yellow" "⏳ Checking for latest version..."
LATEST_VERSION=$(curl -s https://api.github.com/repos/OmniCloudOrg/Omni-CLI/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
if [ -z "$LATEST_VERSION" ]; then
    LATEST_VERSION="v0.2.4"  # Fallback to a known version
    print_colored "yellow" "Could not detect latest version, using fallback: $LATEST_VERSION"
else
    print_colored "blue" "Latest version: $LATEST_VERSION"
fi

DOWNLOAD_URL="https://github.com/OmniCloudOrg/Omni-CLI/releases/download/${LATEST_VERSION}/omni-linux"
INSTALL_DIR="/usr/local/bin"
BINARY_NAME="omni"

echo ""

# CRITICAL: Clear ghost entries FIRST
print_colored "yellow" "Step 1: Checking for ghost references to omni..."

# First, try to find the culprit in shell init files
for config_file in "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile" "$HOME/.zshrc" "$HOME/.bash_aliases"; do
    if [ -f "$config_file" ] && grep -q "cargo/bin/omni" "$config_file"; then
        print_colored "red" "Found ghost reference in $config_file!"
        print_colored "yellow" "Creating backup at ${config_file}.bak"
        cp "$config_file" "${config_file}.bak"
        
        # Remove the problematic line
        grep -v "cargo/bin/omni" "$config_file" > "${config_file}.tmp"
        mv "${config_file}.tmp" "$config_file"
        print_colored "green" "✓ Removed ghost reference from $config_file"
    fi
done

# Force clear bash hash table
hash -r 2>/dev/null || true

# Create a direct fix for ~/.cargo/bin issue
if [ -d "$HOME/.cargo/bin" ] && ! [ -f "$HOME/.cargo/bin/omni" ]; then
    print_colored "blue" "Creating a temporary fix for cargo bin ghost entry"
    
    # Create a temporary shell script at the location bash is looking for
    if [ ! -d "$HOME/.cargo/bin" ]; then
        mkdir -p "$HOME/.cargo/bin"
    fi
    
    # Create a shell script that redirects to the correct location
    cat > "$HOME/.cargo/bin/omni" << EOF
#!/bin/sh
# This is a temporary fix created by the OmniCloud installer
# It redirects calls to the actual installation
if [ -f "$INSTALL_DIR/omni" ]; then
    exec "$INSTALL_DIR/omni" "\$@"
else
    echo "Omni CLI not found at $INSTALL_DIR/omni"
    echo "This is a temporary redirector script at $HOME/.cargo/bin/omni"
    exit 1
fi
EOF
    chmod +x "$HOME/.cargo/bin/omni"
    print_colored "green" "✓ Created temporary redirector at $HOME/.cargo/bin/omni"
    print_colored "blue" "The next 'omni' command will work correctly"
fi

# Check if the script is running with sudo
if [ "$(id -u)" -eq 0 ]; then
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

# Make sure all shells know about it
$SUDO sh -c "hash -r 2>/dev/null || true"
hash -r 2>/dev/null || true

# Force update PATH for this session
export PATH="$INSTALL_DIR:$PATH"

# Verify installation
if [ -f "$INSTALL_DIR/$BINARY_NAME" ]; then
    clear
    print_colored "green" "✅ Omni CLI has been successfully installed!"
    print_colored "blue" "Version: $LATEST_VERSION"
    print_colored "blue" "Location: $INSTALL_DIR/$BINARY_NAME"
    echo ""
    
    # Critical: use read with timeout to prevent script from continuing without input
    print_colored "yellow" "Would you like to see the Omni CLI help information? (y/n): "
    read -r show_help
    if [ "$show_help" = "y" ] || [ "$show_help" = "Y" ]; then
        echo ""
        "$INSTALL_DIR/$BINARY_NAME" --help
    fi
else
    print_colored "red" "⚠️ Installation failed. The binary is not at $INSTALL_DIR/$BINARY_NAME."
fi

echo ""
print_colored "green" "Thank you for installing OmniCloud CLI!"
echo ""
print_colored "blue" "To use Omni CLI, you may need to run: export PATH=\"$INSTALL_DIR:\$PATH\""
print_colored "blue" "Or restart your terminal session."

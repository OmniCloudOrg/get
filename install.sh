#!/bin/bash

# Function to print colored text compatible with various shells
print_colored() {
    local color=$1
    local message=$2
    
    case $color in
        "green") printf "\033[0;32m%s\033[0m\n" "$message" ;;
        "yellow") printf "\033[0;33m%s\033[0m\n" "$message" ;;
        "red") printf "\033[0;31m%s\033[0m\n" "$message" ;;
        "blue") printf "\033[0;34m%s\033[0m\n" "$message" ;;
        *) printf "%s\n" "$message" ;;
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

# Fix PATH issues by cleaning bash completion and hash tables
fix_path_references() {
    print_colored "yellow" "Checking for stale references to omni..."
    
    # Clear bash hash table
    hash -r 2>/dev/null || true
    
    # Check for ghost entries in cargo bin
    if [ -d "$HOME/.cargo/bin" ] && ! [ -f "$HOME/.cargo/bin/omni" ] && grep -q "$HOME/.cargo/bin/omni" "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.bash_profile" "$HOME/.profile" 2>/dev/null; then
        print_colored "yellow" "Found ghost reference to omni in Cargo bin directory"
        print_colored "blue" "Cleaning up PATH references..."
        
        # Create a fix script that will run at next login
        FIX_SCRIPT="$HOME/.fix_omni_path.sh"
        cat > "$FIX_SCRIPT" << 'EOF'
#!/bin/bash
# Remove any lines referencing non-existent omni in cargo
for file in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.bash_profile" "$HOME/.profile"; do
    if [ -f "$file" ]; then
        # Backup the file
        cp "$file" "${file}.bak"
        # Remove lines that reference the non-existent omni
        grep -v "/.cargo/bin/omni" "$file" > "${file}.tmp"
        mv "${file}.tmp" "$file"
    fi
done
# Self-delete this script
rm -- "$0"
EOF
        chmod +x "$FIX_SCRIPT"
        
        print_colored "blue" "Added cleanup script at $FIX_SCRIPT"
        print_colored "yellow" "It will run automatically on next login, or you can run it manually with: bash $FIX_SCRIPT"
    fi
    
    # Check if ~/.cargo/bin is in PATH but omni doesn't exist there
    if echo "$PATH" | tr ':' '\n' | grep -q "$HOME/.cargo/bin" && ! [ -f "$HOME/.cargo/bin/omni" ]; then
        print_colored "yellow" "Your PATH includes ~/.cargo/bin but omni is not there."
        print_colored "blue" "This can cause 'command not found' errors if ~/.cargo/bin comes before $INSTALL_DIR in your PATH."
    fi
}

# Display welcome message with better formatting
clear
printf "\033[0;34m┌─────────────────────────────────────────┐\033[0m\n"
printf "\033[0;34m│        OmniCloud CLI Installer          │\033[0m\n"
printf "\033[0;34m└─────────────────────────────────────────┘\033[0m\n"
echo ""
print_colored "green" "This script will install the Omni CLI tool to your system."
echo ""

# Define variables
print_colored "yellow" "⏳ Checking for latest version..."
LATEST_VERSION=$(curl -s https://api.github.com/repos/OmniCloudOrg/Omni-CLI/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
if [ -z "$LATEST_VERSION" ]; then
    # Fallback if grep -P is not available or curl fails
    LATEST_VERSION=$(curl -s https://api.github.com/repos/OmniCloudOrg/Omni-CLI/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
fi
if [ -z "$LATEST_VERSION" ]; then
    LATEST_VERSION="v0.2.4"  # Fallback to a known version if detection fails
    print_colored "yellow" "Could not detect latest version, using fallback: $LATEST_VERSION"
else
    print_colored "blue" "Latest version: $LATEST_VERSION"
fi

DOWNLOAD_URL="https://github.com/OmniCloudOrg/Omni-CLI/releases/download/${LATEST_VERSION}/omni-linux"
INSTALL_DIR="/usr/local/bin"
BINARY_NAME="omni"

echo ""

# Fix PATH issues with ghost entries
fix_path_references

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

# Create a safe helper that ensures correct PATH
HELPER_SCRIPT="/tmp/omni_helper.sh"
cat > "$HELPER_SCRIPT" << EOF
#!/bin/bash
# Force PATH to include installation directory first
export PATH="$INSTALL_DIR:\$PATH"
# Clear bash's memory of previous command locations
hash -r 2>/dev/null || true
# Run omni with all arguments
"$INSTALL_DIR/$BINARY_NAME" "\$@"
EOF
chmod +x "$HELPER_SCRIPT"

# Check if bash's completion needs updating
print_colored "yellow" "Updating command database..."
$SUDO bash -c "hash -r 2>/dev/null || true"
$SUDO bash -c "command -v $BINARY_NAME >/dev/null 2>&1 || { echo; echo \"$INSTALL_DIR\" > /etc/paths.d/omnicloud 2>/dev/null || true; }"

# Ensure the binary is in PATH
PATH_HAS_INSTALL_DIR=0
echo "$PATH" | tr ':' '\n' | grep -q "^$INSTALL_DIR$" && PATH_HAS_INSTALL_DIR=1

if [ $PATH_HAS_INSTALL_DIR -eq 0 ]; then
    print_colored "yellow" "ℹ $INSTALL_DIR is not in your PATH. Adding it temporarily for this session."
    export PATH="$INSTALL_DIR:$PATH"
    
    # Check if any profile files exist
    PROFILE_FILES="$HOME/.bashrc $HOME/.bash_profile $HOME/.zshrc $HOME/.profile"
    PROFILE_FOUND=0
    
    for FILE in $PROFILE_FILES; do
        if [ -f "$FILE" ]; then
            PROFILE_FOUND=1
            echo -n "Would you like to add $INSTALL_DIR to your PATH in $FILE? (y/n): "
            read -r add_path
            if [ "$add_path" = "y" ] || [ "$add_path" = "Y" ]; then
                echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "$FILE"
                print_colored "green" "✓ Added to $FILE. Changes will take effect in new terminal sessions."
                break
            fi
        fi
    done
    
    if [ $PROFILE_FOUND -eq 0 ]; then
        print_colored "yellow" "To add permanently to your PATH, run one of these commands:"
        print_colored "yellow" "For bash: echo 'export PATH=\"$INSTALL_DIR:\$PATH\"' >> ~/.bashrc"
        print_colored "yellow" "For zsh:  echo 'export PATH=\"$INSTALL_DIR:\$PATH\"' >> ~/.zshrc"
    fi
    echo ""
fi

# Verify installation with the helper script
print_colored "yellow" "Verifying installation..."
if "$HELPER_SCRIPT" --version >/dev/null 2>&1; then
    # Clear screen before showing verification
    clear_and_show_result
    
    # Offer to show help
    echo -n "Would you like to see the Omni CLI help information? (y/n): "
    read -r show_help
    if [ "$show_help" = "y" ] || [ "$show_help" = "Y" ]; then
        echo ""
        "$HELPER_SCRIPT" --help
    fi
    
    # Important: remind user to restart terminal
    echo ""
    print_colored "yellow" "⚠️ IMPORTANT: Please restart your terminal or run 'source ~/.bashrc' (or equivalent)"
    print_colored "yellow" "to ensure the omni command works correctly in your current session."
else
    print_colored "red" "⚠️ Omni CLI was installed to $INSTALL_DIR/$BINARY_NAME but verification failed."
    print_colored "blue" "You can still use it with the absolute path: $INSTALL_DIR/$BINARY_NAME"
    print_colored "yellow" "After restarting your terminal, the 'omni' command should work correctly."
fi

echo ""
print_colored "green" "Thank you for installing OmniCloud CLI!"

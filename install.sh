#!/bin/sh

# Function to print colored text compatible with various shells
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

# Function to clear screen before showing verification results
clear_and_show_result() {
    clear
    print_colored "green" "✅ Omni CLI has been successfully installed!"
    print_colored "blue" "Version: $LATEST_VERSION"
    print_colored "blue" "Location: $INSTALL_DIR/$BINARY_NAME"
    echo ""
    print_colored "yellow" "You can now use the 'omni' command from your terminal."
    echo ""
}

# Function to reload shell environment
reload_shell_env() {
    print_colored "yellow" "Reloading shell environment..."
    
    # Create a temporary script to update PATH and rehash
    TEMP_RELOAD_SCRIPT=$(mktemp)
    cat > "$TEMP_RELOAD_SCRIPT" << 'EOF'
#!/bin/sh
# Add installation directory to PATH if not already there
if ! echo "$PATH" | tr ':' '\n' | grep -q "^/usr/local/bin$"; then
    export PATH="/usr/local/bin:$PATH"
fi

# Clear hash table if possible
hash -r 2>/dev/null || true

# Notify user
echo "Shell environment reloaded. The omni command should now be available."
EOF
    
    chmod +x "$TEMP_RELOAD_SCRIPT"
    
    # Execute with source to affect current environment
    . "$TEMP_RELOAD_SCRIPT"
    
    # Clean up
    rm -f "$TEMP_RELOAD_SCRIPT"
    
    # Verify it worked
    if command -v omni >/dev/null 2>&1; then
        print_colored "green" "✓ Successfully reloaded environment. 'omni' command is now available!"
        ENVIRONMENT_RELOADED=1
    else
        print_colored "yellow" "Automatic reload wasn't fully successful."
        print_colored "yellow" "Please restart your terminal or run: export PATH=\"/usr/local/bin:\$PATH\""
    fi
}

# Fix PATH issues in shell config files
fix_shell_config() {
    print_colored "yellow" "Checking shell configuration files..."
    modified=0
    
    # Check for cargo bin ghost entry
    if [ -d "$HOME/.cargo/bin" ] && ! [ -f "$HOME/.cargo/bin/omni" ]; then
        for config_file in "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile" "$HOME/.zshrc"; do
            if [ -f "$config_file" ] && grep -q "/.cargo/bin/omni" "$config_file" 2>/dev/null; then
                print_colored "blue" "Found ghost reference in $config_file, updating..."
                
                # Backup the file
                cp "$config_file" "${config_file}.bak.$(date +%s)"
                
                # Show the specific lines being removed
                print_colored "yellow" "Removing these lines from $config_file:"
                grep "/.cargo/bin/omni" "$config_file" | while read -r line; do
                    print_colored "red" "  $line"
                done
                
                # Remove problematic lines
                grep -v "/.cargo/bin/omni" "$config_file" > "${config_file}.tmp"
                mv "${config_file}.tmp" "$config_file"
                
                # Make sure /usr/local/bin is in PATH
                if ! grep -q "export PATH=\"/usr/local/bin:" "$config_file" && ! grep -q "export PATH=/usr/local/bin:" "$config_file"; then
                    echo "" >> "$config_file"
                    echo "# Added by OmniCloud installer" >> "$config_file"
                    echo "export PATH=\"/usr/local/bin:\$PATH\"" >> "$config_file"
                    print_colored "green" "✓ Added /usr/local/bin to PATH in $config_file"
                fi
                
                modified=1
                print_colored "green" "✓ Updated $config_file"
            fi
        done
    fi
    
    # Check for any other ghost entries using which command
    if command -v omni >/dev/null 2>&1; then
        omni_path=$(which omni 2>/dev/null)
        if [ -n "$omni_path" ] && [ ! -f "$omni_path" ]; then
            print_colored "red" "⚠️ Detected ghost reference to omni at $omni_path (file doesn't exist)"
            
            # This is more complex - we'll handle by clearing hash table
            print_colored "blue" "Clearing command hash table..."
            hash -r 2>/dev/null || true
            modified=1
        fi
    fi
    
    # Clear bash hash table in any case
    hash -r 2>/dev/null || true
    
    if [ $modified -eq 1 ]; then
        print_colored "green" "✓ Shell configuration files updated successfully."
    else
        print_colored "blue" "No problematic references found in shell configuration files."
    fi
}

# Find ghost entries for omni
find_ghost_entries() {
    print_colored "yellow" "Checking for ghost references to omni..."
    found_ghosts=0
    
    # Check for non-existent omni in cargo bin
    if [ -d "$HOME/.cargo/bin" ] && ! [ -f "$HOME/.cargo/bin/omni" ] && command -v omni >/dev/null 2>&1; then
        which_output=$(which omni 2>/dev/null)
        if echo "$which_output" | grep -q ".cargo/bin/omni"; then
            print_colored "red" "⚠️ Detected ghost reference to omni in ~/.cargo/bin"
            found_ghosts=1
        fi
    fi
    
    # Check for any other ghost entries
    if command -v omni >/dev/null 2>&1; then
        omni_path=$(which omni 2>/dev/null)
        if [ ! -f "$omni_path" ] && [ -n "$omni_path" ]; then
            print_colored "red" "⚠️ Detected ghost reference to omni at $omni_path (file doesn't exist)"
            found_ghosts=1
        fi
    fi
    
    # If any ghost entries were found, prompt user to fix them
    if [ $found_ghosts -eq 1 ]; then
        printf "Would you like to remove ghost entries for omni? (y/n): "
        read -r remove_ghosts
        if [ "$remove_ghosts" = "y" ] || [ "$remove_ghosts" = "Y" ]; then
            print_colored "blue" "Removing ghost entries..."
            fix_shell_config
            return 0
        else
            print_colored "yellow" "Ghost entries will not be removed. This may cause issues."
            return 1
        fi
    fi
    
    return 0
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
LATEST_VERSION=$(curl -s https://api.github.com/repos/OmniCloudOrg/Omni-CLI/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
if [ -z "$LATEST_VERSION" ]; then
    LATEST_VERSION="v0.2.4"  # Fallback to a known version if detection fails
    print_colored "yellow" "Could not detect latest version, using fallback: $LATEST_VERSION"
else
    print_colored "blue" "Latest version: $LATEST_VERSION"
fi

DOWNLOAD_URL="https://github.com/OmniCloudOrg/Omni-CLI/releases/download/${LATEST_VERSION}/omni-linux"
INSTALL_DIR="/usr/local/bin"
BINARY_NAME="omni"
ENVIRONMENT_RELOADED=0

echo ""

# Run ghost entry check
find_ghost_entries

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

# Clean the system's command cache
print_colored "yellow" "Updating system command cache..."
$SUDO sh -c "hash -r 2>/dev/null || true"

# Update PATH and reload shell environment
export PATH="$INSTALL_DIR:$PATH"
hash -r 2>/dev/null || true

# Reload shell environment
reload_shell_env

# Clean any existing bash completions for omni
if [ -d "/etc/bash_completion.d" ] || [ -d "/usr/local/etc/bash_completion.d" ]; then
    print_colored "yellow" "Checking for bash completions..."
    for comp_dir in "/etc/bash_completion.d" "/usr/local/etc/bash_completion.d"; do
        if [ -f "$comp_dir/omni" ]; then
            $SUDO rm -f "$comp_dir/omni"
            print_colored "blue" "Removed old bash completion for omni"
        fi
    done
fi

# Verify installation
if [ $ENVIRONMENT_RELOADED -eq 1 ] && command -v omni >/dev/null 2>&1; then
    # Clear screen before showing verification
    clear_and_show_result
    
    # Offer to show help
    printf "Would you like to see the Omni CLI help information? (y/n): "
    read -r show_help
    if [ "$show_help" = "y" ] || [ "$show_help" = "Y" ]; then
        echo ""
        omni --help
    fi
else
    # If direct command failed, try absolute path
    if [ -f "$INSTALL_DIR/$BINARY_NAME" ]; then
        print_colored "yellow" "The 'omni' command isn't available directly yet, but the binary is installed."
        print_colored "blue" "You can use it with the absolute path: $INSTALL_DIR/$BINARY_NAME"
        
        # We can't use alias in sh, so suggest alternative
        print_colored "green" "✓ For this session, you can use: $INSTALL_DIR/$BINARY_NAME"
        
        # Check shell type and update config if possible
        SHELL_NAME=$(basename "$SHELL")
        if [ "$SHELL_NAME" = "bash" ] || [ "$SHELL_NAME" = "zsh" ]; then
            CONFIG_FILE="$HOME/.${SHELL_NAME}rc"
            if [ -f "$CONFIG_FILE" ]; then
                printf "Would you like to update $CONFIG_FILE to include /usr/local/bin in PATH? (y/n): "
                read -r update_config
                if [ "$update_config" = "y" ] || [ "$update_config" = "Y" ]; then
                    echo "" >> "$CONFIG_FILE"
                    echo "# Added by OmniCloud installer" >> "$CONFIG_FILE"
                    echo "export PATH=\"/usr/local/bin:\$PATH\"" >> "$CONFIG_FILE"
                    echo "hash -r 2>/dev/null || true  # Clear command hash table" >> "$CONFIG_FILE"
                    print_colored "green" "✓ Updated $CONFIG_FILE. Changes will take effect in new terminal sessions."
                    print_colored "yellow" "Run 'source $CONFIG_FILE' to apply changes immediately."
                fi
            fi
        fi
    else
        print_colored "red" "⚠️ Installation appears to have failed. The binary is not at $INSTALL_DIR/$BINARY_NAME."
    fi
fi

echo ""
print_colored "green" "Thank you for installing OmniCloud CLI!"

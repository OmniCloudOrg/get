#!/bin/sh

# Get command line arguments
# Must be at top of script to process args properly

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

# Check arguments for Nix bypass code
NIX_BYPASS_CODE="my-next-os-wont-be-nix"
NIX_BYPASS_PROVIDED=0

for arg in "$@"; do
    if [ "$arg" = "$NIX_BYPASS_CODE" ]; then
        NIX_BYPASS_PROVIDED=1
    fi
done

# Check if we're running in a Nix environment
NIX_ENV=0
if [ -d "/nix" ] || [ -n "$NIX_PROFILES" ] || [ -n "$NIX_PATH" ]; then
    NIX_ENV=1
    if [ $NIX_BYPASS_PROVIDED -eq 1 ]; then
        print_colored "yellow" "😏 Detected Nix environment... but you've provided the bypass code."
        print_colored "green" "Proceeding with installation despite better judgment..."
    else
        print_colored "red" "❌ Detected Nix environment!"
        print_colored "yellow" "Installation on Nix systems requires explicit acknowledgment."
        print_colored "blue" "To continue, please run this script with the parameter: $NIX_BYPASS_CODE"
        print_colored "blue" "Example: ./install.sh $NIX_BYPASS_CODE"
        print_colored "yellow" "This ensures you understand the potential conflicts with Nix's package management."
        exit 1
    fi
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

if [ $NIX_ENV -eq 1 ]; then
    print_colored "blue" "🙄 Oh boy, here we go with Nix... let's see if this works..."
    print_colored "yellow" "Attempting to navigate the maze of Nix's environment isolation..."
    
    # Check if we have write permission to /usr/local/bin
    if [ -w "$INSTALL_DIR" ]; then
        print_colored "green" "✓ Surprisingly, we can write to $INSTALL_DIR directly!"
    else
        print_colored "yellow" "😒 As expected, Nix is being difficult. Looking for alternatives..."
        
        # Try to find a writable bin directory in PATH
        for dir in $(echo "$PATH" | tr ':' ' '); do
            if [ -d "$dir" ] && [ -w "$dir" ]; then
                print_colored "blue" "Found writable directory in PATH: $dir"
                print_colored "yellow" "Would you like to install omni here instead? (y/n): "
                read -r use_alt_dir
                if [ "$use_alt_dir" = "y" ] || [ "$use_alt_dir" = "Y" ]; then
                    INSTALL_DIR="$dir"
                    print_colored "green" "Will install to $INSTALL_DIR instead. Nix won't know what hit it!"
                    break
                fi
            fi
        done
    fi
    
    print_colored "yellow" "Attempting installation despite Nix's best efforts to confuse us..."
else
    print_colored "blue" "This requires sudo privileges. You may be prompted for your password."
fi

if $SUDO mv "$TEMP_DIR/$BINARY_NAME" "$INSTALL_DIR/$BINARY_NAME"; then
    print_colored "green" "✓ Installed successfully to $INSTALL_DIR/$BINARY_NAME"
    
    if [ $NIX_ENV -eq 1 ]; then
        print_colored "green" "😮 Well, that actually worked! Take that, Nix!"
    fi
else
    print_colored "red" "✗ Installation failed."
    
    if [ $NIX_ENV -eq 1 ]; then
        print_colored "yellow" "😑 Nix strikes again. Let's try a user-local installation..."
        
        # Try installing to ~/.local/bin for Nix environments
        LOCAL_BIN="$HOME/.local/bin"
        
        if [ ! -d "$LOCAL_BIN" ]; then
            mkdir -p "$LOCAL_BIN"
            print_colored "blue" "Created $LOCAL_BIN directory"
        fi
        
        if mv "$TEMP_DIR/$BINARY_NAME" "$LOCAL_BIN/$BINARY_NAME"; then
            print_colored "green" "✓ Installed successfully to $LOCAL_BIN/$BINARY_NAME"
            INSTALL_DIR="$LOCAL_BIN"
            print_colored "yellow" "Don't forget to add $LOCAL_BIN to your PATH if it's not already there."
        else
            print_colored "red" "✗ Installation failed even to user directory. Nix wins this round."
            rm -rf "$TEMP_DIR"
            exit 1
        fi
    else
        print_colored "red" "Please try running the script with sudo."
        rm -rf "$TEMP_DIR"
        exit 1
    fi
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
    
    if [ $NIX_ENV -eq 1 ]; then
        print_colored "yellow" "😏 Despite Nix's valiant efforts to maintain purity, we've successfully installed Omni CLI."
        print_colored "yellow" "Next time, consider using a declarative configuration like a proper Nix user..."
        echo ""
    fi
    
    # Critical: use read with timeout to prevent script from continuing without input
    print_colored "yellow" "Would you like to see the Omni CLI help information? (y/n): "
    read -r show_help
    if [ "$show_help" = "y" ] || [ "$show_help" = "Y" ]; then
        echo ""
        "$INSTALL_DIR/$BINARY_NAME" --help
    fi
else
    print_colored "red" "⚠️ Installation failed. The binary is not at $INSTALL_DIR/$BINARY_NAME."
    
    if [ $NIX_ENV -eq 1 ]; then
        print_colored "yellow" "😒 Looks like Nix's purity culture won this round..."
        echo ""
    fi
fi

echo ""
print_colored "green" "Thank you for installing OmniCloud CLI!"
echo ""

if [ $NIX_ENV -eq 1 ]; then
    print_colored "blue" "For Nix environments, you might want to add this to your configuration.nix:"
    print_colored "yellow" "  environment.systemPackages = with pkgs; [ omnicloud ];"
    print_colored "blue" "...but since that doesn't exist yet, you'll have to make do with this silly installer."
    print_colored "blue" "To use Omni CLI, you may need to run: export PATH=\"$INSTALL_DIR:\$PATH\""
    print_colored "blue" "Or restart your terminal session."
    echo ""
    print_colored "yellow" "Remember: friends don't let friends use imperative package management in Nix! 😉"
else
    print_colored "blue" "To use Omni CLI, you may need to run: export PATH=\"$INSTALL_DIR:\$PATH\""
    print_colored "blue" "Or restart your terminal session."
fi

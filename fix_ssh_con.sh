#!/bin/bash

# Basically, this script set IPQoS to 0x00 (best effort/low priority) for GitHub SSH connections

#### When to use this fix?

# Routers handle the Type of Service (ToS) settings in IP packets by examining
# the ToS field in the IP header to determine how to prioritize, route, and manage the
# traffic based on network policies and congestion conditions.

# Some routers have issues with the IP_TOS (Type of Service) value set by SSH
# because they mishandle or improperly process packets marked with non-zero
# ToS or DSCP (Differentiated Services Code Point) values.

# This config forces the IPQoS field to zero (IPQoS 0x00), which removes the
# special QoS markings and makes the packets "best effort" with no special priority.

set -eu  # Exit on any error and treat unset variables as errors

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Unified function to print colored output
print_msg() {
    local color="$1"; shift
    echo -e "${color}$*${NC}"
}

# Function to check if running as root
check_not_root() {
    if [[ $EUID -eq 0 ]]; then
        print_msg "$RED" "[ERROR] This script should not be run as root!"
        print_msg "$RED" "[ERROR] SSH configs should be owned by your user account."
        exit 1
    fi
}

# Function to check if ~/.ssh directory exists
check_ssh_dir_exists() {
    if [[ ! -d "$HOME/.ssh" ]]; then
        print_msg "$RED" "[ERROR] ~/.ssh directory does not exist. Please create it before running this script."
        exit 1
    fi
}

# Function to backup existing config
backup_existing_config() {
    if [[ -f "$HOME/.ssh/config" ]]; then
        local backup_file
        backup_file="$HOME/.ssh/config.backup.$(date +%Y%m%d_%H%M%S)"

        print_msg "$BLUE" "[INFO] Backing up existing SSH config to $backup_file"
        cp "$HOME/.ssh/config" "$backup_file"
        print_msg "$GREEN" "[SUCCESS] Backup created: $backup_file"
        return 0
    else
        print_msg "$BLUE" "[INFO] No existing SSH config found"
        return 1
    fi
}

# Function to show a host block
show_host_block() {
    local host="$1"
    sed -n "/^Host $host/,/^Host /p" "$HOME/.ssh/config" | head -n -1
}

# Function to check if GitHub config already exists
check_existing_github_config() {
    if [[ -f "$HOME/.ssh/config" ]] && grep -q "Host github.com" "$HOME/.ssh/config"; then
        print_msg "$YELLOW" "[WARNING] GitHub configuration already exists in ~/.ssh/config"
        echo
        echo "Existing GitHub configuration:"
        echo "---"
        show_host_block "github.com"
        echo "---"
        echo
        read -p "Do you want to update it? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_msg "$BLUE" "[INFO] Keeping existing configuration. Exiting."
            exit 0
        fi
        return 0
    fi
    return 1
}

# Function to remove existing GitHub config
remove_existing_github_config() {
    if [[ -f "$HOME/.ssh/config" ]]; then
        print_msg "$BLUE" "[INFO] Removing existing GitHub configuration..."
        sed -i.bak '/^Host github\.com/,/^Host /d; /^Host ssh\.github\.com/,/^Host /d' "$HOME/.ssh/config"
    fi
}

# Function to add GitHub configuration
add_github_config() {
    print_msg "$BLUE" "[INFO] Adding GitHub SSH configuration..."
    cat >> "$HOME/.ssh/config" << 'EOF'

# GitHub SSH Configuration
# IPQoS 0x00 fixes connection issues with Technicolor modems and some ISPs
Host github.com
    User git
    Hostname github.com
    IPQoS 0x00

# GitHub SSH over HTTPS (port 443) - alternative if port 22 is blocked
Host ssh.github.com
    User git
    Hostname ssh.github.com
    Port 443
    IPQoS 0x00
EOF
    print_msg "$GREEN" "[SUCCESS] GitHub SSH configuration added"
}

# Function to set correct permissions
set_permissions() {
    print_msg "$BLUE" "[INFO] Setting correct file permissions..."
    if [[ -f "$HOME/.ssh/config" ]]; then
        chmod 600 "$HOME/.ssh/config"
    fi
    print_msg "$GREEN" "[SUCCESS] Permissions set correctly"
}

# Function to test SSH connection
test_ssh_connection() {
    print_msg "$BLUE" "[INFO] Testing SSH connection to GitHub..."
    if ssh -T -o ConnectTimeout=10 git@github.com 2>&1 | grep -q "successfully authenticated"; then
        print_msg "$GREEN" "[SUCCESS] SSH connection to GitHub works!"
    else
        print_msg "$YELLOW" "[WARNING] SSH connection test failed or you haven't set up SSH keys yet"
    fi
}

# Function to show configuration
show_config() {
    echo
    print_msg "$BLUE" "[INFO] Current GitHub SSH configuration:"
    echo "=================================="
    if [[ -f "$HOME/.ssh/config" ]]; then
        show_host_block "github.com"
        echo
        show_host_block "ssh.github.com"
    else
        print_msg "$RED" "[ERROR] No SSH config file found"
    fi
    echo "=================================="
}

# Main execution
main() {
    echo "GitHub SSH Configuration Script"
    echo "==============================="
    echo "This script configures SSH to work properly with GitHub"
    echo "It helps when modems or ISPs interfere with QoS."
    echo "Particularly, this helped to fix a problem with Technicolor modem in bridge mode"
    echo

    check_not_root
    check_ssh_dir_exists
    backup_existing_config
    if check_existing_github_config; then
        remove_existing_github_config
    fi
    add_github_config
    set_permissions
    show_config
    test_ssh_connection
    print_msg "$GREEN" "[SUCCESS] SSH configuration completed!"
}

main "$@"

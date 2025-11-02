#!/usr/bin/env bash
# ==========================================
# 🚀 Linux Distro Setup Script — by Yaad
# Automates post-install setup for fresh Linux installs
# Modular • Colorful • Safe • Professional
# ==========================================

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# --- 🎨 COLOR CODES ---
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly BOLD='\033[1m'
readonly RESET='\033[0m'

# --- 🔧 CONFIGURATION ---
readonly GITHUB_USER="EiadurRahman"
readonly REPO_NAME="pc-backups"
readonly REPO_URL="git@github.com:${GITHUB_USER}/${REPO_NAME}.git"
readonly REPO_DIR="$HOME/${REPO_NAME}"
readonly GRUB_SRC="${REPO_DIR}/grub"
readonly GRUB_DEST="/etc/default/grub"
readonly LOG_FILE="$HOME/setup-$(date +%F-%H%M%S).log"

# --- 📝 LOGGING SETUP ---
exec > >(tee -a "$LOG_FILE") 2>&1

# --- 🛡️ ERROR HANDLING ---
trap 'echo -e "${RED}✖ Error on line $LINENO. Check $LOG_FILE${RESET}" >&2' ERR

# --- 🎨 PRINT UTILITIES ---
print_banner() {
    echo -e "${BOLD}${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║                                                           ║"
    echo "║         Linux Distro Setup Automation Script              ║"
    echo "║                                                           ║"
    echo "║                 Created by: Yaad                          ║"
    echo "║                                                           ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo " Log: $LOG_FILE    "
    echo -e "${RESET}\n"
}

print_step() {
    echo -e "\n${BOLD}${MAGENTA}▶ $1${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

print_success() {
    echo -e "${GREEN}✔ $1${RESET}"
}

print_error() {
    echo -e "${RED}✖ $1${RESET}" >&2
}

print_info() {
    echo -e "${YELLOW}ℹ $1${RESET}"
}

print_progress() {
    echo -e "${BLUE}⟳ $1${RESET}"
}

confirm() {
    local prompt="$1"
    local response
    read -p "$(echo -e ${YELLOW}${prompt} [y/N]: ${RESET})" response
    [[ "$response" =~ ^[Yy]$ ]]
}

# --- 🔍 SYSTEM DETECTION ---
detect_system() {
    print_step "Detecting system information"
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_NAME="$NAME"
        DISTRO_ID="$ID"
        print_info "Detected: ${DISTRO_NAME}"
    else
        print_error "Cannot detect Linux distribution"
        exit 1
    fi
    
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        print_error "Please don't run this script as root (no sudo)"
        exit 1
    fi
    
    # Check sudo access
    if ! sudo -n true 2>/dev/null; then
        print_info "This script requires sudo access. You may be prompted for your password."
        sudo -v
    fi
    
    print_success "System checks passed"
}

# --- 🔐 GIT & SSH SETUP ---
setup_git_ssh() {
    print_step "Setting up Git and SSH authentication"
    
    # Install git if needed
    if ! command -v git &> /dev/null; then
        print_progress "Installing Git..."
        case "$DISTRO_ID" in
            ubuntu|debian|linuxmint|pop)
                sudo apt update -qq
                sudo apt install -y git
                ;;
            arch|manjaro)
                sudo pacman -Syu --noconfirm git
                ;;
            fedora)
                sudo dnf install -y git
                ;;
            *)
                print_error "Unsupported distro for automatic git installation"
                exit 1
                ;;
        esac
        print_success "Git installed"
    else
        print_info "Git is already installed"
    fi
    
    # SSH key setup
    local ssh_dir="$HOME/.ssh"
    local key_path="$ssh_dir/id_ed25519"
    
    if [ -f "$key_path" ]; then
        print_info "SSH key already exists at $key_path"
    else
        print_progress "Generating new SSH key..."
        mkdir -p "$ssh_dir"
        chmod 700 "$ssh_dir"
        
        read -p "$(echo -e ${CYAN}Enter your GitHub email: ${RESET})" git_email
        
        ssh-keygen -t ed25519 -C "$git_email" -f "$key_path" -N ""
        print_success "SSH key generated at $key_path"
    fi
    
    # Start SSH agent and add key
    print_progress "Starting SSH agent and adding key..."
    eval "$(ssh-agent -s)" > /dev/null
    ssh-add "$key_path" 2>/dev/null
    
    # Display public key
    echo ""
    echo -e "${BOLD}${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}${CYAN}📋 Your SSH Public Key:${RESET}"
    echo -e "${BOLD}${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    cat "${key_path}.pub"
    echo -e "${BOLD}${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    print_info "Add this key to GitHub: ${BOLD}https://github.com/settings/keys${RESET}"
    echo ""
    
    read -p "$(echo -e ${YELLOW}Press Enter after adding the key to GitHub...${RESET})"
    
    # Test GitHub connection
    print_progress "Testing GitHub SSH connection..."
    if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
        print_success "GitHub SSH connection verified!"
    else
        print_error "GitHub SSH authentication failed"
        print_info "Please verify:"
        print_info "  1. You added the public key to https://github.com/settings/keys"
        print_info "  2. You selected the correct account"
        if ! confirm "Continue anyway? (not recommended)"; then
            exit 1
        fi
    fi
    
    # Configure Git
    if [ -n "${git_email:-}" ]; then
        git config --global user.name "$GITHUB_USER"
        git config --global user.email "$git_email"
        print_success "Git global config set (user: $GITHUB_USER, email: $git_email)"
    fi
    
    # Offer backup
    if confirm "Create a backup of your SSH keys?"; then
        local backup_file="$HOME/ssh_key_backup_$(date +%F).tar.gz"
        tar -czf "$backup_file" -C "$ssh_dir" id_ed25519 id_ed25519.pub
        print_success "Backup created at $backup_file"
        print_info "Store this backup in a secure location!"
    fi
}

# --- 📦 CLONE REPOSITORY ---
clone_repo() {
    print_step "Cloning GitHub repository"
    
    if [ -d "$REPO_DIR" ]; then
        print_info "Repository already exists at $REPO_DIR"
        if confirm "Pull latest changes?"; then
            print_progress "Updating repository..."
            cd "$REPO_DIR"
            git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || {
                print_error "Failed to update repository"
                return 1
            }
            print_success "Repository updated"
        fi
    else
        print_progress "Cloning $REPO_URL..."
        if git clone "$REPO_URL" "$REPO_DIR"; then
            print_success "Repository cloned to $REPO_DIR"
        else
            print_error "Failed to clone repository"
            print_info "Make sure:"
            print_info "  1. The repository exists: https://github.com/${GITHUB_USER}/${REPO_NAME}"
            print_info "  2. You have access to it"
            print_info "  3. Your SSH key is properly configured"
            exit 1
        fi
    fi
}

# --- 🖥️ GRUB CONFIGURATION ---
setup_grub() {
    print_step "Setting up GRUB configuration"
    
    if [ ! -f "$GRUB_SRC" ]; then
        print_error "GRUB config not found at $GRUB_SRC"
        print_info "Skipping GRUB setup"
        return
    fi
    
    # Backup existing GRUB config
    if [ -f "$GRUB_DEST" ]; then
        local backup_path="${GRUB_DEST}.backup.$(date +%F-%H%M%S)"
        print_progress "Backing up existing GRUB config..."
        sudo cp "$GRUB_DEST" "$backup_path"
        print_success "Backup created at $backup_path"
    fi
    
    # Copy new config
    print_progress "Installing new GRUB configuration..."
    sudo cp "$GRUB_SRC" "$GRUB_DEST"
    
    # Update GRUB
    print_progress "Updating GRUB bootloader..."
    sudo update-grub
    
    print_success "GRUB configuration updated"
}

# --- 📦 INSTALL APPLICATIONS ---
install_apps() {
    print_step "Installing essential applications"
    
    case "$DISTRO_ID" in
        ubuntu|debian|linuxmint|pop)
            print_progress "Updating package lists..."
            sudo apt update -qq
            
            # Core packages
            local packages=(
                curl
                wget
                git
                build-essential
                software-properties-common
                apt-transport-https
                ca-certificates
                gnupg
                htop
                neofetch
                micro
                vlc
                python3
                python3-pip
                unzip
                zip
                tree
            )
            
            print_progress "Installing core packages..."
            sudo apt install -y "${packages[@]}"
            
            # VSCode
            if ! command -v code &> /dev/null; then
                print_progress "Installing Visual Studio Code..."
                wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/packages.microsoft.gpg
                sudo install -D -o root -g root -m 644 /tmp/packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
                sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
                rm -f /tmp/packages.microsoft.gpg
                sudo apt update -qq
                sudo apt install -y code
                print_success "VSCode installed"
            else
                print_info "VSCode already installed"
            fi
            ;;
            
        arch|manjaro)
            print_progress "Installing packages via pacman..."
            sudo pacman -Syu --noconfirm \
                curl wget git base-devel htop neofetch micro vlc \
                python python-pip unzip zip tree code
            ;;
            
        fedora)
            print_progress "Installing packages via dnf..."
            sudo dnf install -y \
                curl wget git @development-tools htop neofetch micro vlc \
                python3 python3-pip unzip zip tree code
            ;;
            
        *)
            print_error "Unsupported distribution for automatic package installation"
            return 1
            ;;
    esac
    
    print_success "All applications installed successfully"
}

# --- 🎉 FINISH ---
print_completion() {
    echo ""
    echo -e "${BOLD}${GREEN}"
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║                                                        ║"
    echo "║                  Setup Complete!                       ║"
    echo "║                                                        ║"
    echo "║  Your system is now configured and ready to use!       ║"
    echo "║                                                        ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
    
    print_info "Setup log saved to: ${BOLD}$LOG_FILE${RESET}"
    print_info "Repository cloned to: ${BOLD}$REPO_DIR${RESET}"
    
    echo ""
    print_success "All done, Yaad! Happy coding! 🚀"
    echo ""
}

# --- 🚀 MAIN EXECUTION ---
main() {
    print_banner
    
    detect_system
    
    if confirm "Setup Git and SSH authentication?"; then
        setup_git_ssh
    else
        print_info "Skipping Git/SSH setup"
    fi
    
    if confirm "Clone your GitHub repository?"; then
        clone_repo
    else
        print_info "Skipping repository clone"
    fi
    
    if confirm "Setup GRUB configuration?"; then
        setup_grub
    else
        print_info "Skipping GRUB setup"
    fi
    
    if confirm "Install essential applications?"; then
        install_apps
    else
        print_info "Skipping application installation"
    fi
    
    print_completion
}

# Run the script
main "$@"
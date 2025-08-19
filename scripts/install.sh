#!/bin/bash
# A one-stop script for installing a Dracula-themed Hyprland setup on Arch Linux.
# This script handles both system-level and user-level tasks in a single run,
# using only official Arch Linux repositories via pacman.
set -euo pipefail

# --- Global Helper Functions ---
print_header() {
    echo -e "\n--- \e[1m\e[34m$1\e[0m ---"
}

print_success() {
    echo -e "\e[32m$1\e[0m"
}

print_warning() {
    echo -e "\e[33mWarning: $1\e[0m" >&2
}

print_error() {
    echo -e "\e[31mError: $1\e[0m" >&2
    exit 1
}

print_bold_blue() {
    echo -e "\e[1m\e[34m$1\e[0m"
}

run_command() {
    local command="$1"
    local description="$2"
    local confirm_needed="${3:-"yes"}"

    if [ "$confirm_needed" == "yes" ] && [ "$CONFIRMATION" == "yes" ]; then
        read -p "Install '$description'? Press Enter to continue..."
    fi

    echo -e "\nRunning: $command"
    if ! eval "$command"; then
        print_error "Failed to '$description'."
    fi
    print_success "✅ Success: '$description'"
}

# --- Main Execution Logic ---

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root. Please run with 'sudo bash $0'."
fi

# Define variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
CONFIG_DIR="$USER_HOME/.config"
CONFIRMATION="yes"

if [[ $# -eq 1 && "$1" == "--noconfirm" ]]; then
    CONFIRMATION="no"
elif [[ $# -gt 0 ]]; then
    echo "Usage: $0 [--noconfirm]"
    exit 1
fi

# --- Pre-run checks ---
print_header "Running Pre-run Checks"

if [ ! -d "$SCRIPT_DIR/configs" ]; then
    print_error "Required 'configs' directory not found in the script's directory: $SCRIPT_DIR.
    Please ensure the entire repository is cloned and you are running the script from its root directory."
fi
print_success "✅ File structure confirmed."

if ! command -v git &>/dev/null; then
    print_error "git is not installed. Please install it with 'sudo pacman -S git'."
fi
if ! command -v curl &>/dev/null; then
    print_error "curl is not installed. Please install it with 'sudo pacman -S curl'."
fi
print_success "✅ Required tools (git, curl) confirmed."

# --- System-level tasks ---
print_header "Starting System-Level Setup"

# Ensure core utilities are installed first, explicitly, to avoid path issues
print_header "Installing Core Utilities"
if ! pacman -S --noconfirm sed grep coreutils; then
    print_error "Failed to install core utilities (sed, grep, tee)."
fi
print_success "✅ Core utilities installed."

# Update system and install required packages with pacman
if [ "$CONFIRMATION" == "yes" ]; then
    read -p "Update system and install packages? Press Enter to continue..."
fi

# Group 1: Core desktop utilities and fonts
CORE_PACKAGES=(
    pipewire wireplumber pamixer brightnessctl
    ttf-jetbrains-mono-nerd ttf-iosevka-nerd ttf-fira-code ttf-fira-mono
    sddm kitty nano tar unzip gnome-disk-utility code mpv dunst pacman-contrib exo firefox cava
)
if ! pacman -Syu "${CORE_PACKAGES[@]:-}" --noconfirm; then
    print_error "Failed to install core desktop packages."
fi
print_success "✅ Core desktop packages installed."

# Group 2: File manager and dependencies
THUNAR_PACKAGES=(
    thunar thunar-archive-plugin thunar-volman tumbler ffmpegthumbnailer file-roller
    gvfs gvfs-mtp gvfs-gphoto2 gvfs-smb polkit polkit-gnome
)
if ! pacman -S "${THUNAR_PACKAGES[@]:-}" --noconfirm; then
    print_error "Failed to install Thunar and dependencies."
fi
print_success "✅ Thunar and dependencies installed."

# Group 3: Hyprland and related components
HYPRLAND_PACKAGES=(
    waybar hyprland hyprpaper hypridle hyprlock starship fastfetch
)
if ! pacman -S "${HYPRLAND_PACKAGES[@]:-}" --noconfirm; then
    print_error "Failed to install Hyprland and related components."
fi
print_success "✅ Hyprland and components installed."

# --- GPU Driver Installation ---
print_header "Installing GPU Drivers"
GPU_INFO=$(lspci | grep -Ei "VGA|3D")

if echo "$GPU_INFO" | grep -qi "nvidia"; then
    print_bold_blue "NVIDIA GPU detected."
    run_command "pacman -S --noconfirm nvidia nvidia-utils nvidia-settings" "Install NVIDIA drivers"
elif echo "$GPU_INFO" | grep -qi "amd"; then
    print_bold_blue "AMD GPU detected."
    run_command "pacman -S --noconfirm xf86-video-amdgpu vulkan-radeon libva-mesa-driver mesa-vdpau" "Install AMD drivers"
elif echo "$GPU_INFO" | grep -qi "intel"; then
    print_bold_blue "Intel GPU detected."
    run_command "pacman -S --noconfirm mesa libva-intel-driver intel-media-driver vulkan-intel" "Install Intel drivers"
else
    print_warning "No supported GPU detected. Info: $GPU_INFO"
    if [ "$CONFIRMATION" == "yes" ]; then
        read -p "Try installing NVIDIA drivers anyway? [Y/n]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            run_command "pacman -S --noconfirm nvidia nvidia-utils nvidia-settings" "Install NVIDIA drivers (forced)"
        fi
    fi
fi
print_success "✅ GPU driver installation complete."

# Enable services
if [ "$CONFIRMATION" == "yes" ]; then
    read -p "Enable system services? Press Enter to continue..."
fi
systemctl enable --now polkit.service
systemctl enable sddm.service
print_success "✅ System services enabled."

# --- SDDM Theme Setup ---
SDDM_THEMES_DIR="/usr/share/sddm/themes"
THEME_NAME="dracula"

print_header "Installing and Configuring Dracula SDDM Theme"

if [ -d "$SDDM_THEMES_DIR/$THEME_NAME" ]; then
    print_success "✅ Dracula SDDM theme already installed. Skipping git clone."
else
    run_command "git clone --depth 1 https://github.com/dracula/sddm.git /tmp/$THEME_NAME-sddm-temp" "Clone the Dracula SDDM theme" "no"
    if [ -d "/tmp/$THEME_NAME-sddm-temp" ]; then
        run_command "mv /tmp/$THEME_NAME-sddm-temp $SDDM_THEMES_DIR/$THEME_NAME" "Move theme to system directory" "no"
    else
        print_error "Cloned theme directory not found. Exiting."
    fi
fi

SDDM_CONF="/etc/sddm.conf"
if ! grep -q "^Current=$THEME_NAME" "$SDDM_CONF" 2>/dev/null; then
    if grep -q "\[Theme\]" "$SDDM_CONF"; then
        run_command "sed -i '/^\[Theme\]/aCurrent=$THEME_NAME' $SDDM_CONF" "Set SDDM theme" "no"
    else
        run_command "echo -e \"\n[Theme]\nCurrent=$THEME_NAME\" | tee -a $SDDM_CONF" "Create and set SDDM theme" "no"
    fi
    print_success "✅ Set '$THEME_NAME' as the current SDDM theme."
else
    print_success "✅ SDDM theme is already set to '$THEME_NAME', skipping configuration."
fi

print_success "\n✅ System-level setup is complete! Now starting user-level setup."

# --- User-level tasks (executed as the user via sudo) ---
print_header "Starting User-Level Setup"

# Install yay
print_header "Installing AUR Packages via yay"
if ! command -v yay &>/dev/null; then
    print_bold_blue "yay is not installed. Installing it from AUR..."
    run_command "sudo -u '$USER_NAME' git clone https://aur.archlinux.org/yay.git /tmp/yay" "Clone yay repository" "no"
    run_command "sudo -u '$USER_NAME' sh -c 'cd /tmp/yay && makepkg -si --noconfirm'" "Build and install yay" "no"
    print_success "✅ yay installation complete."
else
    print_success "✅ yay is already installed, skipping installation."
fi

# Install AUR packages
AUR_PACKAGES=(
    tofi
)
if [ ${#AUR_PACKAGES[@]} -gt 0 ]; then
    if [ "$CONFIRMATION" == "yes" ]; then
        read -p "Install AUR packages (${AUR_PACKAGES[*]})? Press Enter to continue..."
    fi
    if ! sudo -u "$USER_NAME" yay -S --noconfirm "${AUR_PACKAGES[@]:-}"; then
        print_error "Failed to install AUR packages."
    fi
    print_success "✅ AUR packages installed."
fi

# Copy config files
print_header "Copying Configuration Files"
mkdir -p "$CONFIG_DIR"
chown -R "$USER_NAME":"$USER_NAME" "$CONFIG_DIR"
run_command "sudo -u '$USER_NAME' cp -rT \"$SCRIPT_DIR/configs\" \"$CONFIG_DIR\"" "Copy dotfiles and configs" "no"
print_success "✅ Configuration files copied."

# Final message
print_success "\n🎉 Installation complete! Reboot your system to start Hyprland with Dracula theming."

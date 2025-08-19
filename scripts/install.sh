#!/bin/bash
# A one-stop script for installing a Dracula-themed Hyprland setup on Arch Linux.
set -euo pipefail

# --- Helper Functions ---
print_header() { echo -e "\n--- \e[1m\e[34m$1\e[0m ---"; }
print_success() { echo -e "\e[32m$1\e[0m"; }
print_warning() { echo -e "\e[33mWarning: $1\e[0m" >&2; }
print_error() { echo -e "\e[31mError: $1\e[0m" >&2; exit 1; }
print_bold_blue() { echo -e "\e[1m\e[34m$1\e[0m"; }
run_command() {
    local cmd="$1"; local desc="$2"; local confirm="${3:-yes}"
    if [ "$confirm" == "yes" ] && [ "$CONFIRMATION" == "yes" ]; then
        read -p "Install '$desc'? Press Enter to continue..."
    fi
    echo -e "\nRunning: $cmd"
    if ! eval "$cmd"; then print_error "Failed to '$desc'."; fi
    print_success "✅ Success: '$desc'"
}

# --- Main Script ---
if [ "$EUID" -ne 0 ]; then print_error "Run as root with sudo."; fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
CONFIG_DIR="$USER_HOME/.config"
CONFIRMATION="yes"

if [[ $# -eq 1 && "$1" == "--noconfirm" ]]; then CONFIRMATION="no"; fi

# --- Pre-run checks ---
print_header "Running Pre-run Checks"
[ ! -d "$SCRIPT_DIR/configs" ] && print_error "'configs' directory missing in $SCRIPT_DIR"
command -v git >/dev/null || print_error "git not installed."
command -v curl >/dev/null || print_error "curl not installed."
print_success "✅ Pre-run checks passed."

# --- System-level packages ---
print_header "Installing Core Utilities"
pacman -S --noconfirm sed grep coreutils || print_error "Failed core utilities."

CORE_PACKAGES=(pipewire wireplumber pamixer brightnessctl ttf-jetbrains-mono-nerd ttf-iosevka-nerd ttf-fira-code ttf-fira-mono sddm kitty nano tar unzip gnome-disk-utility code mpv dunst pacman-contrib exo firefox cava)
pacman -Syu "${CORE_PACKAGES[@]}" --noconfirm || print_error "Failed core desktop packages."

THUNAR_PACKAGES=(thunar thunar-archive-plugin thunar-volman tumbler ffmpegthumbnailer file-roller gvfs gvfs-mtp gvfs-gphoto2 gvfs-smb polkit polkit-gnome)
pacman -S "${THUNAR_PACKAGES[@]}" --noconfirm || print_error "Failed Thunar packages."

HYPRLAND_PACKAGES=(waybar hyprland hyprpaper hypridle hyprlock starship fastfetch)
pacman -S "${HYPRLAND_PACKAGES[@]}" --noconfirm || print_error "Failed Hyprland packages."

# --- GPU Drivers ---
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
    print_warning "No supported GPU detected: $GPU_INFO"
fi

# --- Enable Services ---
systemctl enable sddm.service
print_success "✅ System services enabled."

# --- SDDM Dracula Theme ---
SDDM_THEMES_DIR="/usr/share/sddm/themes"
THEME_NAME="dracula"
print_header "Installing Dracula SDDM Theme"
if [ ! -d "$SDDM_THEMES_DIR/$THEME_NAME" ]; then
    run_command "git clone --depth 1 https://github.com/dracula/sddm-dracula.git /tmp/$THEME_NAME" "Clone Dracula theme" "no"
    run_command "mv /tmp/$THEME_NAME $SDDM_THEMES_DIR/$THEME_NAME" "Move theme to SDDM directory" "no"
fi

SDDM_CONF="/etc/sddm.conf"
if ! grep -q "^Current=$THEME_NAME" "$SDDM_CONF" 2>/dev/null; then
    if grep -q "\[Theme\]" "$SDDM_CONF"; then
        run_command "sed -i '/^\[Theme\]/aCurrent=$THEME_NAME' $SDDM_CONF" "Set SDDM theme" "no"
    else
        run_command "echo -e \"\n[Theme]\nCurrent=$THEME_NAME\" | tee -a $SDDM_CONF" "Create and set SDDM theme" "no"
    fi
fi

# --- User-level setup ---
print_header "User-Level Setup"

# Install yay
if ! command -v yay &>/dev/null; then
    run_command "sudo -u '$USER_NAME' git clone https://aur.archlinux.org/yay.git /tmp/yay" "Clone yay repo" "no"
    run_command "sudo -u '$USER_NAME' sh -c 'cd /tmp/yay && makepkg -si --noconfirm'" "Build and install yay" "no"
fi

# Install AUR packages
AUR_PACKAGES=(tofi)
sudo -u "$USER_NAME" yay -S --noconfirm "${AUR_PACKAGES[@]:-}"

# Copy configs
mkdir -p "$CONFIG_DIR"
chown -R "$USER_NAME":"$USER_NAME" "$CONFIG_DIR"
run_command "sudo -u '$USER_NAME' cp -rT \"$SCRIPT_DIR/configs\" \"$CONFIG_DIR\"" "Copy dotfiles/configs" "no"

print_success "\n🎉 Installation complete! Reboot to start Hyprland with Dracula theme."

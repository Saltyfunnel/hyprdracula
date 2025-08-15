#!/bin/bash
# A one-stop script for installing a Dracula-themed Hyprland setup.
# This version uses a more robust method to ensure file ownership is correct.
set -euo pipefail

# --- Global Helper Functions ---
print_header() {
    echo -e "\n--- \e[1m\e[34m$1\e[0m ---"
}

print_success() {
    echo -e "\e[32m$1\e[0m"
}

print_error() {
    echo -e "\e[31mError: $1\e[0m" >&2
    exit 1
}

# --- Main Execution Logic ---
# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root. Please run with 'sudo bash $0'."
fi

# Define variables
# The crucial change: navigate to the parent directory to find assets and configs.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
CONFIG_DIR="$USER_HOME/.config"

if [ -z "$USER_NAME" ]; then
    print_error "Could not determine the current user. Please run the script from your user account with 'sudo'."
fi
if [ -z "$USER_HOME" ]; then
    print_error "Could not determine the user's home directory. This is a critical error."
fi

# --- System-level tasks ---
print_header "Starting System-Level Setup"

# Update system and install required packages with pacman
run_command() {
    local cmd="$1"
    local desc="$2"
    echo -e "\nRunning: $desc"
    if ! eval "$cmd"; then
        print_error "Failed to run command: $desc"
    fi
    print_success "✅ $desc"
}

run_command "pacman -Syu --noconfirm git base-devel pipewire wireplumber pamixer brightnessctl starship ttf-jetbrains-mono-nerd ttf-iosevka-nerd ttf-fira-code ttf-fira-mono sddm kitty nano tar unzip gnome-disk-utility code mpv dunst pacman-contrib exo firefox cava steam thunar thunar-archive-plugin thunar-volman tumbler ffmpegthumbnailer file-roller gvfs gvfs-mtp gvfs-gphoto2 gvfs-smb polkit polkit-gnome waybar wofi hyprland hyprpaper hyprlock hypridle" "Update system and install packages"

# --- GPU Driver Installation ---
print_header "Installing GPU Drivers"
GPU_INFO=$(lspci | grep -Ei "VGA|3D")
if echo "$GPU_INFO" | grep -qi "nvidia"; then
    run_command "pacman -S --noconfirm nvidia nvidia-utils nvidia-settings" "Install NVIDIA drivers"
elif echo "$GPU_INFO" | grep -qi "amd"; then
    run_command "pacman -S --noconfirm xf86-video-amdgpu vulkan-radeon libva-mesa-driver mesa-vdpau" "Install AMD drivers"
elif echo "$GPU_INFO" | grep -qi "intel"; then
    run_command "pacman -S --noconfirm mesa libva-intel-driver intel-media-driver vulkan-intel" "Install Intel drivers"
else
    echo "Warning: No supported GPU detected."
fi

run_command "systemctl enable --now polkit.service" "Enable polkit service"
run_command "systemctl enable sddm.service" "Enable sddm service"

print_success "\n✅ System-level setup is complete! Now starting user-level setup."

# --- User-level tasks (executed with sudo and corrected ownership) ---
print_header "Starting User-Level Setup"

# This function copies files and immediately sets ownership
copy_configs() {
    local source_dir="$1"
    local dest_dir="$2"
    local config_name="$3"

    print_success "Copying $config_name..."
    # Create the directory with root and then change ownership
    if ! mkdir -p "$dest_dir"; then
        print_error "Failed to create destination directory for $config_name: '$dest_dir'."
    fi
    if ! chown -R "$USER_NAME:$USER_NAME" "$dest_dir"; then
        print_error "Failed to change ownership of '$dest_dir' to $USER_NAME."
    fi
    # Now copy as the user
    if ! sudo -u "$USER_NAME" cp -r "$source_dir/." "$dest_dir"; then
        print_error "Failed to copy $config_name."
    fi
    print_success "✅ Copied $config_name."
}

# The key fix: This is the critical section for the assets folder
print_header "Creating and Populating the assets directory"
ASSETS_SRC="$SCRIPT_DIR/assets"
ASSETS_DEST="$CONFIG_DIR/assets"

# Check if source exists
if [ ! -d "$ASSETS_SRC" ]; then
    print_error "Source assets directory not found at '$ASSETS_SRC'."
fi

# Perform all assets operations in one command as the user
run_command "sudo -u $USER_NAME bash -c \"mkdir -p '$ASSETS_DEST' && cp -r '$ASSETS_SRC/.' '$ASSETS_DEST'\"" "Create and copy assets with correct user permissions"

# Copy other config files
copy_configs "$SCRIPT_DIR/configs/waybar" "$CONFIG_DIR/waybar" "Waybar"
copy_configs "$SCRIPT_DIR/configs/fastfetch" "$CONFIG_DIR/fastfetch" "Fastfetch"
copy_configs "$SCRIPT_DIR/configs/hypr" "$CONFIG_DIR/hypr" "Hyprland"
copy_configs "$SCRIPT_DIR/configs/kitty" "$CONFIG_DIR/kitty" "Kitty"
copy_configs "$SCRIPT_DIR/configs/dunst" "$CONFIG_DIR/dunst" "Dunst"
copy_configs "$SCRIPT_DIR/configs/wofi" "$CONFIG_DIR/wofi" "Wofi"

# Update shell configs for Starship and Fastfetch
print_header "Setting up Shells"
run_command "sudo -u $USER_NAME cp -f $SCRIPT_DIR/configs/starship/starship.toml $USER_HOME/.config/starship.toml" "Copy starship config"
run_command "echo -e '\n# Added by Dracula Hyprland setup script\neval \"\$(starship init bash)\"\nif command -v fastfetch &>/dev/null; then fastfetch; fi' >> $USER_HOME/.bashrc" "Update .bashrc"
run_command "echo -e '\n# Added by Dracula Hyprland setup script\neval \"\$(starship init zsh)\"\nif command -v fastfetch &>/dev/null; then fastfetch; fi' >> $USER_HOME/.zshrc" "Update .zshrc"

print_success "\n🎉 The installation is complete! Please reboot your system to apply all changes."

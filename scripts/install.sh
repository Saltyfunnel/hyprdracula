#!/bin/bash
# A one-stop script for installing a Dracula-themed Hyprland setup on Arch Linux.
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
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root. Please run with 'sudo bash $0'."
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
CONFIG_DIR="$USER_HOME/.config"
ASSETS_DEST="$CONFIG_DIR/assets"
CONFIRMATION="yes"

if [[ $# -eq 1 && "$1" == "--noconfirm" ]]; then
    CONFIRMATION="no"
elif [[ $# -gt 0 ]]; then
    echo "Usage: $0 [--noconfirm]"
    exit 1
fi

# --- Pre-run checks ---
print_header "Running Pre-run Checks"

[ -d "$SCRIPT_DIR/configs" ] || print_error "Required 'configs' directory not found in $SCRIPT_DIR"
[ -d "$SCRIPT_DIR/assets" ] || print_error "Required 'assets' directory not found in $SCRIPT_DIR"
print_success "✅ File structure confirmed."

for tool in git curl unzip; do
    command -v $tool &>/dev/null || print_error "$tool is not installed. Please install it."
done
print_success "✅ Required tools confirmed."

# --- System-level tasks ---
print_header "Starting System-Level Setup"
PACKAGES=(
    git base-devel pipewire wireplumber pamixer brightnessctl
    ttf-jetbrains-mono-nerd ttf-iosevka-nerd ttf-fira-code ttf-fira-mono
    sddm kitty nano tar unzip gnome-disk-utility code mpv dunst pacman-contrib exo firefox cava
    thunar thunar-archive-plugin thunar-volman tumbler ffmpegthumbnailer file-roller
    gvfs gvfs-mtp gvfs-gphoto2 gvfs-smb polkit polkit-gnome
    waybar hyprland hyprpaper hypridle hyprlock starship fastfetch
)
pacman -Syu "${PACKAGES[@]:-}" --noconfirm
print_success "✅ System updated and packages installed."

# --- AUR Helper: yay Installation ---
print_header "Installing yay (AUR helper)"
YAY_DIR="$USER_HOME/yay"
if [ ! -d "$YAY_DIR" ]; then
    sudo -u "$USER_NAME" git clone https://aur.archlinux.org/yay.git "$YAY_DIR"
    cd "$YAY_DIR"
    sudo -u "$USER_NAME" makepkg -si --noconfirm
    cd "$SCRIPT_DIR" || exit
else
    print_success "✅ yay already installed."
fi

# --- AUR Apps Installation ---
print_header "Installing AUR apps via yay"
AUR_APPS=(tofi)
for app in "${AUR_APPS[@]}"; do
    print_header "Installing $app via yay"
    sudo -u "$USER_NAME" yay -S --noconfirm "$app"
done
print_success "✅ All AUR apps installed."

# --- GPU Driver Installation ---
print_header "Installing GPU Drivers"
GPU_INFO=$(lspci | grep -Ei "VGA|3D")
if echo "$GPU_INFO" | grep -qi "nvidia"; then
    print_bold_blue "NVIDIA GPU detected."
    pacman -S --noconfirm nvidia nvidia-utils nvidia-settings
elif echo "$GPU_INFO" | grep -qi "amd"; then
    print_bold_blue "AMD GPU detected."
    pacman -S --noconfirm xf86-video-amdgpu vulkan-radeon libva-mesa-driver mesa-vdpau
elif echo "$GPU_INFO" | grep -qi "intel"; then
    print_bold_blue "Intel GPU detected."
    pacman -S --noconfirm mesa libva-intel-driver intel-media-driver vulkan-intel
else
    print_warning "No supported GPU detected."
fi
print_success "✅ GPU driver installation complete."

systemctl enable --now polkit.service
systemctl enable sddm.service
print_success "✅ System services enabled."

# --- User-level tasks ---
print_header "Starting User-Level Setup"

copy_configs() {
    local source_dir="$1"
    local dest_dir="$2"
    local config_name="$3"
    print_success "Copying $config_name from '$source_dir' to '$dest_dir'."
    sudo -u "$USER_NAME" mkdir -p "$dest_dir"
    sudo -u "$USER_NAME" cp -r "$source_dir/." "$dest_dir"
    print_success "✅ Copied $config_name."
}

copy_configs "$SCRIPT_DIR/configs/waybar" "$CONFIG_DIR/waybar" "Waybar"
copy_configs "$SCRIPT_DIR/configs/hypr" "$CONFIG_DIR/hypr" "Hyprland"
copy_configs "$SCRIPT_DIR/configs/kitty" "$CONFIG_DIR/kitty" "Kitty"
copy_configs "$SCRIPT_DIR/configs/dunst" "$CONFIG_DIR/dunst" "Dunst"
copy_configs "$SCRIPT_DIR/configs/fastfetch" "$CONFIG_DIR/fastfetch" "Fastfetch"
copy_configs "$SCRIPT_DIR/configs/tofi" "$CONFIG_DIR/tofi" "Tofi"

# Copy starship.toml to root of ~/.config
STARSHIP_SRC="$SCRIPT_DIR/configs/starship/starship.toml"
if [ -f "$STARSHIP_SRC" ]; then
    sudo -u "$USER_NAME" cp "$STARSHIP_SRC" "$CONFIG_DIR/starship.toml"
fi

# Update .bashrc
BASHRC="$USER_HOME/.bashrc"
append_if_missing() {
    local file="$1"
    local line="$2"
    if ! grep -Fxq "$line" "$file"; then
        echo "$line" | sudo -u "$USER_NAME" tee -a "$file" >/dev/null
    fi
}
append_if_missing "$BASHRC" "fastfetch"
append_if_missing "$BASHRC" "eval \"\$(starship init bash)\""

# --- GTK Themes and Icons ---
THEMES_DIR="$USER_HOME/.themes"
ICONS_DIR="$USER_HOME/.icons"

sudo -u "$USER_NAME" mkdir -p "$THEMES_DIR" "$ICONS_DIR" "$ASSETS_DEST"
sudo -u "$USER_NAME" cp -r "$SCRIPT_DIR/assets/." "$ASSETS_DEST"

GTK_ZIP="$ASSETS_DEST/dracula-gtk-master.zip"
ICON_ZIP="$ASSETS_DEST/Dracula.zip"

[ -f "$GTK_ZIP" ] || print_error "GTK theme archive missing at $GTK_ZIP"
[ -f "$ICON_ZIP" ] || print_error "Icons archive missing at $ICON_ZIP"

# Extract GTK theme
sudo -u "$USER_NAME" unzip -o "$GTK_ZIP" -d "$THEMES_DIR"
EXTRACTED_GTK_DIR=$(find "$THEMES_DIR" -maxdepth 1 -type d -name "*gtk*" | head -n 1)
[ -n "$EXTRACTED_GTK_DIR" ] && [ "$(basename "$EXTRACTED_GTK_DIR")" != "dracula-gtk" ] && \
    sudo -u "$USER_NAME" mv "$EXTRACTED_GTK_DIR" "$THEMES_DIR/dracula-gtk"

# Extract Icons
sudo -u "$USER_NAME" unzip -o "$ICON_ZIP" -d "$ICONS_DIR"
EXTRACTED_ICON_DIR=$(find "$ICONS_DIR" -maxdepth 1 -mindepth 1 -type d -name "*Dracula*" | head -n 1)
[ -n "$EXTRACTED_ICON_DIR" ] && [ "$(basename "$EXTRACTED_ICON_DIR")" != "Dracula" ] && \
    sudo -u "$USER_NAME" mv "$EXTRACTED_ICON_DIR" "$ICONS_DIR/Dracula"

# Update icon cache
command -v gtk-update-icon-cache &>/dev/null && \
sudo -u "$USER_NAME" gtk-update-icon-cache -f -t "$ICONS_DIR/Dracula"

# Apply GTK and icon themes via gsettings
USER_DBUS="unix:path=/run/user/$(id -u $USER_NAME)/bus"
sudo -u "$USER_NAME" DBUS_SESSION_BUS_ADDRESS="$USER_DBUS" \
    gsettings set org.gnome.desktop.interface gtk-theme "dracula-gtk"
sudo -u "$USER_NAME" DBUS_SESSION_BUS_ADDRESS="$USER_DBUS" \
    gsettings set org.gnome.desktop.interface icon-theme "Dracula"

print_success "✅ GTK theme and icon theme applied successfully via gsettings."

print_success "\n🎉 Installation complete! Reboot to apply all changes."

#!/bin/bash
set -euo pipefail

# --------------------------
# Helper Functions (inlined)
# --------------------------
print_bold_blue() { echo -e "\e[1;34m$*\e[0m"; }
print_success() { echo -e "\e[1;32m$*\e[0m"; }
print_info() { echo -e "\e[1;36m$*\e[0m"; }
print_warning() { echo -e "\e[1;33m$*\e[0m"; }

run_command() {
    local cmd="$1" msg="$2" show_output="${3:-no}" stop_on_error="${4:-yes}"
    print_info "$msg..."
    if [[ "$show_output" == "yes" ]]; then
        eval "$cmd"
    else
        eval "$cmd" &>/dev/null
    fi
    if [[ $? -ne 0 && "$stop_on_error" == "yes" ]]; then
        print_warning "Command failed: $cmd"
        exit 1
    fi
}

copy_as_user() {
    local src="$1" dest="$2"
    [[ ! -d "$src" ]] && { print_warning "Source not found: $src"; return 1; }
    run_command "mkdir -p \"$dest\"" "Create $dest" "no" "no"
    run_command "cp -r \"$src\"/* \"$dest\"" "Copy $src -> $dest" "yes" "no"
    run_command "chown -R $USER_NAME:$USER_NAME \"$dest\"" "Fix ownership" "no" "yes"
}

add_line_to_shell() {
    local shell_rc="$1" line="$2"
    local path="$USER_HOME/$shell_rc"
    [[ -f "$path" ]] && ! grep -qF "$line" "$path" && echo -e "\n$line" >> "$path" && chown "$USER_NAME:$USER_NAME" "$path"
}

# --------------------------
# Environment
# --------------------------
SCRIPT_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo "~$USER_NAME")
CONFIG_DIR="$USER_HOME/.config"
REPO_DIR="$USER_HOME/hyprdracula"
ASSETS_SRC="$REPO_DIR/assets"
ASSETS_DEST="$CONFIG_DIR/assets"

print_bold_blue "\n🚀 Starting Full HyprDracula Setup"
echo "-------------------------------------"

# --------------------------
# Prerequisites
# --------------------------
run_command "pacman -Syyu --noconfirm" "Update system packages" "yes"
PACKAGES=(
    firefox waybar kitty nano tar gnome-disk-utility code mpv dunst exo
    thunar thunar-archive-plugin thunar-volman tumbler ffmpegthumbnailer file-roller
    gvfs gvfs-mtp gvfs-gphoto2 gvfs-smb polkit polkit-gnome sddm
    pipewire wireplumber pamixer brightnessctl
    ttf-cascadia-code-nerd ttf-cascadia-mono-nerd ttf-fira-code ttf-fira-mono ttf-fira-sans
    ttf-iosevka-nerd ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-mono
)
run_command "pacman -S --noconfirm ${PACKAGES[*]}" "Install system packages" "yes"

# Enable SDDM and Polkit
run_command "systemctl enable --now polkit.service" "Enable polkit" "yes"
run_command "systemctl enable sddm.service" "Enable SDDM" "yes"

# --------------------------
# GPU Drivers
# --------------------------
GPU_INFO=$(lspci | grep -Ei "VGA|3D")
if echo "$GPU_INFO" | grep -qi "nvidia"; then
    print_bold_blue "NVIDIA GPU detected."
    run_command "pacman -S --noconfirm nvidia nvidia-utils nvidia-settings" "Install NVIDIA drivers" "yes"
elif echo "$GPU_INFO" | grep -qi "amd"; then
    print_bold_blue "AMD GPU detected."
    run_command "pacman -S --noconfirm xf86-video-amdgpu vulkan-radeon libva-mesa-driver mesa-vdpau" "Install AMD drivers" "yes"
elif echo "$GPU_INFO" | grep -qi "intel"; then
    print_bold_blue "Intel GPU detected."
    run_command "pacman -S --noconfirm mesa libva-intel-driver intel-media-driver vulkan-intel" "Install Intel drivers" "yes"
else
    print_warning "No supported GPU detected: $GPU_INFO"
fi

# --------------------------
# Utilities
# --------------------------
copy_as_user "$REPO_DIR/configs/waybar" "$CONFIG_DIR/waybar"
copy_as_user "$REPO_DIR/configs/wofi" "$CONFIG_DIR/wofi"
copy_as_user "$REPO_DIR/configs/fastfetch" "$CONFIG_DIR/fastfetch"
copy_as_user "$REPO_DIR/configs/hypr" "$CONFIG_DIR/hypr"

# Fastfetch integration
add_line_to_shell ".bashrc" "fastfetch --kitty-direct $CONFIG_DIR/fastfetch/archkitty.png"
add_line_to_shell ".zshrc" "fastfetch --kitty-direct $CONFIG_DIR/fastfetch/archkitty.png"

# Starship
STARSHIP_SRC="$REPO_DIR/configs/starship/starship.toml"
STARSHIP_DEST="$CONFIG_DIR/starship.toml"
[ -f "$STARSHIP_SRC" ] && cp "$STARSHIP_SRC" "$STARSHIP_DEST" && chown "$USER_NAME:$USER_NAME" "$STARSHIP_DEST"
add_line_to_shell ".bashrc" 'eval "$(starship init bash)"'
add_line_to_shell ".zshrc" 'eval "$(starship init zsh)"'

# --------------------------
# Dracula GTK & Icons
# --------------------------
GTK3_DIR="$CONFIG_DIR/gtk-3.0"
GTK4_DIR="$CONFIG_DIR/gtk-4.0"
mkdir -p "$GTK3_DIR" "$GTK4_DIR"
GTK_SETTINGS="[Settings]
gtk-theme-name=Dracula
gtk-icon-theme-name=Dracula-Icons
gtk-font-name=JetBrainsMono 10"
echo "$GTK_SETTINGS" | sudo -u "$USER_NAME" tee "$GTK3_DIR/settings.ini" "$GTK4_DIR/settings.ini" >/dev/null

# Dracula icon pack
git clone https://github.com/dracula/Dracula-Icons.git /tmp/dracula-icons
cp -r /tmp/dracula-icons /usr/share/icons/Dracula-Icons
rm -rf /tmp/dracula-icons
sudo -u "$USER_NAME" dbus-launch gsettings set org.gnome.desktop.interface icon-theme 'Dracula-Icons'
sudo -u "$USER_NAME" dbus-launch gsettings set org.gnome.desktop.interface gtk-theme 'Dracula'

# --------------------------
# SDDM Dracula Theme
# --------------------------
DRACULA_SDDM_REPO="https://github.com/dracula/sddm.git"
DRACULA_TEMP="/tmp/dracula-sddm"
git clone --depth=1 "$DRACULA_SDDM_REPO" "$DRACULA_TEMP"
cp -r "$DRACULA_TEMP/sddm/themes/dracula" "/usr/share/sddm/themes/dracula"
chown -R root:root "/usr/share/sddm/themes/dracula"
mkdir -p /etc/sddm.conf.d
echo -e "[Theme]\nCurrent=dracula" > /etc/sddm.conf.d/10-theme.conf
rm -rf "$DRACULA_TEMP"

# --------------------------
# Assets
# --------------------------
copy_as_user "$ASSETS_SRC/backgrounds" "$ASSETS_DEST/backgrounds"

print_success "\n✅ HyprDracula setup complete! Reboot to apply all changes."

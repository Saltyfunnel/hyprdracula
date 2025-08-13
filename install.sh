#!/bin/bash
set -euo pipefail

# ----------------------------
# HyprDracula Full Setup Script
# ----------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo "~$USER_NAME")
REPO_DIR="$USER_HOME/hyprdracula"
CONFIG_DIR="$USER_HOME/.config"
ASSETS_SRC="$REPO_DIR/assets"
ASSETS_DEST="$CONFIG_DIR/assets"

source "$SCRIPT_DIR/helper.sh"

# ---------- Helper Functions ----------
copy_as_user() {
    local src="$1" dest="$2"
    [[ ! -d "$src" ]] && { print_warning "Source not found: $src"; return 1; }
    run_command "mkdir -p \"$dest\"" "Create $dest" "no" "no"
    run_command "cp -r \"$src\"/* \"$dest\"" "Copy $src -> $dest" "yes" "no"
    run_command "chown -R $USER_NAME:$USER_NAME \"$dest\"" "Fix ownership" "no" "yes"
}

add_fastfetch_to_shell() {
    local shell_rc="$1"
    local path="$USER_HOME/$shell_rc"
    local line="fastfetch --kitty-direct $CONFIG_DIR/fastfetch/archkitty.png"
    [[ -f "$path" ]] && ! grep -qF "$line" "$path" && echo -e "\n# Run fastfetch on terminal start\n$line" >> "$path" && chown "$USER_NAME:$USER_NAME" "$path"
}

add_starship_to_shell() {
    local shell_rc="$1" shell_name="$2"
    local path="$USER_HOME/$shell_rc"
    local line='eval "$(starship init '"$shell_name"')"'
    [[ -f "$path" ]] && ! grep -qF "$line" "$path" && echo -e "\n$line" >> "$path" && chown "$USER_NAME:$USER_NAME" "$path"
}

# ---------- Begin Setup ----------
print_bold_blue "\n🚀 Starting Full HyprDracula Setup"
echo "-------------------------------------"

check_root
check_os

# ---------- Core Packages ----------
print_header "Installing system packages..."
PACMAN_PACKAGES=(
    pipewire wireplumber pamixer brightnessctl
    ttf-cascadia-code-nerd ttf-cascadia-mono-nerd ttf-fira-code ttf-fira-mono ttf-fira-sans
    ttf-iosevka-nerd ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-mono
    sddm kitty nano tar gnome-disk-utility code mpv dunst pacman-contrib exo
    thunar thunar-archive-plugin thunar-volman tumbler ffmpegthumbnailer file-roller
    gvfs gvfs-mtp gvfs-gphoto2 gvfs-smb polkit polkit-gnome
)
run_command "pacman -Syyu --noconfirm" "Update system packages" "yes"
run_command "pacman -S --noconfirm ${PACMAN_PACKAGES[*]}" "Install core packages" "yes"

systemctl enable --now polkit.service
systemctl enable sddm.service

# ---------- GPU Drivers ----------
print_header "Detecting GPU..."
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
    print_warning "No supported GPU detected."
    ask_confirmation "Try installing NVIDIA drivers anyway?" && run_command "pacman -S --noconfirm nvidia nvidia-utils nvidia-settings" "Install NVIDIA drivers" "yes"
fi

# ---------- Yay / AUR Apps ----------
print_header "Installing AUR utilities..."
if ! command -v yay &>/dev/null; then
    print_info "Yay not found. Installing yay..."
    run_command "pacman -S --noconfirm --needed git base-devel" "Install git & base-devel" "yes"
    run_command "git clone https://aur.archlinux.org/yay.git /tmp/yay" "Clone yay" "no" "no"
    run_command "chown -R $USER_NAME:$USER_NAME /tmp/yay"
    run_command "cd /tmp/yay && sudo -u $USER_NAME makepkg -si --noconfirm" "Build yay" "no" "no"
    run_command "rm -rf /tmp/yay"
fi

YAY_APPS=(firefox tofi fastfetch swww hyprpicker hyprlock grimblast hypridle starship)
run_command "yay -S --sudoloop --noconfirm ${YAY_APPS[*]}" "Install AUR apps" "yes"

# ---------- Copy Configs ----------
copy_as_user "$REPO_DIR/configs/waybar" "$CONFIG_DIR/waybar"
copy_as_user "$REPO_DIR/configs/wofi" "$CONFIG_DIR/wofi"
copy_as_user "$REPO_DIR/configs/tofi" "$CONFIG_DIR/tofi"
copy_as_user "$REPO_DIR/configs/fastfetch" "$CONFIG_DIR/fastfetch"
copy_as_user "$REPO_DIR/configs/hypr" "$CONFIG_DIR/hypr"

# ---------- Shell Integrations ----------
add_fastfetch_to_shell ".bashrc"
add_fastfetch_to_shell ".zshrc"

STARSHIP_SRC="$REPO_DIR/configs/starship/starship.toml"
STARSHIP_DEST="$CONFIG_DIR/starship.toml"
[ -f "$STARSHIP_SRC" ] && cp "$STARSHIP_SRC" "$STARSHIP_DEST" && chown "$USER_NAME:$USER_NAME" "$STARSHIP_DEST"
add_starship_to_shell ".bashrc" "bash"
add_starship_to_shell ".zshrc" "zsh"

# ---------- GTK & Dracula Theme ----------
GTK3_DIR="$CONFIG_DIR/gtk-3.0"
GTK4_DIR="$CONFIG_DIR/gtk-4.0"
mkdir -p "$GTK3_DIR" "$GTK4_DIR"
GTK_SETTINGS="[Settings]
gtk-theme-name=Dracula
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=JetBrainsMono 10"
echo "$GTK_SETTINGS" | sudo -u "$USER_NAME" tee "$GTK3_DIR/settings.ini" "$GTK4_DIR/settings.ini" >/dev/null

# ---------- SDDM Dracula ----------
DRACULA_SDDM_REPO="https://github.com/dracula/sddm.git"
DRACULA_TEMP="/tmp/dracula-sddm"
git clone --depth=1 "$DRACULA_SDDM_REPO" "$DRACULA_TEMP"
cp -r "$DRACULA_TEMP/sddm/themes/dracula" "/usr/share/sddm/themes/dracula"
chown -R root:root "/usr/share/sddm/themes/dracula"
mkdir -p /etc/sddm.conf.d
echo -e "[Theme]\nCurrent=dracula" > /etc/sddm.conf.d/10-theme.conf
rm -rf "$DRACULA_TEMP"

# ---------- Copy Assets ----------
copy_as_user "$ASSETS_SRC/backgrounds" "$ASSETS_DEST/backgrounds"

print_bold_blue "\n✅ HyprDracula full setup complete! Reboot to apply changes."

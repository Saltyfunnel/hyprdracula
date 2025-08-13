#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo "~$USER_NAME")
REPO_DIR="$USER_HOME/hyprdracula"
CONFIG_DIR="$USER_HOME/.config"
ASSETS_SRC="$REPO_DIR/assets"
ASSETS_DEST="$CONFIG_DIR/assets"

source "$SCRIPT_DIR/helper.sh"

check_root
check_os

print_bold_blue "\n🚀 Starting Full HyprDracula Setup"
echo "-------------------------------------"

copy_as_user() {
    local src="$1"
    local dest="$2"

    if [ ! -d "$src" ]; then
        print_warning "Source folder not found: $src"
        return 1
    fi

    run_command "mkdir -p \"$dest\"" "Create destination directory $dest" "no" "no"
    run_command "cp -r \"$src\"/* \"$dest\"" "Copy from $src to $dest" "yes" "no"
    run_command "chown -R $USER_NAME:$USER_NAME \"$dest\"" "Fix ownership for $dest" "no" "yes"
}

# --- Prerequisites ---
print_header "Installing prerequisites..."
run_command "pacman -Syyu --noconfirm" "Update system packages" "yes"

if ! command -v yay &>/dev/null; then
    print_info "Yay not found. Installing yay..."
    run_command "pacman -S --noconfirm --needed git base-devel" "Install git and base-devel" "yes"
    run_command "git clone https://aur.archlinux.org/yay.git /tmp/yay" "Clone yay repository" "no" "no"
    run_command "chown -R $SUDO_USER:$SUDO_USER /tmp/yay" "Fix ownership of yay build directory" "no" "no"
    run_command "cd /tmp/yay && sudo -u $SUDO_USER makepkg -si --noconfirm" "Build and install yay" "no" "no"
    run_command "rm -rf /tmp/yay" "Clean up yay build directory" "no" "no"
else
    print_success "Yay is already installed."
fi

PACKAGES=(
    pipewire wireplumber pamixer brightnessctl
    ttf-cascadia-code-nerd ttf-cascadia-mono-nerd ttf-fira-code ttf-fira-mono ttf-fira-sans
    ttf-iosevka-nerd ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-mono
    sddm kitty nano tar gnome-disk-utility code mpv dunst pacman-contrib exo
    thunar thunar-archive-plugin thunar-volman tumbler ffmpegthumbnailer file-roller
    gvfs gvfs-mtp gvfs-gphoto2 gvfs-smb polkit polkit-gnome
)
run_command "pacman -S --noconfirm ${PACKAGES[*]}" "Install system packages" "yes"
run_command "systemctl enable --now polkit.service" "Enable polkit" "yes"
run_command "systemctl enable sddm.service" "Enable SDDM" "yes"

# --- GPU Drivers ---
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
    print_warning "No supported GPU detected: $GPU_INFO"
    if ask_confirmation "Try installing NVIDIA drivers anyway?"; then
        run_command "pacman -S --noconfirm nvidia nvidia-utils nvidia-settings" "Install NVIDIA drivers (forced)" "yes"
    fi
fi

# --- Utilities ---
print_header "Installing utilities..."
run_command "pacman -S --noconfirm waybar wofi starship cliphist" "Install utilities" "yes"
copy_as_user "$REPO_DIR/configs/waybar" "$CONFIG_DIR/waybar"
copy_as_user "$REPO_DIR/configs/wofi" "$CONFIG_DIR/wofi"
copy_as_user "$REPO_DIR/configs/fastfetch" "$CONFIG_DIR/fastfetch"
copy_as_user "$REPO_DIR/configs/hypr" "$CONFIG_DIR/hypr"

# --- Shell Integration ---
add_fastfetch_to_shell() {
    local shell_rc="$1"
    local shell_rc_path="$USER_HOME/$shell_rc"
    local fastfetch_line="fastfetch --kitty-direct $CONFIG_DIR/fastfetch/archkitty.png"

    if [ -f "$shell_rc_path" ] && ! grep -qF "$fastfetch_line" "$shell_rc_path"; then
        echo -e "\n# Run fastfetch on terminal start\n$fastfetch_line" >> "$shell_rc_path"
        chown "$USER_NAME:$USER_NAME" "$shell_rc_path"
    fi
}
add_fastfetch_to_shell ".bashrc"

STARSHIP_SRC="$REPO_DIR/configs/starship/starship.toml"
STARSHIP_DEST="$CONFIG_DIR/starship.toml"
[ -f "$STARSHIP_SRC" ] && cp "$STARSHIP_SRC" "$STARSHIP_DEST" && chown "$USER_NAME:$USER_NAME" "$STARSHIP_DEST"

add_starship_to_shell() {
    local shell_rc="$1"
    local shell_rc_path="$USER_HOME/$shell_rc"
    local starship_line="eval \"\$(starship init bash)\""

    if [ -f "$shell_rc_path" ] && ! grep -qF "$starship_line" "$shell_rc_path"; then
        echo -e "\n$starship_line" >> "$shell_rc_path"
        chown "$USER_NAME:$USER_NAME" "$shell_rc_path"
    fi
}
add_starship_to_shell ".bashrc"

# --- Dracula GTK & SDDM Theme ---
print_header "Applying Dracula theme..."
GTK3_CONFIG_DIR="$CONFIG_DIR/gtk-3.0"
GTK4_CONFIG_DIR="$CONFIG_DIR/gtk-4.0"
mkdir -p "$GTK3_CONFIG_DIR" "$GTK4_CONFIG_DIR"

GTK_SETTINGS_CONTENT="[Settings]
gtk-theme-name=Dracula
gtk-icon-theme-name=Dracula
gtk-font-name=JetBrainsMono 10"

echo "$GTK_SETTINGS_CONTENT" | sudo -u "$USER_NAME" tee "$GTK3_CONFIG_DIR/settings.ini" "$GTK4_CONFIG_DIR/settings.ini" >/dev/null

DRACULA_SDDM_REPO="https://github.com/dracula/sddm.git"
DRACULA_SDDM_TEMP="/tmp/dracula-sddm"
DRACULA_THEME_NAME="dracula"

git clone --depth=1 "$DRACULA_SDDM_REPO" "$DRACULA_SDDM_TEMP"
cp -r "$DRACULA_SDDM_TEMP/sddm/themes/$DRACULA_THEME_NAME" "/usr/share/sddm/themes/$DRACULA_THEME_NAME"
chown -R root:root "/usr/share/sddm/themes/$DRACULA_THEME_NAME"
mkdir -p /etc/sddm.conf.d
echo -e "[Theme]\nCurrent=$DRACULA_THEME_NAME" > /etc/sddm.conf.d/10-theme.conf
rm -rf "$DRACULA_SDDM_TEMP"

# --- Assets ---
copy_as_user "$ASSETS_SRC/backgrounds" "$ASSETS_DEST/backgrounds"

print_bold_blue "\n✅ HyprDracula setup complete! Reboot to apply all changes."

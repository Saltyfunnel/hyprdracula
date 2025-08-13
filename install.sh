#!/bin/bash
set -euo pipefail

# -----------------------------
# Variables
# -----------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo "~$USER_NAME")
CONFIG_DIR="$USER_HOME/.config"
REPO_DIR="$USER_HOME/hyprdracula"
ASSETS_SRC="$REPO_DIR/assets"
ASSETS_DEST="$CONFIG_DIR/assets"

# -----------------------------
# Helper functions
# -----------------------------
log_message() {
    echo -e "\e[36m[INFO]\e[0m $1"
}

print_success() { echo -e "\e[32m[SUCCESS]\e[0m $1"; }
print_warning() { echo -e "\e[33m[WARN]\e[0m $1"; }
print_info()    { echo -e "\e[34m[INFO]\e[0m $1"; }
print_bold_blue() { echo -e "\e[1;34m$1\e[0m"; }

run_command() {
    local cmd="$1" description="$2" show_output="${3:-no}" exit_on_fail="${4:-yes}"
    print_info "$description..."
    if [ "$show_output" = "yes" ]; then
        eval "$cmd"
    else
        eval "$cmd" &>/dev/null
    fi
    if [ $? -eq 0 ]; then
        print_success "$description completed"
    else
        print_warning "$description failed"
        [ "$exit_on_fail" = "yes" ] && exit 1
    fi
}

copy_as_user() {
    local src="$1" dest="$2"
    [[ ! -d "$src" ]] && { print_warning "Source not found: $src"; return 1; }
    run_command "mkdir -p \"$dest\"" "Create $dest" "no" "no"
    run_command "cp -r \"$src\"/* \"$dest\"" "Copy $src -> $dest" "yes" "no"
    run_command "chown -R $USER_NAME:$USER_NAME \"$dest\"" "Fix ownership of $dest" "no" "yes"
}

# -----------------------------
# System prerequisites
# -----------------------------
print_bold_blue "\n🚀 Starting Full HyprDracula Setup"
run_command "pacman -Syyu --noconfirm" "Update system packages"

# Install yay if missing
if ! command -v yay &>/dev/null; then
    print_info "Yay not found. Installing..."
    run_command "pacman -S --noconfirm --needed git base-devel" "Install git and base-devel"
    run_command "git clone https://aur.archlinux.org/yay.git /tmp/yay" "Clone yay"
    run_command "chown -R $USER_NAME:$USER_NAME /tmp/yay" "Fix ownership"
    run_command "cd /tmp/yay && sudo -u $USER_NAME makepkg -si --noconfirm" "Build and install yay"
    run_command "rm -rf /tmp/yay" "Clean yay build directory"
else
    print_success "Yay is already installed"
fi

# -----------------------------
# System packages
# -----------------------------
PACMAN_APPS=(
    pipewire wireplumber pamixer brightnessctl
    ttf-cascadia-code-nerd ttf-cascadia-mono-nerd ttf-fira-code ttf-fira-mono ttf-fira-sans
    ttf-iosevka-nerd ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-mono
    sddm kitty nano tar gnome-disk-utility code mpv dunst pacman-contrib exo
    thunar thunar-archive-plugin thunar-volman tumbler ffmpegthumbnailer file-roller
    gvfs gvfs-mtp gvfs-gphoto2 gvfs-smb polkit polkit-gnome firefox
)
run_command "pacman -S --noconfirm ${PACMAN_APPS[*]}" "Install system packages"
run_command "systemctl enable --now polkit.service" "Enable polkit"
run_command "systemctl enable sddm.service" "Enable SDDM"

# -----------------------------
# AUR packages
# -----------------------------
AUR_APPS=(wofi fastfetch swww hyprpicker hyprlock grimblast hypridle starship)
print_info "\nInstalling AUR packages as $USER_NAME..."
for app in "${AUR_APPS[@]}"; do
    sudo -u "$USER_NAME" yay -S --noconfirm "$app"
done

# -----------------------------
# GPU Drivers
# -----------------------------
print_header() { echo -e "\n\e[1;35m$1\e[0m"; }
print_header "Detecting GPU..."
GPU_INFO=$(lspci | grep -Ei "VGA|3D")
if echo "$GPU_INFO" | grep -qi "nvidia"; then
    run_command "pacman -S --noconfirm nvidia nvidia-utils nvidia-settings" "Install NVIDIA drivers"
elif echo "$GPU_INFO" | grep -qi "amd"; then
    run_command "pacman -S --noconfirm xf86-video-amdgpu vulkan-radeon libva-mesa-driver mesa-vdpau" "Install AMD drivers"
elif echo "$GPU_INFO" | grep -qi "intel"; then
    run_command "pacman -S --noconfirm mesa libva-intel-driver intel-media-driver vulkan-intel" "Install Intel drivers"
else
    print_warning "No supported GPU detected: $GPU_INFO"
fi

# -----------------------------
# Copy configs
# -----------------------------
copy_as_user "$REPO_DIR/configs/waybar" "$CONFIG_DIR/waybar"
copy_as_user "$REPO_DIR/configs/wofi" "$CONFIG_DIR/wofi"
copy_as_user "$REPO_DIR/configs/fastfetch" "$CONFIG_DIR/fastfetch"
copy_as_user "$REPO_DIR/configs/hypr" "$CONFIG_DIR/hypr"

# -----------------------------
# Shell integration
# -----------------------------
add_fastfetch_to_shell() {
    local shell_rc="$1"
    local path="$USER_HOME/$shell_rc"
    local line="fastfetch --kitty-direct $CONFIG_DIR/fastfetch/archkitty.png"
    [[ -f "$path" ]] && ! grep -qF "$line" "$path" && echo -e "\n# Run fastfetch\n$line" >> "$path" && chown "$USER_NAME:$USER_NAME" "$path"
}
add_fastfetch_to_shell ".bashrc"
add_fastfetch_to_shell ".zshrc"

STARSHIP_SRC="$REPO_DIR/configs/starship/starship.toml"
STARSHIP_DEST="$CONFIG_DIR/starship.toml"
[[ -f "$STARSHIP_SRC" ]] && cp "$STARSHIP_SRC" "$STARSHIP_DEST" && chown "$USER_NAME:$USER_NAME" "$STARSHIP_DEST"

add_starship_to_shell() {
    local shell_rc="$1" shell_name="$2"
    local line="eval \"\$(starship init $shell_name)\""
    local path="$USER_HOME/$shell_rc"
    [[ -f "$path" ]] && ! grep -qF "$line" "$path" && echo -e "\n$line" >> "$path" && chown "$USER_NAME:$USER_NAME" "$path"
}
add_starship_to_shell ".bashrc" "bash"
add_starship_to_shell ".zshrc" "zsh"

# -----------------------------
# Dracula GTK + icon theme
# -----------------------------
GTK3_DIR="$CONFIG_DIR/gtk-3.0"
GTK4_DIR="$CONFIG_DIR/gtk-4.0"
mkdir -p "$GTK3_DIR" "$GTK4_DIR"

GTK_SETTINGS="[Settings]
gtk-theme-name=Dracula
gtk-icon-theme-name=Dracula
gtk-font-name=JetBrainsMono 10"
echo "$GTK_SETTINGS" | sudo -u "$USER_NAME" tee "$GTK3_DIR/settings.ini" "$GTK4_DIR/settings.ini" >/dev/null

# -----------------------------
# SDDM Dracula theme
# -----------------------------
DRACULA_SDDM_REPO="https://github.com/dracula/sddm.git"
DRACULA_TEMP="/tmp/dracula-sddm"
git clone --depth=1 "$DRACULA_SDDM_REPO" "$DRACULA_TEMP"
cp -r "$DRACULA_TEMP/sddm/themes/dracula" "/usr/share/sddm/themes/dracula"
chown -R root:root "/usr/share/sddm/themes/dracula"
mkdir -p /etc/sddm.conf.d
echo -e "[Theme]\nCurrent=dracula" > /etc/sddm.conf.d/10-theme.conf
rm -rf "$DRACULA_TEMP"

# -----------------------------
# Copy assets
# -----------------------------
copy_as_user "$ASSETS_SRC/backgrounds" "$ASSETS_DEST/backgrounds"

# -----------------------------
# Final message
# -----------------------------
print_bold_blue "\n✅ HyprDracula setup complete! Reboot to apply all changes."

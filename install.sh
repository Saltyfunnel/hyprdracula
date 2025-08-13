#!/bin/bash
set -euo pipefail

# ---------------------------
# --- Helper Functions ---
# ---------------------------
print_bold_blue() { echo -e "\033[1;34m$*\033[0m"; }
print_success() { echo -e "\033[1;32m$*\033[0m"; }
print_info() { echo -e "\033[1;36m$*\033[0m"; }
print_warning() { echo -e "\033[1;33m$*\033[0m"; }

run_command() {
    local cmd="$1" msg="$2" show_output="${3:-no}" fail_ok="${4:-no}"
    print_info "$msg..."
    if [[ "$show_output" == "yes" ]]; then
        eval "$cmd" || { [[ "$fail_ok" == "no" ]] && { print_warning "Failed: $msg"; exit 1; } }
    else
        eval "$cmd" &>/dev/null || { [[ "$fail_ok" == "no" ]] && { print_warning "Failed: $msg"; exit 1; } }
    fi
}

ask_confirmation() {
    read -rp "$1 [y/N]: " response
    [[ "$response" =~ ^[Yy]$ ]]
}

# ---------------------------
# --- Variables ---
# ---------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo "~$USER_NAME")
CONFIG_DIR="$USER_HOME/.config"
REPO_DIR="$USER_HOME/hyprdracula"
ASSETS_SRC="$REPO_DIR/assets"
ASSETS_DEST="$CONFIG_DIR/assets"

print_bold_blue "\n🚀 Starting Full HyprDracula Setup"
echo "-------------------------------------"

copy_as_user() {
    local src="$1" dest="$2"
    [[ ! -d "$src" ]] && { print_warning "Source not found: $src"; return 1; }
    run_command "mkdir -p \"$dest\"" "Create $dest" "no"
    run_command "cp -r \"$src\"/* \"$dest\"" "Copy $src -> $dest" "yes"
    run_command "chown -R $USER_NAME:$USER_NAME \"$dest\"" "Fix ownership" "no"
}

# ---------------------------
# --- System Update & Yay ---
# ---------------------------
print_info "\nInstalling prerequisites..."
run_command "pacman -Syyu --noconfirm" "Update system packages"

if ! command -v yay &>/dev/null; then
    print_info "Yay not found. Installing yay..."
    run_command "pacman -S --noconfirm --needed git base-devel" "Install git and base-devel"
    run_command "git clone https://aur.archlinux.org/yay.git /tmp/yay" "Clone yay repo"
    run_command "chown -R $USER_NAME:$USER_NAME /tmp/yay" "Fix ownership of yay build directory"
    run_command "cd /tmp/yay && sudo -u $USER_NAME makepkg -si --noconfirm" "Build and install yay"
    run_command "rm -rf /tmp/yay" "Cleanup yay temp"
else
    print_success "Yay is already installed."
fi

# ---------------------------
# --- Pacman Packages ---
# ---------------------------
PACMAN_PACKAGES=(
    pipewire wireplumber pamixer brightnessctl
    ttf-cascadia-code-nerd ttf-cascadia-mono-nerd ttf-fira-code ttf-fira-mono ttf-fira-sans
    ttf-iosevka-nerd ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-mono
    sddm kitty nano tar gnome-disk-utility code mpv dunst pacman-contrib exo
    thunar thunar-archive-plugin thunar-volman tumbler ffmpegthumbnailer file-roller
    gvfs gvfs-mtp gvfs-gphoto2 gvfs-smb polkit polkit-gnome firefox
)
run_command "pacman -S --noconfirm ${PACMAN_PACKAGES[*]}" "Install system packages"

run_command "systemctl enable --now polkit.service" "Enable polkit"
run_command "systemctl enable sddm.service" "Enable SDDM"

# ---------------------------
# --- GPU Drivers ---
# ---------------------------
print_info "\nDetecting GPU..."
GPU_INFO=$(lspci | grep -Ei "VGA|3D")
if echo "$GPU_INFO" | grep -qi "nvidia"; then
    print_info "NVIDIA GPU detected."
    run_command "pacman -S --noconfirm nvidia nvidia-utils nvidia-settings" "Install NVIDIA drivers"
elif echo "$GPU_INFO" | grep -qi "amd"; then
    print_info "AMD GPU detected."
    run_command "pacman -S --noconfirm xf86-video-amdgpu vulkan-radeon libva-mesa-driver mesa-vdpau" "Install AMD drivers"
elif echo "$GPU_INFO" | grep -qi "intel"; then
    print_info "Intel GPU detected."
    run_command "pacman -S --noconfirm mesa libva-intel-driver intel-media-driver vulkan-intel" "Install Intel drivers"
else
    print_warning "No supported GPU detected: $GPU_INFO"
    if ask_confirmation "Try installing NVIDIA drivers anyway?"; then
        run_command "pacman -S --noconfirm nvidia nvidia-utils nvidia-settings" "Install NVIDIA drivers (forced)"
    fi
fi

# ---------------------------
# --- AUR/Yay Apps ---
# ---------------------------
AUR_APPS=(wofi fastfetch swww hyprpicker hyprlock grimblast hypridle starship)
run_command "yay -S --sudoloop --noconfirm ${AUR_APPS[*]}" "Install AUR apps"

# ---------------------------
# --- Configs ---
# ---------------------------
copy_as_user "$REPO_DIR/configs/waybar" "$CONFIG_DIR/waybar"
copy_as_user "$REPO_DIR/configs/wofi" "$CONFIG_DIR/wofi"
copy_as_user "$REPO_DIR/configs/fastfetch" "$CONFIG_DIR/fastfetch"
copy_as_user "$REPO_DIR/configs/hypr" "$CONFIG_DIR/hypr"

# --- Fastfetch Shell Integration ---
add_fastfetch_to_shell() {
    local shell_rc="$1" line="fastfetch --kitty-direct $CONFIG_DIR/fastfetch/archkitty.png"
    local path="$USER_HOME/$shell_rc"
    [[ -f "$path" ]] && ! grep -qF "$line" "$path" && echo -e "\n# Run fastfetch on terminal start\n$line" >> "$path" && chown "$USER_NAME:$USER_NAME" "$path"
}
add_fastfetch_to_shell ".bashrc"
add_fastfetch_to_shell ".zshrc"

# --- Starship Shell Integration ---
STARSHIP_SRC="$REPO_DIR/configs/starship/starship.toml"
STARSHIP_DEST="$CONFIG_DIR/starship.toml"
[[ -f "$STARSHIP_SRC" ]] && cp "$STARSHIP_SRC" "$STARSHIP_DEST" && chown "$USER_NAME:$USER_NAME" "$STARSHIP_DEST"

add_starship_to_shell() {
    local shell_rc="$1" shell_name="$2"
    local line='eval "$(starship init '"$shell_name"')"'
    local path="$USER_HOME/$shell_rc"
    [[ -f "$path" ]] && ! grep -qF "$line" "$path" && echo -e "\n$line" >> "$path" && chown "$USER_NAME:$USER_NAME" "$path"
}
add_starship_to_shell ".bashrc" "bash"
add_starship_to_shell ".zshrc" "zsh"

# ---------------------------
# --- Dracula GTK & Icon Theme ---
# ---------------------------
GTK3_DIR="$CONFIG_DIR/gtk-3.0"
GTK4_DIR="$CONFIG_DIR/gtk-4.0"
mkdir -p "$GTK3_DIR" "$GTK4_DIR"

GTK_SETTINGS="[Settings]
gtk-theme-name=Dracula
gtk-icon-theme-name=Dracula
gtk-font-name=JetBrainsMono 10"
echo "$GTK_SETTINGS" | sudo -u "$USER_NAME" tee "$GTK3_DIR/settings.ini" "$GTK4_DIR/settings.ini" >/dev/null

# ---------------------------
# --- Dracula SDDM Theme ---
# ---------------------------
DRACULA_SDDM_REPO="https://github.com/dracula/sddm.git"
DRACULA_TEMP="/tmp/dracula-sddm"
git clone --depth=1 "$DRACULA_SDDM_REPO" "$DRACULA_TEMP"
cp -r "$DRACULA_TEMP/sddm/themes/dracula" "/usr/share/sddm/themes/dracula"
chown -R root:root "/usr/share/sddm/themes/dracula"
mkdir -p /etc/sddm.conf.d
echo -e "[Theme]\nCurrent=dracula" > /etc/sddm.conf.d/10-theme.conf
rm -rf "$DRACULA_TEMP"

# ---------------------------
# --- Assets ---
# ---------------------------
copy_as_user "$ASSETS_SRC/backgrounds" "$ASSETS_DEST/backgrounds"

# ---------------------------
# --- Thunar Kitty Action ---
# ---------------------------
THUNAR_DIR="$CONFIG_DIR/Thunar"
mkdir -p "$THUNAR_DIR" && chown "$USER_NAME:$USER_NAME" "$THUNAR_DIR" && chmod 700 "$THUNAR_DIR"
UCA_FILE="$THUNAR_DIR/uca.xml"
KITTY_ACTION='<action><icon>utilities-terminal</icon><name>Open Kitty Here</name><command>kitty --directory=%d</command><description>Open kitty terminal in the current folder</description><patterns>*</patterns><directories_only>true</directories_only><startup_notify>true</startup_notify></action>'
if [ ! -f "$UCA_FILE" ]; then
    cat > "$UCA_FILE" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<actions>
$KITTY_ACTION
</actions>
EOF
    chown "$USER_NAME:$USER_NAME" "$UCA_FILE"
elif ! grep -q "<name>Open Kitty Here</name>" "$UCA_FILE"; then
    sed -i "/<\/actions>/ i\\
$KITTY_ACTION
" "$UCA_FILE"
    chown "$USER_NAME:$USER_NAME" "$UCA_FILE"
fi

print_success "\n🎉 HyprDracula Full Setup Completed!"

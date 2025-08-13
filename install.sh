#!/bin/bash
set -euo pipefail

# ---------------- Helper Functions ----------------
print_info()    { echo -e "\033[1;34m[INFO]\033[0m $*"; }
print_success() { echo -e "\033[1;32m[SUCCESS]\033[0m $*"; }
print_warning() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
print_bold_blue() { echo -e "\033[1;94m$*\033[0m"; }

run_command() {
    local cmd="$1" description="$2" show_output="${3:-yes}" exit_on_fail="${4:-yes}"
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
    run_command "mkdir -p \"$dest\"" "Create $dest" "no"
    run_command "cp -r \"$src\"/* \"$dest\"" "Copy $src -> $dest" "no"
    run_command "chown -R $USER_NAME:$USER_NAME \"$dest\"" "Fix ownership" "no"
}

add_to_shell() {
    local shell_rc="$1" line="$2"
    local path="$USER_HOME/$shell_rc"
    [[ -f "$path" ]] && ! grep -qF "$line" "$path" && echo -e "\n$line" >> "$path" && chown "$USER_NAME:$USER_NAME" "$path"
}

# ---------------- Script Variables ----------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo "~$USER_NAME")
CONFIG_DIR="$USER_HOME/.config"
REPO_DIR="$USER_HOME/hyprdracula"
ASSETS_SRC="$REPO_DIR/assets"
ASSETS_DEST="$CONFIG_DIR/assets"

PACMAN_APPS=(
    pipewire wireplumber pamixer brightnessctl
    ttf-cascadia-code-nerd ttf-cascadia-mono-nerd ttf-fira-code ttf-fira-mono ttf-fira-sans
    ttf-iosevka-nerd ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-mono
    sddm kitty nano tar gnome-disk-utility code mpv dunst pacman-contrib exo
    thunar thunar-archive-plugin thunar-volman tumbler ffmpegthumbnailer file-roller
    gvfs gvfs-mtp gvfs-gphoto2 gvfs-smb polkit polkit-gnome firefox
)

AUR_APPS=(
    wofi starship fastfetch swww hyprpicker hyprlock grimblast hypridle
)

# ---------------- Root & OS Check ----------------
[[ $EUID -ne 0 ]] && { print_warning "Please run as root"; exit 1; }
print_bold_blue "\n🚀 Starting Full HyprDracula Setup"

# ---------------- Update System ----------------
run_command "pacman -Syyu --noconfirm" "Update system packages"

# ---------------- Install Pacman Packages ----------------
run_command "pacman -S --noconfirm ${PACMAN_APPS[*]}" "Install system packages"

# ---------------- Install Yay (if missing) ----------------
if ! command -v yay &>/dev/null; then
    print_info "Yay not found. Installing yay..."
    run_command "pacman -S --noconfirm --needed git base-devel" "Install git/base-devel"
    run_command "git clone https://aur.archlinux.org/yay.git /tmp/yay" "Clone yay repo"
    run_command "chown -R $SUDO_USER:$SUDO_USER /tmp/yay" "Fix yay build ownership"
    run_command "cd /tmp/yay && sudo -u $SUDO_USER makepkg -si --noconfirm" "Build & install yay"
    run_command "rm -rf /tmp/yay" "Clean yay build directory"
fi

# ---------------- Install AUR Packages ----------------
for app in "${AUR_APPS[@]}"; do
    run_command "sudo -u \"$USER_NAME\" yay -S --noconfirm $app" "Install AUR package $app"
done

# ---------------- GPU Drivers ----------------
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

# ---------------- Utilities & Configs ----------------
copy_as_user "$REPO_DIR/configs/waybar" "$CONFIG_DIR/waybar"
copy_as_user "$REPO_DIR/configs/wofi" "$CONFIG_DIR/wofi"
copy_as_user "$REPO_DIR/configs/fastfetch" "$CONFIG_DIR/fastfetch"
copy_as_user "$REPO_DIR/configs/hypr" "$CONFIG_DIR/hypr"

# Fastfetch in shell
add_to_shell ".bashrc" "fastfetch --kitty-direct $CONFIG_DIR/fastfetch/archkitty.png"
add_to_shell ".zshrc"   "fastfetch --kitty-direct $CONFIG_DIR/fastfetch/archkitty.png"

# Starship
STARSHIP_SRC="$REPO_DIR/configs/starship/starship.toml"
STARSHIP_DEST="$CONFIG_DIR/starship.toml"
[ -f "$STARSHIP_SRC" ] && cp "$STARSHIP_SRC" "$STARSHIP_DEST" && chown "$USER_NAME:$USER_NAME" "$STARSHIP_DEST"
add_to_shell ".bashrc" 'eval "$(starship init bash)"'
add_to_shell ".zshrc"   'eval "$(starship init zsh)"'

# ---------------- Dracula GTK & Icons ----------------
GTK3_DIR="$CONFIG_DIR/gtk-3.0"
GTK4_DIR="$CONFIG_DIR/gtk-4.0"
mkdir -p "$GTK3_DIR" "$GTK4_DIR"
GTK_SETTINGS="[Settings]
gtk-theme-name=Dracula
gtk-icon-theme-name=Dracula
gtk-font-name=JetBrainsMono 10"
echo "$GTK_SETTINGS" | sudo -u "$USER_NAME" tee "$GTK3_DIR/settings.ini" "$GTK4_DIR/settings.ini" >/dev/null

# ---------------- SDDM Dracula ----------------
DRACULA_SDDM_REPO="https://github.com/dracula/sddm.git"
DRACULA_TEMP="/tmp/dracula-sddm"
git clone --depth=1 "$DRACULA_SDDM_REPO" "$DRACULA_TEMP"
cp -r "$DRACULA_TEMP/sddm/themes/dracula" "/usr/share/sddm/themes/dracula"
chown -R root:root "/usr/share/sddm/themes/dracula"
mkdir -p /etc/sddm.conf.d
echo -e "[Theme]\nCurrent=dracula" > /etc/sddm.conf.d/10-theme.conf
rm -rf "$DRACULA_TEMP"

# ---------------- Copy Assets ----------------
copy_as_user "$ASSETS_SRC/backgrounds" "$ASSETS_DEST/backgrounds"

print_bold_blue "\n✅ HyprDracula setup complete! Reboot to apply all changes."

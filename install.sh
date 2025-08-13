#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo "~$USER_NAME")
REPO_DIR="$USER_HOME/hyprdracula"
CONFIG_DIR="$USER_HOME/.config"
ASSETS_SRC="$REPO_DIR/assets"
ASSETS_DEST="$CONFIG_DIR/assets"

# --- Helper functions ---
log() { echo -e "\e[34m[INFO]\e[0m $1"; }
success() { echo -e "\e[32m[SUCCESS]\e[0m $1"; }
warn() { echo -e "\e[33m[WARN]\e[0m $1"; }

run_command() {
    log "Running: $1"
    if ! eval "$1"; then
        warn "Command failed: $1"
    fi
}

copy_as_user() {
    local src="$1" dest="$2"
    if [[ -d "$src" ]]; then
        run_command "mkdir -p \"$dest\""
        run_command "cp -r \"$src\"/* \"$dest\""
        run_command "chown -R $USER_NAME:$USER_NAME \"$dest\""
    else
        warn "Source folder missing: $src"
    fi
}

# --- System update ---
log "Updating system packages..."
sudo pacman -Syyu --noconfirm

# --- Install Pacman packages ---
PACMAN_PACKAGES=(
    firefox
    pipewire wireplumber pamixer brightnessctl
    ttf-cascadia-code-nerd ttf-cascadia-mono-nerd ttf-fira-code ttf-fira-mono ttf-fira-sans
    ttf-iosevka-nerd ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-mono
    sddm kitty nano tar gnome-disk-utility code mpv dunst pacman-contrib exo
    thunar thunar-archive-plugin thunar-volman tumbler ffmpegthumbnailer file-roller
    gvfs gvfs-mtp gvfs-gphoto2 gvfs-smb polkit polkit-gnome
    waybar wofi starship cliphist
)
run_command "sudo pacman -S --noconfirm ${PACMAN_PACKAGES[*]}"

# --- Enable services ---
run_command "sudo systemctl enable --now polkit.service sddm.service"

# --- GPU Drivers ---
GPU_INFO=$(lspci | grep -Ei "VGA|3D")
if echo "$GPU_INFO" | grep -qi "nvidia"; then
    run_command "sudo pacman -S --noconfirm nvidia nvidia-utils nvidia-settings"
elif echo "$GPU_INFO" | grep -qi "amd"; then
    run_command "sudo pacman -S --noconfirm xf86-video-amdgpu vulkan-radeon libva-mesa-driver mesa-vdpau"
elif echo "$GPU_INFO" | grep -qi "intel"; then
    run_command "sudo pacman -S --noconfirm mesa libva-intel-driver intel-media-driver vulkan-intel"
else
    warn "No supported GPU detected. Skipping GPU driver installation."
fi

# --- Install Yay if missing ---
if ! command -v yay &>/dev/null; then
    log "Installing yay..."
    sudo pacman -S --noconfirm git base-devel
    sudo -u "$USER_NAME" git clone https://aur.archlinux.org/yay.git /tmp/yay
    run_command "cd /tmp/yay && sudo -u $USER_NAME makepkg -si --noconfirm"
    run_command "rm -rf /tmp/yay"
fi

# --- AUR Packages ---
AUR_PACKAGES=(
    hyprpicker hyprlock grimblast hypridle
    fastfetch
)
run_command "yay -S --noconfirm ${AUR_PACKAGES[*]}"

# --- Copy configs ---
copy_as_user "$REPO_DIR/configs/waybar" "$CONFIG_DIR/waybar"
copy_as_user "$REPO_DIR/configs/wofi" "$CONFIG_DIR/wofi"
copy_as_user "$REPO_DIR/configs/fastfetch" "$CONFIG_DIR/fastfetch"
copy_as_user "$REPO_DIR/configs/hypr" "$CONFIG_DIR/hypr"

# --- Fastfetch integration ---
for shell in .bashrc .zshrc; do
    LINE="fastfetch --kitty-direct $CONFIG_DIR/fastfetch/archkitty.png"
    FILE="$USER_HOME/$shell"
    if [[ -f "$FILE" ]] && ! grep -qF "$LINE" "$FILE"; then
        echo -e "\n# Run fastfetch on terminal start\n$LINE" >> "$FILE"
        chown "$USER_NAME:$USER_NAME" "$FILE"
    fi
done

# --- Starship setup ---
STARSHIP_SRC="$REPO_DIR/configs/starship/starship.toml"
STARSHIP_DEST="$CONFIG_DIR/starship.toml"
[[ -f "$STARSHIP_SRC" ]] && cp "$STARSHIP_SRC" "$STARSHIP_DEST" && chown "$USER_NAME:$USER_NAME" "$STARSHIP_DEST"

for shell in .bashrc .zshrc; do
    LINE='eval "$(starship init bash)"'
    FILE="$USER_HOME/$shell"
    if [[ -f "$FILE" ]] && ! grep -qF "$LINE" "$FILE"; then
        echo -e "\n$LINE" >> "$FILE"
        chown "$USER_NAME:$USER_NAME" "$FILE"
    fi
done

# --- Dracula GTK and icons ---
GTK3_DIR="$CONFIG_DIR/gtk-3.0"
GTK4_DIR="$CONFIG_DIR/gtk-4.0"
mkdir -p "$GTK3_DIR" "$GTK4_DIR"
GTK_SETTINGS="[Settings]
gtk-theme-name=Dracula
gtk-icon-theme-name=Dracula
gtk-font-name=JetBrainsMono 10"
echo "$GTK_SETTINGS" | sudo -u "$USER_NAME" tee "$GTK3_DIR/settings.ini" "$GTK4_DIR/settings.ini" >/dev/null

# --- Dracula Icon Theme from GitHub ---
DRACULA_ICON_REPO="https://github.com/dracula/gtk-theme.git"
ICON_DEST="$USER_HOME/.icons/Dracula"
sudo -u "$USER_NAME" git clone --depth=1 "$DRACULA_ICON_REPO" "$ICON_DEST"
chown -R "$USER_NAME:$USER_NAME" "$ICON_DEST"

# --- SDDM Dracula theme ---
DRACULA_SDDM_REPO="https://github.com/dracula/sddm.git"
DRACULA_TEMP="/tmp/dracula-sddm"
git clone --depth=1 "$DRACULA_SDDM_REPO" "$DRACULA_TEMP"
sudo cp -r "$DRACULA_TEMP/sddm/themes/dracula" "/usr/share/sddm/themes/dracula"
sudo chown -R root:root "/usr/share/sddm/themes/dracula"
mkdir -p /etc/sddm.conf.d
echo -e "[Theme]\nCurrent=dracula" | sudo tee /etc/sddm.conf.d/10-theme.conf
rm -rf "$DRACULA_TEMP"

# --- Copy assets ---
copy_as_user "$ASSETS_SRC/backgrounds" "$ASSETS_DEST/backgrounds"

success "✅ HyprDracula setup complete! Reboot to apply all changes."

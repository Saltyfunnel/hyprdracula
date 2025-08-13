#!/bin/bash

set -euo pipefail

# -------------------------------
# Variables
# -------------------------------
SCRIPT_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo "~$USER_NAME")
CONFIG_DIR="$USER_HOME/.config"
REPO_DIR="$USER_HOME/hyprdracula"
ASSETS_SRC="$REPO_DIR/assets"
ASSETS_DEST="$CONFIG_DIR/assets"

PACMAN_PACKAGES=(
pipewire wireplumber pamixer brightnessctl ttf-cascadia-code-nerd ttf-cascadia-mono-nerd
ttf-fira-code ttf-fira-mono ttf-fira-sans ttf-iosevka-nerd ttf-jetbrains-mono-nerd
ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-mono sddm kitty nano tar gnome-disk-utility
code mpv dunst pacman-contrib exo thunar thunar-archive-plugin thunar-volman tumbler
ffmpegthumbnailer file-roller gvfs gvfs-mtp gvfs-gphoto2 gvfs-smb polkit polkit-gnome
waybar cliphist firefox
)

AUR_PACKAGES=(
wofi fastfetch swww hyprpicker hyprlock grimblast hypridle starship
)

# -------------------------------
# Helper functions
# -------------------------------
log() { echo -e "\e[1;34m[INFO]\e[0m $*"; }
success() { echo -e "\e[1;32m[SUCCESS]\e[0m $*"; }
warn() { echo -e "\e[1;33m[WARN]\e[0m $*"; }

run() {
    log "Running: $*"
    eval "$*"
}

copy_as_user() {
    local src="$1" dest="$2"
    if [[ ! -d "$src" ]]; then
        warn "Source not found: $src"
        return
    fi
    run "mkdir -p \"$dest\""
    run "cp -r \"$src\"/* \"$dest\""
    run "chown -R $USER_NAME:$USER_NAME \"$dest\""
}

# -------------------------------
# 1. Pacman installs
# -------------------------------
log "Installing pacman packages..."
sudo pacman -Syu --noconfirm "${PACMAN_PACKAGES[@]}"
success "Pacman packages installed."

# -------------------------------
# 2. AUR installs (as user)
# -------------------------------
log "Installing AUR packages..."
for pkg in "${AUR_PACKAGES[@]}"; do
    cd "$USER_HOME"
    if [[ -d "${pkg}-aur" ]]; then rm -rf "${pkg}-aur"; fi
    git clone "https://aur.archlinux.org/${pkg}.git" "${pkg}-aur"
    cd "${pkg}-aur"
    makepkg -si --noconfirm
    cd "$USER_HOME"
    rm -rf "${pkg}-aur"
done
success "AUR packages installed."

# -------------------------------
# 3. Copy configs
# -------------------------------
copy_as_user "$REPO_DIR/configs/waybar" "$CONFIG_DIR/waybar"
copy_as_user "$REPO_DIR/configs/wofi" "$CONFIG_DIR/wofi"
copy_as_user "$REPO_DIR/configs/fastfetch" "$CONFIG_DIR/fastfetch"
copy_as_user "$REPO_DIR/configs/hypr" "$CONFIG_DIR/hypr"
copy_as_user "$REPO_DIR/configs/starship" "$CONFIG_DIR/starship"
copy_as_user "$ASSETS_SRC/backgrounds" "$ASSETS_DEST/backgrounds"

# -------------------------------
# 4. Fastfetch & Starship in shell
# -------------------------------
for shell_rc in ".bashrc" ".zshrc"; do
    RC_PATH="$USER_HOME/$shell_rc"
    [[ -f "$RC_PATH" ]] || touch "$RC_PATH"
    grep -qxF "fastfetch --kitty-direct $CONFIG_DIR/fastfetch/archkitty.png" "$RC_PATH" || \
        echo -e "\n# Run fastfetch on terminal start\nfastfetch --kitty-direct $CONFIG_DIR/fastfetch/archkitty.png" >> "$RC_PATH"

    grep -qxF 'eval "$(starship init bash)"' "$RC_PATH" || \
        echo 'eval "$(starship init bash)"' >> "$RC_PATH"
done

# -------------------------------
# 5. Dracula GTK & icons
# -------------------------------
GTK3_DIR="$CONFIG_DIR/gtk-3.0"
GTK4_DIR="$CONFIG_DIR/gtk-4.0"
mkdir -p "$GTK3_DIR" "$GTK4_DIR"

GTK_SETTINGS="[Settings]
gtk-theme-name=Dracula
gtk-icon-theme-name=Dracula
gtk-font-name=JetBrainsMono 10"

echo "$GTK_SETTINGS" > "$GTK3_DIR/settings.ini"
echo "$GTK_SETTINGS" > "$GTK4_DIR/settings.ini"
chown -R $USER_NAME:$USER_NAME "$CONFIG_DIR"

# -------------------------------
# 6. Dracula SDDM theme
# -------------------------------
SDDM_DRACULA="/usr/share/sddm/themes/dracula"
sudo mkdir -p "$SDDM_DRACULA"
sudo cp -r "$REPO_DIR/sddm/dracula/"* "$SDDM_DRACULA"
sudo chown -R root:root "$SDDM_DRACULA"
sudo mkdir -p /etc/sddm.conf.d
echo -e "[Theme]\nCurrent=dracula" | sudo tee /etc/sddm.conf.d/10-theme.conf

# -------------------------------
# 7. Oh My Zsh & default shell
# -------------------------------
if [[ ! -d "$USER_HOME/.oh-my-zsh" ]]; then
    run "sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\" || true"
fi
chsh -s "$(which zsh)" "$USER_NAME"

success "All setup completed. Please log out and back in to apply SDDM, GTK, and shell changes."

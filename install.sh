#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo "~$USER_NAME")
CONFIG_DIR="$USER_HOME/.config"
REPO_DIR="$USER_HOME/hyprdracula"
ASSETS_SRC="$REPO_DIR/assets"
ASSETS_DEST="$CONFIG_DIR/assets"

run_command() {
    echo -e "\n[RUNNING] $1"
    eval "$1"
    echo -e "[DONE] $1"
}

copy_as_user() {
    local src="$1" dest="$2"
    [[ ! -d "$src" ]] && { echo "[WARN] Source not found: $src"; return 1; }
    run_command "mkdir -p \"$dest\""
    run_command "cp -r \"$src\"/* \"$dest\""
    run_command "chown -R $USER_NAME:$USER_NAME \"$dest\""
}

echo -e "\n[INFO] Updating pacman and installing packages with live output"
PACMAN_PACKAGES=(
    pipewire wireplumber pamixer brightnessctl
    ttf-cascadia-code-nerd ttf-cascadia-mono-nerd ttf-fira-code ttf-fira-mono ttf-fira-sans
    ttf-iosevka-nerd ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-mono
    sddm kitty nano tar gnome-disk-utility code mpv dunst pacman-contrib exo thunar
    thunar-archive-plugin thunar-volman tumbler ffmpegthumbnailer file-roller gvfs gvfs-mtp
    gvfs-gphoto2 gvfs-smb polkit polkit-gnome waybar cliphist firefox
)
sudo pacman -Syu --needed --noconfirm "${PACMAN_PACKAGES[@]}"

echo -e "\n[INFO] Installing AUR packages with yay (live output)"
AUR_PACKAGES=(
    wofi swww hyprpicker hyprlock grimblast hypridle
    fastfetch starship
)
sudo -u "$USER_NAME" yay -S --needed --noconfirm "${AUR_PACKAGES[@]}"

# Copy configs
copy_as_user "$REPO_DIR/configs/waybar" "$CONFIG_DIR/waybar"
copy_as_user "$REPO_DIR/configs/wofi" "$CONFIG_DIR/wofi"
copy_as_user "$REPO_DIR/configs/hypr" "$CONFIG_DIR/hypr"
copy_as_user "$REPO_DIR/configs/fastfetch" "$CONFIG_DIR/fastfetch"
copy_as_user "$REPO_DIR/configs/starship" "$CONFIG_DIR/starship"
copy_as_user "$ASSETS_SRC/backgrounds" "$ASSETS_DEST/backgrounds"

# Fastfetch and Starship setup
for shell_rc in .bashrc .zshrc; do
    path="$USER_HOME/$shell_rc"
    fastfetch_line="fastfetch --kitty-direct $CONFIG_DIR/fastfetch/archkitty.png"
    starship_line='eval "$(starship init '"${shell_rc#.}"')"'
    [[ -f "$path" ]] && ! grep -qF "$fastfetch_line" "$path" && echo -e "\n# Run fastfetch on terminal start\n$fastfetch_line" >> "$path"
    [[ -f "$path" ]] && ! grep -qF "$starship_line" "$path" && echo -e "\n$starship_line" >> "$path"
done

# Oh My Zsh and default shell
if [[ ! -d "$USER_HOME/.oh-my-zsh" ]]; then
    sudo -u "$USER_NAME" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    chsh -s "$(which zsh)" "$USER_NAME"
fi

# Dracula icons
DRACULA_ICONS_REPO="https://github.com/dracula/papirus.git"
TMP_DIR=$(mktemp -d)
git clone --depth=1 "$DRACULA_ICONS_REPO" "$TMP_DIR"
cp -r "$TMP_DIR" "$USER_HOME/.icons/dracula"
chown -R "$USER_NAME:$USER_NAME" "$USER_HOME/.icons/dracula"
rm -rf "$TMP_DIR"

# GTK3/4 Dracula theme
GTK3_DIR="$CONFIG_DIR/gtk-3.0"
GTK4_DIR="$CONFIG_DIR/gtk-4.0"
mkdir -p "$GTK3_DIR" "$GTK4_DIR"
GTK_SETTINGS="[Settings]
gtk-theme-name=Dracula
gtk-icon-theme-name=dracula
gtk-font-name=JetBrainsMono 10"
echo "$GTK_SETTINGS" | sudo -u "$USER_NAME" tee "$GTK3_DIR/settings.ini" "$GTK4_DIR/settings.ini" >/dev/null

# SDDM Dracula theme
DRACULA_SDDM_REPO="https://github.com/dracula/sddm.git"
DRACULA_TEMP="/tmp/dracula-sddm"
git clone --depth=1 "$DRACULA_SDDM_REPO" "$DRACULA_TEMP"
sudo cp -r "$DRACULA_TEMP/sddm/themes/dracula" "/usr/share/sddm/themes/dracula"
sudo chown -R root:root "/usr/share/sddm/themes/dracula"
sudo mkdir -p /etc/sddm.conf.d
echo -e "[Theme]\nCurrent=dracula" | sudo tee /etc/sddm.conf.d/10-theme.conf
rm -rf "$DRACULA_TEMP"

echo -e "\n[SETUP COMPLETE] All packages installed with live output, configs applied, themes set, and Zsh default shell."

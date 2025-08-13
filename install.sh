#!/bin/bash

# ---------------------------------------
# One-stop setup script for your Arch setup
# ---------------------------------------

set -e
SCRIPT_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo "~$USER_NAME")
CONFIG_DIR="$USER_HOME/.config"
REPO_DIR="$USER_HOME/hyprdracula"    # Your Dracula repo
ASSETS_SRC="$REPO_DIR/assets"
ASSETS_DEST="$CONFIG_DIR/assets"

log() { echo -e "[INFO] $1"; }
warn() { echo -e "[WARN] $1"; }
error() { echo -e "[ERROR] $1"; }

run() {
    echo -e "\n[RUNNING] $1"
    eval "$1"
}

copy_as_user() {
    local src="$1" dest="$2"
    [[ ! -d "$src" ]] && { warn "Source not found: $src"; return 1; }
    run "mkdir -p \"$dest\""
    run "cp -r \"$src\"/* \"$dest\""
    run "chown -R $USER_NAME:$USER_NAME \"$dest\""
}

# --------------------
# Pacman Packages
# --------------------
PACMAN_PACKAGES=(
pipewire wireplumber pamixer brightnessctl \
ttf-cascadia-code-nerd ttf-cascadia-mono-nerd ttf-fira-code ttf-fira-mono ttf-fira-sans \
ttf-iosevka-nerd ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-mono \
sddm kitty nano tar gnome-disk-utility code mpv dunst pacman-contrib \
exo thunar thunar-archive-plugin thunar-volman tumbler ffmpegthumbnailer file-roller gvfs gvfs-mtp gvfs-gphoto2 gvfs-smb \
polkit polkit-gnome waybar cliphist firefox
)

run "sudo pacman -Syu --noconfirm ${PACMAN_PACKAGES[*]}"

# --------------------
# AUR Packages (install manually if pacman version missing)
# --------------------
AUR_PACKAGES=(
wofi fastfetch swww hyprpicker hyprlock grimblast hypridle starship
)

for pkg in "${AUR_PACKAGES[@]}"; do
    run "git clone https://aur.archlinux.org/${pkg}.git $USER_HOME/${pkg}-aur"
    run "cd $USER_HOME/${pkg}-aur && makepkg -si --noconfirm"
    run "rm -rf $USER_HOME/${pkg}-aur"
done

# --------------------
# Copy configs
# --------------------
copy_as_user "$REPO_DIR/configs/waybar" "$CONFIG_DIR/waybar"
copy_as_user "$REPO_DIR/configs/wofi" "$CONFIG_DIR/wofi"
copy_as_user "$REPO_DIR/configs/fastfetch" "$CONFIG_DIR/fastfetch"
copy_as_user "$REPO_DIR/configs/hypr" "$CONFIG_DIR/hypr"
copy_as_user "$REPO_DIR/configs/starship" "$CONFIG_DIR/starship"
copy_as_user "$ASSETS_SRC/backgrounds" "$ASSETS_DEST/backgrounds"

# --------------------
# Fastfetch integration
# --------------------
for shell_rc in ".bashrc" ".zshrc"; do
    rc_file="$USER_HOME/$shell_rc"
    line="fastfetch --kitty-direct $CONFIG_DIR/fastfetch/archkitty.png"
    [[ -f "$rc_file" ]] && ! grep -qF "$line" "$rc_file" && \
        echo -e "\n# Run fastfetch on terminal start\n$line" >> "$rc_file" && \
        chown "$USER_NAME:$USER_NAME" "$rc_file"
done

# --------------------
# Starship shell
# --------------------
for shell_rc in ".bashrc" ".zshrc"; do
    rc_file="$USER_HOME/$shell_rc"
    line='eval "$(starship init bash)"'
    [[ -f "$rc_file" ]] && ! grep -qF "$line" "$rc_file" && \
        echo -e "\n$line" >> "$rc_file" && \
        chown "$USER_NAME:$USER_NAME" "$rc_file"
done

# --------------------
# Oh My Zsh & default shell
# --------------------
run "sudo -u $USER_NAME sh -c \"$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\" --unattended"
run "chsh -s $(which zsh) $USER_NAME"

# --------------------
# Dracula Icons
# --------------------
DRACULA_ICONS_REPO="https://github.com/dracula/gtk-theme.git"
DRACULA_ICONS_TEMP="$USER_HOME/dracula-icons-temp"
run "git clone --depth=1 $DRACULA_ICONS_REPO $DRACULA_ICONS_TEMP"
copy_as_user "$DRACULA_ICONS_TEMP/icons" "$CONFIG_DIR/icons"
rm -rf "$DRACULA_ICONS_TEMP"

# --------------------
# GTK3/4 Dracula theme
# --------------------
GTK3_DIR="$CONFIG_DIR/gtk-3.0"
GTK4_DIR="$CONFIG_DIR/gtk-4.0"
mkdir -p "$GTK3_DIR" "$GTK4_DIR"
GTK_SETTINGS="[Settings]
gtk-theme-name=Dracula
gtk-icon-theme-name=Dracula
gtk-font-name=JetBrainsMono 10"
echo "$GTK_SETTINGS" | tee "$GTK3_DIR/settings.ini" "$GTK4_DIR/settings.ini" >/dev/null
chown -R $USER_NAME:$USER_NAME "$GTK3_DIR" "$GTK4_DIR"

# --------------------
# SDDM Dracula theme
# --------------------
DRACULA_SDDM_REPO="https://github.com/dracula/sddm.git"
DRACULA_TEMP="$USER_HOME/dracula-sddm-temp"
run "git clone --depth=1 $DRACULA_SDDM_REPO $DRACULA_TEMP"
sudo cp -r "$DRACULA_TEMP/sddm/themes/dracula" /usr/share/sddm/themes/dracula
sudo chown -R root:root /usr/share/sddm/themes/dracula
sudo mkdir -p /etc/sddm.conf.d
echo -e "[Theme]\nCurrent=dracula" | sudo tee /etc/sddm.conf.d/10-theme.conf >/dev/null
rm -rf "$DRACULA_TEMP"

echo -e "\n[SETUP COMPLETE] All utilities, themes, and shell configuration applied!"

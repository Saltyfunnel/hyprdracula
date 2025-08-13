#!/bin/bash
set -euo pipefail

# -------------------------------
# Basic Variables
# -------------------------------
SCRIPT_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo "~$USER_NAME")
CONFIG_DIR="$USER_HOME/.config"
REPO_DIR="$USER_HOME/hyprdracula"    # Your Dracula repo
ASSETS_SRC="$REPO_DIR/assets"
ASSETS_DEST="$CONFIG_DIR/assets"

# -------------------------------
# Helpers
# -------------------------------
run_as_root() {
    echo "Running as root: $*"
    sudo bash -c "$*"
}

copy_as_user() {
    local src="$1" dest="$2"
    [[ ! -d "$src" ]] && { echo "Source not found: $src"; return 1; }
    mkdir -p "$dest"
    cp -r "$src"/* "$dest"
    chown -R "$USER_NAME:$USER_NAME" "$dest"
}

# -------------------------------
# Pacman packages (root)
# -------------------------------
PACMAN_PACKAGES=(
pipewire wireplumber pamixer brightnessctl ttf-cascadia-code-nerd ttf-cascadia-mono-nerd
ttf-fira-code ttf-fira-mono ttf-fira-sans ttf-iosevka-nerd ttf-jetbrains-mono-nerd
ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-mono sddm kitty nano tar gnome-disk-utility
code mpv dunst pacman-contrib exo thunar thunar-archive-plugin thunar-volman tumbler
ffmpegthumbnailer file-roller gvfs gvfs-mtp gvfs-gphoto2 gvfs-smb polkit polkit-gnome
waybar cliphist firefox
)

echo "Installing Pacman packages..."
sudo pacman -Syu --noconfirm "${PACMAN_PACKAGES[@]}"

# -------------------------------
# AUR packages (normal user)
# -------------------------------
AUR_PACKAGES=(
wofi fastfetch swww hyprpicker hyprlock grimblast hypridle starship
)

cd "$USER_HOME"
for pkg in "${AUR_PACKAGES[@]}"; do
    echo "Installing AUR package: $pkg"
    if [[ -d "${pkg}-aur" ]]; then rm -rf "${pkg}-aur"; fi
    git clone "https://aur.archlinux.org/${pkg}.git" "${pkg}-aur"
    cd "${pkg}-aur"
    makepkg -si --noconfirm
    cd "$USER_HOME"
    rm -rf "${pkg}-aur"
done

# -------------------------------
# Oh My Zsh + default shell
# -------------------------------
if ! command -v zsh &>/dev/null; then
    sudo pacman -S --noconfirm zsh
fi

if [ ! -d "$USER_HOME/.oh-my-zsh" ]; then
    echo "Installing Oh My Zsh..."
    RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

chsh -s "$(which zsh)" "$USER_NAME"

# -------------------------------
# Copy config files
# -------------------------------
copy_as_user "$REPO_DIR/configs/waybar" "$CONFIG_DIR/waybar"
copy_as_user "$REPO_DIR/configs/wofi" "$CONFIG_DIR/wofi"
copy_as_user "$REPO_DIR/configs/fastfetch" "$CONFIG_DIR/fastfetch"
copy_as_user "$REPO_DIR/configs/hypr" "$CONFIG_DIR/hypr"
copy_as_user "$ASSETS_SRC/backgrounds" "$ASSETS_DEST/backgrounds"

# -------------------------------
# Fastfetch in shell
# -------------------------------
for shell_rc in ".bashrc" ".zshrc"; do
    path="$USER_HOME/$shell_rc"
    line="fastfetch --kitty-direct $CONFIG_DIR/fastfetch/archkitty.png"
    if [[ -f "$path" ]] && ! grep -qF "$line" "$path"; then
        echo -e "\n# Run fastfetch on terminal start\n$line" >> "$path"
        chown "$USER_NAME:$USER_NAME" "$path"
    fi
done

# -------------------------------
# Starship config
# -------------------------------
STARSHIP_SRC="$REPO_DIR/configs/starship/starship.toml"
STARSHIP_DEST="$CONFIG_DIR/starship.toml"
[[ -f "$STARSHIP_SRC" ]] && cp "$STARSHIP_SRC" "$STARSHIP_DEST" && chown "$USER_NAME:$USER_NAME" "$STARSHIP_DEST"

for shell_rc in ".bashrc" ".zshrc"; do
    line='eval "$(starship init '"${shell_rc#.}"')"'
    path="$USER_HOME/$shell_rc"
    [[ -f "$path" ]] && ! grep -qF "$line" "$path" && echo -e "\n$line" >> "$path" && chown "$USER_NAME:$USER_NAME" "$path"
done

# -------------------------------
# Dracula icon theme
# -------------------------------
DRACULA_ICONS_REPO="https://github.com/dracula/gtk.git"
TMP_DIR=$(mktemp -d)
git clone "$DRACULA_ICONS_REPO" "$TMP_DIR"
run_as_root "cp -r $TMP_DIR/icons /usr/share/icons/Dracula"
rm -rf "$TMP_DIR"

# -------------------------------
# GTK3/4 Dracula theme
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
chown "$USER_NAME:$USER_NAME" "$GTK3_DIR/settings.ini" "$GTK4_DIR/settings.ini"

# -------------------------------
# Dracula SDDM theme
# -------------------------------
DRACULA_SDDM_REPO="https://github.com/dracula/sddm.git"
DRACULA_TEMP="/tmp/dracula-sddm"
git clone --depth=1 "$DRACULA_SDDM_REPO" "$DRACULA_TEMP"
run_as_root "cp -r $DRACULA_TEMP/sddm/themes/dracula /usr/share/sddm/themes/dracula"
run_as_root "mkdir -p /etc/sddm.conf.d"
run_as_root "echo -e '[Theme]\nCurrent=dracula' > /etc/sddm.conf.d/10-theme.conf"
rm -rf "$DRACULA_TEMP"

echo "Setup complete! Reboot to apply SDDM theme and GTK settings."

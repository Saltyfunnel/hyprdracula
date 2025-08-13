#!/bin/bash
set -euo pipefail

USER_NAME="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo "~$USER_NAME")
CONFIG_DIR="$USER_HOME/.config"
REPO_DIR="$USER_HOME/hyprdracula"
ASSETS_SRC="$REPO_DIR/assets"
ASSETS_DEST="$CONFIG_DIR/assets"

# -------------------------------
# Pacman packages
# -------------------------------
PACMAN_PACKAGES=(
pipewire wireplumber pamixer brightnessctl
ttf-cascadia-code-nerd ttf-cascadia-mono-nerd ttf-fira-code ttf-fira-mono ttf-fira-sans
ttf-iosevka-nerd ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-mono
sddm kitty nano tar gnome-disk-utility code mpv dunst pacman-contrib exo thunar
thunar-archive-plugin thunar-volman tumbler ffmpegthumbnailer file-roller gvfs gvfs-mtp
gvfs-gphoto2 gvfs-smb polkit polkit-gnome waybar cliphist firefox zsh
)

sudo pacman -Syu --noconfirm "${PACMAN_PACKAGES[@]}"

# -------------------------------
# AUR packages (normal user)
# -------------------------------
AUR_PACKAGES=(wofi fastfetch swww hyprpicker hyprlock grimblast hypridle starship)

sudo -u "$USER_NAME" bash <<'EOF'
set -e
cd "$HOME"
if ! command -v yay &>/dev/null; then
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd ..
    rm -rf yay
fi
yay -S --noconfirm "${AUR_PACKAGES[@]}"
EOF

# -------------------------------
# Oh My Zsh + default shell
# -------------------------------
sudo -u "$USER_NAME" bash <<'EOF'
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi
EOF
sudo chsh -s "$(command -v zsh)" "$USER_NAME"

# -------------------------------
# Copy configs & assets
# -------------------------------
sudo -u "$USER_NAME" mkdir -p "$CONFIG_DIR"
sudo -u "$USER_NAME" cp -r "$REPO_DIR/configs/." "$CONFIG_DIR/"
sudo -u "$USER_NAME" mkdir -p "$ASSETS_DEST"
sudo -u "$USER_NAME" cp -r "$ASSETS_SRC/." "$ASSETS_DEST/"

# -------------------------------
# Dracula icons & GTK theme
# -------------------------------
TMP_DIR=$(mktemp -d)
sudo -u "$USER_NAME" git clone --depth=1 https://github.com/dracula/gtk.git "$TMP_DIR"
sudo cp -r "$TMP_DIR/icons" /usr/share/icons/Dracula
rm -rf "$TMP_DIR"

GTK_SETTINGS="[Settings]
gtk-theme-name=Dracula
gtk-icon-theme-name=Dracula
gtk-font-name=JetBrainsMono 10"
sudo -u "$USER_NAME" mkdir -p "$CONFIG_DIR/gtk-3.0" "$CONFIG_DIR/gtk-4.0"
echo "$GTK_SETTINGS" | sudo -u "$USER_NAME" tee "$CONFIG_DIR/gtk-3.0/settings.ini" >/dev/null
echo "$GTK_SETTINGS" | sudo -u "$USER_NAME" tee "$CONFIG_DIR/gtk-4.0/settings.ini" >/dev/null

# -------------------------------
# Dracula SDDM theme
# -------------------------------
TMP_DIR=$(mktemp -d)
sudo -u "$USER_NAME" git clone --depth=1 https://github.com/dracula/sddm.git "$TMP_DIR"
sudo cp -r "$TMP_DIR/sddm/themes/dracula" /usr/share/sddm/themes/dracula
sudo mkdir -p /etc/sddm.conf.d
echo -e "[Theme]\nCurrent=dracula" | sudo tee /etc/sddm.conf.d/10-theme.conf >/dev/null
rm -rf "$TMP_DIR"

echo "✅ Setup complete — reboot to apply themes."

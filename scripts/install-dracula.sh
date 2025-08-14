#!/bin/bash

# =============================================
# Dracula Hyprland Setup (all-in-one)
# =============================================

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo "~$USER_NAME")
CONFIG_DIR="$USER_HOME/.config"
REPO_DIR="$USER_HOME/hyprdracula"
ASSETS_SRC="$REPO_DIR/assets"
ASSETS_DEST="$CONFIG_DIR/assets"

# Helper functions
run_as_user() {
    sudo -u "$USER_NAME" bash -c "$1"
}

copy_as_user() {
    local src="$1"
    local dest="$2"

    if [ ! -d "$src" ]; then
        echo "Warning: source folder not found: $src"
        return 1
    fi

    mkdir -p "$dest"
    cp -r "$src"/* "$dest"
    chown -R "$USER_NAME:$USER_NAME" "$dest"
}

# -------------------------------
# System prerequisites
# -------------------------------
echo "Updating system packages..."
pacman -Syyu --noconfirm

echo "Installing core system packages..."
PACKAGES=(
    git base-devel sddm kitty nano tar gnome-disk-utility code mpv dunst pacman-contrib exo firefox cava
    thunar thunar-archive-plugin thunar-volman tumbler ffmpegthumbnailer file-roller
    gvfs gvfs-mtp gvfs-gphoto2 gvfs-smb
    polkit polkit-gnome pipewire wireplumber pamixer brightnessctl
    ttf-cascadia-code-nerd ttf-cascadia-mono-nerd ttf-fira-code ttf-fira-mono ttf-fira-sans
    ttf-iosevka-nerd ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-mono
)
pacman -S --noconfirm "${PACKAGES[@]}"

# Enable essential services
systemctl enable --now polkit.service
systemctl enable sddm.service

# -------------------------------
# Yay installation (if missing)
# -------------------------------
if ! command -v yay &>/dev/null; then
    echo "Installing yay..."
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    chown -R "$USER_NAME:$USER_NAME" /tmp/yay
    run_as_user "cd /tmp/yay && makepkg -si --noconfirm"
    rm -rf /tmp/yay
fi

# -------------------------------
# Install AUR packages
# -------------------------------
AUR_PACKAGES=(tofi fastfetch swww hyprpicker hyprlock grimblast hypridle starship spotify protonplus)
run_as_user "yay -S --noconfirm ${AUR_PACKAGES[*]}"

# -------------------------------
# Copy configs and assets
# -------------------------------
copy_as_user "$REPO_DIR/configs/waybar" "$CONFIG_DIR/waybar"
copy_as_user "$REPO_DIR/configs/tofi" "$CONFIG_DIR/tofi"
copy_as_user "$REPO_DIR/configs/fastfetch" "$CONFIG_DIR/fastfetch"
copy_as_user "$REPO_DIR/configs/hypr" "$CONFIG_DIR/hypr"
copy_as_user "$REPO_DIR/configs/kitty" "$CONFIG_DIR/kitty"
copy_as_user "$REPO_DIR/configs/dunst" "$CONFIG_DIR/dunst"
copy_as_user "$ASSETS_SRC/backgrounds" "$ASSETS_DEST/backgrounds"

# -------------------------------
# Dracula Tofi Config
# -------------------------------
run_as_user "mkdir -p $CONFIG_DIR/tofi"
cat << 'EOF' | run_as_user "tee $CONFIG_DIR/tofi/config >/dev/null"
font = "JetBrainsMono Nerd Font:size=14"
width = 60
height = 200
border-width = 2
padding = 15
corner-radius = 12
background-color = rgba(40,42,54,0.85)
border-color = #bd93f9
text-color = #f8f8f2
selection-color = #44475a
selection-text-color = #f8f8f2
prompt-color = #ff79c6
EOF

# -------------------------------
# Fastfetch integration
# -------------------------------
for shell in ".bashrc" ".zshrc"; do
    shell_file="$USER_HOME/$shell"
    line="fastfetch --kitty-direct $USER_HOME/.config/fastfetch/archkitty.png"
    if [ -f "$shell_file" ] && ! grep -qF "$line" "$shell_file"; then
        echo -e "\n# Run fastfetch on terminal start\n$line" >> "$shell_file"
        chown "$USER_NAME:$USER_NAME" "$shell_file"
    fi
done

# -------------------------------
# Starship integration
# -------------------------------
STARSHIP_SRC="$REPO_DIR/configs/starship/starship.toml"
STARSHIP_DEST="$CONFIG_DIR/starship.toml"
[ -f "$STARSHIP_SRC" ] && cp "$STARSHIP_SRC" "$STARSHIP_DEST" && chown "$USER_NAME:$USER_NAME" "$STARSHIP_DEST"

for shell in ".bashrc" ".zshrc"; do
    shell_file="$USER_HOME/$shell"
    line='eval "$(starship init '${shell#.}')')"'
    if [ -f "$shell_file" ] && ! grep -qF "$line" "$shell_file"; then
        echo -e "\n$line" >> "$shell_file"
        chown "$USER_NAME:$USER_NAME" "$shell_file"
    fi
done

# -------------------------------
# GTK Dracula Theme
# -------------------------------
GTK3="$USER_HOME/.config/gtk-3.0"
GTK4="$USER_HOME/.config/gtk-4.0"
mkdir -p "$GTK3" "$GTK4"
cat << EOF | run_as_user "tee $GTK3/settings.ini $GTK4/settings.ini >/dev/null"
[Settings]
gtk-theme-name=Dracula
gtk-icon-theme-name=Dracula
gtk-font-name=JetBrainsMono 10
EOF

# Apply GTK theme via gsettings
run_as_user "dbus-launch gsettings set org.gnome.desktop.interface gtk-theme 'Dracula'"
run_as_user "dbus-launch gsettings set org.gnome.desktop.interface icon-theme 'Dracula'"

# -------------------------------
# Thunar custom action (kitty)
# -------------------------------
THUNAR_DIR="$CONFIG_DIR/Thunar"
UCA_FILE="$THUNAR_DIR/uca.xml"
mkdir -p "$THUNAR_DIR" && chown "$USER_NAME:$USER_NAME" "$THUNAR_DIR" && chmod 700 "$THUNAR_DIR"

cat << EOF > "$UCA_FILE"
<?xml version="1.0" encoding="UTF-8"?>
<actions>
  <action>
    <icon>utilities-terminal</icon>
    <name>Open Kitty Here</name>
    <command>kitty --directory=%d</command>
    <description>Open kitty terminal in the current folder</description>
    <patterns>*</patterns>
    <directories_only>true</directories_only>
    <startup_notify>true</startup_notify>
  </action>
</actions>
EOF
chown "$USER_NAME:$USER_NAME" "$UCA_FILE"

echo "===================================="
echo "Dracula setup complete!"
echo "===================================="

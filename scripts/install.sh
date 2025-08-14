#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="$(eval echo "~$USER_NAME")"
CONFIG_DIR="$USER_HOME/.config"
REPO_DIR="$USER_HOME/hyprdracula"
ASSETS_SRC="$REPO_DIR/assets"
ASSETS_DEST="$CONFIG_DIR/assets"

source "$SCRIPT_DIR/helper.sh"

# --- Helpers ---
copy_as_user() {
    local src="$1"
    local dest="$2"
    if [ ! -d "$src" ]; then
        print_warning "Source folder not found: $src"
        return
    fi
    run_command "mkdir -p \"$dest\"" "Create $dest" "no" "no"
    run_command "cp -r \"$src\"/* \"$dest\"" "Copy $src -> $dest" "yes" "no"
    run_command "chown -R $USER_NAME:$USER_NAME \"$dest\"" "Fix ownership for $dest" "no" "yes"
}

add_fastfetch_to_shell() {
    local shell_rc="$1"
    local shell_rc_path="$USER_HOME/$shell_rc"
    local fastfetch_line="fastfetch --kitty-direct $CONFIG_DIR/fastfetch/archkitty.png"
    if [ -f "$shell_rc_path" ] && ! grep -qF "$fastfetch_line" "$shell_rc_path"; then
        echo -e "\n# Run fastfetch on terminal start\n$fastfetch_line" >> "$shell_rc_path"
        chown "$USER_NAME:$USER_NAME" "$shell_rc_path"
    fi
}

add_starship_to_shell() {
    local shell_rc="$1"
    local shell_name="$2"
    local shell_rc_path="$USER_HOME/$shell_rc"
    local starship_line="eval \"\$(starship init $shell_name)\""
    if [ -f "$shell_rc_path" ] && ! grep -qF "$starship_line" "$shell_rc_path"; then
        echo -e "\n$starship_line" >> "$shell_rc_path"
        chown "$USER_NAME:$USER_NAME" "$shell_rc_path"
    fi
}

# --- Root checks ---
check_root
check_os

print_header "Starting Full Dracula Hyprland Setup"

# --- System packages ---
PACKAGES=(
    git base-devel yay pipewire wireplumber pamixer brightnessctl
    ttf-jetbrains-mono-nerd ttf-iosevka-nerd ttf-fira-code ttf-fira-mono
    sddm kitty nano tar gnome-disk-utility code mpv dunst pacman-contrib exo firefox cava
    thunar thunar-archive-plugin thunar-volman tumbler ffmpegthumbnailer file-roller
    gvfs gvfs-mtp gvfs-gphoto2 gvfs-smb polkit polkit-gnome
)
run_command "pacman -Syu --noconfirm" "Update system packages" "yes"
run_command "pacman -S --noconfirm ${PACKAGES[*]}" "Install system packages" "yes"

# --- Enable services ---
run_command "systemctl enable --now polkit.service" "Enable polkit" "yes"
run_command "systemctl enable sddm.service" "Enable SDDM" "yes"

# --- Install yay if missing ---
if ! command -v yay &>/dev/null; then
    run_command "git clone https://aur.archlinux.org/yay.git /tmp/yay" "Clone yay" "no" "no"
    run_command "chown -R $USER_NAME:$USER_NAME /tmp/yay" "Fix ownership" "no" "no"
    run_command "cd /tmp/yay && sudo -u $USER_NAME makepkg -si --noconfirm" "Build yay" "no" "no"
    run_command "rm -rf /tmp/yay" "Clean yay temp" "no" "no"
fi

# --- AUR utilities ---
AUR_PACKAGES=(tofi fastfetch swww hyprpicker hyprlock grimblast hypridle starship spotify protonplus)
for pkg in "${AUR_PACKAGES[@]}"; do
    run_command "yay -S --noconfirm $pkg" "Install $pkg via AUR" "yes" "no"
done

# --- Copy configs ---
copy_as_user "$REPO_DIR/configs/waybar" "$CONFIG_DIR/waybar"
copy_as_user "$REPO_DIR/configs/tofi" "$CONFIG_DIR/tofi"
copy_as_user "$REPO_DIR/configs/fastfetch" "$CONFIG_DIR/fastfetch"
copy_as_user "$REPO_DIR/configs/hypr" "$CONFIG_DIR/hypr"
copy_as_user "$REPO_DIR/configs/kitty" "$CONFIG_DIR/kitty"
copy_as_user "$REPO_DIR/configs/dunst" "$CONFIG_DIR/dunst"
copy_as_user "$ASSETS_SRC/backgrounds" "$ASSETS_DEST/backgrounds"

# --- Dracula Tofi Config Override ---
sudo -u "$USER_NAME" tee "$CONFIG_DIR/tofi/config" >/dev/null <<'EOF'
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

# --- Fastfetch & Starship shell integration ---
add_fastfetch_to_shell ".bashrc"
add_fastfetch_to_shell ".zshrc"
STARSHIP_SRC="$REPO_DIR/configs/starship/starship.toml"
STARSHIP_DEST="$CONFIG_DIR/starship.toml"
if [ -f "$STARSHIP_SRC" ]; then
    cp "$STARSHIP_SRC" "$STARSHIP_DEST"
    chown "$USER_NAME:$USER_NAME" "$STARSHIP_DEST"
fi
add_starship_to_shell ".bashrc" "bash"
add_starship_to_shell ".zshrc" "zsh"

# --- GTK Dracula theme ---
GTK3_CONFIG="$CONFIG_DIR/gtk-3.0"
GTK4_CONFIG="$CONFIG_DIR/gtk-4.0"
mkdir -p "$GTK3_CONFIG" "$GTK4_CONFIG"

GTK_SETTINGS="[Settings]
gtk-theme-name=Dracula
gtk-icon-theme-name=Dracula
gtk-font-name=JetBrainsMono 10"

echo "$GTK_SETTINGS" | sudo -u "$USER_NAME" tee "$GTK3_CONFIG/settings.ini" "$GTK4_CONFIG/settings.ini" >/dev/null
chown -R "$USER_NAME:$USER_NAME" "$GTK3_CONFIG" "$GTK4_CONFIG"

sudo -u "$USER_NAME" dbus-launch gsettings set org.gnome.desktop.interface gtk-theme 'Dracula'
sudo -u "$USER_NAME" dbus-launch gsettings set org.gnome.desktop.interface icon-theme 'Dracula'

# --- Thunar Kitty custom action ---
UCA_DIR="$CONFIG_DIR/Thunar"
UCA_FILE="$UCA_DIR/uca.xml"
mkdir -p "$UCA_DIR"
chown "$USER_NAME:$USER_NAME" "$UCA_DIR"
chmod 700 "$UCA_DIR"

if [ ! -f "$UCA_FILE" ]; then
    cat > "$UCA_FILE" <<EOF
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
fi

print_success "\n✅ Full Dracula Hyprland setup complete! Reboot to apply all changes."

#!/bin/bash

# ==============================
# One-Stop Utilities Setup Script
# ==============================

SCRIPT_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo "~$USER_NAME")
CONFIG_DIR="$USER_HOME/.config"
REPO_DIR="$USER_HOME/hyprdracula"
ASSETS_SRC="$REPO_DIR/assets"
ASSETS_DEST="$CONFIG_DIR/assets"

# --- Helper functions ---
run_command() {
    local cmd="$1"; shift
    echo -e "\n==> Running: $cmd"
    eval "$cmd"
}

copy_as_user() {
    local src="$1" dest="$2"
    [[ ! -d "$src" ]] && { echo "Warning: Source not found: $src"; return 1; }
    run_command "mkdir -p \"$dest\""
    run_command "cp -r \"$src\"/* \"$dest\""
    run_command "chown -R $USER_NAME:$USER_NAME \"$dest\""
}

# --- Update system ---
run_command "sudo pacman -Syu --noconfirm"

# --- Pacman Apps ---
PACMAN_APPS=(
pipewire wireplumber pamixer brightnessctl
ttf-cascadia-code-nerd ttf-cascadia-mono-nerd ttf-fira-code ttf-fira-mono ttf-fira-sans
ttf-iosevka-nerd ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-mono
sddm kitty nano tar gnome-disk-utility code mpv dunst pacman-contrib exo thunar thunar-archive-plugin thunar-volman tumbler ffmpegthumbnailer file-roller gvfs gvfs-mtp gvfs-gphoto2 gvfs-smb polkit polkit-gnome waybar cliphist firefox zsh
)
run_command "sudo pacman -S --noconfirm ${PACMAN_APPS[*]}"

# --- AUR apps (use yay if needed) ---
# Only apps not in official repo
AUR_APPS=(wofi fastfetch swww hyprpicker hyprlock grimblast hypridle starship)
for app in "${AUR_APPS[@]}"; do
    run_command "yay -S --noconfirm $app"
done

# --- Create config directories ---
mkdir -p "$CONFIG_DIR"
chown -R "$USER_NAME:$USER_NAME" "$CONFIG_DIR"

# --- Copy configs ---
copy_as_user "$REPO_DIR/configs/wofi" "$CONFIG_DIR/wofi"
copy_as_user "$REPO_DIR/configs/fastfetch" "$CONFIG_DIR/fastfetch"
copy_as_user "$REPO_DIR/configs/hypr" "$CONFIG_DIR/hypr"
copy_as_user "$REPO_DIR/configs/starship" "$CONFIG_DIR/starship"

# --- Fastfetch in shell ---
for shell_rc in .bashrc .zshrc; do
    FILE="$USER_HOME/$shell_rc"
    LINE="fastfetch --kitty-direct $CONFIG_DIR/fastfetch/archkitty.png"
    [[ -f "$FILE" ]] && ! grep -qF "$LINE" "$FILE" && echo -e "\n# Run fastfetch on terminal start\n$LINE" >> "$FILE" && chown "$USER_NAME:$USER_NAME" "$FILE"
done

# --- Starship init in shell ---
for shell_rc in .bashrc .zshrc; do
    FILE="$USER_HOME/$shell_rc"
    LINE='eval "$(starship init '"${shell_rc#*.}"')"'
    [[ -f "$FILE" ]] && ! grep -qF "$LINE" "$FILE" && echo -e "\n$LINE" >> "$FILE" && chown "$USER_NAME:$USER_NAME" "$FILE"
done

# --- GTK3/GTK4 Dracula theme ---
mkdir -p "$CONFIG_DIR/gtk-3.0" "$CONFIG_DIR/gtk-4.0"
chown -R "$USER_NAME:$USER_NAME" "$CONFIG_DIR"
GTK_SETTINGS="[Settings]
gtk-theme-name=Dracula
gtk-icon-theme-name=Dracula
gtk-font-name=JetBrainsMono 10"
echo "$GTK_SETTINGS" | sudo -u "$USER_NAME" tee "$CONFIG_DIR/gtk-3.0/settings.ini" >/dev/null
echo "$GTK_SETTINGS" | sudo -u "$USER_NAME" tee "$CONFIG_DIR/gtk-4.0/settings.ini" >/dev/null

# --- SDDM Dracula Theme ---
DRACULA_SDDM_REPO="https://github.com/dracula/sddm.git"
DRACULA_TEMP="/tmp/dracula-sddm"
git clone --depth=1 "$DRACULA_SDDM_REPO" "$DRACULA_TEMP"
sudo cp -r "$DRACULA_TEMP/sddm/themes/dracula" "/usr/share/sddm/themes/dracula"
sudo chown -R root:root "/usr/share/sddm/themes/dracula"
sudo mkdir -p /etc/sddm.conf.d
echo -e "[Theme]\nCurrent=dracula" | sudo tee /etc/sddm.conf.d/10-theme.conf >/dev/null
rm -rf "$DRACULA_TEMP"

# --- Copy assets ---
copy_as_user "$ASSETS_SRC/backgrounds" "$ASSETS_DEST/backgrounds"

# --- Thunar Kitty action ---
THUNAR_DIR="$CONFIG_DIR/Thunar"
mkdir -p "$THUNAR_DIR"
chown "$USER_NAME:$USER_NAME" "$THUNAR_DIR" && chmod 700 "$THUNAR_DIR"
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

# --- Oh My Zsh (default shell) ---
if [ ! -d "$USER_HOME/.oh-my-zsh" ]; then
    su "$USER_NAME" -c 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended'
    chsh -s "$(which zsh)" "$USER_NAME"
fi

echo -e "\n=== Utilities setup completed! ==="

#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/helper.sh"

log_message "Installation started for utilities section"
print_info "\nStarting utilities setup..."

# Detect the user running sudo (or fallback to current user)
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo "~$USER_NAME")

CONFIG_DIR="$USER_HOME/.config"
REPO_DIR="$USER_HOME/hyprdracula"
ASSETS_SRC="$REPO_DIR/assets"
ASSETS_DEST="$CONFIG_DIR/assets"

copy_as_user() {
    local src="$1"
    local dest="$2"

    if [ ! -d "$src" ]; then
        print_warning "Source folder not found: $src"
        return 1
    fi

    run_command "mkdir -p \"$dest\"" "Create destination directory $dest" "no" "no"
    run_command "cp -r \"$src\"/* \"$dest\"" "Copy from $src to $dest" "yes" "no"
    run_command "chown -R $USER_NAME:$USER_NAME \"$dest\"" "Fix ownership for $dest" "no" "yes"
}

# ----------------------------
# Core Utilities
# ----------------------------
run_command "pacman -S --noconfirm waybar" "Install Waybar" "yes"
[ -d "$REPO_DIR/configs/waybar" ] && copy_as_user "$REPO_DIR/configs/waybar" "$CONFIG_DIR/waybar"

# ----------------------------
# AUR Utilities via yay (as user)
# ----------------------------
AUR_PACKAGES="tofi fastfetch swww hyprpicker hyprlock grimblast hypridle starship spotify protonplus"
sudo -u "$USER_NAME" bash -c "yay -S --noconfirm $AUR_PACKAGES"

for dir in tofi fastfetch hypr kitty dunst; do
    [ -d "$REPO_DIR/configs/$dir" ] && copy_as_user "$REPO_DIR/configs/$dir" "$CONFIG_DIR/$dir"
done

# ----------------------------
# Dracula GTK Theme
# ----------------------------
THEMES_DIR="$USER_HOME/.themes"
sudo -u "$USER_NAME" mkdir -p "$THEMES_DIR"

# Copy Dracula GTK theme if it exists in repo
[ -d "$REPO_DIR/assets/themes/Dracula" ] && copy_as_user "$REPO_DIR/assets/themes/Dracula" "$THEMES_DIR/Dracula"

GTK3_CONFIG_DIR="$CONFIG_DIR/gtk-3.0"
GTK4_CONFIG_DIR="$CONFIG_DIR/gtk-4.0"
sudo -u "$USER_NAME" mkdir -p "$GTK3_CONFIG_DIR" "$GTK4_CONFIG_DIR"

GTK_SETTINGS_CONTENT="[Settings]
gtk-theme-name=Dracula
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=JetBrainsMono 10"

echo "$GTK_SETTINGS_CONTENT" | sudo -u "$USER_NAME" tee "$GTK3_CONFIG_DIR/settings.ini" "$GTK4_CONFIG_DIR/settings.ini" >/dev/null
chown -R "$USER_NAME:$USER_NAME" "$GTK3_CONFIG_DIR" "$GTK4_CONFIG_DIR"

# Apply theme via gsettings as user
sudo -u "$USER_NAME" dbus-launch gsettings set org.gnome.desktop.interface gtk-theme 'Dracula'
sudo -u "$USER_NAME" dbus-launch gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'

# ----------------------------
# Assets
# ----------------------------
[ -d "$ASSETS_SRC/backgrounds" ] && copy_as_user "$ASSETS_SRC/backgrounds" "$ASSETS_DEST/backgrounds"

# ----------------------------
# Fastfetch in shell
# ----------------------------
add_fastfetch_to_shell() {
    local shell_rc="$1"
    local shell_rc_path="$USER_HOME/$shell_rc"
    local fastfetch_line='fastfetch --kitty-direct /home/'"$USER_NAME"'/.config/fastfetch/archkitty.png'

    if [ -f "$shell_rc_path" ] && ! grep -qF "$fastfetch_line" "$shell_rc_path"; then
        echo -e "\n# Run fastfetch on terminal start\n$fastfetch_line" >> "$shell_rc_path"
        chown "$USER_NAME:$USER_NAME" "$shell_rc_path"
    fi
}

add_fastfetch_to_shell ".bashrc"

# ----------------------------
# Starship
# ----------------------------
STARSHIP_SRC="$REPO_DIR/configs/starship/starship.toml"
STARSHIP_DEST="$CONFIG_DIR/starship.toml"

[ -f "$STARSHIP_SRC" ] && cp "$STARSHIP_SRC" "$STARSHIP_DEST" && chown "$USER_NAME:$USER_NAME" "$STARSHIP_DEST"

add_starship_to_shell() {
    local shell_rc="$1"
    local shell_name="$2"
    local shell_rc_path="$USER_HOME/$shell_rc"
    local starship_line='eval "$(starship init '"$shell_name"')"' 

    if [ -f "$shell_rc_path" ] && ! grep -qF "$starship_line" "$shell_rc_path"; then
        echo -e "\n$starship_line" >> "$shell_rc_path"
        chown "$USER_NAME:$USER_NAME" "$shell_rc_path"
    fi
}

add_starship_to_shell ".bashrc" "bash"

print_success "\nUtilities setup complete!"

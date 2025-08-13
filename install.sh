#!/bin/bash

# --- Variables ---
SCRIPT_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo "~$USER_NAME")
CONFIG_DIR="$USER_HOME/.config"
REPO_DIR="$USER_HOME/hyprdracula"
ASSETS_SRC="$REPO_DIR/assets"
ASSETS_DEST="$CONFIG_DIR/assets"

# --- Helper functions ---
log_message() { echo -e "[LOG] $*"; }
print_info() { echo -e "[INFO] $*"; }
print_warning() { echo -e "[WARN] $*"; }
print_success() { echo -e "[OK] $*"; }

run_command() {
    local cmd="$1" desc="$2"
    print_info "$desc..."
    eval "$cmd"
    if [ $? -eq 0 ]; then
        print_success "$desc completed."
    else
        print_warning "$desc failed."
    fi
}

copy_as_user() {
    local src="$1" dest="$2"
    [[ ! -d "$src" ]] && { print_warning "Source not found: $src"; return 1; }
    run_command "mkdir -p \"$dest\"" "Create $dest"
    run_command "cp -r \"$src\"/* \"$dest\"" "Copy $src -> $dest"
    run_command "chown -R $USER_NAME:$USER_NAME \"$dest\"" "Fix ownership"
}

# --- Pacman apps ---
PACMAN_APPS="firefox waybar kitty thunar starship"
run_command "pacman -S --noconfirm $PACMAN_APPS" "Installing core Pacman apps"

# --- Copy configs ---
copy_as_user "$REPO_DIR/configs/waybar" "$CONFIG_DIR/waybar"
copy_as_user "$REPO_DIR/configs/kitty" "$CONFIG_DIR/kitty"
copy_as_user "$REPO_DIR/configs/thunar" "$CONFIG_DIR/thunar"
copy_as_user "$REPO_DIR/configs/starship" "$CONFIG_DIR/starship"

# --- AUR apps ---
AUR_APPS="wofi fastfetch swww hyprpicker hyprlock grimblast hypridle"
sudo -u "$USER_NAME" bash -c "
mkdir -p /tmp/aurbuild
cd /tmp/aurbuild
for app in $AUR_APPS; do
    [ -d \$app ] || git clone https://aur.archlinux.org/\$app.git
    cd \$app
    makepkg -si --noconfirm
    cd ..
done
rm -rf /tmp/aurbuild
"

# --- Fastfetch integration ---
for shell_rc in .bashrc .zshrc; do
    FILE="$USER_HOME/$shell_rc"
    LINE="fastfetch --kitty-direct $CONFIG_DIR/fastfetch/archkitty.png"
    [[ -f "$FILE" ]] && ! grep -qF "$LINE" "$FILE" && echo -e "\n# Run fastfetch on terminal start\n$LINE" >> "$FILE"
done

# --- Starship shell integration ---
for shell_rc in .bashrc .zshrc; do
    LINE='eval "$(starship init '"${shell_rc#.}"' )"'
    FILE="$USER_HOME/$shell_rc"
    [[ -f "$FILE" ]] && ! grep -qF "$LINE" "$FILE" && echo -e "\n$LINE" >> "$FILE"
done

# --- Dracula icons ---
sudo -u "$USER_NAME" bash -c "
git clone --depth=1 https://github.com/dracula/gtk.git /tmp/dracula-icons
mkdir -p $CONFIG_DIR/icons
cp -r /tmp/dracula-icons/* $CONFIG_DIR/icons
rm -rf /tmp/dracula-icons
"

# --- GTK themes ---
GTK3_DIR="$CONFIG_DIR/gtk-3.0"
GTK4_DIR="$CONFIG_DIR/gtk-4.0"
mkdir -p "$GTK3_DIR" "$GTK4_DIR"
GTK_SETTINGS="[Settings]
gtk-theme-name=Dracula
gtk-icon-theme-name=Dracula
gtk-font-name=JetBrainsMono 10"
echo "$GTK_SETTINGS" | sudo -u "$USER_NAME" tee "$GTK3_DIR/settings.ini" "$GTK4_DIR/settings.ini" >/dev/null

# --- SDDM Dracula theme ---
DRACULA_SDDM_REPO="https://github.com/dracula/sddm.git"
DRACULA_TEMP="/tmp/dracula-sddm"
git clone --depth=1 "$DRACULA_SDDM_REPO" "$DRACULA_TEMP"
cp -r "$DRACULA_TEMP/sddm/themes/dracula" "/usr/share/sddm/themes/dracula"
chown -R root:root "/usr/share/sddm/themes/dracula"
mkdir -p /etc/sddm.conf.d
echo -e "[Theme]\nCurrent=dracula" > /etc/sddm.conf.d/10-theme.conf
rm -rf "$DRACULA_TEMP"

# --- Copy assets ---
copy_as_user "$ASSETS_SRC/backgrounds" "$ASSETS_DEST/backgrounds"

print_success "One-stop setup completed. Reboot recommended for full effect."

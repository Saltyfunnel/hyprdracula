#!/bin/bash

SCRIPT_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo "~$USER_NAME")
CONFIG_DIR="$USER_HOME/.config"
REPO_DIR="$USER_HOME/hyprdracula"    # Your Dracula repo
ASSETS_SRC="$REPO_DIR/assets"
ASSETS_DEST="$CONFIG_DIR/assets"

# --- Helper functions ---
log_message() { echo -e "[INFO] $1"; }
print_success() { echo -e "\e[32m[SUCCESS]\e[0m $1"; }
print_warning() { echo -e "\e[33m[WARNING]\e[0m $1"; }
print_info() { echo -e "\e[34m[INFO]\e[0m $1"; }

run_command() {
    local cmd="$1"; shift
    local desc="$1"; shift
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

# --- Core utilities ---
run_command "pacman -S --noconfirm waybar wofi fastfetch swww hyprpicker hyprlock grimblast hypridle starship firefox thunar" "Install core utilities"
copy_as_user "$REPO_DIR/configs/waybar" "$CONFIG_DIR/waybar"
copy_as_user "$REPO_DIR/configs/wofi" "$CONFIG_DIR/wofi"
copy_as_user "$REPO_DIR/configs/fastfetch" "$CONFIG_DIR/fastfetch"
copy_as_user "$REPO_DIR/configs/hypr" "$CONFIG_DIR/hypr"
copy_as_user "$REPO_DIR/configs/starship" "$CONFIG_DIR/starship"

# --- Fastfetch integration ---
add_fastfetch_to_shell() {
    local shell_rc="$1"
    local line="fastfetch --kitty-direct $CONFIG_DIR/fastfetch/archkitty.png"
    local path="$USER_HOME/$shell_rc"
    [[ -f "$path" ]] && ! grep -qF "$line" "$path" && echo -e "\n# Run fastfetch on terminal start\n$line" >> "$path" && chown "$USER_NAME:$USER_NAME" "$path"
}
add_fastfetch_to_shell ".bashrc"
add_fastfetch_to_shell ".zshrc"

# --- Starship shell integration ---
add_starship_to_shell() {
    local shell_rc="$1" shell_name="$2"
    local line='eval "$(starship init '"$shell_name"')"'
    local path="$USER_HOME/$shell_rc"
    [[ -f "$path" ]] && ! grep -qF "$line" "$path" && echo -e "\n$line" >> "$path" && chown "$USER_NAME:$USER_NAME" "$path"
}
add_starship_to_shell ".bashrc" "bash"
add_starship_to_shell ".zshrc" "zsh"

# --- Dracula icons ---
DRACULA_ICON_REPO="https://github.com/dracula/icons.git"
ICON_TEMP="/tmp/dracula-icons"
git clone --depth=1 "$DRACULA_ICON_REPO" "$ICON_TEMP"
run_command "cp -r $ICON_TEMP/* /usr/share/icons" "Install Dracula icons"
rm -rf "$ICON_TEMP"

# --- GTK3/4 Dracula theme ---
GTK3_DIR="$CONFIG_DIR/gtk-3.0"
GTK4_DIR="$CONFIG_DIR/gtk-4.0"
mkdir -p "$GTK3_DIR" "$GTK4_DIR"
chown -R "$USER_NAME:$USER_NAME" "$GTK3_DIR" "$GTK4_DIR"
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

# --- Thunar Kitty action ---
THUNAR_DIR="$CONFIG_DIR/Thunar"
mkdir -p "$THUNAR_DIR" && chown "$USER_NAME:$USER_NAME" "$THUNAR_DIR" && chmod 700 "$THUNAR_DIR"
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

print_success "Utilities and theming setup completed."

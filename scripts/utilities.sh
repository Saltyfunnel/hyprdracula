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

    mkdir -p "$dest"
    cp -r "$src"/* "$dest"
    chown -R "$USER_NAME:$USER_NAME" "$dest"
}

# --- Install core utilities ---
pacman -S --noconfirm waybar
copy_as_user "$REPO_DIR/configs/waybar" "$CONFIG_DIR/waybar"

yay -S --noconfirm tofi fastfetch swww hyprpicker hyprlock grimblast hypridle starship spotify protonplus

copy_as_user "$REPO_DIR/configs/tofi" "$CONFIG_DIR/tofi"
copy_as_user "$REPO_DIR/configs/fastfetch" "$CONFIG_DIR/fastfetch"
copy_as_user "$REPO_DIR/configs/hypr" "$CONFIG_DIR/hypr"
copy_as_user "$REPO_DIR/configs/kitty" "$CONFIG_DIR/kitty"
copy_as_user "$REPO_DIR/configs/dunst" "$CONFIG_DIR/dunst"

# --- Add fastfetch to shell ---
add_fastfetch_to_shell() {
    local shell_rc="$1"
    local shell_rc_path="$USER_HOME/$shell_rc"
    local fastfetch_line="fastfetch --kitty-direct $CONFIG_DIR/fastfetch/archkitty.png"

    if [ -f "$shell_rc_path" ] && ! grep -qF "$fastfetch_line" "$shell_rc_path"; then
        echo -e "\n# Run fastfetch on terminal start\n$fastfetch_line" >> "$shell_rc_path"
        chown "$USER_NAME:$USER_NAME" "$shell_rc_path"
    fi
}

add_fastfetch_to_shell ".bashrc"
add_fastfetch_to_shell ".zshrc"

# --- Starship config ---
STARSHIP_SRC="$REPO_DIR/configs/starship/starship.toml"
STARSHIP_DEST="$CONFIG_DIR/starship.toml"

if [ -f "$STARSHIP_SRC" ]; then
    cp "$STARSHIP_SRC" "$STARSHIP_DEST"
    chown "$USER_NAME:$USER_NAME" "$STARSHIP_DEST"
fi

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

add_starship_to_shell ".bashrc" "bash"
add_starship_to_shell ".zshrc" "zsh"

# --- Install additional utilities ---
pacman -S --noconfirm cliphist
copy_as_user "$ASSETS_SRC/backgrounds" "$ASSETS_DEST/backgrounds"

# --- Dracula GTK Theme ---
GTK3_CONFIG_DIR="$CONFIG_DIR/gtk-3.0"
GTK4_CONFIG_DIR="$CONFIG_DIR/gtk-4.0"
THEME_REPO="$USER_HOME/Dracula-gtk-theme"

if [ ! -d "$THEME_REPO" ]; then
    git clone https://github.com/dracula/gtk.git "$THEME_REPO"
fi

mkdir -p "$USER_HOME/.themes"
cp -r "$THEME_REPO"/* "$USER_HOME/.themes/"
chown -R "$USER_NAME:$USER_NAME" "$USER_HOME/.themes"

# Apply Dracula GTK theme
mkdir -p "$GTK3_CONFIG_DIR" "$GTK4_CONFIG_DIR"

cat > "$GTK3_CONFIG_DIR/settings.ini" << EOF
[Settings]
gtk-theme-name=Dracula
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=JetBrains Mono 11
EOF

cat > "$GTK4_CONFIG_DIR/settings.ini" << EOF
[Settings]
gtk-theme-name=Dracula
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=JetBrains Mono 11
EOF

chown -R "$USER_NAME:$USER_NAME" "$GTK3_CONFIG_DIR" "$GTK4_CONFIG_DIR"

# --- Thunar Kitty custom action ---
setup_thunar_kitty_action() {
    local uca_dir="$CONFIG_DIR/Thunar"
    local uca_file="$uca_dir/uca.xml"

    mkdir -p "$uca_dir"
    chown "$USER_NAME:$USER_NAME" "$uca_dir"
    chmod 700 "$uca_dir"

    local kitty_action_xml='
  <action>
    <icon>utilities-terminal</icon>
    <name>Open Kitty Here</name>
    <command>kitty --directory=%d</command>
    <description>Open kitty terminal in the current folder</description>
    <patterns>*</patterns>
    <directories_only>true</directories_only>
    <startup_notify>true</startup_notify>
  </action>'

    if [ ! -f "$uca_file" ]; then
        cat > "$uca_file" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<actions>
$kitty_action_xml
</actions>
EOF
        chown "$USER_NAME:$USER_NAME" "$uca_file"
    else
        if ! grep -q "<name>Open Kitty Here</name>" "$uca_file"; then
            sed -i "/<\/actions>/ i\\
$kitty_action_xml
" "$uca_file"
            chown "$USER_NAME:$USER_NAME" "$uca_file"
        fi
    fi
}

setup_thunar_kitty_action

print_success "\nUtilities setup complete!"

#!/bin/bash
# A one-stop script for installing a Dracula-themed Hyprland setup on Arch Linux.
# This script handles both system-level and user-level tasks in a single run.
set -euo pipefail

# --- Global Helper Functions ---
print_header() {
    echo -e "\n--- \e[1m\e[34m$1\e[0m ---"
}

print_success() {
    echo -e "\e[32m$1\e[0m"
}

print_warning() {
    echo -e "\e[33mWarning: $1\e[0m" >&2
}

print_error() {
    echo -e "\e[31mError: $1\e[0m" >&2
}

# --- Main Execution Logic ---

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root. Please run with 'sudo bash $0'."
    exit 1
fi

# Define variables accessible by the main script and the user subshell
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
CONFIG_DIR="$USER_HOME/.config"
CONFIRMATION="yes"

if [[ $# -eq 1 && "$1" == "--noconfirm" ]]; then
    CONFIRMATION="no"
elif [[ $# -gt 0 ]]; then
    echo "Usage: $0 [--noconfirm]"
    exit 1
fi

# --- System-level tasks ---
print_header "Starting System-Level Setup"

# Update system and install required packages with pacman
if [ "$CONFIRMATION" == "yes" ]; then
    read -p "Update system and install packages? Press Enter to continue..."
fi
# The PACKAGES array is defined just before it is used to ensure it's always in scope.
PACKAGES=(
    git base-devel pipewire wireplumber pamixer brightnessctl
    ttf-jetbrains-mono-nerd ttf-iosevka-nerd ttf-fira-code ttf-fira-mono
    sddm kitty nano tar gnome-disk-utility code mpv dunst pacman-contrib exo firefox cava
    thunar thunar-archive-plugin thunar-volman tumbler ffmpegthumbnailer file-roller
    gvfs gvfs-mtp gvfs-gphoto2 gvfs-smb polkit polkit-gnome
)
# The conditional check for an empty array was removed to avoid "unbound variable" errors.
# The pacman command can handle an empty array, so the check is not necessary.
if ! pacman -Syu "${PACKAGES[@]}" --noconfirm; then
    print_error "Failed to install system packages."
    exit 1
fi
print_success "✅ System packages installed."


# Enable services
if [ "$CONFIRMATION" == "yes" ]; then
    read -p "Enable system services? Press Enter to continue..."
fi
systemctl enable --now polkit.service
systemctl enable sddm.service
print_success "✅ System services enabled."

print_success "\n✅ System-level setup is complete! Now starting user-level setup."

# --- User-level tasks (executed as the user) ---
# Use a here document (EOF block) to run all commands as the non-root user.
# Variables are explicitly exported to the subshell to ensure they are available.
export SCRIPT_DIR
export USER_HOME
export CONFIG_DIR
export REPO_DIR="$SCRIPT_DIR"

sudo -u "$USER_NAME" bash <<EOF
set -euo pipefail

# --- Helper Functions for subshell ---
print_header() {
    echo -e "\n--- \e[1m\e[34m$1\e[0m ---"
}
print_success() {
    echo -e "\e[32m$1\e[0m"
}
print_warning() {
    echo -e "\e[33mWarning: $1\e[0m" >&2
}
print_error() {
    echo -e "\e[31mError: $1\e[0m" >&2
}

# --- Install yay if missing ---
if ! command -v yay &>/dev/null; then
    print_header "Installing yay from AUR"
    if bash -c '
        set -e
        YAY_TEMP_DIR="$(mktemp -d -p "$HOME")"
        cd "$YAY_TEMP_DIR" || exit 1
        
        git clone https://aur.archlinux.org/yay.git
        cd yay || exit 1
        makepkg -si --noconfirm
        
        rm -rf "$YAY_TEMP_DIR"
    '; then
        print_success "✅ Success: yay installed from AUR"
    else
        print_error "❌ Failed: yay installation failed"
        exit 1
    fi
else
    print_header "yay is already installed."
fi

# --- AUR utilities ---
AUR_PACKAGES=(tofi fastfetch swww hyprpicker hyprlock grimblast hypridle starship spotify protonplus)
for pkg in "\${AUR_PACKAGES[@]}"; do
    print_header "Install \$pkg via AUR"
    yay -S --noconfirm "\$pkg" || print_warning "Installation of \$pkg failed (non-fatal)."
done

# --- Copy configs ---
print_header "Copying configuration files"
mkdir -p "\$CONFIG_DIR/waybar"
cp -r "\$REPO_DIR/configs/waybar"/* "\$CONFIG_DIR/waybar" || print_warning "Failed to copy waybar config."

mkdir -p "\$CONFIG_DIR/tofi"
cp -r "\$REPO_DIR/configs/tofi"/* "\$CONFIG_DIR/tofi" || print_warning "Failed to copy tofi config."

mkdir -p "\$CONFIG_DIR/fastfetch"
cp -r "\$REPO_DIR/configs/fastfetch"/* "\$CONFIG_DIR/fastfetch" || print_warning "Failed to copy fastfetch config."

mkdir -p "\$CONFIG_DIR/hypr"
cp -r "\$REPO_DIR/configs/hypr"/* "\$CONFIG_DIR/hypr" || print_warning "Failed to copy hypr config."

mkdir -p "\$CONFIG_DIR/kitty"
cp -r "\$REPO_DIR/configs/kitty"/* "\$CONFIG_DIR/kitty" || print_warning "Failed to copy kitty config."

mkdir -p "\$CONFIG_DIR/dunst"
cp -r "\$REPO_DIR/configs/dunst"/* "\$CONFIG_DIR/dunst" || print_warning "Failed to copy dunst config."

mkdir -p "\$CONFIG_DIR/assets/backgrounds"
cp -r "\$REPO_DIR/assets/backgrounds"/* "\$CONFIG_DIR/assets/backgrounds" || print_warning "Failed to copy assets."

# --- Dracula Tofi Config Override ---
print_header "Setting up Dracula Tofi config"
mkdir -p "\$CONFIG_DIR/tofi"
tee "\$CONFIG_DIR/tofi/config" >/dev/null <<'EOF_TOFI'
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
EOF_TOFI
print_success "✅ Tofi config applied."

# --- Fastfetch & Starship shell integration ---
print_header "Setting up Fastfetch and Starship"
add_fastfetch_to_shell() {
    local shell_config="\$1"
    local shell_file="\$USER_HOME/\$shell_config"
    local shell_content="\n# Added by Dracula Hyprland setup script\nif command -v fastfetch &>/dev/null; then\n  fastfetch --w-size 60 --w-border-color 44475a --w-color f8f8f2\nfi\n"
    if ! grep -q "fastfetch" "\$shell_file" 2>/dev/null; then
        echo -e "\$shell_content" | tee -a "\$shell_file" >/dev/null
    fi
}
add_starship_to_shell() {
    local shell_config="\$1"
    local shell_type="\$2"
    local shell_file="\$USER_HOME/\$shell_config"
    local shell_content="\n# Added by Dracula Hyprland setup script\neval \"\$(starship init \$shell_type)\"\n"
    if ! grep -q "starship" "\$shell_file" 2>/dev/null; then
        echo -e "\$shell_content" | tee -a "\$shell_file" >/dev/null
    fi
}
add_fastfetch_to_shell ".bashrc"
add_fastfetch_to_shell ".zshrc"

STARSHIP_SRC="\$REPO_DIR/configs/starship/starship.toml"
STARSHIP_DEST="\$CONFIG_DIR/starship.toml"
if [ -f "\$STARSHIP_SRC" ]; then
    cp "\$STARSHIP_SRC" "\$STARSHIP_DEST" || print_warning "Failed to copy starship config."
fi
add_starship_to_shell ".bashrc" "bash"
add_starship_to_shell ".zshrc" "zsh"
print_success "✅ Shell integrations complete."

# --- GTK Dracula theme and icon setup ---
print_header "Setting up GTK themes and icons"
THEMES_DIR="\$USER_HOME/.themes"
ICONS_DIR="\$USER_HOME/.icons"

mkdir -p "\$THEMES_DIR" "\$ICONS_DIR"
cp -r "\$REPO_DIR/assets/themes/Dracula" "\$THEMES_DIR/Dracula" || print_warning "Failed to copy GTK theme."
cp -r "\$REPO_DIR/assets/icons/Dracula" "\$ICONS_DIR/Dracula" || print_warning "Failed to copy icons."

GTK3_CONFIG="\$CONFIG_DIR/gtk-3.0"
GTK4_CONFIG="\$CONFIG_DIR/gtk-4.0"
mkdir -p "\$GTK3_CONFIG" "\$GTK4_CONFIG"

GTK_SETTINGS="[Settings]\ngtk-theme-name=Dracula\ngtk-icon-theme-name=Dracula\ngtk-font-name=JetBrainsMono 10"

echo -e "\$GTK_SETTINGS" | tee "\$GTK3_CONFIG/settings.ini" "\$GTK4_CONFIG/settings.ini" >/dev/null

XPROFILE="\$USER_HOME/.xprofile"
echo "export GTK_THEME=Dracula\nexport ICON_THEME=Dracula\nexport XDG_CURRENT_DESKTOP=Hyprland" >> "\$XPROFILE"
print_success "✅ GTK themes configured."

# --- Thunar Kitty custom action ---
print_header "Setting up Thunar custom action"
UCA_DIR="\$CONFIG_DIR/Thunar"
UCA_FILE="\$UCA_DIR/uca.xml"
mkdir -p "\$UCA_DIR"
chmod 700 "\$UCA_DIR"

if [ ! -f "\$UCA_FILE" ]; then
    tee "\$UCA_FILE" >/dev/null <<'EOF_UCA'
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
EOF_UCA
fi
print_success "✅ Thunar action configured."

# --- Restart Thunar to apply theme ---
pkill thunar || true
thunar &
print_success "✅ Thunar restarted."

EOF

print_success "\n🎉 The installation is complete! Please reboot your system to apply all changes."

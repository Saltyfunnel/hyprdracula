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

# Define variables
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
# The PACKAGES array is defined here, just before it is used.
PACKAGES=(
    git base-devel pipewire wireplumber pamixer brightnessctl
    ttf-jetbrains-mono-nerd ttf-iosevka-nerd ttf-fira-code ttf-fira-mono
    sddm kitty nano tar gnome-disk-utility code mpv dunst pacman-contrib exo firefox cava
    thunar thunar-archive-plugin thunar-volman tumbler ffmpegthumbnailer file-roller
    gvfs gvfs-mtp gvfs-gphoto2 gvfs-smb polkit polkit-gnome
)
# We perform the system update and package installation in a single command.
# Using "${PACKAGES[@]:-}" prevents unbound variable errors with empty arrays.
if ! pacman -Syu "${PACKAGES[@]:-}" --noconfirm; then
    print_error "Failed to install system packages."
    exit 1
fi
print_success "✅ System updated and packages installed."

# Enable services
if [ "$CONFIRMATION" == "yes" ]; then
    read -p "Enable system services? Press Enter to continue..."
fi
systemctl enable --now polkit.service
systemctl enable sddm.service
print_success "✅ System services enabled."

print_success "\n✅ System-level setup is complete! Now starting user-level setup."

# --- User-level tasks (executed as the user via sudo) ---
print_header "Starting User-Level Setup"

# --- Install yay if missing ---
if ! sudo -u "$USER_NAME" command -v yay &>/dev/null; then
    print_header "Installing yay from AUR"
    if sudo -u "$USER_NAME" bash -c '
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
declare -a AUR_PACKAGES=(tofi fastfetch swww hyprpicker hyprlock grimblast hypridle starship spotify protonplus)
# Install all AUR packages at once to avoid unbound variable issues with loops.
if [[ "${#AUR_PACKAGES[@]}" -gt 0 ]]; then
    print_header "Installing AUR packages..."
    if ! sudo -u "$USER_NAME" yay -S --noconfirm "${AUR_PACKAGES[@]}"; then
        print_warning "Installation of some AUR packages failed (non-fatal)."
    else
        print_success "✅ All AUR packages installed."
    fi
else
    print_warning "No AUR packages to install. Skipping package installation."
fi

# --- Copy configs ---
print_header "Copying configuration files"

# Copy Waybar configs
SOURCE_DIR="$SCRIPT_DIR/configs/waybar"
DEST_DIR="$CONFIG_DIR/waybar"
if [ -d "$SOURCE_DIR" ]; then
    print_success "Copying Waybar configs from '$SOURCE_DIR' to '$DEST_DIR'."
    sudo -u "$USER_NAME" mkdir -p "$DEST_DIR"
    sudo -u "$USER_NAME" cp -r "$SOURCE_DIR/." "$DEST_DIR"
    print_success "✅ Copied Waybar configs."
else
    print_warning "Source directory not found: $SOURCE_DIR. Skipping."
fi

# Copy Tofi configs
SOURCE_DIR="$SCRIPT_DIR/configs/tofi"
DEST_DIR="$CONFIG_DIR/tofi"
if [ -d "$SOURCE_DIR" ]; then
    print_success "Copying Tofi configs from '$SOURCE_DIR' to '$DEST_DIR'."
    sudo -u "$USER_NAME" mkdir -p "$DEST_DIR"
    sudo -u "$USER_NAME" cp -r "$SOURCE_DIR/." "$DEST_DIR"
    print_success "✅ Copied Tofi configs."
else
    print_warning "Source directory not found: $SOURCE_DIR. Skipping."
fi

# Copy Fastfetch configs
SOURCE_DIR="$SCRIPT_DIR/configs/fastfetch"
DEST_DIR="$CONFIG_DIR/fastfetch"
if [ -d "$SOURCE_DIR" ]; then
    print_success "Copying Fastfetch configs from '$SOURCE_DIR' to '$DEST_DIR'."
    sudo -u "$USER_NAME" mkdir -p "$DEST_DIR"
    sudo -u "$USER_NAME" cp -r "$SOURCE_DIR/." "$DEST_DIR"
    print_success "✅ Copied Fastfetch configs."
else
    print_warning "Source directory not found: $SOURCE_DIR. Skipping."
fi

# Copy Hypr configs
SOURCE_DIR="$SCRIPT_DIR/configs/hypr"
DEST_DIR="$CONFIG_DIR/hypr"
if [ -d "$SOURCE_DIR" ]; then
    print_success "Copying Hypr configs from '$SOURCE_DIR' to '$DEST_DIR'."
    sudo -u "$USER_NAME" mkdir -p "$DEST_DIR"
    sudo -u "$USER_NAME" cp -r "$SOURCE_DIR/." "$DEST_DIR"
    print_success "✅ Copied Hypr configs."
else
    print_warning "Source directory not found: $SOURCE_DIR. Skipping."
fi

# Copy Kitty configs
SOURCE_DIR="$SCRIPT_DIR/configs/kitty"
DEST_DIR="$CONFIG_DIR/kitty"
if [ -d "$SOURCE_DIR" ]; then
    print_success "Copying Kitty configs from '$SOURCE_DIR' to '$DEST_DIR'."
    sudo -u "$USER_NAME" mkdir -p "$DEST_DIR"
    sudo -u "$USER_NAME" cp -r "$SOURCE_DIR/." "$DEST_DIR"
    print_success "✅ Copied Kitty configs."
else
    print_warning "Source directory not found: $SOURCE_DIR. Skipping."
fi

# Copy Dunst configs
SOURCE_DIR="$SCRIPT_DIR/configs/dunst"
DEST_DIR="$CONFIG_DIR/dunst"
if [ -d "$SOURCE_DIR" ]; then
    print_success "Copying Dunst configs from '$SOURCE_DIR' to '$DEST_DIR'."
    sudo -u "$USER_NAME" mkdir -p "$DEST_DIR"
    sudo -u "$USER_NAME" cp -r "$SOURCE_DIR/." "$DEST_DIR"
    print_success "✅ Copied Dunst configs."
else
    print_warning "Source directory not found: $SOURCE_DIR. Skipping."
fi

# Copy assets and backgrounds
SOURCE_DIR="$SCRIPT_DIR/assets/backgrounds"
DEST_DIR="$CONFIG_DIR/assets/backgrounds"
if [ -d "$SOURCE_DIR" ]; then
    print_success "Copying backgrounds from '$SOURCE_DIR' to '$DEST_DIR'."
    sudo -u "$USER_NAME" mkdir -p "$DEST_DIR"
    sudo -u "$USER_NAME" cp -r "$SOURCE_DIR/." "$DEST_DIR"
    print_success "✅ Copied assets and backgrounds."
else
    print_warning "Source directory not found: $SOURCE_DIR. Skipping."
fi

# --- Dracula Tofi Config Override ---
print_header "Setting up Dracula Tofi config"
sudo -u "$USER_NAME" mkdir -p "$CONFIG_DIR/tofi"
sudo -u "$USER_NAME" tee "$CONFIG_DIR/tofi/config" >/dev/null <<'EOF_TOFI'
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
sudo -u "$USER_NAME" bash -c "
  add_fastfetch_to_shell() {
      local shell_config=\"\$1\"
      local shell_file=\"$USER_HOME/\$shell_config\"
      local shell_content=\"\\n# Added by Dracula Hyprland setup script\\nif command -v fastfetch &>/dev/null; then\\n  fastfetch --w-size 60 --w-border-color 44475a --w-color f8f8f2\\nfi\\n\"
      if ! grep -q \"fastfetch\" \"\$shell_file\" 2>/dev/null; then
          echo -e \"\$shell_content\" | tee -a \"\$shell_file\" >/dev/null
      fi
  }
  add_starship_to_shell() {
      local shell_config=\"\$1\"
      local shell_type=\"\$2\"
      local shell_file=\"$USER_HOME/\$shell_config\"
      local shell_content=\"\\n# Added by Dracula Hyprland setup script\\neval \\\"\\\$(starship init \$shell_type)\\\"\\n\"
      if ! grep -q \"starship\" \"\$shell_file\" 2>/dev/null; then
          echo -e \"\$shell_content\" | tee -a \"\$shell_file\" >/dev/null
      fi
  }
  add_fastfetch_to_shell \".bashrc\"
  add_fastfetch_to_shell \".zshrc\"

  STARSHIP_SRC=\"$SCRIPT_DIR/configs/starship/starship.toml\"
  STARSHIP_DEST=\"$CONFIG_DIR/starship.toml\"
  if [ -f \"\$STARSHIP_SRC\" ]; then
      cp \"\$STARSHIP_SRC\" \"\$STARSHIP_DEST\" || print_warning \"Failed to copy starship config.\"
  fi
  add_starship_to_shell \".bashrc\" \"bash\"
  add_starship_to_shell \".zshrc\" \"zsh\"
"
print_success "✅ Shell integrations complete."

# --- GTK Dracula theme and icon setup ---
print_header "Setting up GTK themes and icons"
THEMES_DIR="$USER_HOME/.themes"
ICONS_DIR="$USER_HOME/.icons"

sudo -u "$USER_NAME" mkdir -p "$THEMES_DIR" "$ICONS_DIR"
sudo -u "$USER_NAME" cp -r "$SCRIPT_DIR/assets/themes/Dracula" "$THEMES_DIR/Dracula" || print_warning "Failed to copy GTK theme."
sudo -u "$USER_NAME" cp -r "$SCRIPT_DIR/assets/icons/Dracula" "$ICONS_DIR/Dracula" || print_warning "Failed to copy icons."

GTK3_CONFIG="$CONFIG_DIR/gtk-3.0"
GTK4_CONFIG="$CONFIG_DIR/gtk-4.0"
sudo -u "$USER_NAME" mkdir -p "$GTK3_CONFIG" "$GTK4_CONFIG"

GTK_SETTINGS="[Settings]\ngtk-theme-name=Dracula\ngtk-icon-theme-name=Dracula\ngtk-font-name=JetBrainsMono 10"

sudo -u "$USER_NAME" bash -c "echo -e \"$GTK_SETTINGS\" | tee \"$GTK3_CONFIG/settings.ini\" \"$GTK4_CONFIG/settings.ini\" >/dev/null"

XPROFILE="$USER_HOME/.xprofile"
sudo -u "$USER_NAME" bash -c "echo \"export GTK_THEME=Dracula\nexport ICON_THEME=Dracula\nexport XDG_CURRENT_DESKTOP=Hyprland\" >> \"$XPROFILE\""
print_success "✅ GTK themes configured."

# --- Thunar Kitty custom action ---
print_header "Setting up Thunar custom action"
UCA_DIR="$CONFIG_DIR/Thunar"
UCA_FILE="$UCA_DIR/uca.xml"
sudo -u "$USER_NAME" mkdir -p "$UCA_DIR"
sudo -u "$USER_NAME" chmod 700 "$UCA_DIR"

if [ ! -f "$UCA_FILE" ]; then
    sudo -u "$USER_NAME" tee "$UCA_FILE" >/dev/null <<'EOF_UCA'
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
sudo -u "$USER_NAME" pkill thunar || true
sudo -u "$USER_NAME" thunar &
print_success "✅ Thunar restarted."

print_success "\n🎉 The installation is complete! Please reboot your system to apply all changes."

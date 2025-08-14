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
    exit 1
}

# --- Main Execution Logic ---

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root. Please run with 'sudo bash $0'."
fi

# Define variables
# The script now correctly navigates up one directory to find the configs.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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

# --- Pre-run checks ---
print_header "Running Pre-run Checks"

# Check for required directories in the script's location
if [ ! -d "$SCRIPT_DIR/configs" ]; then
    print_error "Required 'configs' directory not found in the script's directory: $SCRIPT_DIR.
    Please ensure the entire repository is cloned and you are running the script from its root directory."
fi
print_success "✅ File structure confirmed."

# Check for necessary tools before proceeding
if ! command -v git &>/dev/null; then
    print_error "git is not installed. Please install it with 'sudo pacman -S git'."
fi
if ! command -v curl &>/dev/null; then
    print_error "curl is not installed. Please install it with 'sudo pacman -S curl'."
fi
print_success "✅ Required tools (git, curl) confirmed."

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
    sddm kitty nano tar unzip gnome-disk-utility code mpv dunst pacman-contrib exo firefox cava
    thunar thunar-archive-plugin thunar-volman tumbler ffmpegthumbnailer file-roller
    gvfs gvfs-mtp gvfs-gphoto2 gvfs-smb polkit polkit-gnome
)
# We perform the system update and package installation in a single command.
# Using "${PACKAGES[@]:-}" prevents unbound variable errors with empty arrays.
if ! pacman -Syu "${PACKAGES[@]:-}" --noconfirm; then
    print_error "Failed to install system packages."
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

# --- File Copying Function ---
copy_configs() {
    local source_dir="$1"
    local dest_dir="$2"
    local config_name="$3"

    print_success "Copying $config_name from '$source_dir' to '$dest_dir'."
    if ! sudo -u "$USER_NAME" mkdir -p "$dest_dir"; then
        print_warning "Failed to create destination directory for $config_name: '$dest_dir'."
        return 1
    fi
    if ! sudo -u "$USER_NAME" cp -r "$source_dir/." "$dest_dir"; then
        print_warning "Failed to copy $config_name."
        return 1
    fi
    print_success "✅ Copied $config_name."
    return 0
}

# --- Copy configs ---
print_header "Copying configuration files"
copy_configs "$SCRIPT_DIR/configs/waybar" "$CONFIG_DIR/waybar" "Waybar"
copy_configs "$SCRIPT_DIR/configs/tofi" "$CONFIG_DIR/tofi" "Tofi"
copy_configs "$SCRIPT_DIR/configs/fastfetch" "$CONFIG_DIR/fastfetch" "Fastfetch"
copy_configs "$SCRIPT_DIR/configs/hypr" "$CONFIG_DIR/hypr" "Hyprland"
copy_configs "$SCRIPT_DIR/configs/kitty" "$CONFIG_DIR/kitty" "Kitty"
copy_configs "$SCRIPT_DIR/configs/dunst" "$CONFIG_DIR/dunst" "Dunst"

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
  add_fastfetch_to_shell \".bashrc\" \"bash\"
  add_fastfetch_to_shell \".zshrc\" \"zsh\"
  
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
print_header "Setting up GTK themes and icons from local assets"
THEMES_DIR="$USER_HOME/.themes"
ICONS_DIR="$USER_HOME/.icons"
ASSETS_DIR="$SCRIPT_DIR/assets"

# Check if the asset files exist locally
if [ ! -f "$ASSETS_DIR/dracula-gtk-master.zip" ]; then
    print_error "Dracula GTK theme archive not found at $ASSETS_DIR/dracula-gtk-master.zip. Please download it and place it there."
fi
if [ ! -f "$ASSETS_DIR/Dracula.zip" ]; then
    print_error "Dracula Icons archive not found at $ASSETS_DIR/Dracula.zip. Please download it and place it there."
fi
print_success "✅ Local asset files confirmed."

# Extract and install Dracula GTK theme
print_success "Installing Dracula GTK theme..."
sudo -u "$USER_NAME" mkdir -p "$THEMES_DIR"
sudo -u "$USER_NAME" unzip "$ASSETS_DIR/dracula-gtk-master.zip" -d "$THEMES_DIR"
sudo -u "$USER_NAME" mv "$THEMES_DIR/dracula-gtk-master" "$THEMES_DIR/Dracula"
print_success "✅ Dracula GTK theme installed."

# Extract and install Dracula Icons
print_success "Installing Dracula Icons..."
sudo -u "$USER_NAME" mkdir -p "$ICONS_DIR"
sudo -u "$USER_NAME" unzip "$ASSETS_DIR/Dracula.zip" -d "$ICONS_DIR"
sudo -u "$USER_NAME" mv "$ICONS_DIR/icons-master" "$ICONS_DIR/Dracula"
print_success "✅ Dracula Icons installed."


# --- Clean up the temporary directory ---
# Note: The temporary directory is no longer used, so this section is removed.

GTK3_CONFIG="$CONFIG_DIR/gtk-3.0"
GTK4_CONFIG="$CONFIG_DIR/gtk-4.0"
sudo -u "$USER_NAME" mkdir -p "$GTK3_CONFIG" "$GTK4_CONFIG"

GTK_SETTINGS="[Settings]\ngtk-theme-name=Dracula\ngtk-icon-theme-name=Dracula\ngtk-font-name=JetBrainsMono 10"

sudo -u "$USER_NAME" bash -c "echo -e \"$GTK_SETTINGS\" | tee \"$GTK3_CONFIG/settings.ini\" \"$GTK4_CONFIG/settings.ini\" >/dev/null"

HYPR_VARS_FILE="$CONFIG_DIR/hypr/hypr-vars.conf"
sudo -u "$USER_NAME" tee "$HYPR_VARS_FILE" >/dev/null <<'EOF_HYPR_VARS'
# Set GTK theme and icon theme
env = GTK_THEME,Dracula
env = ICON_THEME,Dracula
# Set XDG desktop to Hyprland
env = XDG_CURRENT_DESKTOP,Hyprland
EOF_HYPR_VARS

# Source the new config file in the main Hyprland config
HYPR_CONF="$CONFIG_DIR/hypr/hyprland.conf"
if [ -f "$HYPR_CONF" ] && ! grep -q "source = $HYPR_VARS_FILE" "$HYPR_CONF"; then
    sudo -u "$USER_NAME" echo -e "\n# Sourced by the setup script to set GTK and icon themes\nsource = $HYPR_VARS_FILE" >> "$HYPR_CONF"
fi

print_success "✅ GTK themes and icons configured for Hyprland."

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

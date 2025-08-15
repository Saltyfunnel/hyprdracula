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

print_bold_blue() {
    echo -e "\e[1m\e[34m$1\e[0m"
}

# This function is used for critical commands that should halt the script on failure.
run_critical_command() {
    local command="$1"
    local description="$2"
    local confirm_needed="${3:-"yes"}"

    if [ "$confirm_needed" == "yes" ] && [ "$CONFIRMATION" == "yes" ]; then
        read -p "Install '$description'? Press Enter to continue..."
    fi

    echo -e "\nRunning: $command"
    if ! eval "$command"; then
        print_error "Failed to '$description'."
    fi
    print_success "✅ Success: '$description'"
}

# --- Main Execution Logic ---

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root. Please run with 'sudo bash $0'."
fi

# Define variables
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

if [ ! -d "$SCRIPT_DIR/configs" ]; then
    print_error "Required 'configs' directory not found in the script's directory: $SCRIPT_DIR.
    Please ensure the entire repository is cloned and you are running the script from its root directory."
fi
print_success "✅ File structure confirmed."

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
PACKAGES=(
    git base-devel pipewire wireplumber pamixer brightnessctl
    ttf-jetbrains-mono-nerd ttf-iosevka-nerd ttf-fira-code ttf-fira-mono
    sddm kitty nano tar unzip gnome-disk-utility code mpv dunst pacman-contrib exo firefox cava steam
    thunar thunar-archive-plugin thunar-volman tumbler ffmpegthumbnailer file-roller
    gvfs gvfs-mtp gvfs-gphoto2 gvfs-smb polkit polkit-gnome
    waybar wofi hyprland hyprpaper
)
if ! pacman -Syu "${PACKAGES[@]:-}" --noconfirm; then
    print_error "Failed to install system packages."
fi
print_success "✅ System updated and packages installed."

# --- GPU Driver Installation ---
print_header "Installing GPU Drivers"
GPU_INFO=$(lspci | grep -Ei "VGA|3D")

if echo "$GPU_INFO" | grep -qi "nvidia"; then
    print_bold_blue "NVIDIA GPU detected."
    run_critical_command "pacman -S --noconfirm nvidia nvidia-utils nvidia-settings" "Install NVIDIA drivers"
elif echo "$GPU_INFO" | grep -qi "amd"; then
    print_bold_blue "AMD GPU detected."
    run_critical_command "pacman -S --noconfirm xf86-video-amdgpu vulkan-radeon libva-mesa-driver mesa-vdpau" "Install AMD drivers"
elif echo "$GPU_INFO" | grep -qi "intel"; then
    print_bold_blue "Intel GPU detected."
    run_critical_command "pacman -S --noconfirm mesa libva-intel-driver intel-media-driver vulkan-intel" "Install Intel drivers"
else
    print_warning "No supported GPU detected. Info: $GPU_INFO"
    if [ "$CONFIRMATION" == "yes" ]; then
        read -p "Try installing NVIDIA drivers anyway? [Y/n]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            run_critical_command "pacman -S --noconfirm nvidia nvidia-utils nvidia-settings" "Install NVIDIA drivers (forced)"
        fi
    fi
fi
print_success "✅ GPU driver installation complete."

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

print_header "Copying configuration files"
copy_configs "$SCRIPT_DIR/configs/waybar" "$CONFIG_DIR/waybar" "Waybar"
copy_configs "$SCRIPT_DIR/configs/fastfetch" "$CONFIG_DIR/fastfetch" "Fastfetch"
copy_configs "$SCRIPT_DIR/configs/hypr" "$CONFIG_DIR/hypr" "Hyprland"
copy_configs "$SCRIPT_DIR/configs/kitty" "$CONFIG_DIR/kitty" "Kitty"
copy_configs "$SCRIPT_DIR/configs/dunst" "$CONFIG_DIR/dunst" "Dunst"
# FIX: Added line to copy Wofi configuration files
copy_configs "$SCRIPT_DIR/configs/wofi" "$CONFIG_DIR/wofi" "Wofi"

print_header "Setting up Fastfetch and Starship"
# The 'EOT' here-document is now quoted to prevent variable expansion by the root shell.
# This ensures that `$HOME` is correctly evaluated by the target user's shell.
sudo -u "$USER_NAME" bash -c "
    add_fastfetch_to_shell() {
        local shell_config=\"$1\"
        local shell_file=\"\$HOME/\$shell_config\"
        local shell_content=\"\\n# Added by Dracula Hyprland setup script\\nif command -v fastfetch &>/dev/null; then\\n  fastfetch\\nfi\\n\"
        if ! grep -q \"fastfetch\" \"\$shell_file\" 2>/dev/null; then
            echo -e \"\$shell_content\" | tee -a \"\$shell_file\" >/dev/null
        fi
    }
    add_starship_to_shell() {
        local shell_config=\"$1\"
        local shell_type=\"$2\"
        local shell_file=\"\$HOME/\$shell_config\"
        local shell_content=\"\\n# Added by Dracula Hyprland setup script\\neval \\\"\\\$(starship init \$shell_type)\\\"\\n\"
        if ! grep -q \"starship\" \"\$shell_file\" 2>/dev/null; then
            echo -e \"\$shell_content\" | tee -a \"\$shell_file\" >/dev/null
        fi
    }
    
    add_fastfetch_to_shell \".bashrc\" \"bash\"
    add_fastfetch_to_shell \".zshrc\" \"zsh\"
    
    STARSHIP_SRC=\"$USER_HOME/dracula-hyprland-setup/configs/starship/starship.toml\"
    STARSHIP_DEST=\"$USER_HOME/.config/starship.toml\"
    if [ -f \"\$STARSHIP_SRC\" ]; then
        cp \"\$STARSHIP_SRC\" \"\$STARSHIP_DEST\" || echo \"Failed to copy starship config.\"
    fi
    add_starship_to_shell \".bashrc\" \"bash\"
    add_starship_to_shell \".zshrc\" \"zsh\"
"
print_success "✅ Shell integrations complete."

# --- Setting up GTK themes and icons from local zip files ---
print_header "Setting up GTK themes and icons from local zip files"
THEMES_DIR="$USER_HOME/.themes"
ICONS_DIR="$USER_HOME/.icons"
ASSETS_DIR="$SCRIPT_DIR/assets"

# Check if the user's home directory exists and is a directory
if [ ! -d "$USER_HOME" ]; then
    print_error "User home directory '$USER_HOME' not found. Cannot proceed with user-level setup."
fi

if [ ! -f "$ASSETS_DIR/dracula-gtk-master.zip" ]; then
    print_error "Dracula GTK theme archive not found at $ASSETS_DIR/dracula-gtk-master.zip. Please download it and place it there."
fi
if [ ! -f "$ASSETS_DIR/Dracula.zip" ]; then
    print_error "Dracula Icons archive not found at $ASSETS_DIR/Dracula.zip. Please download it and place it there."
fi
print_success "✅ Local asset files confirmed."

# Updated GTK theme installation logic to be more robust
print_success "Installing Dracula GTK theme..."
TEMP_THEME_DIR=$(sudo -u "$USER_NAME" mktemp -d)
sudo -u "$USER_NAME" rm -rf "$THEMES_DIR"/gtk-master
if ! sudo -u "$USER_NAME" unzip "$ASSETS_DIR/dracula-gtk-master.zip" -d "$TEMP_THEME_DIR"; then
    print_error "Unzipping the GTK theme failed. Please check the 'dracula-gtk-master.zip' file for corruption or download issues."
fi
GTK_THEME_NAME=$(sudo -u "$USER_NAME" find "$TEMP_THEME_DIR" -maxdepth 1 -mindepth 1 -type d -printf '%f\n' | head -n 1)
if [ -z "$GTK_THEME_NAME" ]; then
    print_error "The 'dracula-gtk-master.zip' file did not contain a valid theme directory. Please check its contents and re-run the script."
fi
print_success "✅ Found extracted GTK theme folder named: $GTK_THEME_NAME"
# New: Ensure the destination directory exists before moving the files
if ! sudo -u "$USER_NAME" mkdir -p "$THEMES_DIR"; then
    print_error "Failed to create destination directory for GTK theme."
fi
if ! sudo -u "$USER_NAME" mv "$TEMP_THEME_DIR/$GTK_THEME_NAME" "$THEMES_DIR/"; then
    print_error "Failed to move the extracted GTK theme folder into the user's .themes directory."
fi
sudo -u "$USER_NAME" rm -rf "$TEMP_THEME_DIR"
print_success "✅ Successfully installed the GTK theme."

# Updated Icons installation logic to be more robust
print_success "Installing Dracula Icons..."
TEMP_ICON_DIR=$(sudo -u "$USER_NAME" mktemp -d)
sudo -u "$USER_NAME" rm -rf "$ICONS_DIR"/Dracula
if ! sudo -u "$USER_NAME" unzip "$ASSETS_DIR/Dracula.zip" -d "$TEMP_ICON_DIR"; then
    print_error "Unzipping the Icon theme failed. Please check the 'Dracula.zip' file for corruption or download issues."
fi
ICON_THEME_NAME=$(sudo -u "$USER_NAME" find "$TEMP_ICON_DIR" -maxdepth 1 -mindepth 1 -type d -printf '%f\n' | head -n 1)
if [ -z "$ICON_THEME_NAME" ]; then
    print_error "The 'Dracula.zip' file did not contain a valid icon directory. Please check its contents and re-run the script."
fi
print_success "✅ Found extracted Icon theme folder named: $ICON_THEME_NAME"
# New: Ensure the destination directory exists before moving the files
if ! sudo -u "$USER_NAME" mkdir -p "$ICONS_DIR"; then
    print_error "Failed to create destination directory for Icon theme."
fi
if ! sudo -u "$USER_NAME" mv "$TEMP_ICON_DIR/$ICON_THEME_NAME" "$ICONS_DIR/"; then
    print_error "Failed to move the extracted Icon theme folder into the user's .icons directory."
fi
sudo -u "$USER_NAME" rm -rf "$TEMP_ICON_DIR"
print_success "✅ Successfully installed the Icon theme."


# --- The key addition: Update the icon cache to ensure icons are found by applications like Thunar. ---
if command -v gtk-update-icon-cache &>/dev/null; then
    print_success "Updating the GTK icon cache for a smooth user experience..."
    sudo -u "$USER_NAME" gtk-update-icon-cache -f -t "$ICONS_DIR/$ICON_THEME_NAME" || true
else
    print_warning "gtk-update-icon-cache not found. Icons may not appear correctly until a reboot."
fi

# New, robust way to write settings.ini using here-documents
print_header "Setting GTK themes in settings.ini"
# The 'EOF_GTK' here-document is now quoted to prevent variable expansion by the root shell.
# This ensures that `$HOME` is correctly evaluated by the target user's shell.
sudo -u "$USER_NAME" HOME="$USER_HOME" bash <<EOF_GTK
    # Write settings.ini for gtk-3.0
    mkdir -p "\$HOME/.config/gtk-3.0"
    cat > "\$HOME/.config/gtk-3.0/settings.ini" <<EOT_GTK3
[Settings]
gtk-theme-name=$GTK_THEME_NAME
gtk-icon-theme-name=$ICON_THEME_NAME
gtk-font-name=JetBrainsMono 10
EOT_GTK3

    # Write settings.ini for gtk-4.0
    mkdir -p "\$HOME/.config/gtk-4.0"
    cat > "\$HOME/.config/gtk-4.0/settings.ini" <<EOT_GTK4
[Settings]
gtk-theme-name=$GTK_THEME_NAME
gtk-icon-theme-name=$ICON_THEME_NAME
gtk-font-name=JetBrainsMono 10
EOT_GTK4
EOF_GTK
print_success "✅ GTK settings files created."

# --- FIX: GSettings and Thunar restart block now uses variables correctly ---
print_header "Applying GTK themes with gsettings and restarting Thunar"
sudo -u "$USER_NAME" bash <<EOF_GSETTINGS
    set -euo pipefail
    
    # Get the user's UID and DBUS path in the correct context
    USER_UID=\$(id -u)
    DBUS_PATH="unix:path=/run/user/\${USER_UID}/bus"
    
    # GSettings commands
    if command -v gsettings &>/dev/null; then
        echo 'Using gsettings to apply GTK themes.'
        env DBUS_SESSION_BUS_ADDRESS="\${DBUS_PATH}" gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME_NAME"
        env DBUS_SESSION_BUS_ADDRESS="\${DBUS_PATH}" gsettings set org.gnome.desktop.interface icon-theme "$ICON_THEME_NAME"
        echo '✅ Themes applied with gsettings.'
    else
        echo 'gsettings not found. Themes may not apply correctly to all applications.'
    fi
    
    # Thunar restart commands
    if command -v thunar &>/dev/null; then
        echo 'Restarting Thunar to apply changes'
        env DBUS_SESSION_BUS_ADDRESS="\${DBUS_PATH}" pkill thunar || true
        env DBUS_SESSION_BUS_ADDRESS="\${DBUS_PATH}" thunar &
        echo '✅ Thunar restarted successfully.'
    else
        echo 'Thunar not found, skipping restart.'
    fi
EOF_GSETTINGS

# --- FIX: New section to use xfconf-query to apply themes for XFCE apps like Thunar ---
print_header "Applying GTK theme with xfconf-query for XFCE apps"
if command -v xfconf-query &>/dev/null; then
    sudo -u "$USER_NAME" xfconf-query -c xsettings -p /Net/ThemeName -s "$GTK_THEME_NAME" --create -t string
    sudo -u "$USER_NAME" xfconf-query -c xsettings -p /Net/IconThemeName -s "$ICON_THEME_NAME" --create -t string
    print_success "✅ Themes applied with xfconf-query."
else
    print_warning "xfconf-query not found. Themes may not apply correctly to all XFCE applications."
fi


HYPR_VARS_FILE="$CONFIG_DIR/hypr/hypr-vars.conf"
sudo -u "$USER_NAME" tee "$HYPR_VARS_FILE" >/dev/null <<EOF_HYPR_VARS
# Set GTK theme and icon theme for Hyprland
env = GTK_THEME,$GTK_THEME_NAME
env = ICON_THEME,$ICON_THEME_NAME
# Set XDG desktop to Hyprland
env = XDG_CURRENT_DESKTOP,Hyprland
EOF_HYPR_VARS

HYPR_CONF="$CONFIG_DIR/hypr/hyprland.conf"
if [ -f "$HYPR_CONF" ] && ! grep -q "source = $HYPR_VARS_FILE" "$HYPR_CONF"; then
    sudo -u "$USER_NAME" echo -e "\n# Sourced by the setup script to set GTK and icon themes\nsource = $HYPR_VARS_FILE" >> "$HYPR_CONF"
fi

# Apply the new wallpaper and launcher configs
print_header "Updating Hyprland and Waybar configs for Pacman packages"
sudo -u "$USER_NAME" sed -i 's/^exec-once = swww-daemon$/exec-once = hyprpaper/' "$CONFIG_DIR/hypr/hyprland.conf"
sudo -u "$USER_NAME" sed -i 's/^bind = \$mainMod, R, exec, tofi-drun$/bind = \$mainMod, R, exec, wofi --show drun/' "$CONFIG_DIR/hypr/hyprland.conf"
sudo -u "$USER_NAME" sed -i 's/"swww"/"hyprpaper"/' "$CONFIG_DIR/waybar/config"
sudo -u "$USER_NAME" sed -i 's/swww.js//' "$CONFIG_DIR/waybar/config"
sudo -u "$USER_NAME" sed -i 's/\.swww {/\.hyprpaper {/' "$CONFIG_DIR/waybar/style.css"
sudo -u "$USER_NAME" sed -i 's/swww-next.sh/hyprpaper-next.sh/' "$CONFIG_DIR/waybar/config"
print_success "✅ Hyprland and Waybar configs updated to use wofi and hyprpaper."

print_success "✅ GTK themes and icons configured for Hyprland."

print_header "Creating backgrounds directory"
WALLPAPER_SRC="$SCRIPT_DIR/assets/backgrounds"
WALLPAPER_DEST="$CONFIG_DIR/assets/backgrounds"
if [ ! -d "$WALLPAPER_SRC" ]; then
    print_warning "Source backgrounds directory not found. Creating a placeholder directory at $WALLPAPER_SRC. Please place your wallpapers there."
    sudo -u "$USER_NAME" mkdir -p "$WALLPAPER_SRC"
else
    print_success "✅ Source backgrounds directory exists."
fi

print_success "Copying backgrounds from '$WALLPAPER_SRC' to '$WALLPAPER_DEST'."
sudo -u "$USER_NAME" mkdir -p "$WALLPAPER_DEST"
sudo -u "$USER_NAME" cp -r "$WALLPAPER_SRC/." "$WALLPAPER_DEST"
print_success "✅ Wallpapers copied to $WALLPAPER_DEST."

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

print_success "\n🎉 The installation is complete! Please reboot your system to apply all changes."

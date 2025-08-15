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

# This new function is for non-critical commands that should be tried, but not fatal.
run_nonfatal_command() {
    local command="$1"
    local description="$2"
    echo -e "\nAttempting: $description"
    if ! eval "$command"; then
        print_warning "Failed to '$description'. Skipping this step."
        return 1
    fi
    print_success "✅ Success: '$description'"
    return 0
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
    waybar
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

# Modified to use the new non-fatal run function
if ! sudo -u "$USER_NAME" command -v yay &>/dev/null; then
    print_header "Installing yay from AUR"
    if sudo -u "$USER_NAME" bash -c '
        set -e
        YAY_TEMP_DIR="$(mktemp -d -p "$HOME")"
        cd "$YAY_TEMP_DIR" || exit 1
        
        # Git clone command is now wrapped to allow failure without exiting the whole script
        git clone https://aur.archlinux.org/yay.git || { echo "Failed to clone yay.git"; exit 1; }
        
        cd yay || exit 1
        makepkg -si --noconfirm
        
        rm -rf "$YAY_TEMP_DIR"
    '; then
        print_success "✅ Success: yay installed from AUR"
    else
        print_warning "❌ Failed: yay installation failed (non-fatal). The script will continue."
    fi
else
    print_header "yay is already installed."
fi

declare -a AUR_PACKAGES=(tofi fastfetch swww hyprpicker hyprlock grimblast hypridle starship spotify protonplus)
if [[ "${#AUR_PACKAGES[@]}" -gt 0 ]]; then
    print_header "Installing AUR packages..."
    # The yay command is also now run in a non-fatal way
    if ! sudo -u "$USER_NAME" yay -S --noconfirm "${AUR_PACKAGES[@]}"; then
        print_warning "Installation of some AUR packages failed (non-fatal). The script will continue."
    else
        print_success "✅ All AUR packages installed."
    fi
else
    print_warning "No AUR packages to install. Skipping package installation."
fi

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
copy_configs "$SCRIPT_DIR/configs/tofi" "$CONFIG_DIR/tofi" "Tofi"
copy_configs "$SCRIPT_DIR/configs/fastfetch" "$CONFIG_DIR/fastfetch" "Fastfetch"
copy_configs "$SCRIPT_DIR/configs/hypr" "$CONFIG_DIR/hypr" "Hyprland"
copy_configs "$SCRIPT_DIR/configs/kitty" "$CONFIG_DIR/kitty" "Kitty"
copy_configs "$SCRIPT_DIR/configs/dunst" "$CONFIG_DIR/dunst" "Dunst"

print_header "Setting up Fastfetch and Starship"
# Corrected with a 'here document' to avoid quoting issues
sudo -u "$USER_NAME" bash <<'EOT'
    add_fastfetch_to_shell() {
        local shell_config="$1"
        local shell_file="$HOME/$shell_config"
        local shell_content="\n# Added by Dracula Hyprland setup script\nif command -v fastfetch &>/dev/null; then\n  fastfetch\nfi\n"
        if ! grep -q "fastfetch" "$shell_file" 2>/dev/null; then
            echo -e "$shell_content" | tee -a "$shell_file" >/dev/null
        fi
    }
    add_starship_to_shell() {
        local shell_config="$1"
        local shell_type="$2"
        local shell_file="$HOME/$shell_config"
        local shell_content="\n# Added by Dracula Hyprland setup script\neval \"$(starship init $shell_type)\"\n"
        if ! grep -q "starship" "$shell_file" 2>/dev/null; then
            echo -e "$shell_content" | tee -a "$shell_file" >/dev/null
        fi
    }
    
    add_fastfetch_to_shell ".bashrc" "bash"
    add_fastfetch_to_shell ".zshrc" "zsh"
    
    STARSHIP_SRC="/home/$USER/dracula-hyprland-setup/configs/starship/starship.toml"
    STARSHIP_DEST="/home/$USER/.config/starship.toml"
    if [ -f "$STARSHIP_SRC" ]; then
        cp "$STARSHIP_SRC" "$STARSHIP_DEST" || echo "Failed to copy starship config."
    fi
    add_starship_to_shell ".bashrc" "bash"
    add_starship_to_shell ".zshrc" "zsh"
EOT
print_success "✅ Shell integrations complete."

# --- Setting up GTK themes and icons from local zip files ---
print_header "Setting up GTK themes and icons from local zip files"
THEMES_DIR="$USER_HOME/.themes"
ICONS_DIR="$USER_HOME/.icons"
ASSETS_DIR="$SCRIPT_DIR/assets"

if [ ! -f "$ASSETS_DIR/dracula-gtk-master.zip" ]; then
    print_error "Dracula GTK theme archive not found at $ASSETS_DIR/dracula-gtk-master.zip. Please download it and place it there."
fi
if [ ! -f "$ASSETS_DIR/Dracula.zip" ]; then
    print_error "Dracula Icons archive not found at $ASSETS_DIR/Dracula.zip. Please download it and place it there."
fi
print_success "✅ Local asset files confirmed."

# Corrected GTK theme installation logic
print_success "Installing Dracula GTK theme..."
# Clean up any previous install to prevent overwrite errors
sudo -u "$USER_NAME" rm -rf "$THEMES_DIR/dracula-gtk" "$THEMES_DIR/dracula-gtk-master"
sudo -u "$USER_NAME" mkdir -p "$THEMES_DIR"
sudo -u "$USER_NAME" unzip -o "$ASSETS_DIR/dracula-gtk-master.zip" -d "$THEMES_DIR" >/dev/null

# Find the unzipped folder and rename it correctly
UNZIPPED_GTK_DIR=$(sudo -u "$USER_NAME" find "$THEMES_DIR" -maxdepth 1 -mindepth 1 -type d -name "*dracula-gtk*" | head -n 1)
if [ -n "$UNZIPPED_GTK_DIR" ] && [ "$(basename "$UNZIPPED_GTK_DIR")" != "dracula-gtk" ]; then
    print_success "Renaming '$(basename "$UNZIPPED_GTK_DIR")' to 'dracula-gtk'..."
    if ! sudo -u "$USER_NAME" mv "$UNZIPPED_GTK_DIR" "$THEMES_DIR/dracula-gtk"; then
        print_warning "Failed to rename GTK theme folder. Theme may not appear correctly."
    else
        print_success "✅ GTK theme folder renamed to dracula-gtk."
    fi
fi
print_success "✅ Dracula GTK theme installed."

# Corrected Icons installation logic
print_success "Installing Dracula Icons..."
# Clean up any previous install to prevent overwrite errors
sudo -u "$USER_NAME" rm -rf "$ICONS_DIR/Dracula" "$ICONS_DIR/Dracula-*"
sudo -u "$USER_NAME" mkdir -p "$ICONS_DIR"
sudo -u "$USER_NAME" unzip -o "$ASSETS_DIR/Dracula.zip" -d "$ICONS_DIR" >/dev/null

# Find the unzipped folder and rename it correctly
ACTUAL_ICON_DIR=$(sudo -u "$USER_NAME" find "$ICONS_DIR" -maxdepth 1 -mindepth 1 -type d -name "*Dracula*" | head -n 1)
if [ -n "$ACTUAL_ICON_DIR" ] && [ "$(basename "$ACTUAL_ICON_DIR")" != "Dracula" ]; then
    print_success "Renaming '$(basename "$ACTUAL_ICON_DIR")' to '$ICONS_DIR/Dracula'..."
    if ! sudo -u "$USER_NAME" mv "$ACTUAL_ICON_DIR" "$ICONS_DIR/Dracula"; then
        print_warning "Failed to rename icon folder. Icons may not appear correctly."
    else
        print_success "✅ Icon folder renamed to Dracula."
    fi
fi
print_success "✅ Dracula Icons installed."

# --- The key addition: Update the icon cache to ensure icons are found by applications like Thunar. ---
if command -v gtk-update-icon-cache &>/dev/null; then
    print_success "Updating the GTK icon cache for a smooth user experience..."
    sudo -u "$USER_NAME" gtk-update-icon-cache -f -t "$ICONS_DIR/Dracula"
    print_success "✅ GTK icon cache updated successfully."
else
    print_warning "gtk-update-icon-cache not found. Icons may not appear correctly until a reboot."
fi

# New, robust way to write settings.ini using here-documents
print_header "Setting GTK themes in settings.ini"
sudo -u "$USER_NAME" bash <<EOF_GTK
    # Write settings.ini for gtk-3.0
    mkdir -p "$HOME/.config/gtk-3.0"
    cat > "$HOME/.config/gtk-3.0/settings.ini" <<EOT_GTK3
[Settings]
gtk-theme-name=dracula-gtk
gtk-icon-theme-name=Dracula
gtk-font-name=JetBrainsMono 10
EOT_GTK3

    # Write settings.ini for gtk-4.0
    mkdir -p "$HOME/.config/gtk-4.0"
    cat > "$HOME/.config/gtk-4.0/settings.ini" <<EOT_GTK4
[Settings]
gtk-theme-name=dracula-gtk
gtk-icon-theme-name=Dracula
gtk-font-name=JetBrainsMono 10
EOT_GTK4
EOF_GTK
print_success "✅ GTK settings files created."

# --- FIX: New, robust gsettings commands using the user's D-Bus session ---
if command -v gsettings &>/dev/null; then
    print_success "Using gsettings to apply GTK themes."
    # Get the user's UID for the run directory path
    user_uid=$(id -u "$USER_NAME")
    # Run gsettings with the user's correct D-Bus session environment
    sudo -u "$USER_NAME" env DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${user_uid}/bus" gsettings set org.gnome.desktop.interface gtk-theme "dracula-gtk"
    sudo -u "$USER_NAME" env DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${user_uid}/bus" gsettings set org.gnome.desktop.interface icon-theme "Dracula"
    print_success "✅ Themes applied with gsettings."
else
    print_warning "gsettings not found. Themes may not apply correctly to all applications."
fi

HYPR_VARS_FILE="$CONFIG_DIR/hypr/hypr-vars.conf"
sudo -u "$USER_NAME" tee "$HYPR_VARS_FILE" >/dev/null <<'EOF_HYPR_VARS'
# Set GTK theme and icon theme
env = GTK_THEME,dracula-gtk
env = ICON_THEME,Dracula
# Set XDG desktop to Hyprland
env = XDG_CURRENT_DESKTOP,Hyprland
EOF_HYPR_VARS

HYPR_CONF="$CONFIG_DIR/hypr/hyprland.conf"
if [ -f "$HYPR_CONF" ] && ! grep -q "source = $HYPR_VARS_FILE" "$HYPR_CONF"; then
    sudo -u "$USER_NAME" echo -e "\n# Sourced by the setup script to set GTK and icon themes\nsource = $HYPR_VARS_FILE" >> "$HYPR_CONF"
fi

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

sudo -u "$USER_NAME" pkill thunar || true
sudo -u "$USER_NAME" thunar &
print_success "✅ Thunar restarted."

print_success "\n🎉 The installation is complete! Please reboot your system to apply all changes."

#!/bin/bash
# A more robust and interactive script for setting up Dracula Hyprland on Arch Linux.
# This script has been modified to be self-contained and handle user input.
set -euo pipefail

# --- User and Path Variables ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
CONFIG_DIR="$USER_HOME/.config"
REPO_DIR="$USER_HOME/hyprdracula"
ASSETS_SRC="$REPO_DIR/assets"
ASSETS_DEST="$CONFIG_DIR/assets"

# --- Argument Parsing ---
# Check for a single argument: '--noconfirm'
CONFIRMATION="yes"
if [[ $# -eq 1 && "$1" == "--noconfirm" ]]; then
    echo "Running in non-interactive mode. All package installations will be automatic."
    CONFIRMATION="no"
elif [[ $# -gt 0 ]]; then
    echo "Usage: $0 [--noconfirm]"
    exit 1
fi

# --- Helper Functions ---
# These functions were previously in a separate helper.sh
print_header() {
    echo -e "\n--- \e[1m\e[34m$1\e[0m ---"
}

print_success() {
    echo -e "\e[32m$1\e[0m"
}

print_warning() {
    echo -e "\e[33mWarning: $1\e[0m"
}

print_error() {
    echo -e "\e[31mError: $1\e[0m" >&2
}

run_command() {
    local cmd="$1"
    local desc="$2"
    local is_sudo="${3:-no}"
    local handle_error="${4:-yes}"

    print_header "$desc"
    
    if [ "$CONFIRMATION" == "yes" ]; then
        echo -e "\nRunning: \e[36m$cmd\e[0m"
        read -p "Press Enter to continue, or Ctrl+C to cancel."
    fi

    if [ "$is_sudo" == "yes" ]; then
        if sudo bash -c "$cmd"; then
            print_success "✅ Success: $desc"
        elif [ "$handle_error" == "yes" ]; then
            print_error "❌ Failed: $desc"
            exit 1
        else
            print_warning "⚠️ Failed (non-fatal): $desc"
        fi
    else
        if bash -c "$cmd"; then
            print_success "✅ Success: $desc"
        elif [ "$handle_error" == "yes" ]; then
            print_error "❌ Failed: $desc"
            exit 1
        else
            print_warning "⚠️ Failed (non-fatal): $desc"
        fi
    fi
}

copy_as_user() {
    local src="$1"
    local dest="$2"
    if [ ! -d "$src" ]; then
        print_warning "Source folder not found: $src"
        return
    fi
    # Use the run_command function for consistent output and error handling
    run_command "mkdir -p \"$dest\"" "Create $dest" "yes" "no"
    run_command "cp -r \"$src\"/* \"$dest\"" "Copy $src -> $dest" "yes" "no"
    run_command "chown -R $USER_NAME:$USER_NAME \"$dest\"" "Fix ownership for $dest" "yes" "no"
}

# --- Root and OS checks ---
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "Please run as root using sudo."
        exit 1
    fi
}

check_os() {
    if [ ! -f "/etc/arch-release" ]; then
        print_error "This script is intended for Arch Linux."
        exit 1
    fi
}

# --- Main Script Execution ---
check_root
check_os

print_header "Starting Full Dracula Hyprland Setup"

# --- System packages ---
PACKAGES=(
    git base-devel pipewire wireplumber pamixer brightnessctl
    ttf-jetbrains-mono-nerd ttf-iosevka-nerd ttf-fira-code ttf-fira-mono
    sddm kitty nano tar gnome-disk-utility code mpv dunst pacman-contrib exo firefox cava
    thunar thunar-archive-plugin thunar-volman tumbler ffmpegthumbnailer file-roller
    gvfs gvfs-mtp gvfs-gphoto2 gvfs-smb polkit polkit-gnome
)
# Combined update and install command
run_command "pacman -Syu ${PACKAGES[*]} --noconfirm" "Update system and install packages" "yes"

# --- Enable services ---
run_command "systemctl enable --now polkit.service" "Enable polkit" "yes"
run_command "systemctl enable sddm.service" "Enable SDDM" "yes"

# --- Install yay if missing ---
if ! command -v yay &>/dev/null; then
    print_header "Installing yay from AUR"
    # Execute the entire yay installation process as the non-root user.
    # This prevents makepkg from running as root and avoids permission issues.
    if sudo -u "$USER_NAME" bash -c "
        set -e
        cd /tmp
        git clone https://aur.archlinux.org/yay.git
        cd yay
        makepkg -si --noconfirm
        cd ..
        rm -rf yay
    "; then
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
for pkg in "${AUR_PACKAGES[@]}"; do
    run_command "yay -S --noconfirm $pkg" "Install $pkg via AUR" "yes" "no"
done

# --- Copy configs ---
# Assuming these are in the same directory as the script.
copy_as_user "$SCRIPT_DIR/configs/waybar" "$CONFIG_DIR/waybar"
copy_as_user "$SCRIPT_DIR/configs/tofi" "$CONFIG_DIR/tofi"
copy_as_user "$SCRIPT_DIR/configs/fastfetch" "$CONFIG_DIR/fastfetch"
copy_as_user "$SCRIPT_DIR/configs/hypr" "$CONFIG_DIR/hypr"
copy_as_user "$SCRIPT_DIR/configs/kitty" "$CONFIG_DIR/kitty"
copy_as_user "$SCRIPT_DIR/configs/dunst" "$CONFIG_DIR/dunst"
copy_as_user "$SCRIPT_DIR/assets/backgrounds" "$ASSETS_DEST/backgrounds"

# --- Dracula Tofi Config Override ---
# In this version, we write the config directly to the file.
run_command "mkdir -p \"$CONFIG_DIR/tofi\"" "Ensure tofi config directory exists" "yes" "no"
sudo -u "$USER_NAME" tee "$CONFIG_DIR/tofi/config" >/dev/null <<'EOF'
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
EOF
run_command "chown $USER_NAME:$USER_NAME \"$CONFIG_DIR/tofi/config\"" "Fix ownership of tofi config" "yes" "no"

# --- Fastfetch & Starship shell integration ---
# These functions are now part of the script as well.
add_fastfetch_to_shell() {
    local shell_config="$1"
    local shell_file="$USER_HOME/$shell_config"
    local shell_content="\n# Added by Dracula Hyprland setup script\nif command -v fastfetch &>/dev/null; then\n  fastfetch --w-size 60 --w-border-color 44475a --w-color f8f8f2\nfi\n"
    if ! grep -q "fastfetch" "$shell_file" 2>/dev/null; then
        echo -e "$shell_content" | sudo -u "$USER_NAME" tee -a "$shell_file" >/dev/null
    fi
}

add_starship_to_shell() {
    local shell_config="$1"
    local shell_type="$2"
    local shell_file="$USER_HOME/$shell_config"
    local shell_content="\n# Added by Dracula Hyprland setup script\neval \"\$(starship init $shell_type)\"\n"
    if ! grep -q "starship" "$shell_file" 2>/dev/null; then
        echo -e "$shell_content" | sudo -u "$USER_NAME" tee -a "$shell_file" >/dev/null
    fi
}

add_fastfetch_to_shell ".bashrc"
add_fastfetch_to_shell ".zshrc"

STARSHIP_SRC="$SCRIPT_DIR/configs/starship/starship.toml"
STARSHIP_DEST="$CONFIG_DIR/starship.toml"
if [ -f "$STARSHIP_SRC" ]; then
    run_command "cp \"$STARSHIP_SRC\" \"$STARSHIP_DEST\"" "Copy starship config" "yes" "no"
    run_command "chown \"$USER_NAME:$USER_NAME\" \"$STARSHIP_DEST\"" "Fix ownership of starship config" "yes" "no"
fi
add_starship_to_shell ".bashrc" "bash"
add_starship_to_shell ".zshrc" "zsh"

# --- GTK Dracula theme and icon setup ---
THEMES_DIR="$USER_HOME/.themes"
ICONS_DIR="$USER_HOME/.icons"

run_command "mkdir -p \"$THEMES_DIR\" \"$ICONS_DIR\"" "Create themes and icons directories" "yes"

# Copy themes/icons from repo
copy_as_user "$SCRIPT_DIR/assets/themes/Dracula" "$THEMES_DIR/Dracula"
copy_as_user "$SCRIPT_DIR/assets/icons/Dracula" "$ICONS_DIR/Dracula"

# Create GTK settings
GTK3_CONFIG="$CONFIG_DIR/gtk-3.0"
GTK4_CONFIG="$CONFIG_DIR/gtk-4.0"
run_command "mkdir -p \"$GTK3_CONFIG\" \"$GTK4_CONFIG\"" "Create GTK config directories" "yes"

GTK_SETTINGS="[Settings]
gtk-theme-name=Dracula
gtk-icon-theme-name=Dracula
gtk-font-name=JetBrainsMono 10"

echo "$GTK_SETTINGS" | sudo -u "$USER_NAME" tee "$GTK3_CONFIG/settings.ini" "$GTK4_CONFIG/settings.ini" >/dev/null
run_command "chown -R \"$USER_NAME:$USER_NAME\" \"$GTK3_CONFIG\" \"$GTK4_CONFIG\"" "Fix ownership of GTK config" "yes"

# Ensure GTK apps pick up theme via .xprofile
XPROFILE="$USER_HOME/.xprofile"
run_command "echo \"export GTK_THEME=Dracula\nexport ICON_THEME=Dracula\nexport XDG_CURRENT_DESKTOP=Hyprland\" >> \"$XPROFILE\"" "Add GTK and XDG vars to .xprofile" "no" "yes"
run_command "chown \"$USER_NAME:$USER_NAME\" \"$XPROFILE\"" "Fix ownership of .xprofile" "yes" "no"

# --- Thunar Kitty custom action ---
UCA_DIR="$CONFIG_DIR/Thunar"
UCA_FILE="$UCA_DIR/uca.xml"
run_command "mkdir -p \"$UCA_DIR\"" "Create Thunar UCA directory" "yes"
run_command "chown \"$USER_NAME:$USER_NAME\" \"$UCA_DIR\"" "Fix ownership of Thunar UCA directory" "yes"
run_command "chmod 700 \"$UCA_DIR\"" "Set permissions for Thunar UCA directory" "yes" "no"

if [ ! -f "$UCA_FILE" ]; then
    sudo -u "$USER_NAME" tee "$UCA_FILE" >/dev/null <<EOF
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
EOF
    run_command "chown \"$USER_NAME:$USER_NAME\" \"$UCA_FILE\"" "Fix ownership of Thunar UCA file" "yes"
fi

# --- Restart Thunar to apply theme ---
run_command "sudo -u \"$USER_NAME\" pkill thunar || true" "Kill Thunar to apply theme changes" "yes" "no"
run_command "sudo -u \"$USER_NAME\" thunar &" "Restart Thunar" "yes" "no"

print_success "\n✅ Full Dracula Hyprland setup complete! Reboot or log out/in to apply all GTK and Thunar changes."

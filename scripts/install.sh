#!/bin/bash
# A one-stop script for installing a Dracula-themed Hyprland setup on Arch Linux.
# This script handles both system-level and user-level tasks in a single run.
set -euo pipefail

# --- User and Path Variables ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
CONFIG_DIR="$USER_HOME/.config"
REPO_DIR="$SCRIPT_DIR"

# --- Argument Parsing ---
CONFIRMATION="yes"
if [[ $# -eq 1 && "$1" == "--noconfirm" ]]; then
    echo "Running in non-interactive mode. All package installations will be automatic."
    CONFIRMATION="no"
elif [[ $# -gt 0 ]]; then
    echo "Usage: $0 [--noconfirm]"
    exit 1
fi

# --- Helper Functions ---
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

# --- System-level tasks (run as root) ---
run_system_setup() {
    # --- Root and OS checks ---
    if [ "$EUID" -ne 0 ]; then
        print_error "Please run this script as root using sudo."
        exit 1
    fi

    if [ ! -f "/etc/arch-release" ]; then
        print_error "This script is intended for Arch Linux."
        exit 1
    fi

    print_header "Starting System-Level Setup"

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

    print_success "\n✅ System-level setup is complete! Now starting user-level setup."
}

# --- User-level tasks (run as a regular user) ---
run_user_setup() {
    print_header "Starting User-Level Setup"

    # --- Install yay if missing ---
    if ! command -v yay &>/dev/null; then
        print_header "Installing yay from AUR"
        if bash -c "
            set -e
            # Create a temporary directory in the user's home
            YAY_TEMP_DIR=\"\$(mktemp -d -p \"\$HOME\")\"
            cd \"\$YAY_TEMP_DIR\"
            
            git clone https://aur.archlinux.org/yay.git
            cd yay
            makepkg -si --noconfirm
            
            # Clean up the temporary directory
            rm -rf \"\$YAY_TEMP_DIR\"
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
        run_command "yay -S --noconfirm $pkg" "Install $pkg via AUR" "no" "no"
    done

    # --- Copy configs ---
    run_command "mkdir -p \"$CONFIG_DIR/waybar\"" "Create waybar config dir" "no" "no"
    run_command "cp -r \"$REPO_DIR/configs/waybar\"/* \"$CONFIG_DIR/waybar\"" "Copy waybar config" "no" "no"
    run_command "mkdir -p \"$CONFIG_DIR/tofi\"" "Create tofi config dir" "no" "no"
    run_command "cp -r \"$REPO_DIR/configs/tofi\"/* \"$CONFIG_DIR/tofi\"" "Copy tofi config" "no" "no"
    run_command "mkdir -p \"$CONFIG_DIR/fastfetch\"" "Create fastfetch config dir" "no" "no"
    run_command "cp -r \"$REPO_DIR/configs/fastfetch\"/* \"$CONFIG_DIR/fastfetch\"" "Copy fastfetch config" "no" "no"
    run_command "mkdir -p \"$CONFIG_DIR/hypr\"" "Create hypr config dir" "no" "no"
    run_command "cp -r \"$REPO_DIR/configs/hypr\"/* \"$CONFIG_DIR/hypr\"" "Copy hypr config" "no" "no"
    run_command "mkdir -p \"$CONFIG_DIR/kitty\"" "Create kitty config dir" "no" "no"
    run_command "cp -r \"$REPO_DIR/configs/kitty\"/* \"$CONFIG_DIR/kitty\"" "Copy kitty config" "no" "no"
    run_command "mkdir -p \"$CONFIG_DIR/dunst\"" "Create dunst config dir" "no" "no"
    run_command "cp -r \"$REPO_DIR/configs/dunst\"/* \"$CONFIG_DIR/dunst\"" "Copy dunst config" "no" "no"
    run_command "mkdir -p \"$CONFIG_DIR/assets/backgrounds\"" "Create assets config dir" "no" "no"
    run_command "cp -r \"$REPO_DIR/assets/backgrounds\"/* \"$CONFIG_DIR/assets/backgrounds\"" "Copy assets" "no" "no"

    # --- Dracula Tofi Config Override ---
    run_command "mkdir -p \"$CONFIG_DIR/tofi\"" "Ensure tofi config directory exists" "no" "no"
    tee "$CONFIG_DIR/tofi/config" >/dev/null <<'EOF'
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

    # --- Fastfetch & Starship shell integration ---
    add_fastfetch_to_shell() {
        local shell_config="$1"
        local shell_file="$USER_HOME/$shell_config"
        local shell_content="\n# Added by Dracula Hyprland setup script\nif command -v fastfetch &>/dev/null; then\n  fastfetch --w-size 60 --w-border-color 44475a --w-color f8f8f2\nfi\n"
        if ! grep -q "fastfetch" "$shell_file" 2>/dev/null; then
            echo -e "$shell_content" | tee -a "$shell_file" >/dev/null
        fi
    }

    add_starship_to_shell() {
        local shell_config="$1"
        local shell_type="$2"
        local shell_file="$USER_HOME/$shell_config"
        local shell_content="\n# Added by Dracula Hyprland setup script\neval \"\$(starship init $shell_type)\"\n"
        if ! grep -q "starship" "$shell_file" 2>/dev/null; then
            echo -e "$shell_content" | tee -a "$shell_file" >/dev/null
        fi
    }

    add_fastfetch_to_shell ".bashrc"
    add_fastfetch_to_shell ".zshrc"

    STARSHIP_SRC="$REPO_DIR/configs/starship/starship.toml"
    STARSHIP_DEST="$CONFIG_DIR/starship.toml"
    if [ -f "$STARSHIP_SRC" ]; then
        run_command "cp \"$STARSHIP_SRC\" \"$STARSHIP_DEST\"" "Copy starship config" "no" "no"
    fi
    add_starship_to_shell ".bashrc" "bash"
    add_starship_to_shell ".zshrc" "zsh"

    # --- GTK Dracula theme and icon setup ---
    THEMES_DIR="$USER_HOME/.themes"
    ICONS_DIR="$USER_HOME/.icons"

    run_command "mkdir -p \"$THEMES_DIR\" \"$ICONS_DIR\"" "Create themes and icons directories" "no"

    # Copy themes/icons from repo
    run_command "cp -r \"$REPO_DIR/assets/themes/Dracula\" \"$THEMES_DIR/Dracula\"" "Copy Dracula theme" "no"
    run_command "cp -r \"$REPO_DIR/assets/icons/Dracula\" \"$ICONS_DIR/Dracula\"" "Copy Dracula icons" "no"

    # Create GTK settings
    GTK3_CONFIG="$CONFIG_DIR/gtk-3.0"
    GTK4_CONFIG="$CONFIG_DIR/gtk-4.0"
    run_command "mkdir -p \"$GTK3_CONFIG\" \"$GTK4_CONFIG\"" "Create GTK config directories" "no"

    GTK_SETTINGS="[Settings]
gtk-theme-name=Dracula
gtk-icon-theme-name=Dracula
gtk-font-name=JetBrainsMono 10"

    echo "$GTK_SETTINGS" | tee "$GTK3_CONFIG/settings.ini" "$GTK4_CONFIG/settings.ini" >/dev/null

    # Ensure GTK apps pick up theme via .xprofile
    XPROFILE="$USER_HOME/.xprofile"
    run_command "echo \"export GTK_THEME=Dracula\nexport ICON_THEME=Dracula\nexport XDG_CURRENT_DESKTOP=Hyprland\" >> \"$XPROFILE\"" "Add GTK and XDG vars to .xprofile" "no" "no"

    # --- Thunar Kitty custom action ---
    UCA_DIR="$CONFIG_DIR/Thunar"
    UCA_FILE="$UCA_DIR/uca.xml"
    run_command "mkdir -p \"$UCA_DIR\"" "Create Thunar UCA directory" "no"
    run_command "chmod 700 \"$UCA_DIR\"" "Set permissions for Thunar UCA directory" "no" "no"

    if [ ! -f "$UCA_FILE" ]; then
        tee "$UCA_FILE" >/dev/null <<EOF
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
    fi

    # --- Restart Thunar to apply theme ---
    run_command "pkill thunar || true" "Kill Thunar to apply theme changes" "no" "no"
    run_command "thunar &" "Restart Thunar" "no" "no"
}

# --- Main execution logic ---
# Check if the script is running as root
if [ "$EUID" -eq 0 ]; then
    run_system_setup
    # Now, run the user-level setup as the original user
    sudo -u "$USER_NAME" bash "$0" --user-only
else
    # If the user-only flag is set, run the user setup
    if [[ "$1" == "--user-only" ]]; then
        run_user_setup
    else
        print_error "This script must be run as root. Please run with 'sudo bash $0'."
        exit 1
    fi
fi

print_success "\n🎉 The installation is complete! Please reboot your system to apply all changes."

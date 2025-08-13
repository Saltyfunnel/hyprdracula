#!/bin/bash

SCRIPT_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo "~$USER_NAME")

source "$SCRIPT_DIR/helper.sh"

check_root
check_os

print_header "Starting prerequisites setup..."

# Update system
run_command "pacman -Syyu --noconfirm" "Update system packages" "yes"

# Install yay if missing
if ! command -v yay &>/dev/null; then
    print_info "Yay not found. Installing yay..."
    run_command "pacman -S --noconfirm --needed git base-devel" "Install git & base-devel" "yes"
    run_command "git clone https://aur.archlinux.org/yay.git /tmp/yay" "Clone yay repository" "no" "no"
    run_command "chown -R $USER_NAME:$USER_NAME /tmp/yay" "Fix ownership of yay build dir" "no" "no"
    run_command "cd /tmp/yay && sudo -u $USER_NAME makepkg -si --noconfirm" "Build and install yay" "no" "no"
    run_command "rm -rf /tmp/yay" "Clean up yay build dir" "no" "no"
else
    print_success "Yay is already installed."
fi

# Core system packages
PACKAGES=(
    pipewire wireplumber pamixer brightnessctl
    ttf-cascadia-code-nerd ttf-cascadia-mono-nerd ttf-fira-code ttf-fira-mono ttf-fira-sans
    ttf-iosevka-nerd ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-mono
    sddm kitty nano tar gnome-disk-utility code mpv dunst pacman-contrib exo
    thunar thunar-archive-plugin thunar-volman tumbler ffmpegthumbnailer file-roller
    gvfs gvfs-mtp gvfs-gphoto2 gvfs-smb polkit polkit-gnome
)
run_command "pacman -S --noconfirm ${PACKAGES[*]}" "Install system packages" "yes"

# Enable essential services
run_command "systemctl enable --now polkit.service" "Enable polkit"
run_command "systemctl enable sddm.service" "Enable SDDM display manager"

# Optional browser
run_command "yay -S --sudoloop --noconfirm firefox" "Install Firefox (AUR)" "yes" "no"

echo "------------------------------------------------------------------------"

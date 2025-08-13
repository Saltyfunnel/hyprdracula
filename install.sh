#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo "~$USER_NAME")
REPO_DIR="$USER_HOME/hyprdracula"
CONFIG_DIR="$USER_HOME/.config"
ASSETS_SRC="$REPO_DIR/assets"
ASSETS_DEST="$CONFIG_DIR/assets"

source "$SCRIPT_DIR/helper.sh"

check_root
check_os

print_bold_blue "\n🚀 Starting Full Hyprland + Dracula Setup"
echo "-------------------------------------"

# ------------------------------
# PHASE 1: Prerequisites
# ------------------------------
print_header "Installing prerequisites"

run_command "pacman -Syyu --noconfirm" "Update system packages" "yes"

# Install yay if missing
if ! command -v yay &>/dev/null; then
    print_info "Yay not found. Installing yay..."
    run_command "pacman -S --noconfirm --needed git base-devel" "Install git and base-devel" "yes"
    run_command "git clone https://aur.archlinux.org/yay.git /tmp/yay" "Clone yay repository" "no" "no"
    run_command "chown -R $USER_NAME:$USER_NAME /tmp/yay" "Fix ownership of yay build directory" "no" "no"
    run_command "cd /tmp/yay && sudo -u $USER_NAME makepkg -si --noconfirm" "Build and install yay" "no" "no"
    run_command "rm -rf /tmp/yay" "Clean up yay build directory" "no" "no"
else
    print_success "Yay is already installed."
fi

# System packages
PACKAGES=(
    pipewire wireplumber pamixer brightnessctl
    ttf-cascadia-code-nerd ttf-cascadia-mono-nerd ttf-fira-code ttf-fira-mono ttf-fira-sans
    ttf-iosevka-nerd ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-mono
    sddm kitty nano tar gnome-disk-utility code mpv dunst pacman-contrib exo
    thunar thunar-archive-plugin thunar-volman tumbler ffmpegthumbnailer file-roller
    gvfs gvfs-mtp gvfs-gphoto2 gvfs-smb
    polkit polkit-gnome
)
run_command "pacman -S --noconfirm ${PACKAGES[*]}" "Install system packages" "yes"
run_command "systemctl enable --now polkit.service" "Enable polkit daemon" "yes"
run_command "systemctl enable sddm.service" "Enable SDDM display manager" "yes"

# AUR packages
AUR_PACKAGES=(firefox wofi tofi fastfetch swww hyprpicker hyprlock grimblast hypridle starship cliphist)
for pkg in "${AUR_PACKAGES[@]}"; do
    run_command "yay -S --sudoloop --noconfirm $pkg" "Install $pkg" "yes" "no"
done

# ------------------------------
# PHASE 2: GPU Drivers
# ------------------------------
print_header "Detecting GPU and installing drivers"

GPU_INFO=$(lspci | grep -Ei "VGA|3D")
if echo "$GPU_INFO" | grep -qi "nvidia"; then
    print_bold_blue "\nNVIDIA GPU detected."
    run_command "pacman -S --noconfirm nvidia nvidia-utils nvidia-settings" "Install NVIDIA drivers" "yes"
elif echo "$GPU_INFO" | grep -qi "amd"; then
    print_bold_blue "\nAMD GPU detected."
    run_command "pacman -S --noconfirm xf86-video-amdgpu vulkan-radeon libva-mesa-driver mesa-vdpau" "Install AMD drivers" "yes"
elif echo "$GPU_INFO" | grep -qi "intel"; then
    print_bold_blue "\nIntel GPU detected."
    run_command "pacman -S --noconfirm mesa libva-intel-driver intel-media-driver vulkan-intel" "Install Intel drivers" "yes"
else
    print_warning "\nNo supported GPU detected. Info: $GPU_INFO"
    if ask_confirmation "Try installing NVIDIA drivers anyway?"; then
        run_command "pacman -S --noconfirm nvidia nvidia-utils nvidia-settings" "Install NVIDIA drivers (forced)" "yes"
    fi
fi

# ------------------------------
# PHASE 3: Copy Configs & Assets
# ------------------------------
print_header "Copying configs and assets"

copy_as_user() {
    local src="$1"
    local dest="$2"
    run_command "mkdir -p \"$dest\"" "Create $dest" "no" "no"
    run_command "cp -r \"$src\"/* \"$dest\"" "Copy $src to $dest" "yes" "no"
    run_command "chown -R $USER_NAME:$USER_NAME \"$dest\"" "Fix ownership $dest" "no" "yes"
}

# Core configs
copy_as_user "$REPO_DIR/configs/waybar" "$CONFIG_DIR/waybar"
copy_as_user "$REPO_DIR/configs/wofi" "$CONFIG_DIR/wofi"
copy_as_user "$REPO_DIR/configs/fastfetch" "$CONFIG_DIR/fastfetch"
copy_as_user "$REPO_DIR/configs/hypr" "$CONFIG_DIR/hypr"
copy_as_user "$ASSETS_SRC/backgrounds" "$ASSETS_DEST/backgrounds"
copy_as_user "$REPO_DIR/configs/starship" "$CONFIG_DIR/starship"

# Fastfetch integration
for shell_rc in ".bashrc" ".zshrc"; do
    shell_rc_path="$USER_HOME/$shell_rc"
    fastfetch_line='fastfetch --kitty-direct /home/'"$USER_NAME"'/.config/fastfetch/archkitty.png'
    if [ -f "$shell_rc_path" ] && ! grep -qF "$fastfetch_line" "$shell_rc_path"; then
        echo -e "\n# Run fastfetch on terminal start\n$fastfetch_line" >> "$shell_rc_path"
        chown "$USER_NAME:$USER_NAME" "$shell_rc_path"
    fi
done

# Starship prompt integration
for shell_rc in ".bashrc" ".zshrc"; do
    shell_rc_path="$USER_HOME/$shell_rc"
    starship_line='eval "$(starship init '"${shell_rc%.*}"')"'
    if [ -f "$shell_rc_path" ] && ! grep -qF "$starship_line" "$shell_rc_path"; then
        echo -e "\n$starship_line" >> "$shell_rc_path"
        chown "$USER_NAME:$USER_NAME" "$shell_rc_path"
    fi
done

# ------------------------------
# PHASE 4: Dracula GTK + Icons
# ------------------------------
print_header "Setting Dracula GTK and icon theme"

GTK_CONFIGS=("$USER_HOME/.config/gtk-3.0" "$USER_HOME/.config/gtk-4.0")
mkdir -p "${GTK_CONFIGS[@]}"

GTK_SETTINGS_CONTENT="[Settings]
gtk-theme-name=Dracula
gtk-icon-theme-name=Dracula
gtk-font-name=JetBrainsMono 10"

for gtk_cfg in "${GTK_CONFIGS[@]}"; do
    echo "$GTK_SETTINGS_CONTENT" | sudo -u "$USER_NAME" tee "$gtk_cfg/settings.ini" >/dev/null
done

# Dracula SDDM theme
DRACULA_SDDM_REPO="https://github.com/dracula/sddm.git"
DRACULA_SDDM_TEMP="/tmp/dracula-sddm"
DRACULA_THEME_NAME="dracula"

git clone --depth=1 "$DRACULA_SDDM_REPO" "$DRACULA_SDDM_TEMP"
cp -r "$DRACULA_SDDM_TEMP/sddm/themes/$DRACULA_THEME_NAME" "/usr/share/sddm/themes/$DRACULA_THEME_NAME"
chown -R root:root "/usr/share/sddm/themes/$DRACULA_THEME_NAME"
mkdir -p /etc/sddm.conf.d
echo -e "[Theme]\nCurrent=$DRACULA_THEME_NAME" > /etc/sddm.conf.d/10-theme.conf
rm -rf "$DRACULA_SDDM_TEMP"

# ------------------------------
# PHASE 5: Thunar Kitty Action
# ------------------------------
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

# ------------------------------
# PHASE 6: Zsh + Oh My Zsh + Dracula
# ------------------------------
print_header "Installing Zsh + Oh My Zsh + Dracula theme"

if ! command -v zsh &>/dev/null; then
    run_command "pacman -S --noconfirm zsh" "Install Zsh" "yes"
fi

OH_MY_ZSH_DIR="$USER_HOME/.oh-my-zsh"
if [ ! -d "$OH_MY_ZSH_DIR" ]; then
    sudo -u "$USER_NAME" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

chsh -s "$(which zsh)" "$USER_NAME"

# Copy zshrc
ZSHRC_SRC="$REPO_DIR/configs/zsh/.zshrc"
ZSHRC_DEST="$USER_HOME/.zshrc"
if [ -f "$ZSHRC_SRC" ]; then
    cp "$ZSHRC_SRC" "$ZSHRC_DEST"
    chown "$USER_NAME:$USER_NAME" "$ZSHRC_DEST"
fi

# Install Dracula Zsh theme
DRACULA_ZSH_DIR="$OH_MY_ZSH_DIR/custom/themes/dracula"
if [ ! -d "$DRACULA_ZSH_DIR" ]; then
    sudo -u "$USER_NAME" git clone https://github.com/dracula/zsh.git "$DRACULA_ZSH_DIR"
fi

if ! grep -q "ZSH_THEME=\"dracula/dracula\"" "$ZSHRC_DEST"; then
    sed -i 's/^ZSH_THEME=.*$/ZSH_THEME="dracula\/dracula"/' "$ZSHRC_DEST"
fi

print_success "\n✅ Full HyprDracula setup complete! Reboot recommended."

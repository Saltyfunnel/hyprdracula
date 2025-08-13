#!/bin/bash
set -euo pipefail

# --- Basic paths and user info ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo "~$USER_NAME")
REPO_DIR="$USER_HOME/hyprdracula"
CONFIG_DIR="$USER_HOME/.config"
ASSETS_SRC="$REPO_DIR/assets"
ASSETS_DEST="$CONFIG_DIR/assets"

# --- Helper functions ---
run_command() {
    local cmd="$1"; local msg="$2"
    echo -e "\n➡️ $msg..."
    eval "$cmd"
}

copy_as_user() {
    local src="$1" dest="$2"
    if [[ -d "$src" ]]; then
        sudo -u "$USER_NAME" mkdir -p "$dest"
        sudo -u "$USER_NAME" cp -r "$src/"* "$dest/"
        sudo -u "$USER_NAME" chown -R "$USER_NAME:$USER_NAME" "$dest"
        echo "✅ Copied $src -> $dest"
    else
        echo "⚠️ Source not found: $src"
    fi
}

# --- Update system ---
run_command "pacman -Syyu --noconfirm" "Updating system packages"

# --- Install core packages with pacman ---
PACMAN_PACKAGES=(
    firefox
    pipewire wireplumber pamixer brightnessctl
    ttf-cascadia-code-nerd ttf-cascadia-mono-nerd ttf-fira-code ttf-fira-mono ttf-fira-sans
    ttf-iosevka-nerd ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-mono
    sddm kitty nano tar gnome-disk-utility code mpv dunst pacman-contrib exo
    thunar thunar-archive-plugin thunar-volman tumbler ffmpegthumbnailer file-roller
    gvfs gvfs-mtp gvfs-gphoto2 gvfs-smb polkit polkit-gnome
    waybar wofi starship
)
run_command "pacman -S --noconfirm ${PACMAN_PACKAGES[*]}" "Installing system packages"

# --- Enable polkit and SDDM ---
run_command "systemctl enable --now polkit.service" "Enable polkit"
run_command "systemctl enable sddm.service" "Enable SDDM"

# --- GPU Drivers detection ---
GPU_INFO=$(lspci | grep -Ei "VGA|3D")
if echo "$GPU_INFO" | grep -qi "nvidia"; then
    run_command "pacman -S --noconfirm nvidia nvidia-utils nvidia-settings" "Install NVIDIA drivers"
elif echo "$GPU_INFO" | grep -qi "amd"; then
    run_command "pacman -S --noconfirm xf86-video-amdgpu vulkan-radeon libva-mesa-driver mesa-vdpau" "Install AMD drivers"
elif echo "$GPU_INFO" | grep -qi "intel"; then
    run_command "pacman -S --noconfirm mesa libva-intel-driver intel-media-driver vulkan-intel" "Install Intel drivers"
else
    echo "⚠️ No supported GPU detected: $GPU_INFO"
fi

# --- Copy configs ---
copy_as_user "$REPO_DIR/configs/waybar" "$CONFIG_DIR/waybar"
copy_as_user "$REPO_DIR/configs/wofi" "$CONFIG_DIR/wofi"
copy_as_user "$REPO_DIR/configs/fastfetch" "$CONFIG_DIR/fastfetch"
copy_as_user "$REPO_DIR/configs/hypr" "$CONFIG_DIR/hypr"
copy_as_user "$REPO_DIR/configs/starship" "$CONFIG_DIR/starship"

# --- Fastfetch & Starship integration ---
for shell_rc in ".bashrc" ".zshrc"; do
    FASTFETCH_LINE="fastfetch --kitty-direct $CONFIG_DIR/fastfetch/archkitty.png"
    STARSHIP_LINE='eval "$(starship init bash)"'
    SHELL_FILE="$USER_HOME/$shell_rc"
    [[ -f "$SHELL_FILE" ]] && ! grep -qF "$FASTFETCH_LINE" "$SHELL_FILE" && echo -e "\n$FASTFETCH_LINE" >> "$SHELL_FILE" && chown "$USER_NAME:$USER_NAME" "$SHELL_FILE"
    [[ -f "$SHELL_FILE" ]] && ! grep -qF "$STARSHIP_LINE" "$SHELL_FILE" && echo -e "\n$STARSHIP_LINE" >> "$SHELL_FILE" && chown "$USER_NAME:$USER_NAME" "$SHELL_FILE"
done

# --- GTK Dracula theme & Dracula icons ---
GTK3_DIR="$CONFIG_DIR/gtk-3.0"
GTK4_DIR="$CONFIG_DIR/gtk-4.0"
mkdir -p "$GTK3_DIR" "$GTK4_DIR"
GTK_SETTINGS="[Settings]
gtk-theme-name=Dracula
gtk-icon-theme-name=Dracula
gtk-font-name=JetBrainsMono 10"
echo "$GTK_SETTINGS" | sudo -u "$USER_NAME" tee "$GTK3_DIR/settings.ini" "$GTK4_DIR/settings.ini" >/dev/null

# --- SDDM Dracula theme ---
DRACULA_SDDM_REPO="https://github.com/dracula/sddm.git"
DRACULA_TEMP="/tmp/dracula-sddm"
git clone --depth=1 "$DRACULA_SDDM_REPO" "$DRACULA_TEMP"
cp -r "$DRACULA_TEMP/sddm/themes/dracula" "/usr/share/sddm/themes/dracula"
chown -R root:root "/usr/share/sddm/themes/dracula"
mkdir -p /etc/sddm.conf.d
echo -e "[Theme]\nCurrent=dracula" > /etc/sddm.conf.d/10-theme.conf
rm -rf "$DRACULA_TEMP"

# --- Copy assets ---
copy_as_user "$ASSETS_SRC/backgrounds" "$ASSETS_DEST/backgrounds"

# --- Thunar Dracula configuration ---
THUNAR_DIR="$CONFIG_DIR/Thunar"
mkdir -p "$THUNAR_DIR"
chown "$USER_NAME:$USER_NAME" "$THUNAR_DIR"
UCA_FILE="$THUNAR_DIR/uca.xml"
KITTY_ACTION='<action><icon>utilities-terminal</icon><name>Open Kitty Here</name><command>kitty --directory=%d</command><description>Open kitty terminal in the current folder</description><patterns>*</patterns><directories_only>true</directories_only><startup_notify>true</startup_notify></action>'
if [[ ! -f "$UCA_FILE" ]]; then
    cat > "$UCA_FILE" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<actions>
$KITTY_ACTION
</actions>
EOF
    chown "$USER_NAME:$USER_NAME" "$UCA_FILE"
elif ! grep -q "<name>Open Kitty Here</name>" "$UCA_FILE"; then
    sed -i "/<\/actions>/ i\\
$KITTY_ACTION
" "$UCA_FILE"
    chown "$USER_NAME:$USER_NAME" "$UCA_FILE"
fi

echo -e "\n✅ HyprDracula full setup complete! Reboot to apply all changes."

#!/bin/bash

# --- Variables ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo "~$USER_NAME")
CONFIG_DIR="$USER_HOME/.config"
REPO_DIR="$USER_HOME/hyprdracula"
ASSETS_SRC="$REPO_DIR/assets"
ASSETS_DEST="$CONFIG_DIR/assets"

# --- Helper functions ---
log() { echo -e "\e[32m[INFO]\e[0m $1"; }
warn() { echo -e "\e[33m[WARN]\e[0m $1"; }
error() { echo -e "\e[31m[ERROR]\e[0m $1"; }
run() { 
    log "$2"
    eval "$1"
    if [ $? -ne 0 ]; then error "$2 failed"; exit 1; fi
}

copy_as_user() {
    local src="$1" dest="$2"
    [[ ! -d "$src" ]] && { warn "Source not found: $src"; return; }
    run "mkdir -p \"$dest\"" "Creating $dest"
    run "cp -r \"$src\"/* \"$dest\"" "Copy $src -> $dest"
    run "chown -R $USER_NAME:$USER_NAME \"$dest\"" "Fix ownership of $dest"
}

# --- Update system ---
run "pacman -Syyu --noconfirm" "Updating system packages"

# --- Install pacman packages ---
PACMAN_PACKAGES=(
    pipewire wireplumber pamixer brightnessctl
    ttf-cascadia-code-nerd ttf-cascadia-mono-nerd ttf-fira-code ttf-fira-mono ttf-fira-sans
    ttf-iosevka-nerd ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-mono
    sddm kitty nano tar gnome-disk-utility code mpv dunst pacman-contrib exo
    thunar thunar-archive-plugin thunar-volman tumbler ffmpegthumbnailer file-roller
    gvfs gvfs-mtp gvfs-gphoto2 gvfs-smb
    polkit polkit-gnome waybar firefox
)
run "pacman -S --noconfirm ${PACMAN_PACKAGES[*]}" "Installing system packages"

run "systemctl enable --now polkit.service" "Enable polkit"
run "systemctl enable sddm.service" "Enable SDDM"

# --- Install yay if missing ---
if ! command -v yay &>/dev/null; then
    log "Installing yay..."
    run "pacman -S --noconfirm --needed git base-devel" "Install git/base-devel"
    run "git clone https://aur.archlinux.org/yay.git /tmp/yay" "Clone yay"
    run "chown -R $USER_NAME:$USER_NAME /tmp/yay" "Fix ownership"
    run "sudo -u $USER_NAME bash -c 'cd /tmp/yay && makepkg -si --noconfirm'" "Build and install yay"
    run "rm -rf /tmp/yay" "Clean yay build"
fi

# --- Install AUR packages as user ---
AUR_PACKAGES=(wofi fastfetch swww hyprpicker hyprlock grimblast hypridle starship)
for pkg in "${AUR_PACKAGES[@]}"; do
    log "Installing AUR package: $pkg"
    sudo -u $USER_NAME yay -S --sudoloop --noconfirm "$pkg"
done

# --- Copy config assets ---
copy_as_user "$ASSETS_SRC/backgrounds" "$ASSETS_DEST/backgrounds"

# --- Waybar config ---
copy_as_user "$REPO_DIR/configs/waybar" "$CONFIG_DIR/waybar"

# --- Wofi config ---
copy_as_user "$REPO_DIR/configs/wofi" "$CONFIG_DIR/wofi"

# --- Fastfetch config ---
copy_as_user "$REPO_DIR/configs/fastfetch" "$CONFIG_DIR/fastfetch"

# --- Hypr config ---
copy_as_user "$REPO_DIR/configs/hypr" "$CONFIG_DIR/hypr"

# --- Starship config ---
STARSHIP_SRC="$REPO_DIR/configs/starship/starship.toml"
STARSHIP_DEST="$CONFIG_DIR/starship.toml"
[[ -f "$STARSHIP_SRC" ]] && cp "$STARSHIP_SRC" "$STARSHIP_DEST" && chown "$USER_NAME:$USER_NAME" "$STARSHIP_DEST"

# --- Add Fastfetch to shell ---
for shell_rc in ".bashrc" ".zshrc"; do
    line="fastfetch --kitty-direct $CONFIG_DIR/fastfetch/archkitty.png"
    path="$USER_HOME/$shell_rc"
    [[ -f "$path" ]] && ! grep -qF "$line" "$path" && echo -e "\n# Run fastfetch on terminal start\n$line" >> "$path" && chown "$USER_NAME:$USER_NAME" "$path"
done

# --- Add Starship to shell ---
for shell_rc in ".bashrc" ".zshrc"; do
    shell_name="${shell_rc#*.}"
    line='eval "$(starship init '"$shell_name"')"'
    path="$USER_HOME/$shell_rc"
    [[ -f "$path" ]] && ! grep -qF "$line" "$path" && echo -e "\n$line" >> "$path" && chown "$USER_NAME:$USER_NAME" "$path"
done

# --- Oh My Zsh ---
if [ ! -d "$USER_HOME/.oh-my-zsh" ]; then
    log "Installing Oh My Zsh"
    sudo -u $USER_NAME sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    sudo -u $USER_NAME chsh -s "$(which zsh)"
fi

# --- Dracula SDDM theme ---
DRACULA_SDDM_REPO="https://github.com/dracula/sddm.git"
DRACULA_TEMP="/tmp/dracula-sddm"
git clone --depth=1 "$DRACULA_SDDM_REPO" "$DRACULA_TEMP"
cp -r "$DRACULA_TEMP/sddm/themes/dracula" "/usr/share/sddm/themes/dracula"
chown -R root:root "/usr/share/sddm/themes/dracula"
mkdir -p /etc/sddm.conf.d
echo -e "[Theme]\nCurrent=dracula" > /etc/sddm.conf.d/10-theme.conf
rm -rf "$DRACULA_TEMP"

# --- Dracula icons ---
DRACULA_ICONS_REPO="https://github.com/dracula/gtk-theme.git"
ICONS_TEMP="/tmp/dracula-icons"
git clone --depth=1 "$DRACULA_ICONS_REPO" "$ICONS_TEMP"
copy_as_user "$ICONS_TEMP/icons" "$CONFIG_DIR/icons"
rm -rf "$ICONS_TEMP"

# --- GTK settings ---
GTK3_DIR="$CONFIG_DIR/gtk-3.0"
GTK4_DIR="$CONFIG_DIR/gtk-4.0"
mkdir -p "$GTK3_DIR" "$GTK4_DIR"
GTK_SETTINGS="[Settings]
gtk-theme-name=Dracula
gtk-icon-theme-name=Dracula
gtk-font-name=JetBrainsMono 10"
echo "$GTK_SETTINGS" | sudo -u "$USER_NAME" tee "$GTK3_DIR/settings.ini" "$GTK4_DIR/settings.ini" >/dev/null

log "Setup completed! Reboot recommended."

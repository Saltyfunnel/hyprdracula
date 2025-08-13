#!/bin/bash

# --- Basic setup ---
SCRIPT_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo "~$USER_NAME")
CONFIG_DIR="$USER_HOME/.config"
REPO_DIR="$USER_HOME/hyprdracula"    # Dracula repo
ASSETS_SRC="$REPO_DIR/assets"
ASSETS_DEST="$CONFIG_DIR/assets"

log() { echo -e "\e[32m[INFO]\e[0m $1"; }
warn() { echo -e "\e[33m[WARN]\e[0m $1"; }
error() { echo -e "\e[31m[ERROR]\e[0m $1"; }

copy_as_user() {
    local src="$1" dest="$2"
    [[ ! -d "$src" ]] && { warn "Source not found: $src"; return 1; }
    mkdir -p "$dest"
    cp -r "$src"/* "$dest"
    chown -R "$USER_NAME:$USER_NAME" "$dest"
}

# --- Pacman packages ---
PACMAN_PACKAGES=(
pipewire wireplumber pamixer brightnessctl
ttf-cascadia-code-nerd ttf-cascadia-mono-nerd ttf-fira-code ttf-fira-mono ttf-fira-sans ttf-iosevka-nerd ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-mono
sddm kitty nano tar gnome-disk-utility code mpv dunst pacman-contrib exo thunar thunar-archive-plugin thunar-volman tumbler ffmpegthumbnailer file-roller gvfs gvfs-mtp gvfs-gphoto2 gvfs-smb polkit polkit-gnome waybar cliphist firefox
)

log "Installing Pacman packages..."
sudo pacman -S --noconfirm "${PACMAN_PACKAGES[@]}"

# --- AUR packages as normal user ---
AUR_PACKAGES=(
wofi fastfetch swww hyprpicker hyprlock grimblast hypridle starship
)

log "Installing AUR packages..."
for pkg in "${AUR_PACKAGES[@]}"; do
    log "Installing $pkg via yay..."
    su "$USER_NAME" -c "yay -S --noconfirm $pkg"
done

# --- Copy configs ---
copy_as_user "$REPO_DIR/configs/waybar" "$CONFIG_DIR/waybar"
copy_as_user "$REPO_DIR/configs/wofi" "$CONFIG_DIR/wofi"
copy_as_user "$REPO_DIR/configs/fastfetch" "$CONFIG_DIR/fastfetch"
copy_as_user "$REPO_DIR/configs/hypr" "$CONFIG_DIR/hypr"
copy_as_user "$REPO_DIR/configs/starship" "$CONFIG_DIR/starship"
copy_as_user "$ASSETS_SRC/backgrounds" "$ASSETS_DEST/backgrounds"

# --- Fastfetch integration ---
for shell_rc in ".bashrc" ".zshrc"; do
    RC_PATH="$USER_HOME/$shell_rc"
    LINE="fastfetch --kitty-direct $CONFIG_DIR/fastfetch/archkitty.png"
    [[ -f "$RC_PATH" ]] && ! grep -qF "$LINE" "$RC_PATH" && echo -e "\n# Run fastfetch on terminal start\n$LINE" >> "$RC_PATH" && chown "$USER_NAME:$USER_NAME" "$RC_PATH"
done

# --- Starship shell prompt ---
for shell_rc in ".bashrc" ".zshrc"; do
    RC_PATH="$USER_HOME/$shell_rc"
    LINE='eval "$(starship init '"${shell_rc/.bashrc/bash}"')"'
    [[ -f "$RC_PATH" ]] && ! grep -qF "$LINE" "$RC_PATH" && echo -e "\n$LINE" >> "$RC_PATH" && chown "$USER_NAME:$USER_NAME" "$RC_PATH"
done

# --- Dracula icons ---
DRACULA_ICONS_DIR="/usr/share/icons/Dracula"
if [ ! -d "$DRACULA_ICONS_DIR" ]; then
    log "Installing Dracula icon theme..."
    sudo -u "$USER_NAME" git clone --depth=1 https://github.com/dracula/gtk "$USER_HOME/dracula-icons-temp"
    sudo cp -r "$USER_HOME/dracula-icons-temp" "$DRACULA_ICONS_DIR"
    sudo chown -R root:root "$DRACULA_ICONS_DIR"
    rm -rf "$USER_HOME/dracula-icons-temp"
fi

# --- GTK3/GTK4 Dracula theme ---
GTK3_DIR="$CONFIG_DIR/gtk-3.0"
GTK4_DIR="$CONFIG_DIR/gtk-4.0"
mkdir -p "$GTK3_DIR" "$GTK4_DIR"
GTK_SETTINGS="[Settings]
gtk-theme-name=Dracula
gtk-icon-theme-name=Dracula
gtk-font-name=JetBrainsMono 10"
echo "$GTK_SETTINGS" | sudo -u "$USER_NAME" tee "$GTK3_DIR/settings.ini" "$GTK4_DIR/settings.ini" >/dev/null

# --- Oh My Zsh & default shell ---
if [ ! -d "$USER_HOME/.oh-my-zsh" ]; then
    su "$USER_NAME" -c 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended'
    chsh -s "$(which zsh)" "$USER_NAME"
fi

# --- Set SDDM theme ---
DRACULA_SDDM_REPO="https://github.com/dracula/sddm.git"
DRACULA_TEMP="/tmp/dracula-sddm"
git clone --depth=1 "$DRACULA_SDDM_REPO" "$DRACULA_TEMP"
sudo cp -r "$DRACULA_TEMP/sddm/themes/dracula" "/usr/share/sddm/themes/dracula"
sudo chown -R root:root "/usr/share/sddm/themes/dracula"
sudo mkdir -p /etc/sddm.conf.d
echo -e "[Theme]\nCurrent=dracula" | sudo tee /etc/sddm.conf.d/10-theme.conf
rm -rf "$DRACULA_TEMP"

log "Setup completed successfully."

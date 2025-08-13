#!/bin/bash

set -e

# --- Basic variables ---
SCRIPT_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo "~$USER_NAME")
CONFIG_DIR="$USER_HOME/.config"
REPO_DIR="$USER_HOME/hyprdracula"
ASSETS_SRC="$REPO_DIR/assets"
ASSETS_DEST="$CONFIG_DIR/assets"

# --- Helper functions ---
run_command() {
    local cmd="$1" description="$2"
    echo "[INFO] $description..."
    eval "$cmd"
}

copy_as_user() {
    local src="$1" dest="$2"
    [[ ! -d "$src" ]] && { echo "[WARN] Source not found: $src"; return 1; }
    run_command "mkdir -p \"$dest\"" "Create $dest"
    run_command "cp -r \"$src\"/* \"$dest\"" "Copy $src -> $dest"
    run_command "chown -R $USER_NAME:$USER_NAME \"$dest\"" "Fix ownership"
}

# --- Pacman packages ---
PACMAN_PACKAGES=(
    pipewire wireplumber pamixer brightnessctl ttf-cascadia-code-nerd ttf-cascadia-mono-nerd
    ttf-fira-code ttf-fira-mono ttf-fira-sans ttf-iosevka-nerd ttf-jetbrains-mono-nerd
    ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-mono sddm kitty nano tar gnome-disk-utility
    code mpv dunst pacman-contrib exo thunar thunar-archive-plugin thunar-volman tumbler
    ffmpegthumbnailer file-roller gvfs gvfs-mtp gvfs-gphoto2 gvfs-smb polkit polkit-gnome
    waybar cliphist firefox
)

run_command "sudo pacman -Syu --noconfirm ${PACMAN_PACKAGES[*]}" "Installing Pacman packages"

# --- AUR packages ---
AUR_PACKAGES=(
    wofi fastfetch swww hyprpicker hyprlock grimblast hypridle starship
)

# Install yay if missing
if ! command -v yay &>/dev/null; then
    echo "[INFO] yay not found. Installing..."
    sudo pacman -S --needed --noconfirm git base-devel
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay
    sudo -u "$USER_NAME" makepkg -si --noconfirm
    cd -
    rm -rf /tmp/yay
fi

# Install AUR packages
sudo -u "$USER_NAME" bash -c "yay -S --needed --noconfirm ${AUR_PACKAGES[*]}"

# --- Copy configs ---
copy_as_user "$REPO_DIR/configs/waybar" "$CONFIG_DIR/waybar"
copy_as_user "$REPO_DIR/configs/wofi" "$CONFIG_DIR/wofi"
copy_as_user "$REPO_DIR/configs/fastfetch" "$CONFIG_DIR/fastfetch"
copy_as_user "$REPO_DIR/configs/hypr" "$CONFIG_DIR/hypr"
copy_as_user "$ASSETS_SRC/backgrounds" "$ASSETS_DEST/backgrounds"

# --- Fastfetch integration ---
for shell_rc in ".bashrc" ".zshrc"; do
    line="fastfetch --kitty-direct $CONFIG_DIR/fastfetch/archkitty.png"
    path="$USER_HOME/$shell_rc"
    [[ -f "$path" ]] && ! grep -qF "$line" "$path" && echo -e "\n# Run fastfetch on terminal start\n$line" >> "$path" && chown "$USER_NAME:$USER_NAME" "$path"
done

# --- Starship integration ---
STARSHIP_SRC="$REPO_DIR/configs/starship/starship.toml"
STARSHIP_DEST="$CONFIG_DIR/starship.toml"
[[ -f "$STARSHIP_SRC" ]] && cp "$STARSHIP_SRC" "$STARSHIP_DEST" && chown "$USER_NAME:$USER_NAME" "$STARSHIP_DEST"

for shell_rc in ".bashrc" ".zshrc"; do
    line='eval "$(starship init '"${shell_rc#.}"')"'
    path="$USER_HOME/$shell_rc"
    [[ -f "$path" ]] && ! grep -qF "$line" "$path" && echo -e "\n$line" >> "$path" && chown "$USER_NAME:$USER_NAME" "$path"
done

# --- Oh My Zsh ---
if [[ ! -d "$USER_HOME/.oh-my-zsh" ]]; then
    sudo -u "$USER_NAME" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    chsh -s "$(which zsh)" "$USER_NAME"
fi

# --- Dracula SDDM theme ---
DRACULA_SDDM_REPO="https://github.com/dracula/sddm.git"
DRACULA_TEMP="/tmp/dracula-sddm"
git clone --depth=1 "$DRACULA_SDDM_REPO" "$DRACULA_TEMP"
sudo cp -r "$DRACULA_TEMP/sddm/themes/dracula" "/usr/share/sddm/themes/dracula"
sudo chown -R root:root "/usr/share/sddm/themes/dracula"
sudo mkdir -p /etc/sddm.conf.d
echo -e "[Theme]\nCurrent=dracula" | sudo tee /etc/sddm.conf.d/10-theme.conf
rm -rf "$DRACULA_TEMP"

# --- Dracula icons ---
sudo -u "$USER_NAME" git clone https://github.com/dracula/icons.git "$CONFIG_DIR/icons/dracula"

# --- GTK theme settings ---
GTK3_DIR="$CONFIG_DIR/gtk-3.0"
GTK4_DIR="$CONFIG_DIR/gtk-4.0"
mkdir -p "$GTK3_DIR" "$GTK4_DIR"
GTK_SETTINGS="[Settings]
gtk-theme-name=Dracula
gtk-icon-theme-name=Dracula
gtk-font-name=JetBrainsMono 10"
echo "$GTK_SETTINGS" | sudo -u "$USER_NAME" tee "$GTK3_DIR/settings.ini" "$GTK4_DIR/settings.ini" >/dev/null

# --- Thunar Dracula icons ---
mkdir -p "$CONFIG_DIR/Thunar" && chown "$USER_NAME:$USER_NAME" "$CONFIG_DIR/Thunar" && chmod 700 "$CONFIG_DIR/Thunar"

echo "[INFO] Setup completed successfully!"

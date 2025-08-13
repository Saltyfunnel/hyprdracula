#!/bin/bash

set -e

SCRIPT_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo "~$USER_NAME")
CONFIG_DIR="$USER_HOME/.config"
REPO_DIR="$USER_HOME/hyprdracula"    # Dracula repo
ASSETS_SRC="$REPO_DIR/assets"
ASSETS_DEST="$CONFIG_DIR/assets"

# --- Helper functions ---
run_command() {
    local cmd="$1" description="$2"
    echo -e "\n>>> $description"
    eval "$cmd"
}

copy_as_user() {
    local src="$1" dest="$2"
    [[ ! -d "$src" ]] && { echo "Warning: Source not found: $src"; return 1; }
    run_command "mkdir -p \"$dest\"" "Create $dest"
    run_command "cp -r \"$src\"/* \"$dest\"" "Copy $src -> $dest"
    run_command "chown -R $USER_NAME:$USER_NAME \"$dest\"" "Fix ownership"
}

# --- Update system ---
run_command "sudo pacman -Syu --noconfirm" "Updating system"

# --- Pacman packages ---
PACMAN_APPS=(
pipewire wireplumber pamixer brightnessctl
ttf-cascadia-code-nerd ttf-cascadia-mono-nerd ttf-fira-code ttf-fira-mono ttf-fira-sans
ttf-iosevka-nerd ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-mono
sddm kitty nano tar gnome-disk-utility code mpv dunst pacman-contrib exo thunar
thunar-archive-plugin thunar-volman tumbler ffmpegthumbnailer file-roller gvfs gvfs-mtp
gvfs-gphoto2 gvfs-smb polkit polkit-gnome waybar cliphist firefox
)
run_command "sudo pacman -S --noconfirm ${PACMAN_APPS[*]}" "Install Pacman apps"

# --- AUR packages (build as normal user) ---
AUR_APPS=(
wofi fastfetch swww hyprpicker hyprlock grimblast hypridle starship
)
mkdir -p "$USER_HOME/aur_builds"
for app in "${AUR_APPS[@]}"; do
    cd "$USER_HOME/aur_builds"
    if [ ! -d "$app" ]; then
        run_command "git clone https://aur.archlinux.org/$app.git" "Cloning $app"
    fi
    cd "$app"
    run_command "makepkg -si --noconfirm" "Build & install $app"
done

# --- Oh My Zsh ---
if [ ! -d "$USER_HOME/.oh-my-zsh" ]; then
    run_command "RUNZSH=no CHSH=no sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\"" "Installing Oh My Zsh"
else
    run_command "sudo -u $USER_NAME git -C $USER_HOME/.oh-my-zsh pull" "Updating Oh My Zsh"
fi

run_command "chsh -s $(which zsh) $USER_NAME" "Set Zsh as default shell"

# --- Copy configs ---
copy_as_user "$REPO_DIR/configs/waybar" "$CONFIG_DIR/waybar"
copy_as_user "$REPO_DIR/configs/wofi" "$CONFIG_DIR/wofi"
copy_as_user "$REPO_DIR/configs/fastfetch" "$CONFIG_DIR/fastfetch"
copy_as_user "$REPO_DIR/configs/hypr" "$CONFIG_DIR/hypr"
copy_as_user "$ASSETS_SRC/backgrounds" "$ASSETS_DEST/backgrounds"

# --- Fastfetch integration ---
for shell_rc in ".bashrc" ".zshrc"; do
    local_line="fastfetch --kitty-direct $CONFIG_DIR/fastfetch/archkitty.png"
    [[ -f "$USER_HOME/$shell_rc" ]] && ! grep -qF "$local_line" "$USER_HOME/$shell_rc" && \
        echo -e "\n# Run fastfetch on terminal start\n$local_line" >> "$USER_HOME/$shell_rc"
done

# --- Starship ---
STARSHIP_SRC="$REPO_DIR/configs/starship/starship.toml"
STARSHIP_DEST="$CONFIG_DIR/starship.toml"
[[ -f "$STARSHIP_SRC" ]] && cp "$STARSHIP_SRC" "$STARSHIP_DEST" && chown "$USER_NAME:$USER_NAME" "$STARSHIP_DEST"

for shell_rc in ".bashrc" ".zshrc"; do
    local_line='eval "$(starship init '"$(basename "$SHELL")"')"'
    [[ -f "$USER_HOME/$shell_rc" ]] && ! grep -qF "$local_line" "$USER_HOME/$shell_rc" && \
        echo -e "\n$local_line" >> "$USER_HOME/$shell_rc"
done

# --- Dracula icons ---
DRACULA_ICONS_REPO="https://github.com/dracula/gtk-theme.git"
TMP_DIR=$(mktemp -d)
git clone --depth=1 "$DRACULA_ICONS_REPO" "$TMP_DIR"
ICONS_DIR="$CONFIG_DIR/icons"
mkdir -p "$ICONS_DIR"
cp -r "$TMP_DIR/icons/Dracula" "$ICONS_DIR/Dracula"
chown -R $USER_NAME:$USER_NAME "$ICONS_DIR"
rm -rf "$TMP_DIR"

# --- GTK3/4 Dracula theme ---
GTK3_DIR="$CONFIG_DIR/gtk-3.0"
GTK4_DIR="$CONFIG_DIR/gtk-4.0"
mkdir -p "$GTK3_DIR" "$GTK4_DIR"
GTK_SETTINGS="[Settings]
gtk-theme-name=Dracula
gtk-icon-theme-name=Dracula
gtk-font-name=JetBrainsMono 10"
echo "$GTK_SETTINGS" | tee "$GTK3_DIR/settings.ini" "$GTK4_DIR/settings.ini" >/dev/null
chown -R $USER_NAME:$USER_NAME "$CONFIG_DIR"

# --- SDDM Dracula theme ---
SDDM_THEME_DIR="/usr/share/sddm/themes/dracula"
git clone --depth=1 https://github.com/dracula/sddm.git /tmp/dracula-sddm
cp -r /tmp/dracula-sddm/sddm/themes/dracula "$SDDM_THEME_DIR"
chown -R root:root "$SDDM_THEME_DIR"
mkdir -p /etc/sddm.conf.d
echo -e "[Theme]\nCurrent=dracula" > /etc/sddm.conf.d/10-theme.conf
rm -rf /tmp/dracula-sddm

echo "Setup completed successfully!"

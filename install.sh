#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_HOME="/home/$SUDO_USER"

# Helper functions
print_header() { echo -e "\n===== $1 =====\n"; }
print_info() { echo -e "[INFO] $1"; }
print_success() { echo -e "[OK] $1"; }
run_command() { echo -e "[RUN] $1"; eval "$1"; }

# Check root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

print_header "Updating system packages"
run_command "pacman -Syyu --noconfirm"

# Install yay if missing
if ! command -v yay &>/dev/null; then
  print_info "Installing yay..."
  pacman -S --noconfirm --needed git base-devel
  git clone https://aur.archlinux.org/yay.git /tmp/yay
  chown -R $SUDO_USER:$SUDO_USER /tmp/yay
  sudo -u $SUDO_USER bash -c "cd /tmp/yay && makepkg -si --noconfirm"
  rm -rf /tmp/yay
else
  print_success "Yay is already installed"
fi

# System packages
PACKAGES=(
  pipewire wireplumber pamixer brightnessctl
  ttf-cascadia-code-nerd ttf-cascadia-mono-nerd ttf-fira-code ttf-fira-mono ttf-fira-sans
  ttf-iosevka-nerd ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-mono
  sddm kitty nano tar gnome-disk-utility code mpv dunst pacman-contrib exo
  thunar thunar-archive-plugin thunar-volman tumbler ffmpegthumbnailer file-roller
  gvfs gvfs-mtp gvfs-gphoto2 gvfs-smb polkit polkit-gnome
)
run_command "pacman -S --noconfirm ${PACKAGES[*]}"
run_command "systemctl enable --now polkit.service"
run_command "systemctl enable sddm.service"

# Yay apps
YAY_APPS=(
  firefox wofi fastfetch swww hyprpicker hyprlock grimblast hypridle starship
)
for app in "${YAY_APPS[@]}"; do
  sudo -u $SUDO_USER yay -S --noconfirm "$app"
done

# Oh-My-Zsh
if [ ! -d "$USER_HOME/.oh-my-zsh" ]; then
  sudo -u $SUDO_USER sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  sudo -u $SUDO_USER chsh -s "$(which zsh)" $SUDO_USER
fi

# Dracula SDDM Theme
print_header "Installing Dracula SDDM Theme"
git clone https://github.com/nopain2110/Yet-another-dracula.git /tmp/dracula-theme
sudo cp -r /tmp/dracula-theme/sddm-dracula /usr/share/sddm/themes/dracula
sudo rm -rf /tmp/dracula-theme
mkdir -p /etc/sddm.conf.d
echo "CurrentTheme=dracula" | sudo tee /etc/sddm.conf.d/dracula.conf
print_success "Dracula SDDM theme installed"

# Dracula GTK and Icon Themes
print_header "Installing Dracula GTK and Icon Themes"
# Icons
sudo -u $SUDO_USER mkdir -p $USER_HOME/.icons
git clone https://github.com/dracula/gtk.git /tmp/dracula-gtk
sudo -u $SUDO_USER cp -r /tmp/dracula-gtk/icons/* $USER_HOME/.icons/
# GTK themes
sudo -u $SUDO_USER mkdir -p $USER_HOME/.themes
sudo -u $SUDO_USER cp -r /tmp/dracula-gtk/gtk/* $USER_HOME/.themes/
sudo rm -rf /tmp/dracula-gtk

# Set GTK theme and icon theme for user
GTK_SETTINGS="$USER_HOME/.config/gtk-3.0/settings.ini"
mkdir -p "$(dirname "$GTK_SETTINGS")"
cat << EOF > "$GTK_SETTINGS"
[Settings]
gtk-theme-name = Dracula
gtk-icon-theme-name = Dracula
gtk-font-name = Fira Code 10
EOF
chown $SUDO_USER:$SUDO_USER "$GTK_SETTINGS"
print_success "Dracula GTK and Icon themes installed"

print_success "Setup completed!"

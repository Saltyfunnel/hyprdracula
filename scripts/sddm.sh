#!/bin/bash
# Install Dracula SDDM theme and set it as default on Arch/Hyprland

set -e

# Dependencies
sudo pacman -S --needed git sddm --noconfirm

# Clone the Dracula SDDM theme
git clone https://github.com/adi1090x/Yet-another-Dracula.git /tmp/Yet-another-Dracula

# Move the theme to the SDDM themes directory
sudo mkdir -p /usr/share/sddm/themes/Yet-another-Dracula
sudo cp -r /tmp/Yet-another-Dracula/* /usr/share/sddm/themes/Yet-another-Dracula/

# Fix folder structure (move nested files up)
sudo mv /usr/share/sddm/themes/Yet-another-Dracula/Yet-another-dracula/sddm/Dracula/* /usr/share/sddm/themes/Yet-another-Dracula/ 2>/dev/null || true
sudo mv /usr/share/sddm/themes/Yet-another-Dracula/Yet-another-dracula/sddm/theme.conf /usr/share/sddm/themes/Yet-another-Dracula/ 2>/dev/null || true
sudo rm -rf /usr/share/sddm/themes/Yet-another-Dracula/Yet-another-dracula

# Set the theme as current in sddm.conf
sudo mkdir -p /etc/sddm.conf.d
echo "[Theme]" | sudo tee /etc/sddm.conf.d/dracula.conf
echo "Current=Yet-another-Dracula" | sudo tee -a /etc/sddm.conf.d/dracula.conf

# Enable and restart SDDM
sudo systemctl enable sddm
sudo systemctl restart sddm

# Cleanup
rm -rf /tmp/Yet-another-Dracula

echo "✅ Dracula SDDM theme installed and set as default!"

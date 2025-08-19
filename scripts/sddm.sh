#!/bin/bash

# Script to install Dracula-inspired SDDM theme on Arch Linux

set -e

# Variables
THEME_NAME="Yet-another-dracula"
THEME_REPO="https://github.com/trancong12102/Yet-another-dracula.git"
SDDM_DIR="/usr/share/sddm/themes"

echo "==> Installing required packages..."
sudo pacman -S --noconfirm sddm qt5-declarative git

echo "==> Cloning the Dracula SDDM theme..."
git clone "$THEME_REPO" /tmp/"$THEME_NAME"

echo "==> Copying theme to SDDM directory..."
sudo cp -r /tmp/"$THEME_NAME"/SDDM "$SDDM_DIR/$THEME_NAME"

echo "==> Setting SDDM theme..."
if ! grep -q "Current=" /etc/sddm.conf 2>/dev/null; then
    # If the config doesn't exist, create it
    echo -e "[Theme]\nCurrent=$THEME_NAME" | sudo tee /etc/sddm.conf
else
    sudo sed -i "s/^Current=.*/Current=$THEME_NAME/" /etc/sddm.conf
fi

echo "==> Cleaning up..."
rm -rf /tmp/"$THEME_NAME"

echo "==> Restarting SDDM to apply theme..."
sudo systemctl restart sddm

echo "==> Done! Your SDDM theme should now be set to $THEME_NAME."

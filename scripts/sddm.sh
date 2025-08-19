#!/bin/bash
set -e

THEME_NAME="Yet-another-dracula"
THEME_REPO="https://github.com/trancong12102/Yet-another-dracula.git"
SDDM_DIR="/usr/share/sddm/themes"

# Install dependencies
sudo pacman -S --noconfirm sddm qt5-declarative git

# Clone the theme
git clone "$THEME_REPO" /tmp/"$THEME_NAME"

# Detect correct theme folder
if [ -d "/tmp/$THEME_NAME/SDDM" ]; then
    THEME_SRC="/tmp/$THEME_NAME/SDDM"
else
    THEME_SRC="/tmp/$THEME_NAME"
fi

# Copy theme
sudo cp -r "$THEME_SRC" "$SDDM_DIR/$THEME_NAME"

# Set permissions
sudo chown -R root:root "$SDDM_DIR/$THEME_NAME"

# Create or update config
if [ ! -f /etc/sddm.conf ]; then
    echo -e "[Theme]\nCurrent=$THEME_NAME" | sudo tee /etc/sddm.conf
else
    sudo sed -i '/^\[Theme\]/,/^\[/ s/^Current=.*/Current='"$THEME_NAME"'/' /etc/sddm.conf || \
    echo -e "[Theme]\nCurrent=$THEME_NAME" | sudo tee -a /etc/sddm.conf
fi

echo "==> Done. Please reboot or switch to a TTY and run 'sudo systemctl restart sddm' to see the theme."

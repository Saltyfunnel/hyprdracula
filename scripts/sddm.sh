#!/bin/bash

# --- CONFIGURATION VARIABLES ---
# The AUR package name for the theme
SDDM_THEME_NAME="sddm-sugar-candy"

# The location of the theme on your system after installation
THEME_DIR="/usr/share/sddm/themes/sugar-candy"

# The configuration file to edit
THEME_CONF="$THEME_DIR/theme.conf"

# The filename of your wallpaper within the theme's directory
# This assumes you have already copied it to /usr/share/sddm/themes/sugar-candy/Backgrounds/
WALLPAPER_NAME="tree.png"

# --- FUNCTIONS ---

# Function to install yay if it's not present
install_yay() {
    if ! command -v yay &> /dev/null; then
        echo "yay is not installed. Installing now..."
        sudo pacman -S --needed git base-devel --noconfirm
        git clone https://aur.archlinux.org/yay.git
        cd yay
        makepkg -si --noconfirm
        cd ..
        rm -rf yay
        echo "yay has been installed."
    else
        echo "yay is already installed."
    fi
}

# Function to install the SDDM theme
install_theme() {
    echo "Installing SDDM theme: $SDDM_THEME_NAME..."
    yay -S --noconfirm "$SDDM_THEME_NAME"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to install $SDDM_THEME_NAME. Exiting."
        exit 1
    fi
}

# Function to edit the theme's configuration file
configure_theme() {
    echo "Configuring theme with Dracula colors and custom wallpaper..."

    # Check if the config file exists
    if [ ! -f "$THEME_CONF" ]; then
        echo "Error: Theme configuration file not found at $THEME_CONF. Exiting."
        echo "This means the theme installation may have failed or the file structure has changed."
        exit 1
    fi

    # Use sed to replace the color and background paths in one go
    sudo sed -i \
        -e 's/^MainColor=.*/MainColor="#f8f8f2"/' \
        -e 's/^AccentColor=.*/AccentColor="#bd93f9"/' \
        -e 's/^BackgroundColor=.*/BackgroundColor="#282a36"/' \
        -e 's|^Background=".*"|Background="Backgrounds/'$WALLPAPER_NAME'"|' \
        "$THEME_CONF"

    # Set the theme in SDDM's main config file
    if [ -f "/etc/sddm.conf" ]; then
        echo "Setting theme in /etc/sddm.conf..."
        sudo sed -i 's/^Current=.*/Current=sugar-candy/' /etc/sddm.conf
    else
        echo "Warning: /etc/sddm.conf not found. Creating a new one."
        sudo sh -c "echo -e '[Theme]\nCurrent=sugar-candy' > /etc/sddm.conf"
    fi
}

# Function to restart SDDM service
restart_sddm() {
    echo "Restarting SDDM service to apply all changes..."
    sudo systemctl restart sddm.service
    if [ $? -ne 0 ]; then
        echo "Warning: Failed to restart SDDM. You may need to reboot to see changes."
    else
        echo "Done. The script has finished successfully."
    fi
}

# --- MAIN EXECUTION ---
echo "Starting SDDM theming script..."
install_yay
install_theme
configure_theme
restart_sddm

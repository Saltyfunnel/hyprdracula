#!/usr/bin/env bash

# File where the last selected wallpaper is stored
LAST_WALLPAPER_FILE="/home/gerard/.config/hypr/last_wallpaper.txt"

# Your default fallback wallpaper
DEFAULT_WALLPAPER="/home/gerard/.config/assets/backgrounds/d.jpg"

# Use the last selected wallpaper if it exists, otherwise use the default.
if [ -s "$LAST_WALLPAPER_FILE" ]; then
    WALLPAPER=$(cat "$LAST_WALLPAPER_FILE")
else
    WALLPAPER="$DEFAULT_WALLPAPER"
fi

# Launch swaybg to set the wallpaper
swaybg -i "$WALLPAPER" & disown
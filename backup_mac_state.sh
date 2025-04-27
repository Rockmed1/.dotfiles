#!/bin/bash

# ======================================================
# backup_mac_state.sh
# ------------------------------------------------------
# This script creates a backup of your Mac's current state
# including installed applications, system preferences,
# and configuration files.
#
# The backup can be used with restore_mac_state.sh to 
# replicate your setup on a new Mac.
# ======================================================

# Exit on error
set -e

# Set text formatting
BOLD=$(tput bold)
NORMAL=$(tput sgr0)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
RED=$(tput setaf 1)

# Print heading function
print_heading() {
    echo ""
    echo "${BOLD}${GREEN}==== $1 ====${NORMAL}"
    echo ""
}

# Print subheading function
print_subheading() {
    echo "${BOLD}${YELLOW}--- $1 ---${NORMAL}"
}

# Print error function
print_error() {
    echo "${BOLD}${RED}ERROR: $1${NORMAL}"
}

# Create timestamp for backup directory
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="$HOME/mac_backup_$TIMESTAMP"

# Create backup directory structure
print_heading "Creating backup directory"
mkdir -p "$BACKUP_DIR"
mkdir -p "$BACKUP_DIR/homebrew"
mkdir -p "$BACKUP_DIR/dotfiles"
mkdir -p "$BACKUP_DIR/preferences"
mkdir -p "$BACKUP_DIR/app_store"
mkdir -p "$BACKUP_DIR/misc"

echo "Backup directory created at: $BACKUP_DIR"

# # Backup Homebrew packages, casks, and taps
# print_heading "Backing up Homebrew packages, casks, and taps"

# if command -v brew &> /dev/null; then
#     print_subheading "Exporting Homebrew packages"
#     brew list --formula > "$BACKUP_DIR/homebrew/brew_packages.txt"
#     echo "Exported $(wc -l < "$BACKUP_DIR/homebrew/brew_packages.txt") packages"
    
#     print_subheading "Exporting Homebrew casks"
#     brew list --cask > "$BACKUP_DIR/homebrew/brew_casks.txt"
#     echo "Exported $(wc -l < "$BACKUP_DIR/homebrew/brew_casks.txt") casks"
    
#     print_subheading "Exporting Homebrew taps"
#     brew tap > "$BACKUP_DIR/homebrew/brew_taps.txt"
#     echo "Exported $(wc -l < "$BACKUP_DIR/homebrew/brew_taps.txt") taps"
    
#     print_subheading "Creating Brewfile"
#     brew bundle dump --file="$BACKUP_DIR/homebrew/Brewfile"
#     echo "Brewfile created"
# else
#     print_error "Homebrew is not installed. Skipping Homebrew backup."
# fi

# # Backup important dotfiles
# print_heading "Backing up dotfiles"

# # List of dotfiles to backup
# DOTFILES=(
#     ".zshrc"
#     ".bashrc"
#     ".bash_profile"
#     ".profile"
#     ".gitconfig"
#     ".gitignore_global"
#     ".vimrc"
#     ".tmux.conf"
#     ".ssh/config"
#     ".p10k.zsh"  # If using powerlevel10k
# )

# for file in "${DOTFILES[@]}"; do
#     if [ -f "$HOME/$file" ]; then
#         print_subheading "Copying $file"
#         # Create directory structure if needed
#         mkdir -p "$BACKUP_DIR/dotfiles/$(dirname "$file")"
#         cp -p "$HOME/$file" "$BACKUP_DIR/dotfiles/$file"
#         echo "Copied $file"
#     fi
# done

# # Backup additional config directories
# CONFIG_DIRS=(
#     ".config/nvim"
#     ".config/alacritty"
#     ".config/karabiner"
#     ".config/iterm2"
# )

# for dir in "${CONFIG_DIRS[@]}"; do
#     if [ -d "$HOME/$dir" ]; then
#         print_subheading "Copying $dir"
#         mkdir -p "$BACKUP_DIR/dotfiles/$dir"
#         cp -R "$HOME/$dir" "$BACKUP_DIR/dotfiles/$(dirname "$dir")/"
#         echo "Copied $dir directory"
#     fi
# done

# Export Mac App Store applications
print_heading "Backing up Mac App Store applications"

if command -v mas &> /dev/null; then
    print_subheading "Exporting Mac App Store applications"
    mas list > "$BACKUP_DIR/app_store/mas_apps.txt"
    echo "Exported $(wc -l < "$BACKUP_DIR/app_store/mas_apps.txt") App Store applications"
else
    print_error "The 'mas' command is not available. Install it with 'brew install mas' to backup App Store apps."
    echo "You can install it later and run: mas list > \"$BACKUP_DIR/app_store/mas_apps.txt\""
fi

# Export macOS preferences
print_heading "Backing up macOS preferences"

print_subheading "Exporting general preferences"
# Backup various preferences

# Dock preferences
defaults export com.apple.dock "$BACKUP_DIR/preferences/dock.plist"
echo "Exported Dock preferences"

# Finder preferences
defaults export com.apple.finder "$BACKUP_DIR/preferences/finder.plist"
echo "Exported Finder preferences"

# Finder Sidebar preferences
cp "/Users/themac/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.FavoriteItems.sfl3" "$BACKUP_DIR/preferences/"
echo "Exported Sidebar preferences"


# Mission Control preferences
defaults export com.apple.spaces "$BACKUP_DIR/preferences/mission_control.plist"
echo "Exported Mission Control preferences"

# General UI/UX preferences
defaults export -g "$BACKUP_DIR/preferences/global_domain.plist"
echo "Exported global preferences"

# Rectangle
cp ~/Library/Preferences/com.knollsoft.Rectangle.plist ~/mac_backup_20250424_152200/misc/ && echo "Rectangle preferences back
ed up successfully"

# AltTab
cp ~/Library/Preferences/com.lwouis.alt-tab-macos.plist ~/mac_backup_20250424_152200/pref/ && echo "AltTab settings backed up successfully"

# Warp
# cp -r "$HOME/Library/Application Support/dev.warp.Warp/" "$HOME/mac_backup_20250424_152200/misc/"

# Menu bar
cp ~/Library/Preferences/com.apple.systemuiserver.plist ./mac_backup_20250424_182654/misc/ && echo "Menu Bar settings backed up successfully"

# Terminal settings

if [ -d "$HOME/Library/Preferences/com.apple.Terminal.plist" ]; then
    cp -p "$HOME/Library/Preferences/com.apple.Terminal.plist" "$BACKUP_DIR/preferences/"
    echo "Exported Terminal preferences"
fi

# iTerm2 settings
if [ -d "$HOME/Library/Preferences/com.googlecode.iterm2.plist" ]; then
    cp -p "$HOME/Library/Preferences/com.googlecode.iterm2.plist" "$BACKUP_DIR/preferences/"
    echo "Exported iTerm2 preferences"
fi

# Backup login items
osascript -e 'tell application "System Events" to get the name of every login item' > "$BACKUP_DIR/preferences/login_items.txt"
echo "Exported login items"

# Export keyboard shortcuts
defaults read com.apple.symbolichotkeys > "$BACKUP_DIR/preferences/keyboard_shortcuts.txt"
echo "Exported keyboard shortcuts"

# Desktop settings
print_subheading "Exporting Desktop preferences"
defaults export com.apple.desktop "$BACKUP_DIR/preferences/desktop.plist" 2>/dev/null || echo "No Desktop preferences found"
defaults export com.apple.desktoppicture "$BACKUP_DIR/preferences/desktop_picture.plist" 2>/dev/null
echo "Exported Desktop preferences"

# Widget/Dashboard settings
print_subheading "Exporting Widget preferences"
defaults export com.apple.dashboard "$BACKUP_DIR/preferences/dashboard.plist" 2>/dev/null || echo "No Dashboard preferences found"
defaults export com.apple.widgetkit "$BACKUP_DIR/preferences/widgets.plist" 2>/dev/null
echo "Exported Widget preferences"

# Windows management settings
print_subheading "Exporting Window management preferences"
defaults export com.apple.WindowManager "$BACKUP_DIR/preferences/window_manager.plist" 2>/dev/null
defaults export com.apple.preference.general "$BACKUP_DIR/preferences/window_settings.plist" 2>/dev/null
echo "Exported Window management preferences"

# Keyboard settings
print_subheading "Exporting Keyboard preferences"
defaults export com.apple.keyboard "$BACKUP_DIR/preferences/keyboard.plist" 2>/dev/null
defaults export com.apple.HIToolbox "$BACKUP_DIR/preferences/input_sources.plist" 2>/dev/null
echo "Exported Keyboard preferences"

# Mouse settings
print_subheading "Exporting Mouse preferences"
defaults export com.apple.mouse "$BACKUP_DIR/preferences/mouse.plist" 2>/dev/null
defaults export com.apple.driver.AppleHIDMouse "$BACKUP_DIR/preferences/mouse_driver.plist" 2>/dev/null
defaults export com.apple.AppleMultitouchMouse "$BACKUP_DIR/preferences/magic_mouse.plist" 2>/dev/null
echo "Exported Mouse preferences"

# Trackpad settings
print_subheading "Exporting Trackpad preferences"
defaults export com.apple.driver.AppleBluetoothMultitouch.trackpad "$BACKUP_DIR/preferences/trackpad.plist" 2>/dev/null
defaults export com.apple.AppleMultitouchTrackpad "$BACKUP_DIR/preferences/multitouch_trackpad.plist" 2>/dev/null
echo "Exported Trackpad preferences"

# Printer & Scanner settings
print_subheading "Exporting Printer & Scanner preferences"
defaults export com.apple.print "$BACKUP_DIR/preferences/print.plist" 2>/dev/null
defaults export org.cups.PrintingPrefs "$BACKUP_DIR/preferences/cups_printing.plist" 2>/dev/null

# Create a folder for printer settings
mkdir -p "$BACKUP_DIR/preferences/printers"
# Export printer configuration files if they exist
if [ -d "/etc/cups" ]; then
    sudo cp -R /etc/cups/ppd "$BACKUP_DIR/preferences/printers/" 2>/dev/null || echo "Could not copy printer PPD files (may require sudo)"
fi
echo "Exported Printer & Scanner preferences"

# Lock screen settings
print_subheading "Exporting Lock screen preferences"
defaults export com.apple.screensaver "$BACKUP_DIR/preferences/screensaver.plist" 2>/dev/null
defaults export com.apple.screenlock "$BACKUP_DIR/preferences/screenlock.plist" 2>/dev/null
echo "Exported Lock screen preferences"

# Additional shortcuts and gestures
print_subheading "Exporting additional shortcuts and gestures"
defaults export com.apple.preference.trackpad "$BACKUP_DIR/preferences/trackpad_shortcuts.plist" 2>/dev/null
defaults export com.apple.controlcenter "$BACKUP_DIR/preferences/control_center.plist" 2>/dev/null
defaults export com.apple.touchbar.agent "$BACKUP_DIR/preferences/touchbar.plist" 2>/dev/null
defaults export com.apple.systempreferences "$BACKUP_DIR/preferences/system_preferences.plist" 2>/dev/null
echo "Exported additional shortcuts and gestures"

# Additional backups
print_heading "Backing up additional information"

# Backup installed fonts
print_subheading "Backing up fonts"
ls -la "$HOME/Library/Fonts" > "$BACKUP_DIR/misc/fonts.txt" 2>/dev/null || echo "No user fonts found"
echo "Exported user fonts list"

# Backup network configurations
print_subheading "Backing up network configurations"
networksetup -listallnetworkservices > "$BACKUP_DIR/misc/network_services.txt"
echo "Exported network services"

# Backup information about system
# print_subheading "Backing up system information"
# system_profiler SPSoftwareDataType > "$BACKUP_DIR/misc/system_info.txt"
# echo "Exported system information"

# Copy the restore script to the backup directory
print_heading "Copying restoration script"
if [ -f "$(dirname "$0")/restore_mac_state.sh" ]; then
    cp "$(dirname "$0")/restore_mac_state.sh" "$BACKUP_DIR/"
    chmod +x "$BACKUP_DIR/restore_mac_state.sh"
    echo "Copied restore script to backup directory"
else
    print_error "restore_mac_state.sh not found in the same directory as this script"
    echo "Please ensure restore_mac_state.sh is in the same directory as this script"
fi

# Create an archive of the backup
print_heading "Creating archive of the backup"
cd "$(dirname "$BACKUP_DIR")"
tar -czf "$(basename "$BACKUP_DIR").tar.gz" "$(basename "$BACKUP_DIR")"
echo "Created archive: $(dirname "$BACKUP_DIR")/$(basename "$BACKUP_DIR").tar.gz"

print_heading "Backup completed successfully!"
echo "You can find your backup at: $BACKUP_DIR"
echo "An archive has been created at: $(dirname "$BACKUP_DIR")/$(basename "$BACKUP_DIR").tar.gz"
echo ""
echo "To restore this backup on a new Mac:"
echo "1. Copy the backup directory or archive to the new Mac"
echo "2. Extract the archive if necessary"
echo "3. Run the restoration script: $BACKUP_DIR/restore_mac_state.sh"


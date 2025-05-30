#!/bin/bash

# ======================================================
# restore_mac_state.sh
# ------------------------------------------------------
# This script restores a Mac from a backup created with
# backup_mac_state.sh. It installs Homebrew, restores
# applications, configurations, and preferences.
#
# Usage: ./restore_mac_state.sh [backup_dir]
# ======================================================

# Exit on error
set -e

# Define info print helper
print_info() {
    echo -e "\033[1;34m[INFO]\033[0m $1"
}

# Detect architecture and set paths accordingly
ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" ]]; then
    IS_APPLE_SILICON=true
    HOMEBREW_PREFIX="/opt/homebrew"
    print_info "Detected Apple Silicon Mac (M-series chip)"
else
    IS_APPLE_SILICON=false
    HOMEBREW_PREFIX="/usr/local"
    print_info "Detected Intel Mac"
fi

# Set text formatting
BOLD=$(tput bold)
NORMAL=$(tput sgr0)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
RED=$(tput setaf 1)
BLUE=$(tput setaf 4)

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

# Print info function
print_info() {
    echo "${BLUE}$1${NORMAL}"
}

# Print error function
print_error() {
    echo "${BOLD}${RED}ERROR: $1${NORMAL}"
}

# Print success function
print_success() {
    echo "${GREEN}✓ $1${NORMAL}"
}

# Check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Progress indicator for long-running commands
progress_indicator() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Check if running as sudo (we don't want that)
if [ "$EUID" -eq 0 ]; then
    print_error "Please don't run this script with sudo or as root."
    exit 1
fi

# Determine backup directory
BACKUP_DIR=""
if [ -z "$1" ]; then
    # No argument provided, look for the most recent backup
    print_info "No backup directory specified, looking for most recent backup..."
    LATEST_BACKUP=$(find "$HOME" -maxdepth 2 -name "mac_backup_*" -type d | sort -r | head -n 1)
    
    if [ -z "$LATEST_BACKUP" ]; then
        print_error "No backup directory found. Please specify the backup directory as an argument."
        echo "Usage: ./restore_mac_state.sh [backup_dir]"
        exit 1
    else
        BACKUP_DIR="$LATEST_BACKUP"
        print_info "Found backup directory: $BACKUP_DIR"
    fi
else
    # Argument provided, use it as backup directory
    BACKUP_DIR="$1"
    if [ ! -d "$BACKUP_DIR" ]; then
        print_error "Backup directory does not exist: $BACKUP_DIR"
        exit 1
    fi
fi

# Check if the backup directory has the expected structure
if [ ! -d "$BACKUP_DIR/homebrew" ] || [ ! -d "$BACKUP_DIR/app_store" ]|| [ ! -d "$BACKUP_DIR/misc" ] || [ ! -d "$BACKUP_DIR/preferences" ] || [ ! -d "$BACKUP_DIR/fonts" ]; then
    print_error "Backup directory does not have the expected structure."
    print_info "Expected directories: app_store, homebrew, fonts, preferences, misc"
    exit 1
fi

print_heading "Starting restoration from $BACKUP_DIR"

# Ensure Xcode Command Line Tools are installed
print_heading "Checking for Xcode Command Line Tools"
if command_exists xcode-select && xcode-select -p &> /dev/null; then
    print_success "Xcode Command Line Tools are already installed."
else
    print_info "Installing Xcode Command Line Tools..."
    xcode-select --install
    print_info "A dialog should appear to install the Command Line Tools."
    read -p "Press Enter when the installation is complete..." 
    if ! xcode-select -p &> /dev/null; then
        print_error "Xcode Command Line Tools installation failed."
        print_info "Please install them manually and run this script again."
        exit 1
    fi
    print_success "Xcode Command Line Tools installed successfully."
fi

# install oh-my-zsh
print_heading "installing oh-my-zsh"
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" && print_success "oh-my-zsh installed successfully"


# Install Homebrew if it's not installed
print_heading "Checking for Homebrew"
if command_exists brew; then
    print_success "Homebrew is already installed."
else
    print_info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" &
    brew_pid=$!
    progress_indicator $brew_pid
    
    # Add Homebrew to PATH for the current session
    # Add Homebrew to PATH for the current session
    if [ -f "$HOMEBREW_PREFIX/bin/brew" ]; then
        eval "$($HOMEBREW_PREFIX/bin/brew shellenv)"
    elif [ -f /opt/homebrew/bin/brew ]; then
        HOMEBREW_PREFIX="/opt/homebrew"
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -f /usr/local/bin/brew ]; then
        HOMEBREW_PREFIX="/usr/local"
        eval "$(/usr/local/bin/brew shellenv)"
    fi
    if ! command_exists brew; then
        print_error "Homebrew installation failed."
        exit 1
    fi
    print_success "Homebrew installed successfully."
    
    # Configure Homebrew in user's shell profile
    print_info "Adding Homebrew to $USER's shell profile"
    echo "" >> /Users/$USER/.zprofile
    echo "eval \"\$(${HOMEBREW_PREFIX}/bin/brew shellenv)\"" >> /Users/$USER/.zprofile
    eval "$($HOMEBREW_PREFIX/bin/brew shellenv)"
    print_success "Added Homebrew to shell profile"
fi

# Restore Homebrew packages
print_heading "Restoring Homebrew packages"

# Check which Brewfile to use
BREWFILE="$BACKUP_DIR/homebrew/Brewfile"
if [ -f "$BACKUP_DIR/homebrew/Brewfile.essential" ]; then
    # If there's a Brewfile.essential, ask the user which one to use
    print_info "Found Brewfile.essential - a curated list of essential packages."
    echo "1. Restore all packages (Brewfile)"
    echo "2. Restore essential packages only (Brewfile.essential)"
    read -p "Choose an option (1/2): " brewfile_option
    
    if [ "$brewfile_option" = "2" ]; then
        BREWFILE="$BACKUP_DIR/homebrew/Brewfile.essential"
        print_info "Using Brewfile.essential"
    else
        print_info "Using complete Brewfile"
    fi
fi

if [ -f "$BREWFILE" ]; then
    print_info "Installing packages from $BREWFILE..."
    brew bundle install --file="$BREWFILE" || {
        print_error "Some Homebrew packages failed to install."
        print_info "Continuing with the restoration process..."
    }
    print_success "Homebrew packages restored."
else
    # Try individual files if no Brewfile is found
    print_info "No Brewfile found, using individual package lists..."
    
    # # Install taps
    # if [ -f "$BACKUP_DIR/homebrew/brew_taps.txt" ]; then
    #     print_subheading "Restoring Homebrew taps"
    #     while IFS= read -r tap; do
    #         print_info "Adding tap: $tap"
    #         brew tap "$tap" || print_error "Failed to add tap: $tap"
    #     done < "$BACKUP_DIR/homebrew/brew_taps.txt"
    #     print_success "Homebrew taps restored."
    # fi
    
    # Install formulae
    if [ -f "$BACKUP_DIR/homebrew/brew_packages.txt" ]; then
        print_subheading "Restoring Homebrew packages"
        while IFS= read -r package; do
            print_info "Installing package: $package"
            brew install "$package" || print_error "Failed to install package: $package"
        done < "$BACKUP_DIR/homebrew/brew_packages.txt"
        print_success "Homebrew packages restored."
    fi
    
    # Install casks
    if [ -f "$BACKUP_DIR/homebrew/brew_casks.txt" ]; then
        print_subheading "Restoring Homebrew casks"
        while IFS= read -r cask; do
            print_info "Installing cask: $cask"
            brew install --cask "$cask" || print_error "Failed to install cask: $cask"
        done < "$BACKUP_DIR/homebrew/brew_casks.txt"
        print_success "Homebrew casks restored."
    fi
fi

# # fonts
# if [ -f "$BACKUP_DIR/fonts/font_list.txt" ]; then
#         print_subheading "Restoring fonts..."
#         $BACKUP_DIR/fonts/restore_font.sh $BACKUP_DIR/fonts/font_list.txt
#     fi

# # Restore Mac App Store applications
# print_heading "Restoring Mac App Store applications"

# if command_exists mas; then
#     print_success "mas command is available."
# else
#     print_info "Installing mas command to manage Mac App Store apps..."
#     brew install mas
#     if ! command_exists mas; then
#         print_error "Failed to install mas. App Store applications will not be restored."
#     else
#         print_success "mas installed successfully."
#     fi
# fi

# if command_exists mas && [ -f "$BACKUP_DIR/app_store/mas_apps.txt" ]; then
#     print_info "Please sign in to the App Store first"
#     open -a "App Store"
#     read -p "Press Enter when you're signed in to the App Store..." 
    
#     print_info "Restoring App Store applications..."
    
    
#     # Check if user is signed in to App Store
#     if ! mas account &> /dev/null; then
#         print_error "Not signed in to the App Store or mas command not compatible with this macOS version."
#         print_error "App Store applications will not be restored."
#         print_info "Continuing with restoration process..."
#     else
#         # Install applications
#         while IFS= read -r line; do
#             if [[ $line =~ ([0-9]+)[[:space:]](.+) ]]; then
#                 app_id="${BASH_REMATCH[1]}"
#                 app_name="${BASH_REMATCH[2]}"
#                 print_info "Installing $app_name..."
#                 mas install "$app_id" &> /dev/null || print_error "Failed to install $app_name"
#             fi
#         done < "$BACKUP_DIR/app_store/mas_apps.txt"
#         print_success "App Store applications restored."
#     fi
# else
#     print_info "Skipping App Store applications restoration (no list found or mas unavailable)."
# fi

# Restore macOS preferences
print_heading "Restoring macOS preferences"

if [ -d "$BACKUP_DIR/preferences" ]; then
    # Function to restore a preferences file with architecture considerations
    restore_pref_file() {
        local source_file="$1"
        local target_dir="$2"
        local pref_name="$3"
        
        if [ -f "$source_file" ]; then
            print_info "Restoring $pref_name preferences..."
            mkdir -p "$target_dir"
            cp -f "$source_file" "$target_dir/" && {
                print_success "$pref_name preferences restored."
                return 0
            } || {
                print_error "Failed to restore $pref_name preferences."
                return 1
            }
        fi
        return 0
    }
    
    # Restore Desktop settings
    print_subheading "Restoring Desktop preferences"
    if [ -f "$BACKUP_DIR/preferences/desktop.plist" ]; then
        print_info "Restoring Desktop preferences..."
        defaults import com.apple.desktop "$BACKUP_DIR/preferences/desktop.plist" 2>/dev/null && {
            print_success "Desktop preferences restored."
        } || print_error "Failed to restore Desktop preferences."
    fi
    
    if [ -f "$BACKUP_DIR/preferences/desktop_picture.plist" ]; then
        print_info "Restoring Desktop picture settings..."
        defaults import com.apple.desktoppicture "$BACKUP_DIR/preferences/desktop_picture.plist" 2>/dev/null && {
            print_success "Desktop picture settings restored."
        } || print_error "Failed to restore Desktop picture settings."
    fi
    
    # Restore Dock settings
    print_subheading "Restoring Dock preferences"
    if [ -f "$BACKUP_DIR/preferences/dock.plist" ]; then
        print_info "Restoring Dock preferences..."
        defaults import com.apple.dock "$BACKUP_DIR/preferences/dock.plist" 2>/dev/null && {
            print_success "Dock preferences restored."
        } || print_error "Failed to restore Dock preferences."
    fi

    # Restore Widget/Dashboard settings
    print_subheading "Restoring Widget preferences"
    if [ -f "$BACKUP_DIR/preferences/dashboard.plist" ]; then
        print_info "Restoring Dashboard preferences..."
        defaults import com.apple.dashboard "$BACKUP_DIR/preferences/dashboard.plist" 2>/dev/null && {
            print_success "Dashboard preferences restored."
        } || print_error "Failed to restore Dashboard preferences."
    fi
    
    if [ -f "$BACKUP_DIR/preferences/widgets.plist" ]; then
        print_info "Restoring Widget preferences..."
        defaults import com.apple.widgetkit "$BACKUP_DIR/preferences/widgets.plist" 2>/dev/null && {
            print_success "Widget preferences restored."
        } || print_error "Failed to restore Widget preferences."
    fi
    
    # Restore Window Manager settings
    print_subheading "Restoring Window Management preferences"
    if [ -f "$BACKUP_DIR/preferences/window_manager.plist" ]; then
        print_info "Restoring Window Manager preferences..."
        defaults import com.apple.WindowManager "$BACKUP_DIR/preferences/window_manager.plist" 2>/dev/null && {
            print_success "Window Manager preferences restored."
        } || print_error "Failed to restore Window Manager preferences."
    fi
    
    if [ -f "$BACKUP_DIR/preferences/window_settings.plist" ]; then
        print_info "Restoring Window settings..."
        defaults import com.apple.preference.general "$BACKUP_DIR/preferences/window_settings.plist" 2>/dev/null && {
            print_success "Window settings restored."
        } || print_error "Failed to restore Window settings."
    fi
    
    # Restore Keyboard settings
    print_subheading "Restoring Keyboard preferences"
    if [ -f "$BACKUP_DIR/preferences/keyboard.plist" ]; then
        print_info "Restoring Keyboard preferences..."
        defaults import com.apple.keyboard "$BACKUP_DIR/preferences/keyboard.plist" 2>/dev/null && {
            print_success "Keyboard preferences restored."
        } || print_error "Failed to restore Keyboard preferences."
    fi
    
    if [ -f "$BACKUP_DIR/preferences/input_sources.plist" ]; then
        print_info "Restoring Input Sources..."
        defaults import com.apple.HIToolbox "$BACKUP_DIR/preferences/input_sources.plist" 2>/dev/null && {
            print_success "Input Sources restored."
        } || print_error "Failed to restore Input Sources."
    fi
    
    if [ -f "$BACKUP_DIR/preferences/keyboard_shortcuts.txt" ]; then
        print_info "Restoring Keyboard shortcuts..."
        defaults import com.apple.symbolichotkeys "$BACKUP_DIR/preferences/keyboard_shortcuts.txt" 2>/dev/null && {
            print_success "Keyboard shortcuts restored."
        } || print_error "Failed to restore Keyboard shortcuts."
    fi
    
    # Restore Mouse settings
    print_subheading "Restoring Mouse preferences"
    if [ -f "$BACKUP_DIR/preferences/mouse.plist" ]; then
        print_info "Restoring Mouse preferences..."
        defaults import com.apple.mouse "$BACKUP_DIR/preferences/mouse.plist" 2>/dev/null && {
            print_success "Mouse preferences restored."
        } || print_error "Failed to restore Mouse preferences."
    fi
    
    if [ -f "$BACKUP_DIR/preferences/mouse_driver.plist" ]; then
        print_info "Restoring Mouse driver settings..."
        defaults import com.apple.driver.AppleHIDMouse "$BACKUP_DIR/preferences/mouse_driver.plist" 2>/dev/null && {
            print_success "Mouse driver settings restored."
        } || print_error "Failed to restore Mouse driver settings."
    fi
    
    if [ -f "$BACKUP_DIR/preferences/magic_mouse.plist" ]; then
        print_info "Restoring Magic Mouse settings..."
        defaults import com.apple.AppleMultitouchMouse "$BACKUP_DIR/preferences/magic_mouse.plist" 2>/dev/null && {
            print_success "Magic Mouse settings restored."
        } || print_error "Failed to restore Magic Mouse settings."
    fi
    
    # Restore Trackpad settings
    print_subheading "Restoring Trackpad preferences"
    if [ -f "$BACKUP_DIR/preferences/trackpad.plist" ]; then
        print_info "Restoring Trackpad preferences..."
        defaults import com.apple.driver.AppleBluetoothMultitouch.trackpad "$BACKUP_DIR/preferences/trackpad.plist" 2>/dev/null && {
            print_success "Trackpad preferences restored."
        } || print_error "Failed to restore Trackpad preferences."
    fi
    
    if [ -f "$BACKUP_DIR/preferences/multitouch_trackpad.plist" ]; then
        print_info "Restoring Multitouch Trackpad settings..."
        defaults import com.apple.AppleMultitouchTrackpad "$BACKUP_DIR/preferences/multitouch_trackpad.plist" 2>/dev/null && {
            print_success "Multitouch Trackpad settings restored."
        } || print_error "Failed to restore Multitouch Trackpad settings."
    fi
    
    if [ -f "$BACKUP_DIR/preferences/trackpad_shortcuts.plist" ]; then
        print_info "Restoring Trackpad shortcuts..."
        defaults import com.apple.preference.trackpad "$BACKUP_DIR/preferences/trackpad_shortcuts.plist" 2>/dev/null && {
            print_success "Trackpad shortcuts restored."
        } || print_error "Failed to restore Trackpad shortcuts."
    fi
    
    # Restore Printer & Scanner settings
    print_subheading "Restoring Printer & Scanner preferences"
    if [ -f "$BACKUP_DIR/preferences/print.plist" ]; then
        print_info "Restoring Print preferences..."
        defaults import com.apple.print "$BACKUP_DIR/preferences/print.plist" 2>/dev/null && {
            print_success "Print preferences restored."
        } || print_error "Failed to restore Print preferences."
    fi
    
    if [ -f "$BACKUP_DIR/preferences/cups_printing.plist" ]; then
        print_info "Restoring CUPS printing preferences..."
        defaults import org.cups.PrintingPrefs "$BACKUP_DIR/preferences/cups_printing.plist" 2>/dev/null && {
            print_success "CUPS printing preferences restored."
        } || print_error "Failed to restore CUPS printing preferences."
    fi
    
    if [ -d "$BACKUP_DIR/preferences/printers/ppd" ]; then
        print_info "Restoring printer PPD files..."
        sudo mkdir -p /etc/cups/ppd 2>/dev/null
        sudo cp -R "$BACKUP_DIR/preferences/printers/ppd/"* /etc/cups/ppd/ 2>/dev/null && {
            print_success "Printer PPD files restored."
        } || print_error "Failed to restore printer PPD files (may require sudo permissions)."
    fi
    
    # Restore Lock screen settings
    print_subheading "Restoring Lock screen preferences"
    if [ -f "$BACKUP_DIR/preferences/screensaver.plist" ]; then
        print_info "Restoring Screensaver preferences..."
        defaults import com.apple.screensaver "$BACKUP_DIR/preferences/screensaver.plist" 2>/dev/null && {
            print_success "Screensaver preferences restored."
        } || print_error "Failed to restore Screensaver preferences."
    fi
    
    if [ -f "$BACKUP_DIR/preferences/screenlock.plist" ]; then
        print_info "Restoring Screen lock preferences..."
        defaults import com.apple.screenlock "$BACKUP_DIR/preferences/screenlock.plist" 2>/dev/null && {
            print_success "Screen lock preferences restored."
        } || print_error "Failed to restore Screen lock preferences."
    fi
    
    # Restore additional shortcuts and gestures
    print_subheading "Restoring additional shortcuts and gestures"
    if [ -f "$BACKUP_DIR/preferences/control_center.plist" ]; then
        print_info "Restoring Control Center preferences..."
        defaults import com.apple.controlcenter "$BACKUP_DIR/preferences/control_center.plist" 2>/dev/null && {
            print_success "Control Center preferences restored."
        } || print_error "Failed to restore Control Center preferences."
    fi
    
    if [ -f "$BACKUP_DIR/preferences/touchbar.plist" ]; then
        print_info "Restoring Touch Bar preferences..."
        defaults import com.apple.touchbar.agent "$BACKUP_DIR/preferences/touchbar.plist" 2>/dev/null && {
            print_success "Touch Bar preferences restored."
        } || print_error "Failed to restore Touch Bar preferences."
    fi
    
    if [ -f "$BACKUP_DIR/preferences/system_preferences.plist" ]; then
        print_info "Restoring System Preferences settings..."
        defaults import com.apple.systempreferences "$BACKUP_DIR/preferences/system_preferences.plist" 2>/dev/null && {
            print_success "System Preferences settings restored."
        } || print_error "Failed to restore System Preferences settings."
    fi
    
    # Restore iTerm2 preferences
    if [ -f "$BACKUP_DIR/preferences/com.googlecode.iterm2.plist" ]; then
        print_info "Restoring iTerm2 preferences..."
        cp -f "$BACKUP_DIR/preferences/com.googlecode.iterm2.plist" "$HOME/Library/Preferences/" && {
            print_success "iTerm2 preferences restored."
        } || print_error "Failed to restore iTerm2 preferences."
    fi

    # Restore Rectangle preferences
    restore_pref_file "$BACKUP_DIR/preferences/com.knollsoft.Rectangle.plist" "$HOME/Library/Preferences" "Rectangle"
    

    # Restore AltTab settings
    restore_pref_file "$BACKUP_DIR/com.lwouis.alt-tab-macos.plist" "$HOME/Library/Preferences/"


    # Function to restore application support directories
    restore_app_support_dir() {
        local source_dir="$1"
        local target_base="$2"
        local app_name="$3"
        
        if [ -d "$source_dir" ]; then
            print_info "Restoring $app_name settings..."
            # Create directory if it doesn't exist
            mkdir -p "$target_base"
            cp -Rf "$source_dir/"* "$target_base/" && {
                print_success "$app_name settings restored."
                return 0
            } || {
                print_error "Failed to restore $app_name settings."
                return 1
            }
        fi
        return 0
    }
    # Restore Mousecape settings
    print_info "Restoring Mousescape settings"
    restore_app_support_dir "$BACKUP_DIR/misc/Mousecape" "$HOME/Library/Application Support/Mousecape" "Mousecape"


    # Restore Finder Sidebar
    print_info "Restoring Finder Sidebar preferences..."
    restore_pref_file  "$BACKUP_DIR/preferences/com.apple.LSSharedFileList.FavoriteItems.sfl2" "$HOME/Library/Application\ Support/com.apple.sharedfilelist/" && {
            print_success "Finder Sidebar preferences restored."
        } || print_error "Failed to restore Finder Sidebar preferences."
    killall Finder
open /System/Library/CoreServices/Finder.app


# Restore Menu Bar
print_info "Restoring Menu Bar preferences..."
    restore_pref_file  "$BACKUP_DIR/misc/com.apple.systemuiserver.plist" "$HOME/Library/Preferences/" && {
            print_success "Menu Bar preferences restored."
        } || print_error "Failed to restore Menu Bar preferences."


    # # Restore Raycast settings
    # if [ -d "$BACKUP_DIR/app_store/raycast" ]; then
    #     print_info "Restoring Raycast settings..."
    #     # Restore plist file
    #     restore_pref_file "$BACKUP_DIR/app_store/raycast/com.raycast.macos.plist" "$HOME/Library/Preferences" "Raycast preferences file"
    #     
    #     # Restore Application Support files
    #     restore_app_support_dir "$BACKUP_DIR/app_store/raycast/com.raycast.macos" "$HOME/Library/Application Support/com.raycast.macos" "Raycast application data"
    #     
    #     restore_app_support_dir "$BACKUP_DIR/app_store/raycast/com.raycast.shared" "$HOME/Library/Application Support/com.raycast.shared" "Raycast shared data"
    # fi
    
    print_info "Preferences restoration completed."
else
    print_error "No preferences directory found in the backup."
fi
    
    # Function to import preference file using defaults command
    import_pref_file() {
        local pref_file="$1"
        local domain="$2"
        local description="$3"
        local post_cmd="$4"
        
        if [ -f "$pref_file" ]; then
            print_info "Restoring $description..."
            defaults import "$domain" "$pref_file" && {
                if [ -n "$post_cmd" ]; then
                    eval "$post_cmd"
                fi
                print_success "$description restored."
                return 0
            } || {
                print_error "Failed to restore $description."
                return 1
            }
        fi
        return 0
    }

    # Restore Finder preferences
    import_pref_file "$BACKUP_DIR/preferences/finder.plist" "com.apple.finder" "Finder preferences" "killall Finder"
    
    # Restore Mission Control preferences
    import_pref_file "$BACKUP_DIR/preferences/mission_control.plist" "com.apple.spaces" "Mission Control preferences"
    
    # Restore global preferences
    import_pref_file "$BACKUP_DIR/preferences/global_domain.plist" "-g" "Global preferences"
    



# # Restore dotfiles
# print_heading "Restoring dotfiles"

# if [ -d "$BACKUP_DIR/dotfiles" ]; then
#     print_info "Copying dotfiles to home directory..."
#     cp -R "$BACKUP_DIR/dotfiles/." "$HOME/" || {
#         print_error "Failed to copy some dotfiles."
#         print_info "Continuing with the restoration process..."
#     }
#     print_success "Dotfiles restored."
# else
#     print_error "No dotfiles directory found in the backup."
# fi

# Backup: restore dotfiles with stow

DOTFILES_DIR="$HOME/.dotfiles"

if [ -d "$DOTFILES_DIR" ]; then
  cd "$DOTFILES_DIR" || exit 1
  stow */        # stow everything inside .dotfiles
  
else
  echo "Dotfiles directory not found at $DOTFILES_DIR"
     echo "${RED}✗${NORMAL} Dotfiles: Not restored"
  exit 1
fi


# zsh-syntax-highlighting
# MacOs
# echo "source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" >> ${ZDOTDIR:-$HOME}/.zshrc

# Linux
# echo "source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" >> ${ZDOTDIR:-$HOME}/.zshrc

# color ls
gem install --user-install public_suffix -v 5.1.1 && gem install --user-install colorls && print_success "colorls installed succesfully" || print_error "Failed to install colorls"


# source "$HOME/.zshrc" 


# Verify installations
print_heading "Verifying installations"

# Verify Homebrew installations
if command_exists brew; then
    print_subheading "Verifying Homebrew installations"
    brew_failed=0
    
    print_info "Checking Homebrew install status..."
    brew doctor || {
        print_error "Homebrew doctor found issues. Some packages may not work correctly."
        brew_failed=1
    }
    
    if [ $brew_failed -eq 0 ]; then
        print_success "Homebrew installation verified."
    else
        print_error "Homebrew verification found issues. Please check the output above."
    fi
fi

# Summarize what was restored
print_heading "Restoration Summary"

echo "${BOLD}The following items were processed:${NORMAL}"

# Homebrew
if command_exists brew; then
    formula_count=$(brew list --formula | wc -l | tr -d ' ')
    cask_count=$(brew list --cask | wc -l | tr -d ' ')
    echo "${GREEN}✓${NORMAL} Homebrew: $formula_count formulae and $cask_count casks installed"
else
    echo "${RED}✗${NORMAL} Homebrew: Not installed"
fi

# Mac App Store
if command_exists mas && [ -f "$BACKUP_DIR/app_store/mas_apps.txt" ]; then
    mas_count=$(wc -l < "$BACKUP_DIR/app_store/mas_apps.txt" | tr -d ' ')
    echo "${GREEN}✓${NORMAL} App Store: Attempted to restore $mas_count applications"
else
    echo "${RED}✗${NORMAL} App Store: Applications not restored"
fi

# # Dotfiles
# if [ -d "$BACKUP_DIR/dotfiles" ]; then
#     dotfile_count=$(find "$BACKUP_DIR/dotfiles" -type f | wc -l | tr -d ' ')
#     echo "${GREEN}✓${NORMAL} Dotfiles: $dotfile_count files copied"
# else
#     echo "${RED}✗${NORMAL} Dotfiles: Not restored"
# fi

# Preferences
if [ -d "$BACKUP_DIR/preferences" ]; then
    pref_count=$(find "$BACKUP_DIR/preferences" -type f | wc -l | tr -d ' ')
    echo "${GREEN}✓${NORMAL} Preferences: $pref_count preference files restored"
else
    echo "${RED}✗${NORMAL} Preferences: Not restored"
fi

# System Preferences Check
print_heading "System Preferences Check"

# Check which system preferences were restored
system_pref_types=()

# Check Desktop & Widgets preferences
if defaults read com.apple.dock 2>/dev/null; then
    system_pref_types+=("Desktop & Dock settings")
fi

# Check Keyboard shortcuts
if [ -f "$BACKUP_DIR/preferences/keyboard_shortcuts.txt" ] || defaults read com.apple.symbolichotkeys &>/dev/null; then
    system_pref_types+=("Keyboard shortcuts")
fi

# Check Mouse/Trackpad preferences
if defaults read com.apple.driver.AppleBluetoothMultitouch.trackpad &>/dev/null || defaults read com.apple.driver.AppleBluetoothMultitouch.mouse &>/dev/null; then
    system_pref_types+=("Mouse & Trackpad settings")
fi

# Check Lock Screen preferences
if defaults read com.apple.screensaver &>/dev/null; then
    system_pref_types+=("Lock screen settings")
fi

# Check Printer & Scanner preferences
if [ -d "/Users/Shared/Library/Preferences/org.cups.printers.plist" ]; then
    system_pref_types+=("Printer & Scanner settings")
fi

if [ ${#system_pref_types[@]} -gt 0 ]; then
    print_success "The following system preferences were restored:"
    for pref in "${system_pref_types[@]}"; do
        echo "  - $pref"
    done
else
    print_info "No specific system preferences were detected as restored."
    print_info "You may need to manually configure some system settings."
fi

# Final tasks and cleanup
print_heading "Final Steps"

# Check if shell needs to be reloaded
print_info "You may need to reload your shell to apply all changes."

# Recommend logout/restart
print_info "Some settings may require logging out or restarting your Mac to take full effect."

# Check for common post-install tasks
if command_exists zsh && grep -q "powerlevel10k" "$HOME/.zshrc" 2>/dev/null; then
    print_info "Powerlevel10k theme detected. You might want to run 'p10k configure' to set it up."
fi

if command_exists tmux && [ -f "$HOME/.tmux.conf" ]; then
    print_info "Tmux configuration restored. Run 'tmux source-file ~/.tmux.conf' to apply changes in existing sessions."
fi

# # Check additional application-specific settings
# if [ -d "$HOME/Library/Application Support/Raycast" ] || [ -f "$HOME/Library/Preferences/com.raycast.macos.plist" ]; then
#     print_info "Raycast settings were restored. Launch Raycast to verify all extensions and settings are working."
# fi

if command_exists brew && brew list --cask | grep -q karabiner-elements; then
    print_info "Karabiner-Elements was installed. You may need to enable it in Security & Privacy settings."
fi

# Next steps
print_heading "Next Steps"

echo "Your Mac restoration is complete! Here's what you might want to do next:"
echo ""
echo "1. ${BOLD}Restart your Mac${NORMAL} to ensure all settings are applied"
echo "2. ${BOLD}Check applications${NORMAL} to ensure they're working properly"
echo "3. ${BOLD}Verify system preferences${NORMAL} for:"
echo "   - Desktop, dock, and widgets"
echo "   - Window management"
echo "   - Keyboard and mouse shortcuts"
echo "   - Lockscreen and security settings"
echo "   - Trackpad and mouse configuration"
echo "   - Printer and scanner setup"
echo "4. ${BOLD}Sign in to accounts${NORMAL} in restored applications"
echo ""
echo "If you encounter any issues, check the installation logs or run 'brew doctor' to diagnose Homebrew problems."

print_heading "Restoration Complete!"
echo "Your Mac has been restored from: $BACKUP_DIR"
echo "Completed at: $(date)"

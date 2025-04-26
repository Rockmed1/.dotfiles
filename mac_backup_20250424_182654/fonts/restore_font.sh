#!/bin/bash

# FONT_DIR="./fonts"       # Folder for local .ttf/.otf files

# FONT_LIST="./font_list.txt"  # List of font names
BREW_FONT_TAP="homebrew/cask-fonts"

# Helper functions
print_info() {
    echo -e "\033[1;34m[INFO]\033[0m $1"
}

print_success() {
    echo -e "\033[1;32m[SUCCESS]\033[0m $1"
}

print_error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1"
}

FONT_LIST="$1" # List of font names
    if [ ! -f "$FONT_LIST" ]; then
        print_error "Font list file does not exist: $BACKUP_DIR"
        exit 1
    fi

# Ensure brew font tap is added
brew tap "$BREW_FONT_TAP" >/dev/null 2>&1

# Function to attempt brew install
install_font_with_brew() {
    local brew_name="$1"

    if brew search "$brew_name" | grep -q "^$brew_name\$"; then
        print_info "Installing $brew_name via Homebrew..."
        brew install --cask "$brew_name"
        return 0
    else
        return 1
    fi
}

# Function to attempt Google Fonts download
install_font_from_google() {
    local font_name="$1"
    local formatted_name=$(echo "$font_name" | tr ' ' '+' | sed 's/++/+/g')
    local download_url="https://fonts.google.com/download?family=$formatted_name"
    local temp_zip="/tmp/${font_name// /_}.zip"

    print_info "Downloading $font_name from Google Fonts..."
    curl -L -o "$temp_zip" "$download_url"

    if [ -f "$temp_zip" ]; then
        unzip -o "$temp_zip" -d /tmp/font_install/
        mkdir -p ~/Library/Fonts/
        cp /tmp/font_install/*.ttf ~/Library/Fonts/ 2>/dev/null
        cp /tmp/font_install/*.otf ~/Library/Fonts/ 2>/dev/null
        print_success "Installed $font_name from Google Fonts."
        rm -rf /tmp/font_install "$temp_zip"
    else
        print_error "Failed to download $font_name from Google Fonts."
    fi
}

# Check and install fonts
while IFS= read -r font_name; do
    if system_profiler SPFontsDataType | grep -q "$font_name"; then
        print_success "Font '$font_name' already installed."
    else
        print_info "Font '$font_name' not found. Attempting installation..."

        # 1. Try Homebrew
        brew_cask_name="font-$(echo "$font_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')"
        if install_font_with_brew "$brew_cask_name"; then
            print_success "Installed '$font_name' via Homebrew."
        else
            # # 2. Try local font files
            # font_file=$(find "$FONT_DIR" -iname "*$font_name*.ttf" -o -iname "*$font_name*.otf" | head -n 1)
            # if [ -n "$font_file" ]; then
            #     print_info "Installing from local file: $font_file"
            #     cp "$font_file" ~/Library/Fonts/
            #     print_success "Installed '$font_name' from local fonts."
            # else
                # 3. Try downloading from Google Fonts
                install_font_from_google "$font_name"
            # fi
        fi
    fi
done < "$FONT_LIST"

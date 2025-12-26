#!/bin/bash

# Import functions from brew_functions.sh.
echo "Sourcing functions.sh..."
source "brew_functions.sh"
echo "Functions imported successfully!"

# # Import pkg list from brew_lists.sh.
echo "Sourcing brew_lists.sh..."
source "brew_lists.sh"
echo "Lists imported successfully!"

# Install Homebrew.
echo "Installing Homebrew..."
install_homebrew
echo "Homebrew is ready to use!"
brew --version

# Update to the latest Homebrew.
echo "Updating Homebrew..."
brew doctor
brew update

# Install brew formulae and casks.
install_brew_packages "CORE_PACKAGES" "${CORE_PACKAGES[@]}"
install_brew_packages "LANG_PACKAGES" "${LANG_PACKAGES[@]}"
install_brew_packages "TOOL_PACKAGES" "${TOOL_PACKAGES[@]}"
install_brew_packages "DB_PACKAGES" "${DB_PACKAGES[@]}"
install_brew_casks "CASK_APPS" "${CASK_APPS[@]}"


# Upgrade any already-installed formulae.
echo "Upgrading formulae..."
brew upgrade

# Cleanup old formulae. 
echo "Cleaning up old formulae..."
brew cleanup
echo "Cleanup is complete!"

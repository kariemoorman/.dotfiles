#!/bin/bash

# Function to install Homebrew if not already installed
function install_homebrew() {
  echo "Checking for Homebrew..."

  if command -v brew >/dev/null 2>&1; then
    echo "Homebrew is already installed."
    brew --version
  else
    echo "Homebrew not found. Installing Homebrew..."

    # Official installation script
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    echo "Homebrew installation complete."

    # Add Homebrew to PATH
    if [[ "$(uname)" == "Darwin" ]]; then
      if [[ -d "/opt/homebrew/bin" ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
        eval "$(/opt/homebrew/bin/brew shellenv)"
      elif [[ -d "/usr/local/bin" ]]; then
        echo "Using Intel Homebrew path (/usr/local/bin)"
      fi
    fi
  fi
}

# Install brew formulae
function install_brew_packages() {
    local package_list_name="$1"
    shift
    local package_list=("$@")

    if [[ ${#package_list[@]} -eq 0 ]]; then
        echo "No packages to install!"
        return 1
    fi

    echo "Installing packages from '$package_list_name'..."
    
    for recipe in "${package_list[@]}"; do
        if brew list "$recipe" &>/dev/null; then
            echo "$recipe is already installed. Skipping..."
        else
            echo "Installing $recipe"
            brew install "$recipe"
        fi
    done

    echo "Package installations complete!"
}

# Install brew casks
function install_brew_casks() {
    local cask_list_name="$1"
    shift
    local cask_list=("$@") 

    if [[ ${#cask_list[@]} -eq 0 ]]; then
        echo "No casks to install!"
        return 1
    fi

    echo "Installing casks from '$cask_list'..."
    for cask in "${cask_list[@]}"; do
        if brew list "$cask" &>/dev/null; then
            echo "$cask is already installed. Skipping..."
        else
            echo "Installing $cask"
            brew install "$cask"
        fi
    done
    echo "Cask installations complete!"
}

#!/bin/bash


set -e

echo "✨ Setting up Oh My Zsh..."


if [[ "$OSTYPE" != "darwin"* ]]; then
  echo "❌ This script is for macOS only."
  exit 1
fi


if ! command -v zsh >/dev/null 2>&1; then
  echo "❌ zsh not found. Install it first."
  exit 1
fi


if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  echo "📦 Installing Oh My Zsh..."
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  echo "✅ Oh My Zsh already installed."
fi


ZSH_PATH="$(command -v zsh)"

if ! grep -q "$ZSH_PATH" /etc/shells; then
  echo "🔐 Adding zsh to /etc/shells (sudo required)..."
  echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null
fi

if [[ "$SHELL" != "$ZSH_PATH" ]]; then
  echo "🔄 Setting zsh as default shell..."
  chsh -s "$ZSH_PATH"
else
  echo "✅ zsh already default shell."
fi


ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

echo "🔌 Installing plugins..."

install_plugin() {
  local name=$1
  local repo=$2
  local dir="$ZSH_CUSTOM/plugins/$name"

  if [[ ! -d "$dir" ]]; then
    git clone --depth=1 "$repo" "$dir"
  else
    echo "  ✔ $name already installed"
  fi
}

install_plugin zsh-autosuggestions https://github.com/zsh-users/zsh-autosuggestions
install_plugin zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting


ZSHRC="$HOME/.zshrc"

if [[ -f "$ZSHRC" ]]; then
  echo "📝 Updating plugins in .zshrc"
  sed -i '' \
    's/^plugins=.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' \
    "$ZSHRC"
else
  echo "📝 Creating .zshrc"
  cat <<'EOF' > "$ZSHRC"
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="aussiegeek"

plugins=(
  docker
  docker-compose
  git
  postgres
  pylint
  terraform
  zsh-autosuggestions
  zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh
EOF
fi

echo "✅ Oh My Zsh setup complete"
echo "👉 Restart your terminal or run: exec zsh"

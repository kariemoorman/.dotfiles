#!/bin/bash
set -euo pipefail

# ============================================================================
# setup_claude_agent.sh
# Creates a low-privilege macOS user for running Claude Code with hardened
# security settings, shared workspace, and homograph attack filtering.
#
# Usage:
#   sudo ./setup_claude_agent.sh              # uses current user
#   sudo ./setup_claude_agent.sh <username>   # specify user explicitly
# ============================================================================

# --- Determine the primary user ---
if [ -n "${1:-}" ]; then
    USERNAME="$1"
else
    # Get the real user even when run with sudo
    USERNAME="${SUDO_USER:-$(whoami)}"
fi

# --- Validate admin privileges ---
if [ "$(id -u)" -ne 0 ]; then
    echo "❌ This script must be run with sudo."
    echo "Usage: sudo $0 [username]"
    exit 1
fi

if ! dseditgroup -o checkmember -m "$USERNAME" admin &>/dev/null; then
    echo "❌ User '$USERNAME' is not an admin. Admin privileges required."
    exit 1
fi

echo "============================================"
echo "  Claude Agent Setup"
echo "  Primary user: $USERNAME"
echo "============================================"
echo ""

# --- Configuration ---
AGENT_USER="claude_agent"
AGENT_UID=599
AGENT_GROUP="claude_agent"
AGENT_GID=601
SHARED_GROUP="claude_shared"
SHARED_GID=602
AGENT_HOME="/Users/${AGENT_USER}"
WORKSPACE="/opt/workspace/CLAUDE_ONLY"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
USER_HOME=$(dscl . -read /Users/"$USERNAME" NFSHomeDirectory | awk '{print $2}')

# ============================================================================
# 0. Install Claude Code via Homebrew (if not already installed)
# ============================================================================
echo "--- Step 0: Checking Claude Code installation ---"
if command -v claude &>/dev/null; then
    echo "✅ Claude Code already installed: $(which claude)"
else
    echo "Installing Claude Code via Homebrew..."
    if ! command -v brew &>/dev/null; then
        echo "❌ Homebrew not found. Install it first: https://brew.sh"
        exit 1
    fi
    sudo -u "${USERNAME}" brew install claude-code
    if command -v claude &>/dev/null; then
        echo "✅ Claude Code installed: $(which claude)"
    else
        echo "❌ Installation failed."
        exit 1
    fi
fi

# ============================================================================
# 1. Create dedicated group for claude_agent
# ============================================================================
echo "--- Step 1: Creating dedicated group ---"
if dscl . -read /Groups/${AGENT_GROUP} &>/dev/null; then
    echo "⚠️  Group '${AGENT_GROUP}' already exists, skipping."
else
    dscl . -create /Groups/${AGENT_GROUP}
    dscl . -create /Groups/${AGENT_GROUP} PrimaryGroupID ${AGENT_GID}
    dscl . -create /Groups/${AGENT_GROUP} RealName "Claude Agent"
    echo "✅ Created group '${AGENT_GROUP}' (GID ${AGENT_GID})"
fi

# ============================================================================
# 2. Create the user with its own group (NOT staff)
# ============================================================================
echo "--- Step 2: Creating user ---"
if dscl . -read /Users/${AGENT_USER} &>/dev/null; then
    echo "⚠️  User '${AGENT_USER}' already exists, skipping."
else
    dscl . -create /Users/${AGENT_USER}
    dscl . -create /Users/${AGENT_USER} UserShell /bin/zsh
    dscl . -create /Users/${AGENT_USER} UniqueID ${AGENT_UID}
    dscl . -create /Users/${AGENT_USER} PrimaryGroupID ${AGENT_GID}
    dscl . -create /Users/${AGENT_USER} RealName "Claude Agent"
    dscl . -create /Users/${AGENT_USER} IsHidden 1
    echo "✅ Created user '${AGENT_USER}' (UID ${AGENT_UID}, hidden)"
fi

# ============================================================================
# 3. Create and own the home directory
# ============================================================================
echo "--- Step 3: Setting up home directory ---"
mkdir -p ${AGENT_HOME}
chown ${AGENT_USER}:${AGENT_GROUP} ${AGENT_HOME}
chmod 700 ${AGENT_HOME}
echo "✅ Home directory: ${AGENT_HOME} (700)"

# ============================================================================
# 4. Set up shell profile
# ============================================================================
echo "--- Step 4: Configuring shell ---"
tee ${AGENT_HOME}/.zshrc << 'ZSHRC' > /dev/null
export HOME="/Users/claude_agent"
export PATH="/opt/homebrew/bin:$HOME/.local/bin:$PATH"
alias curl="$HOME/.scripts/check_all_curl.py"
ZSHRC
chown ${AGENT_USER}:${AGENT_GROUP} ${AGENT_HOME}/.zshrc
echo "✅ Shell profile configured"

# ============================================================================
# 5. Copy scripts
# https://github.com/kariemoorman/homograph_detect
# ============================================================================
echo "--- Step 5: Copying security scripts ---"
mkdir -p ${AGENT_HOME}/.scripts

SCRIPTS_REPO="https://raw.githubusercontent.com/kariemoorman/homograph_detect/main/src"
SCRIPTS_NEEDED=(check_all_curl.py check_piped_curl.py homograph_filter.py setup_claude_project.sh)
SCRIPTS_MISSING=0

for script in "${SCRIPTS_NEEDED[@]}"; do
    if [ -f "${SCRIPT_DIR}/${script}" ]; then
        cp "${SCRIPT_DIR}/${script}" "${AGENT_HOME}/.scripts/"
        echo "  ✅ Copied ${script} (local)"
    else
        echo "  ⚠️  Not found locally: ${SCRIPT_DIR}/${script}"
        echo "  ⬇️  Downloading from GitHub..."
        if curl -fsSL "${SCRIPTS_REPO}/${script}" -o "${AGENT_HOME}/.scripts/${script}"; then
            echo "  ✅ Downloaded ${script}"
        else
            echo "  ❌ Failed to download ${script}"
            SCRIPTS_MISSING=1
        fi
    fi
done

chown -R ${AGENT_USER}:${AGENT_GROUP} ${AGENT_HOME}/.scripts
chmod +x ${AGENT_HOME}/.scripts/*.py 2>/dev/null || true
chmod +x ${AGENT_HOME}/.scripts/*.sh 2>/dev/null || true

if [ "$SCRIPTS_MISSING" -eq 1 ]; then
    echo "  ⚠️  Some scripts could not be copied or downloaded."
    echo "  Download them manually from: https://github.com/kariemoorman/homograph_detect"
fi

# ============================================================================
# 6. Create keychain
# ============================================================================
echo "--- Step 6: Setting up keychain ---"
mkdir -p ${AGENT_HOME}/Library/Keychains
chown -R ${AGENT_USER}:${AGENT_GROUP} ${AGENT_HOME}/Library

KEYCHAIN_PATH="${AGENT_HOME}/Library/Keychains/login.keychain-db"
if [ -f "${KEYCHAIN_PATH}" ]; then
    echo "⚠️  Keychain already exists, skipping."
else
    cd /tmp
    sudo -u ${AGENT_USER} security create-keychain "${KEYCHAIN_PATH}"
    sudo -u ${AGENT_USER} env HOME=${AGENT_HOME} security default-keychain -s "${KEYCHAIN_PATH}"
    sudo -u ${AGENT_USER} env HOME=${AGENT_HOME} security unlock-keychain "${KEYCHAIN_PATH}"
    sudo -u ${AGENT_USER} env HOME=${AGENT_HOME} security set-keychain-settings "${KEYCHAIN_PATH}"
    echo "✅ Keychain created and set as default"
fi

# ============================================================================
# 7. Create shared group for project access
# ============================================================================
echo "--- Step 7: Setting up shared group ---"
if dscl . -read /Groups/${SHARED_GROUP} &>/dev/null; then
    echo "⚠️  Group '${SHARED_GROUP}' already exists, skipping creation."
else
    dscl . -create /Groups/${SHARED_GROUP}
    dscl . -create /Groups/${SHARED_GROUP} PrimaryGroupID ${SHARED_GID}
    dscl . -create /Groups/${SHARED_GROUP} RealName "Claude Shared"
    echo "✅ Created group '${SHARED_GROUP}' (GID ${SHARED_GID})"
fi

# Add both users to shared group (idempotent)
dseditgroup -o edit -a "${USERNAME}" -t user ${SHARED_GROUP} 2>/dev/null || true
dseditgroup -o edit -a ${AGENT_USER} -t user ${SHARED_GROUP} 2>/dev/null || true
echo "✅ Both '${USERNAME}' and '${AGENT_USER}' are in '${SHARED_GROUP}'"

# ============================================================================
# 8. Set up shared workspace
# ============================================================================
echo "--- Step 8: Setting up shared workspace ---"

# /opt/workspace owned by root — traversable but not writable
mkdir -p /opt/workspace
chown root:staff /opt/workspace
chmod 755 /opt/workspace

# CLAUDE_ONLY owned by shared group
mkdir -p ${WORKSPACE}
chown :${SHARED_GROUP} ${WORKSPACE}
chmod 2770 ${WORKSPACE}
chmod -R g+rwX ${WORKSPACE}
echo "✅ Workspace: ${WORKSPACE} (2770, group ${SHARED_GROUP})"

# Symlink from user's home
SYMLINK_PATH="${USER_HOME}/Projects/CLAUDE_ONLY"
if [ -L "${SYMLINK_PATH}" ]; then
    echo "⚠️  Symlink already exists: ${SYMLINK_PATH}"
elif [ -d "${SYMLINK_PATH}" ]; then
    echo "⚠️  ${SYMLINK_PATH} is a real directory, not creating symlink."
    echo "    Move contents to ${WORKSPACE} and replace with symlink manually."
else
    mkdir -p "${USER_HOME}/Projects"
    ln -s ${WORKSPACE} "${SYMLINK_PATH}"
    echo "✅ Symlink: ${SYMLINK_PATH} → ${WORKSPACE}"
fi

# ============================================================================
# 9. Authenticate Claude (interactive — requires browser)
# ============================================================================
echo "--- Step 9: Authenticate Claude ---"
echo ""
echo "  Run this manually after the script completes:"
echo ""
echo "  cd /tmp && sudo -u ${AGENT_USER} env HOME=${AGENT_HOME} sh -c 'ulimit -n 65536 && /opt/homebrew/bin/claude login'"
echo ""

# ============================================================================
# 10. Create hardened settings
# ============================================================================
echo "--- Step 10: Creating hardened settings ---"
mkdir -p ${AGENT_HOME}/.claude

SETTINGS_SRC="${SCRIPT_DIR}/claude_settings.json"

if [ -f "${SETTINGS_SRC}" ]; then
    cp "${SETTINGS_SRC}" "${AGENT_HOME}/.claude/settings.json"
    echo "  ✅ Copied claude_settings.json"
else
    echo "  ⚠️  Not found: ${SETTINGS_SRC}"
    echo "  ⬇️  Downloading from GitHub..."
    if curl -fsSL "${SCRIPTS_REPO}/claude_settings.json" -o "${AGENT_HOME}/.claude/settings.json"; then
        echo "  ✅ Downloaded claude_settings.json"
    else
        echo "  ❌ Failed to download claude_settings.json — create it manually at ${AGENT_HOME}/.claude/settings.json"
    fi
fi

chown -R ${AGENT_USER}:${AGENT_GROUP} ${AGENT_HOME}/.claude
echo "✅ Hardened settings installed"

# ============================================================================
# 11. Configure sudoers (non-interactive)
# ============================================================================
echo "--- Step 11: Configuring sudoers ---"
SUDOERS_LINE="${USERNAME} ALL=(${AGENT_USER}) NOPASSWD: ALL"
SUDOERS_FILE="/etc/sudoers.d/claude_agent"

if [ -f "${SUDOERS_FILE}" ]; then
    echo "⚠️  Sudoers file already exists: ${SUDOERS_FILE}"
else
    echo "${SUDOERS_LINE}" > "${SUDOERS_FILE}"
    chmod 440 "${SUDOERS_FILE}"
    # Validate
    if visudo -cf "${SUDOERS_FILE}" &>/dev/null; then
        echo "✅ Sudoers configured: ${USERNAME} can run commands as ${AGENT_USER} without password"
    else
        echo "❌ Sudoers file is invalid — removing"
        rm -f "${SUDOERS_FILE}"
        exit 1
    fi
fi

# ============================================================================
# 12. Lock down Claude binaries (only claude_agent can execute)
# ============================================================================
echo "--- Step 12: Locking down Claude binaries ---"
CLAUDE_CASK_DIR="/opt/homebrew/Caskroom/claude-code"
CLAUDE_SYMLINK="/opt/homebrew/bin/claude"

if [ -d "${CLAUDE_CASK_DIR}" ]; then
    chown -R ${AGENT_USER}:${AGENT_GROUP} "${CLAUDE_CASK_DIR}"
    chmod -R 750 "${CLAUDE_CASK_DIR}"
    echo "  ✅ Locked: ${CLAUDE_CASK_DIR}"

    if [ -L "${CLAUDE_SYMLINK}" ]; then
        chown -h ${AGENT_USER}:${AGENT_GROUP} "${CLAUDE_SYMLINK}"
        echo "  ✅ Locked: ${CLAUDE_SYMLINK}"
    fi

    echo "✅ Claude binaries only executable by ${AGENT_USER}:${AGENT_GROUP}"
    echo "   (Note: 'brew upgrade' may reset these permissions)"
else
    echo "⚠️  No claude-code cask found at ${CLAUDE_CASK_DIR} — skipping lockdown."
    echo "   You can lock them manually:"
    echo "   sudo chown -R ${AGENT_USER}:${AGENT_GROUP} ${CLAUDE_CASK_DIR}"
    echo "   sudo chmod -R 750 ${CLAUDE_CASK_DIR}"
    echo "   sudo chown -h ${AGENT_USER}:${AGENT_GROUP} ${CLAUDE_SYMLINK}"
fi

# ============================================================================
# 13. Print summary
# ============================================================================
echo ""
echo "============================================"
echo "  Setup Complete"
echo "============================================"
echo ""
echo "  Agent user:      ${AGENT_USER} (UID ${AGENT_UID})"
echo "  Agent group:     ${AGENT_GROUP} (GID ${AGENT_GID})"
echo "  Shared group:    ${SHARED_GROUP} (GID ${SHARED_GID})"
echo "  Workspace:       ${WORKSPACE}"
echo "  Symlink:         ${USER_HOME}/Projects/CLAUDE_ONLY"
echo "  Settings:        ${AGENT_HOME}/.claude/settings.json"
echo "  Scripts:         ${AGENT_HOME}/.scripts/"
echo ""
echo "  Next steps:"
echo ""
echo "  1. Authenticate Claude:"
echo "     cd /tmp && sudo -u ${AGENT_USER} env HOME=${AGENT_HOME} sh -c 'ulimit -n 65536 && /opt/homebrew/bin/claude login'"
echo ""
echo "  2. Add this alias to your ~/.zshrc:"
echo "     alias claude-safe='cd /tmp && sudo -u ${AGENT_USER} env HOME=${AGENT_HOME} sh -c \"ulimit -n 65536 && cd ${WORKSPACE} && /opt/homebrew/bin/claude\"'"
echo ""
echo "  3. Verify isolation:"
echo "     cd /tmp && sudo -u ${AGENT_USER} groups"
echo "     cd /tmp && sudo -u ${AGENT_USER} ls /Users/${USERNAME}"
echo "     cd /tmp && sudo -u ${AGENT_USER} ls ${WORKSPACE}"
echo ""
echo "  Note: Claude binaries are locked to ${AGENT_USER} only."
echo "  If 'brew upgrade' resets permissions, re-run:"
echo "     for bin in \$(brew list claude-code | grep /bin/); do"
echo "       sudo chown ${AGENT_USER}:${AGENT_GROUP} \"\$bin\""
echo "       sudo chmod 700 \"\$bin\""
echo "     done"
echo ""
echo "============================================"
echo "  Cleanup (if needed later):"
echo "============================================"
echo ""
echo "  sudo dscl . -delete /Users/${AGENT_USER}"
echo "  sudo dscl . -delete /Groups/${AGENT_GROUP}"
echo "  sudo dscl . -delete /Groups/${SHARED_GROUP}"
echo "  sudo rm -rf ${AGENT_HOME}"
echo "  sudo rm -f ${SUDOERS_FILE}"
echo "  sudo chgrp -R staff ${WORKSPACE}"
echo "  sudo rm -f ${WORKSPACE}"
echo ""

#!/bin/bash
# setup_claude_project.sh
# Usage: ./setup_claude_project.sh /path/to/project

PROJECT_DIR="${1:-.}"

SETTINGS_DIR="$PROJECT_DIR/.claude"
SETTINGS_FILE="$SETTINGS_DIR/settings.json"
LOCAL_FILE="$SETTINGS_DIR/settings.local.json"

if [ -f "$SETTINGS_FILE" ]; then
    echo "✅ Project settings already exist: $SETTINGS_FILE"
    # Validate JSON
    if python3 -m json.tool "$SETTINGS_FILE" > /dev/null 2>&1; then
        echo "✅ JSON is valid"
    else
        echo "❌ Invalid JSON — settings are silently ignored!"
        exit 1
    fi
    exit 0
fi

echo "⚠️  No project settings found. Creating $SETTINGS_FILE"

mkdir -p "$SETTINGS_DIR"

cat > "$SETTINGS_FILE" << 'EOF'
{
  "permissions": {
    "allow": [
      "Read(./**)",
      "Edit(./**)",
      "Write(./**)"
    ],
    "deny": [
      "Edit(~/**)",
      "Write(~/**)",
      "Read(~/**)",
      "Bash(wget *)",
      "Bash(/usr/bin/wget *)",
      "Bash(/usr/local/bin/wget *)",
      "Bash(rm -rf *)"
    ]
  }
}
EOF

# Create gitignored local settings for personal overrides
if [ ! -f "$LOCAL_FILE" ]; then
    cat > "$LOCAL_FILE" << 'EOF'
{
}
EOF
fi

# Ensure settings.local.json is gitignored
GITIGNORE="$PROJECT_DIR/.gitignore"
if [ -f "$GITIGNORE" ]; then
    if ! grep -q "settings.local.json" "$GITIGNORE"; then
        echo ".claude/settings.local.json" >> "$GITIGNORE"
    fi
else
    echo ".claude/settings.local.json" > "$GITIGNORE"
fi

# Validate what we just wrote
if python3 -m json.tool "$SETTINGS_FILE" > /dev/null 2>&1; then
    echo "✅ Created and validated: $SETTINGS_FILE"
else
    echo "❌ Something went wrong — invalid JSON"
    exit 1
fi

echo "✅ Created local overrides: $LOCAL_FILE"
echo "✅ Added settings.local.json to .gitignore"

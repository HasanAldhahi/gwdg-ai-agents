#!/usr/bin/env bash
set -euo pipefail

# ZeroClaw GWDG setup script

echo "=== ZeroClaw + GWDG Setup ==="

if [ -z "${SAIA_API_KEY:-}" ]; then
  echo "Error: SAIA_API_KEY not set."
  echo "Get your key at: https://docs.hpc.gwdg.de/services/ai-services/saia/index.html"
  echo "Then run: export SAIA_API_KEY='your-key'"
  exit 1
fi

if ! command -v zeroclaw &> /dev/null; then
  echo "Installing ZeroClaw..."
  if command -v brew &> /dev/null; then
    brew install zeroclaw
  else
    curl -fsSL https://raw.githubusercontent.com/zeroclaw-labs/zeroclaw/main/scripts/bootstrap.sh | bash
  fi
else
  echo "ZeroClaw already installed."
fi

CONFIG_DIR="${HOME}/.zeroclaw"
mkdir -p "$CONFIG_DIR"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$CONFIG_DIR/config.toml" ]; then
  echo "Existing config found at $CONFIG_DIR/config.toml"
  echo "Patching GWDG provider settings..."
  # Patch the existing config in-place
  TMPFILE="$(mktemp)"
  sed \
    -e "s|^default_provider = .*|default_provider = \"custom:https://chat-ai.academiccloud.de/v1\"|" \
    -e "s|^default_model = .*|default_model = \"glm-4.7\"|" \
    -e "/^api_key = /d" \
    "$CONFIG_DIR/config.toml" > "$TMPFILE"
  # Insert api_key right after default_provider line
  sed -e "/^default_provider = /a\\
api_key = \"${SAIA_API_KEY}\"" "$TMPFILE" > "$CONFIG_DIR/config.toml"
  rm -f "$TMPFILE"
else
  cp "$SCRIPT_DIR/config.toml" "$CONFIG_DIR/config.toml"
  # Inject the API key
  sed -i '' "/^default_provider = /a\\
api_key = \"${SAIA_API_KEY}\"" "$CONFIG_DIR/config.toml"
fi

echo ""
echo "Done! Config written to ${CONFIG_DIR}/config.toml"
echo "  Provider: custom:https://chat-ai.academiccloud.de/v1"
echo "  Model:    glm-4.7"
echo ""
echo "Run 'zeroclaw agent' to start."

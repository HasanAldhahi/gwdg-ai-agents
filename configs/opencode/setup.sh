#!/usr/bin/env bash
set -euo pipefail

# OpenCode GWDG setup script
# Installs OpenCode and configures it for GWDG CoCo AI

echo "=== OpenCode + GWDG Setup ==="

if [ -z "${SAIA_API_KEY:-}" ]; then
  echo "Error: SAIA_API_KEY not set."
  echo "Get your key at: https://docs.hpc.gwdg.de/services/ai-services/saia/index.html"
  echo "Then run: export SAIA_API_KEY='your-key'"
  exit 1
fi

if ! command -v opencode &> /dev/null; then
  echo "Installing OpenCode..."
  curl -fsSL https://opencode.ai/install | bash
else
  echo "OpenCode already installed: $(opencode --version 2>/dev/null || echo 'unknown version')"
fi

CONFIG_DIR="${HOME}/.config/opencode"
mkdir -p "$CONFIG_DIR"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp "$SCRIPT_DIR/opencode.json" "$CONFIG_DIR/opencode.json"

echo ""
echo "Done! Config written to ${CONFIG_DIR}/opencode.json"
echo "Set your API key: export OPENAI_API_KEY='your-saia-key'"
echo "Run 'opencode' to start."

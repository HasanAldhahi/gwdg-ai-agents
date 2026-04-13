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

CONFIG_DIR="${HOME}/.config/zeroclaw"
mkdir -p "$CONFIG_DIR"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp "$SCRIPT_DIR/config.toml" "$CONFIG_DIR/config.toml"

echo ""
echo "Done! Config written to ${CONFIG_DIR}/config.toml"
echo "Run 'zeroclaw agent' to start."

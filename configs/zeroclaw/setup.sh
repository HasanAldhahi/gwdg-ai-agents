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
  echo "Patching top-level provider/model..."
  python3 -c "
import sys
lines = open(sys.argv[1]).readlines()
patched = False
out = []
for line in lines:
    if not patched and line.startswith('default_provider = '):
        out.append('default_provider = \"custom:https://chat-ai.academiccloud.de/v1\"\n')
        patched = True
    elif not patched and line.startswith('default_model = '):
        out.append('default_model = \"glm-4.7\"\n')
    else:
        out.append(line)
open(sys.argv[1], 'w').writelines(out)
" "$CONFIG_DIR/config.toml"
else
  cp "$SCRIPT_DIR/config.toml" "$CONFIG_DIR/config.toml"
fi

echo ""
echo "Done! Config written to ${CONFIG_DIR}/config.toml"
echo "  Provider: custom:https://chat-ai.academiccloud.de/v1"
echo "  Model:    glm-4.7"
echo ""
echo "ZeroClaw custom: providers use API_KEY env var (not OPENAI_API_KEY)."
echo "Run:"
echo "  export API_KEY=\"\$SAIA_API_KEY\""
echo "  zeroclaw agent"

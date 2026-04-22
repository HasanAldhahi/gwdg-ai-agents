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

if [ -z "${GWDG_MODEL:-}" ]; then
  echo ""
  echo "Choose default model:"
  echo "  1) glm-4.7 (recommended)"
  echo "  2) qwen3-coder-30b-a3b-instruct"
  echo "  3) qwen2.5-coder-32b-instruct"
  echo "  4) codestral-22b"
  echo "  5) custom model id"
  printf "  Choose [1-5] (default 1): "
  read -r zc_choice
  case "${zc_choice:-1}" in
    1) GWDG_MODEL="glm-4.7" ;;
    2) GWDG_MODEL="qwen3-coder-30b-a3b-instruct" ;;
    3) GWDG_MODEL="qwen2.5-coder-32b-instruct" ;;
    4) GWDG_MODEL="codestral-22b" ;;
    5) printf "  Enter model id: "; read -r zc_custom; GWDG_MODEL="${zc_custom:-glm-4.7}" ;;
    *) GWDG_MODEL="glm-4.7" ;;
  esac
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
path, model = sys.argv[1], sys.argv[2]
lines = open(path).readlines()
out = []
set_prov = False
set_model = False
for line in lines:
    if not set_prov and line.startswith('default_provider = '):
        out.append('default_provider = \"custom:https://chat-ai.academiccloud.de/v1\"\n')
        set_prov = True
    elif not set_model and line.startswith('default_model = '):
        out.append(f'default_model = \"{model}\"\n')
        set_model = True
    else:
        out.append(line)
open(path, 'w').writelines(out)
" "$CONFIG_DIR/config.toml" "$GWDG_MODEL"
else
  cp "$SCRIPT_DIR/config.toml" "$CONFIG_DIR/config.toml"
  sed -i.bak "s|^default_model = .*|default_model = \"${GWDG_MODEL}\"|" "$CONFIG_DIR/config.toml"
  rm -f "$CONFIG_DIR/config.toml.bak"
fi

echo ""
echo "Done! Config written to ${CONFIG_DIR}/config.toml"
echo "  Provider: custom:https://chat-ai.academiccloud.de/v1"
echo "  Model:    ${GWDG_MODEL}"
echo ""
echo "ZeroClaw custom: providers use API_KEY env var (not OPENAI_API_KEY)."
echo "Run:"
echo "  export API_KEY=\"\$SAIA_API_KEY\""
echo "  zeroclaw agent"

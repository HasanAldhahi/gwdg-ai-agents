#!/usr/bin/env bash
set -euo pipefail

# Launch Claude Code with GWDG CoCo AI models via litellm proxy
# Save to ~/.local/bin/gwdg-claude and chmod +x
#
# Usage:
#   gwdg-claude                                  # default model
#   gwdg-claude qwen2.5-coder-32b-instruct       # specific model
#   gwdg-claude qwen3-coder-30b-a3b-instruct -p  # pass flags to claude

GWDG_HOST="${GWDG_HOST:-chat-ai.academiccloud.de}"
GWDG_MODEL="${1:-qwen3-coder-30b-a3b-instruct}"
PROXY_PORT="${PROXY_PORT:-8080}"

if [ -z "${SAIA_API_KEY:-}" ]; then
  echo "Error: SAIA_API_KEY not set."
  echo "Get your key at: https://docs.hpc.gwdg.de/services/ai-services/saia/index.html"
  echo "Then run: export SAIA_API_KEY='your-key'"
  exit 1
fi

if ! command -v claude &> /dev/null; then
  echo "Error: Claude Code not installed."
  echo "Install with: npm install -g @anthropic-ai/claude-code"
  echo "  or: curl -fsSL https://claude.ai/install.sh | bash"
  exit 1
fi

if ! command -v litellm &> /dev/null; then
  echo "Error: litellm not installed."
  echo "Install with: pip install 'litellm[proxy]'"
  exit 1
fi

if ! curl -sf "http://127.0.0.1:${PROXY_PORT}/health" > /dev/null 2>&1; then
  echo "Starting litellm proxy (port ${PROXY_PORT})..."
  litellm --model "openai/${GWDG_MODEL}" \
          --api_base "https://${GWDG_HOST}/v1" \
          --api_key "$SAIA_API_KEY" \
          --port "$PROXY_PORT" > /dev/null 2>&1 &
  PROXY_PID=$!
  sleep 3

  if ! kill -0 "$PROXY_PID" 2>/dev/null; then
    echo "Error: litellm proxy failed to start."
    exit 1
  fi
  echo "Proxy started (PID: ${PROXY_PID})."
fi

export ANTHROPIC_BASE_URL="http://127.0.0.1:${PROXY_PORT}"
export ANTHROPIC_AUTH_TOKEN="local"
export ANTHROPIC_API_KEY=""
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1

echo "Launching Claude Code → GWDG model: ${GWDG_MODEL}"
exec claude --model "$GWDG_MODEL" "${@:2}"

#!/usr/bin/env bash
set -euo pipefail

# Agent Zero GWDG setup script

echo "=== Agent Zero + GWDG Setup ==="

if ! command -v docker &> /dev/null; then
  echo "Error: Docker is required. Install it from https://docs.docker.com/get-docker/"
  exit 1
fi

if [ -z "${SAIA_API_KEY:-}" ]; then
  echo "Error: SAIA_API_KEY not set."
  echo "Get your key at: https://docs.hpc.gwdg.de/services/ai-services/saia/index.html"
  echo "Then run: export SAIA_API_KEY='your-key'"
  exit 1
fi

INSTALL_DIR="${AGENT_ZERO_DIR:-$HOME/agent-zero}"
mkdir -p "$INSTALL_DIR/usr"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cp "$SCRIPT_DIR/.env" "$INSTALL_DIR/.env"
# Inject the actual API key
sed -i.bak "s|your-saia-api-key-here|${SAIA_API_KEY}|g" "$INSTALL_DIR/.env"
rm -f "$INSTALL_DIR/.env.bak"

echo ""
echo "Done! .env written to ${INSTALL_DIR}/.env"
echo ""
echo "Start with:"
echo "  docker run -d --name agent-zero --restart unless-stopped \\"
echo "    -p 50001:80 \\"
echo "    -v ${INSTALL_DIR}/.env:/a0/.env \\"
echo "    -v ${INSTALL_DIR}/usr:/a0/usr \\"
echo "    agent0ai/agent-zero:latest"
echo ""
echo "Or use the one-liner installer:"
echo "  curl -fsSL https://bash.agent-zero.ai | bash"
echo ""
echo "Open http://localhost:50001"

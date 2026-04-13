#!/usr/bin/env bash
set -euo pipefail

# Terok GWDG setup script

echo "=== Terok + GWDG Setup ==="

if [ -z "${SAIA_API_KEY:-}" ]; then
  echo "Error: SAIA_API_KEY not set."
  echo "Get your key at: https://docs.hpc.gwdg.de/services/ai-services/saia/index.html"
  echo "Then run: export SAIA_API_KEY='your-key'"
  exit 1
fi

if ! command -v podman &> /dev/null; then
  echo "Warning: Podman not found. Install from https://podman.io/getting-started/installation"
  echo "Docker can be used as an experimental alternative."
fi

if ! command -v terok &> /dev/null; then
  echo "Installing Terok..."
  if command -v pipx &> /dev/null; then
    echo "Downloading latest Terok wheel from GitHub Releases..."
    TEROK_WHL_URL=$(curl -sf "https://api.github.com/repos/terok-ai/terok/releases/latest" \
      | grep "browser_download_url.*\.whl" | head -1 | cut -d '"' -f 4)
    if [ -n "${TEROK_WHL_URL:-}" ]; then
      TMPWHL="$(mktemp -d)/terok.whl"
      curl -fSL "$TEROK_WHL_URL" -o "$TMPWHL"
      pipx install "$TMPWHL"
      rm -f "$TMPWHL"
    else
      echo "Could not find wheel. Installing from source..."
      pipx install "git+https://github.com/terok-ai/terok.git"
    fi
  elif command -v uv &> /dev/null; then
    uv tool install "git+https://github.com/terok-ai/terok.git"
  else
    echo "Error: Neither pipx nor uv found."
    echo "Install pipx first: pip install pipx"
    exit 1
  fi
else
  echo "Terok already installed."
fi

echo ""
echo "Done! Quick start commands:"
echo "  terok                           # Start TUI"
echo "  terok run chat-ai-demo 'Quick repo review' --preset solo"
echo "  terok run chat-ai-demo 'Review auth module' --preset review"
echo "  terok run chat-ai-demo 'Add pagination' --preset team"
echo ""
echo "Headless mode:"
echo "  terok run chat-ai-demo 'Refactor the auth module' --no-follow"

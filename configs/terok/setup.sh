#!/usr/bin/env bash
set -euo pipefail

# Terok + GWDG full setup script
# Handles: install → project creation → credential proxy → auth

echo "=== Terok + GWDG Setup ==="

if [ -z "${SAIA_API_KEY:-}" ]; then
  echo "Error: SAIA_API_KEY not set."
  echo "Get your key at: https://docs.hpc.gwdg.de/services/ai-services/saia/index.html"
  echo "Then run: export SAIA_API_KEY='your-key'"
  exit 1
fi

# ── 1. Check container runtime ──────────────────────────────────────────────
if command -v podman &> /dev/null; then
  echo "✓ Podman found."
elif command -v docker &> /dev/null; then
  echo "! Podman not found, Docker detected (experimental support)."
else
  echo "✗ Neither Podman nor Docker found."
  echo "  Install Podman: https://podman.io/getting-started/installation"
  exit 1
fi

# ── 2. Install Terok ────────────────────────────────────────────────────────
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
  echo "✓ Terok already installed."
fi

# ── 3. Create a GWDG demo project (if none exists) ─────────────────────────
PROJECT_ID="${TEROK_PROJECT:-gwdg-demo}"
PROJECT_DIR="${HOME}/.config/terok/projects/${PROJECT_ID}"

if [ -d "$PROJECT_DIR" ]; then
  echo "✓ Project '${PROJECT_ID}' already exists."
else
  echo ""
  echo "Creating project '${PROJECT_ID}'..."
  mkdir -p "$PROJECT_DIR"

  cat > "$PROJECT_DIR/project.yml" << YAML
project:
  id: "${PROJECT_ID}"
  name: "GWDG AI Demo"
  security_class: "online"

git:
  upstream_url: "https://github.com/gwdg/chat-ai.git"
  default_branch: "main"

image:
  base_image: "ubuntu:24.04"
  user_snippet_inline: |
    RUN apt-get update && apt-get install -y --no-install-recommends \\
          git curl ca-certificates ripgrep jq \\
        && rm -rf /var/lib/apt/lists/*

default_agent: opencode
YAML

  echo "✓ Project config written to $PROJECT_DIR/project.yml"
  echo ""
  echo "Building project (ssh-init + generate + build + gate-sync)..."
  terok project-init "$PROJECT_ID" || {
    echo "! project-init had issues (this is normal on first run without SSH keys)."
    echo "  You can re-run: terok project-init ${PROJECT_ID}"
  }
fi

# ── 4. Start credential proxy ──────────────────────────────────────────────
echo ""
PROXY_STATUS=$(terok credential-proxy status 2>&1 | grep "^Status:" | awk '{print $2}')
if [ "$PROXY_STATUS" = "running" ]; then
  echo "✓ Credential proxy already running."
else
  echo "Starting credential proxy..."
  terok credential-proxy start || {
    echo "! Could not start credential proxy."
    echo "  Try manually: terok credential-proxy start"
  }
fi

# ── 5. Store KISSKI (SAIA) credentials ──────────────────────────────────────
echo ""
echo "Storing your SAIA API key for project '${PROJECT_ID}'..."
printf '%s\n' "$SAIA_API_KEY" | terok auth kisski "$PROJECT_ID" 2>/dev/null || {
  echo "! Auto-store failed. Store manually:"
  echo "  terok auth kisski ${PROJECT_ID}"
}

# ── 6. Summary ──────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║       Terok + GWDG Setup Complete        ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "  Project: ${PROJECT_ID}"
echo ""
echo "  Quick start:"
echo "    terok tui                                         # Interactive TUI"
echo "    terok run ${PROJECT_ID} 'Quick repo review' --preset solo"
echo "    terok run ${PROJECT_ID} 'Review auth module' --preset review"
echo "    terok run ${PROJECT_ID} 'Add pagination' --preset team"
echo ""
echo "  Create your own project:"
echo "    terok project-wizard        # Interactive wizard"
echo "    terok project-init <name>   # Build it"
echo "    terok auth kisski <name>    # Store API key"
echo ""
echo "  Credential proxy:"
echo "    terok credential-proxy status"
echo "    terok credential-proxy start"

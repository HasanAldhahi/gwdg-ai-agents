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
# Newer Terok launches containers with `--userns=keep-id:uid=...,gid=...` which
# requires Podman >= 4.x. Ubuntu 22.04 default repo only ships 3.4.4.
# This helper auto-upgrades via the OpenSUSE Kubic unstable repo on Debian/Ubuntu.
upgrade_podman_via_kubic() {
  if ! command -v apt-get &> /dev/null; then
    echo "  Auto-upgrade only supported on Debian/Ubuntu (apt-get not found)."
    return 1
  fi
  if ! command -v sudo &> /dev/null; then
    echo "  sudo is required for auto-upgrade."
    return 1
  fi
  local ubu
  ubu="$(. /etc/os-release 2>/dev/null && echo "${VERSION_ID:-}")"
  if [ -z "$ubu" ]; then
    echo "  Could not detect OS version."
    return 1
  fi
  local key_url="https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/unstable/xUbuntu_${ubu}/Release.key"
  local src_url="https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/unstable/xUbuntu_${ubu}"
  if ! curl -sfI "$key_url" > /dev/null; then
    echo "  Kubic unstable repo not available for Ubuntu ${ubu}."
    return 1
  fi
  echo "  Adding Kubic unstable repo for Ubuntu ${ubu}..."
  echo "deb ${src_url}/ /" | sudo tee /etc/apt/sources.list.d/devel-kubic-libcontainers-unstable.list > /dev/null
  curl -fsSL "$key_url" | gpg --dearmor \
    | sudo tee /etc/apt/trusted.gpg.d/devel_kubic_libcontainers_unstable.gpg > /dev/null
  sudo apt-get update -qq
  echo "  Installing newer Podman..."
  # First try plain install; if it hits file-conflict with old golang-github-containers-common
  # retry with --force-overwrite, then fix broken deps.
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -o Dpkg::Options::="--force-overwrite" podman \
    || sudo DEBIAN_FRONTEND=noninteractive apt-get -f install -y -o Dpkg::Options::="--force-overwrite"
  podman system migrate 2>/dev/null || true
}

if command -v podman &> /dev/null; then
  echo "✓ Podman found."
else
  echo "✗ Podman not found."
  echo "  Install Podman: https://podman.io/getting-started/installation"
  echo "  Ubuntu/Debian quick install: sudo apt update && sudo apt install -y podman"
  exit 1
fi
PODMAN_VERSION="$(podman --version 2>/dev/null | awk '{print $3}')"
PODMAN_MAJOR="$(printf '%s' "$PODMAN_VERSION" | cut -d. -f1)"
if [ "${PODMAN_MAJOR:-0}" -lt 4 ]; then
  echo "! Podman ${PODMAN_VERSION} is too old for current Terok task runtime."
  echo "  Attempting auto-upgrade via OpenSUSE Kubic unstable repo..."
  if upgrade_podman_via_kubic; then
    PODMAN_VERSION="$(podman --version 2>/dev/null | awk '{print $3}')"
    PODMAN_MAJOR="$(printf '%s' "$PODMAN_VERSION" | cut -d. -f1)"
    echo "  Podman is now ${PODMAN_VERSION}."
  fi
  if [ "${PODMAN_MAJOR:-0}" -lt 4 ]; then
    echo "✗ Could not upgrade Podman automatically."
    echo "  Upgrade Podman to >=4.x manually, then re-run setup."
    echo "  See: https://podman.io/docs/installation"
    exit 1
  fi
fi
echo "✓ Podman ${PODMAN_VERSION} (>=4.x) ready."

# ── 2. Install Terok ────────────────────────────────────────────────────────

# Ensure pipx is installed if needed for the rest of the script.
ensure_pipx_installed() {
  if ! command -v pipx &> /dev/null; then
    echo "pipx not found. Attempting to install pipx..."
    # Try with pip, fallback to system
    if command -v pip &> /dev/null; then
      pip install --user pipx || { echo "Failed to install pipx with user pip."; exit 1; }
      export PATH="$HOME/.local/bin:$PATH"
      hash -r
    elif command -v apt &> /dev/null; then
      sudo apt update && sudo apt install -y pipx || { echo "Failed to install pipx with apt."; exit 1; }
      export PATH="/usr/local/bin:$PATH"
      hash -r
    else
      echo "Error: Could not find a way to install pipx. Please install it manually: https://pypa.github.io/pipx/installation/"
      exit 1
    fi
    if ! command -v pipx &> /dev/null; then
      echo "pipx installation was attempted but could not be found in PATH."
      exit 1
    fi
    echo "✓ pipx installed."
  fi
}

TEROK_CMD="terok"
LOCAL_BIN="${HOME}/.local/bin"
if command -v pipx &> /dev/null; then
  if command -v terok &> /dev/null; then
    echo "Upgrading Terok..."
    if ! pipx upgrade terok; then
      echo "Upgrade failed. Reinstalling Terok from source..."
      pipx uninstall terok || true
      pipx install "git+https://github.com/terok-ai/terok.git"
    fi
  else
    echo "Installing Terok..."
    # First, try installing with pipx (install pipx if missing)
    ensure_pipx_installed
    echo "Downloading latest Terok wheel from GitHub Releases..."
    TEROK_WHL_URL=$(curl -sf "https://api.github.com/repos/terok-ai/terok/releases/latest" \
      | grep "browser_download_url.*\.whl" | head -1 | cut -d '"' -f 4)
    if [ -n "${TEROK_WHL_URL:-}" ]; then
      TMPDIR_WHL="$(mktemp -d)"
      TMPWHL="$TMPDIR_WHL/$(basename "$TEROK_WHL_URL")"
      curl -fSL "$TEROK_WHL_URL" -o "$TMPWHL"
      pipx install "$TMPWHL"
      rm -rf "$TMPDIR_WHL"
    else
      echo "Could not find wheel. Installing from source..."
      pipx install "git+https://github.com/terok-ai/terok.git"
    fi
  fi
elif command -v uv &> /dev/null; then
  if command -v terok &> /dev/null; then
    echo "✓ Terok already installed (uv-managed)."
  else
    uv tool install "git+https://github.com/terok-ai/terok.git"
  fi
else
  echo "Error: Neither pipx nor uv found, and could not install pipx."
  exit 1
fi

# pipx may install into ~/.local/bin, which may not be in PATH yet.
if [[ ":${PATH}:" != *":${LOCAL_BIN}:"* ]]; then
  export PATH="${LOCAL_BIN}:${PATH}"
fi
if command -v terok &> /dev/null; then
  TEROK_CMD="terok"
elif [ -x "${LOCAL_BIN}/terok" ]; then
  TEROK_CMD="${LOCAL_BIN}/terok"
  export PATH="${LOCAL_BIN}:${PATH}"
else
  echo "Error: Terok was installed but command is not available in PATH."
  echo "Try: pipx ensurepath && exec \$SHELL -l"
  exit 1
fi

# Persist ~/.local/bin for future shells if missing.
if [ -f "${HOME}/.bashrc" ] && ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "${HOME}/.bashrc"; then
  printf '\n# pipx apps\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "${HOME}/.bashrc"
  echo "Added ~/.local/bin to ~/.bashrc. Open a new shell to use 'terok' directly."
fi

# ── 3. Create a GWDG demo project (if none exists) ─────────────────────────
PROJECT_ID="${TEROK_PROJECT:-gwdg-demo}"
PROJECT_DIR="${HOME}/.config/terok/projects/${PROJECT_ID}"
TEROK_AGENT_PROVIDER="${TEROK_AGENT_PROVIDER:-kisski}"
if [ -z "${TEROK_AGENT_MODEL:-}" ]; then
  if [ -n "${GWDG_MODEL:-}" ]; then
    TEROK_AGENT_MODEL="$GWDG_MODEL"
  else
    echo ""
    echo "Choose default Terok model (provider: ${TEROK_AGENT_PROVIDER})"
    echo "  1) glm-4.7 (recommended)"
    echo "  2) qwen3-coder-30b-a3b-instruct"
    echo "  3) qwen2.5-coder-32b-instruct"
    echo "  4) custom model id"
    printf "  Choose [1-4] (default 1): "
    read -r model_choice
    case "${model_choice:-1}" in
      1) TEROK_AGENT_MODEL="glm-4.7" ;;
      2) TEROK_AGENT_MODEL="qwen3-coder-30b-a3b-instruct" ;;
      3) TEROK_AGENT_MODEL="qwen2.5-coder-32b-instruct" ;;
      4)
        printf "  Enter model id: "
        read -r custom_model
        TEROK_AGENT_MODEL="${custom_model:-glm-4.7}"
        ;;
      *) TEROK_AGENT_MODEL="glm-4.7" ;;
    esac
  fi
fi

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

agent:
  provider: "${TEROK_AGENT_PROVIDER}"
  model: "${TEROK_AGENT_MODEL}"
YAML

  echo "✓ Project config written to $PROJECT_DIR/project.yml"
  echo ""
  echo "Building project (ssh-init + generate + build + gate-sync)..."
  "$TEROK_CMD" project-init "$PROJECT_ID" || {
    echo "! project-init had issues (this is normal on first run without SSH keys)."
    echo "  You can re-run: terok project-init ${PROJECT_ID}"
  }
fi

# ── 4. Start credential proxy ──────────────────────────────────────────────
echo ""
PROXY_STATUS=$("$TEROK_CMD" credential-proxy status 2>&1 | grep "^Status:" | awk '{print $2}')
if [ "$PROXY_STATUS" = "running" ]; then
  echo "✓ Credential proxy already running."
else
  echo "Starting credential proxy..."
  "$TEROK_CMD" credential-proxy start || {
    echo "! Could not start credential proxy."
    echo "  Try manually: terok credential-proxy start"
  }
fi

# ── 5. Store KISSKI (SAIA) credentials ──────────────────────────────────────
echo ""
echo "Storing your SAIA API key for project '${PROJECT_ID}'..."
printf '%s\n' "$SAIA_API_KEY" | "$TEROK_CMD" auth kisski "$PROJECT_ID" 2>/dev/null || {
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

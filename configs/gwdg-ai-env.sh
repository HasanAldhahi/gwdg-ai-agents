#!/usr/bin/env bash
set -euo pipefail

# GWDG CoCo AI / SAIA — Interactive Environment Setup
# Usage: bash configs/gwdg-ai-env.sh

GWDG_API_BASE="https://chat-ai.academiccloud.de/v1"
DEFAULT_MODEL="qwen3-coder-30b-a3b-instruct"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()  { printf "${CYAN}▸${NC} %s\n" "$*"; }
ok()    { printf "${GREEN}✓${NC} %s\n" "$*"; }
warn()  { printf "${YELLOW}!${NC} %s\n" "$*"; }
err()   { printf "${RED}✗${NC} %s\n" "$*" >&2; }

# ── 1. API Key ──────────────────────────────────────────────────────────────
printf "\n${BOLD}╔══════════════════════════════════════════╗${NC}\n"
printf "${BOLD}║   GWDG CoCo AI — Environment Setup      ║${NC}\n"
printf "${BOLD}╚══════════════════════════════════════════╝${NC}\n\n"

if [ -n "${SAIA_API_KEY:-}" ]; then
  masked="${SAIA_API_KEY:0:6}…${SAIA_API_KEY: -4}"
  info "Detected existing SAIA_API_KEY ($masked)"
  printf "  Use this key? [Y/n]: "
  read -r use_existing
  if [ "$(printf '%s' "$use_existing" | tr '[:upper:]' '[:lower:]')" = "n" ]; then
    unset SAIA_API_KEY
  fi
fi

if [ -z "${SAIA_API_KEY:-}" ]; then
  echo ""
  info "You need a SAIA API key from GWDG."
  info "Get one at: https://docs.hpc.gwdg.de/services/ai-services/saia/index.html"
  echo ""
  printf "  Enter your SAIA API key: "
  read -r SAIA_API_KEY
  if [ -z "$SAIA_API_KEY" ]; then
    err "No API key provided. Exiting."
    exit 1
  fi
fi

# Validate the key with a lightweight API call
info "Validating API key…"
HTTP_CODE=$(curl -sf -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer ${SAIA_API_KEY}" \
  "${GWDG_API_BASE}/models" 2>/dev/null || echo "000")

if [ "$HTTP_CODE" = "200" ]; then
  ok "API key is valid."
elif [ "$HTTP_CODE" = "000" ]; then
  warn "Could not reach ${GWDG_API_BASE} (network issue?). Continuing anyway."
else
  warn "API returned HTTP ${HTTP_CODE}. Double-check your key."
fi

# ── 2. Persist env vars ────────────────────────────────────────────────────
export SAIA_API_KEY
export GWDG_API_BASE
GWDG_MODEL_PREEMPT="${GWDG_MODEL:-}"
export OPENAI_API_KEY="$SAIA_API_KEY"
export OPENAI_BASE_URL="$GWDG_API_BASE"

echo ""
info "Shall I add the API key to your shell profile so it persists across sessions?"
printf "  Add to shell profile? [y/N]: "
read -r persist
if [ "$(printf '%s' "$persist" | tr '[:upper:]' '[:lower:]')" = "y" ]; then
  SHELL_RC="$HOME/.bashrc"
  [ -n "${ZSH_VERSION:-}" ] && SHELL_RC="$HOME/.zshrc"
  [ "$SHELL" = "/bin/zsh" ] && SHELL_RC="$HOME/.zshrc"

  if grep -q "SAIA_API_KEY" "$SHELL_RC" 2>/dev/null; then
    warn "SAIA_API_KEY already in $SHELL_RC — skipping."
  else
    {
      echo ""
      echo "# GWDG CoCo AI / SAIA"
      echo "export SAIA_API_KEY=\"${SAIA_API_KEY}\""
      echo "export OPENAI_API_KEY=\"\$SAIA_API_KEY\""
      echo "export OPENAI_BASE_URL=\"${GWDG_API_BASE}\""
    } >> "$SHELL_RC"
    ok "Added to $SHELL_RC"
  fi
fi

# ── 3. Tool selection ──────────────────────────────────────────────────────
echo ""
printf "${BOLD}Which tool(s) do you want to set up?${NC}\n\n"
echo "  1) OpenCode       — Terminal TUI coding agent"
echo "  2) ZeroClaw       — Lightweight Rust AI agent"
echo "  3) Agent Zero     — Multi-agent framework (Docker)"
echo "  4) Terok          — Container manager for AI agents (Podman)"
echo "  5) Claude Code    — Claude Code with GWDG models (via litellm proxy)"
echo "  6) All of the above"
echo "  0) None — just configure environment variables"
echo ""
printf "  Choose [0-6, comma-separated for multiple]: "
read -r choices

if [ -z "$choices" ]; then
  choices="0"
fi

# Parse comma-separated choices into an array
IFS=',' read -ra SELECTIONS <<< "$choices"
TOOLS=()
for sel in "${SELECTIONS[@]}"; do
  sel="$(echo "$sel" | tr -d ' ')"
  case "$sel" in
    6) TOOLS=(opencode zeroclaw agent-zero terok claude-code); break ;;
    1) TOOLS+=(opencode) ;;
    2) TOOLS+=(zeroclaw) ;;
    3) TOOLS+=(agent-zero) ;;
    4) TOOLS+=(terok) ;;
    5) TOOLS+=(claude-code) ;;
    0) ;;
    *) warn "Unknown option: $sel" ;;
  esac
done

# ── 3b. Global model selection (applied across all tools) ──────────────────
choose_gwdg_model() {
  if [ -n "${GWDG_MODEL_PREEMPT:-}" ]; then
    GWDG_MODEL="$GWDG_MODEL_PREEMPT"
    return
  fi
  echo ""
  printf "${BOLD}Choose default model for all tools:${NC}\n"
  echo "  1) glm-4.7 (recommended)"
  echo "  2) qwen3-coder-30b-a3b-instruct"
  echo "  3) qwen2.5-coder-32b-instruct"
  echo "  4) codestral-22b"
  echo "  5) llama-3.3-70b-instruct"
  echo "  6) deepseek-r1"
  echo "  7) qwen3-235b-a22b"
  echo "  8) mistral-large-instruct"
  echo "  9) custom model id"
  printf "  Choose [1-9] (default 1): "
  read -r gm_choice
  case "${gm_choice:-1}" in
    1) GWDG_MODEL="glm-4.7" ;;
    2) GWDG_MODEL="qwen3-coder-30b-a3b-instruct" ;;
    3) GWDG_MODEL="qwen2.5-coder-32b-instruct" ;;
    4) GWDG_MODEL="codestral-22b" ;;
    5) GWDG_MODEL="llama-3.3-70b-instruct" ;;
    6) GWDG_MODEL="deepseek-r1" ;;
    7) GWDG_MODEL="qwen3-235b-a22b" ;;
    8) GWDG_MODEL="mistral-large-instruct" ;;
    9)
      printf "  Enter model id: "
      read -r gm_custom
      GWDG_MODEL="${gm_custom:-glm-4.7}"
      ;;
    *) GWDG_MODEL="glm-4.7" ;;
  esac
  ok "Selected model: ${GWDG_MODEL}"
}

if [ ${#TOOLS[@]} -gt 0 ]; then
  choose_gwdg_model
else
  GWDG_MODEL="${GWDG_MODEL_PREEMPT:-$DEFAULT_MODEL}"
fi
export GWDG_MODEL

# ── 4. Install / configure selected tools ──────────────────────────────────
setup_opencode() {
  printf "\n${BOLD}── OpenCode ──${NC}\n"

  if ! command -v opencode &> /dev/null; then
    info "Installing OpenCode…"
    if command -v brew &> /dev/null; then
      brew install anomalyco/tap/opencode
    else
      curl -fsSL https://opencode.ai/install | bash
    fi
  else
    ok "OpenCode already installed ($(opencode --version 2>/dev/null || echo '?'))"
  fi

  CONFIG_DIR="${HOME}/.config/opencode"
  mkdir -p "$CONFIG_DIR"
  if [ -f "$SCRIPT_DIR/opencode/config.toml" ]; then
    cp "$SCRIPT_DIR/opencode/config.toml" "$CONFIG_DIR/config.toml"
    if [ -n "${GWDG_MODEL:-}" ]; then
      python3 -c "
import sys, re
path = sys.argv[1]; model = sys.argv[2]
src = open(path).read()
src = re.sub(r'(\[models\.default\][^\[]*?model\s*=\s*\")[^\"]*(\")', r'\1' + model + r'\2', src, count=1, flags=re.S)
open(path, 'w').write(src)
" "$CONFIG_DIR/config.toml" "$GWDG_MODEL"
    fi
    ok "Config written to $CONFIG_DIR/config.toml (model: ${GWDG_MODEL:-default})"
  fi

  echo ""
  ok "Run 'opencode' to start."
}

setup_zeroclaw() {
  printf "\n${BOLD}── ZeroClaw ──${NC}\n"

  if ! command -v zeroclaw &> /dev/null; then
    info "Installing ZeroClaw…"
    if command -v brew &> /dev/null; then
      brew install zeroclaw
    else
      curl -fsSL https://github.com/zeroclaw-labs/zeroclaw/releases/latest/download/install.sh | \
        bash -s -- --prefer-prebuilt --install-system-deps --install-rust
    fi
  else
    ok "ZeroClaw already installed."
  fi

  CONFIG_DIR="${HOME}/.zeroclaw"
  mkdir -p "$CONFIG_DIR"

  ZC_MODEL="${GWDG_MODEL:-glm-4.7}"
  if [ -f "$CONFIG_DIR/config.toml" ]; then
    info "Patching existing config at $CONFIG_DIR/config.toml…"
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
" "$CONFIG_DIR/config.toml" "$ZC_MODEL"
  elif [ -f "$SCRIPT_DIR/zeroclaw/config.toml" ]; then
    cp "$SCRIPT_DIR/zeroclaw/config.toml" "$CONFIG_DIR/config.toml"
    sed -i.bak "s|^default_model = .*|default_model = \"${ZC_MODEL}\"|" "$CONFIG_DIR/config.toml"
    rm -f "$CONFIG_DIR/config.toml.bak"
  fi

  # ZeroClaw custom: providers read API_KEY env var, not OPENAI_API_KEY
  export API_KEY="$SAIA_API_KEY"

  ok "Config: $CONFIG_DIR/config.toml"
  info "ZeroClaw custom: providers use API_KEY env var (already set from your SAIA key)."
  echo ""
  ok "Run 'API_KEY=\$SAIA_API_KEY zeroclaw agent' to start."
}

setup_agent_zero() {
  printf "\n${BOLD}── Agent Zero ──${NC}\n"

  if ! command -v docker &> /dev/null; then
    err "Docker is required. Install from https://docs.docker.com/get-docker/"
    return 1
  fi

  printf "  Install method:\n"
  printf "    a) One-liner installer (recommended)\n"
  printf "    b) Docker run (manual)\n"
  printf "  Choose [a/b]: "
  read -r az_method

  if [ "$(printf '%s' "$az_method" | tr '[:upper:]' '[:lower:]')" = "a" ]; then
    info "Running Agent Zero installer…"
    curl -fsSL https://bash.agent-zero.ai | bash
  else
    INSTALL_DIR="${AGENT_ZERO_DIR:-$HOME/agent-zero}"
    mkdir -p "$INSTALL_DIR/usr"

    if [ -f "$SCRIPT_DIR/agent-zero/.env" ]; then
      cp "$SCRIPT_DIR/agent-zero/.env" "$INSTALL_DIR/.env"
      sed -i.bak "s|CHAT_API_KEY=.*|CHAT_API_KEY=\"${SAIA_API_KEY}\"|" "$INSTALL_DIR/.env"
      sed -i.bak "s|UTILITY_API_KEY=.*|UTILITY_API_KEY=\"${SAIA_API_KEY}\"|" "$INSTALL_DIR/.env"
      sed -i.bak "s|EMBEDDING_API_KEY=.*|EMBEDDING_API_KEY=\"${SAIA_API_KEY}\"|" "$INSTALL_DIR/.env"
      if [ -n "${GWDG_MODEL:-}" ]; then
        sed -i.bak "s|^CHAT_MODEL=.*|CHAT_MODEL=\"${GWDG_MODEL}\"|" "$INSTALL_DIR/.env"
      fi
      rm -f "$INSTALL_DIR/.env.bak"
      ok ".env written to $INSTALL_DIR/.env (CHAT_MODEL=${GWDG_MODEL:-default})"
    fi

    info "Starting Agent Zero container…"
    docker rm -f agent-zero 2>/dev/null || true
    docker run -d --name agent-zero --restart unless-stopped \
      -p 50001:80 \
      -v "$INSTALL_DIR/.env:/a0/.env" \
      -v "$INSTALL_DIR/usr:/a0/usr" \
      agent0ai/agent-zero:latest

    echo ""
    ok "Agent Zero running at http://localhost:50001"
  fi
}

setup_terok() {
  printf "\n${BOLD}── Terok ──${NC}\n"
  TEROK_CMD="terok"
  LOCAL_BIN="${HOME}/.local/bin"
  TEROK_AGENT_PROVIDER="${TEROK_AGENT_PROVIDER:-kisski}"
  TEROK_AGENT_MODEL="${TEROK_AGENT_MODEL:-${GWDG_MODEL:-glm-4.7}}"

  # Newer Terok requires Podman >= 4.x (for `--userns=keep-id:uid=...,gid=...`).
  # Ubuntu 22.04 default repo ships 3.4.4, so auto-upgrade via OpenSUSE Kubic unstable.
  _upgrade_podman_via_kubic() {
    command -v apt-get &> /dev/null || { warn "Auto-upgrade needs apt-get (Debian/Ubuntu)."; return 1; }
    command -v sudo    &> /dev/null || { warn "Auto-upgrade needs sudo."; return 1; }
    local ubu
    ubu="$(. /etc/os-release 2>/dev/null && echo "${VERSION_ID:-}")"
    [ -n "$ubu" ] || { warn "Could not detect OS version."; return 1; }
    local key_url="https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/unstable/xUbuntu_${ubu}/Release.key"
    local src_url="https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/unstable/xUbuntu_${ubu}"
    curl -sfI "$key_url" > /dev/null || { warn "Kubic unstable repo unavailable for Ubuntu ${ubu}."; return 1; }
    info "Adding Kubic unstable repo for Ubuntu ${ubu}…"
    echo "deb ${src_url}/ /" | sudo tee /etc/apt/sources.list.d/devel-kubic-libcontainers-unstable.list > /dev/null
    curl -fsSL "$key_url" | gpg --dearmor \
      | sudo tee /etc/apt/trusted.gpg.d/devel_kubic_libcontainers_unstable.gpg > /dev/null
    sudo apt-get update -qq
    info "Upgrading Podman…"
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -o Dpkg::Options::="--force-overwrite" podman \
      || sudo DEBIAN_FRONTEND=noninteractive apt-get -f install -y -o Dpkg::Options::="--force-overwrite"
    podman system migrate 2>/dev/null || true
  }

  if ! command -v podman &> /dev/null; then
    err "Podman is required for Terok setup."
    info "Install Podman: https://podman.io/getting-started/installation"
    info "Ubuntu/Debian quick install: sudo apt update && sudo apt install -y podman"
    return 1
  fi
  PODMAN_VERSION="$(podman --version 2>/dev/null | awk '{print $3}')"
  PODMAN_MAJOR="$(printf '%s' "$PODMAN_VERSION" | cut -d. -f1)"
  if [ "${PODMAN_MAJOR:-0}" -lt 4 ]; then
    warn "Podman ${PODMAN_VERSION} is too old for current Terok task runtime (needs >=4.x)."
    info "Attempting auto-upgrade via OpenSUSE Kubic unstable…"
    if _upgrade_podman_via_kubic; then
      PODMAN_VERSION="$(podman --version 2>/dev/null | awk '{print $3}')"
      PODMAN_MAJOR="$(printf '%s' "$PODMAN_VERSION" | cut -d. -f1)"
    fi
    if [ "${PODMAN_MAJOR:-0}" -lt 4 ]; then
      err "Could not auto-upgrade Podman. Upgrade to >=4.x manually and re-run."
      info "See: https://podman.io/docs/installation"
      return 1
    fi
  fi
  ok "Podman ${PODMAN_VERSION} (>=4.x) ready."

  if command -v pipx &> /dev/null; then
    if command -v terok &> /dev/null; then
      info "Upgrading Terok…"
      if ! pipx upgrade terok; then
        warn "pipx upgrade failed. Reinstalling Terok from source…"
        pipx uninstall terok || true
        pipx install "git+https://github.com/terok-ai/terok.git"
      fi
    else
      info "Installing Terok…"
      info "Downloading latest Terok wheel from GitHub Releases…"
      TEROK_WHL_URL=$(curl -sf "https://api.github.com/repos/terok-ai/terok/releases/latest" \
        | grep "browser_download_url.*\.whl" | head -1 | cut -d '"' -f 4)
      if [ -n "${TEROK_WHL_URL:-}" ]; then
        TMPDIR_WHL="$(mktemp -d)"
        TMPWHL="$TMPDIR_WHL/$(basename "$TEROK_WHL_URL")"
        curl -fSL "$TEROK_WHL_URL" -o "$TMPWHL"
        pipx install "$TMPWHL"
        rm -rf "$TMPDIR_WHL"
      else
        warn "Could not find wheel. Installing from source…"
        pipx install "git+https://github.com/terok-ai/terok.git"
      fi
    fi
  elif command -v uv &> /dev/null; then
    if command -v terok &> /dev/null; then
      info "Terok already installed (uv-managed)."
    else
      uv tool install "git+https://github.com/terok-ai/terok.git"
    fi
  else
    warn "Neither pipx nor uv found. Install pipx first: pip install pipx"
    return 1
  fi

  # pipx may install into ~/.local/bin, which is not always in PATH until a new shell.
  if [[ ":${PATH}:" != *":${LOCAL_BIN}:"* ]]; then
    export PATH="${LOCAL_BIN}:${PATH}"
  fi
  if command -v terok &> /dev/null; then
    TEROK_CMD="terok"
  elif [ -x "${LOCAL_BIN}/terok" ]; then
    TEROK_CMD="${LOCAL_BIN}/terok"
    export PATH="${LOCAL_BIN}:${PATH}"
  else
    err "Terok was installed but command is not available in PATH."
    info "Try: pipx ensurepath && exec \$SHELL -l"
    return 1
  fi

  # Persist ~/.local/bin for future shells if missing.
  if [ -f "${HOME}/.bashrc" ] && ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "${HOME}/.bashrc"; then
    printf '\n# pipx apps\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "${HOME}/.bashrc"
    info "Added ~/.local/bin to ~/.bashrc. Open a new shell to use 'terok' directly."
  fi

  # Create a GWDG demo project if none exists
  PROJECT_ID="${TEROK_PROJECT:-gwdg-demo}"
  PROJECT_DIR="${HOME}/.config/terok/projects/${PROJECT_ID}"

  if [ ! -d "$PROJECT_DIR" ]; then
    info "Creating project '${PROJECT_ID}'…"
    mkdir -p "$PROJECT_DIR"
    cat > "$PROJECT_DIR/project.yml" << PROJYML
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
PROJYML
    ok "Project config: $PROJECT_DIR/project.yml"

    info "Building project (project-init)…"
    "$TEROK_CMD" project-init "$PROJECT_ID" 2>&1 || warn "project-init had issues — re-run: terok project-init ${PROJECT_ID}"
  else
    ok "Project '${PROJECT_ID}' already exists."
  fi

  # Start credential proxy
  PROXY_STATUS=$("$TEROK_CMD" credential-proxy status 2>&1 | grep "^Status:" | awk '{print $2}')
  if [ "$PROXY_STATUS" != "running" ]; then
    info "Starting credential proxy…"
    "$TEROK_CMD" credential-proxy start 2>&1 || warn "Could not start proxy. Try: terok credential-proxy start"
  else
    ok "Credential proxy running."
  fi

  # Store KISSKI (SAIA) credentials
  info "Storing SAIA API key for project '${PROJECT_ID}'…"
  printf '%s\n' "$SAIA_API_KEY" | "$TEROK_CMD" auth kisski "$PROJECT_ID" 2>/dev/null \
    || warn "Auto-store failed. Run manually: terok auth kisski ${PROJECT_ID}"

  echo ""
  ok "Terok ready! Commands:"
  echo "  terok tui                                                # Interactive TUI"
  echo "  terok run ${PROJECT_ID} 'Quick repo review' --preset solo"
  echo "  terok project-wizard                                     # Create new project"
}

setup_claude_code() {
  printf "\n${BOLD}── Claude Code (with GWDG) ──${NC}\n"

  if ! command -v claude &> /dev/null; then
    info "Installing Claude Code…"
    if command -v npm &> /dev/null; then
      npm install -g @anthropic-ai/claude-code
    else
      curl -fsSL https://claude.ai/install.sh | bash
    fi
  else
    ok "Claude Code already installed."
  fi

  if ! command -v litellm &> /dev/null; then
    info "Installing litellm proxy (bridges OpenAI → Anthropic format)…"
    pip install 'litellm[proxy]'
  else
    ok "litellm already installed."
  fi

  LAUNCH_DIR="${HOME}/.local/bin"
  mkdir -p "$LAUNCH_DIR"
  if [ -f "$SCRIPT_DIR/claude-code/gwdg-claude.sh" ]; then
    cp "$SCRIPT_DIR/claude-code/gwdg-claude.sh" "$LAUNCH_DIR/gwdg-claude"
    chmod +x "$LAUNCH_DIR/gwdg-claude"
    ok "Launcher installed to $LAUNCH_DIR/gwdg-claude"
  fi

  echo ""
  ok "Run 'gwdg-claude' to launch Claude Code with GWDG models."
  info "Make sure $LAUNCH_DIR is in your PATH."
}

for tool in "${TOOLS[@]}"; do
  case "$tool" in
    opencode)    setup_opencode ;;
    zeroclaw)    setup_zeroclaw ;;
    agent-zero)  setup_agent_zero ;;
    terok)       setup_terok ;;
    claude-code) setup_claude_code ;;
  esac
done

# ── 5. Summary ─────────────────────────────────────────────────────────────
printf "\n${BOLD}╔══════════════════════════════════════════╗${NC}\n"
printf "${BOLD}║            Setup Complete                ║${NC}\n"
printf "${BOLD}╚══════════════════════════════════════════╝${NC}\n\n"

echo "  API Base : $GWDG_API_BASE"
echo "  Model    : $GWDG_MODEL"
echo ""
echo "  Available models:"
echo "    qwen3-coder-30b-a3b-instruct, codestral-22b,"
echo "    qwen2.5-coder-32b-instruct, llama-3.3-70b-instruct,"
echo "    deepseek-r1, qwen3-235b-a22b, mistral-large-instruct"
echo ""
echo "  Full list: https://docs.hpc.gwdg.de/services/ai-services/chat-ai/models/index.html"
echo ""

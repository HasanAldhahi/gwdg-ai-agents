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
  if [[ "${use_existing,,}" == "n" ]]; then
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
export GWDG_MODEL="${GWDG_MODEL:-$DEFAULT_MODEL}"
export OPENAI_API_KEY="$SAIA_API_KEY"
export OPENAI_BASE_URL="$GWDG_API_BASE"

echo ""
info "Shall I add the API key to your shell profile so it persists across sessions?"
printf "  Add to shell profile? [y/N]: "
read -r persist
if [[ "${persist,,}" == "y" ]]; then
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
    ok "Config written to $CONFIG_DIR/config.toml"
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
      curl -fsSL https://raw.githubusercontent.com/zeroclaw-labs/zeroclaw/main/scripts/bootstrap.sh | bash
    fi
  else
    ok "ZeroClaw already installed."
  fi

  CONFIG_DIR="${HOME}/.config/zeroclaw"
  mkdir -p "$CONFIG_DIR"
  if [ -f "$SCRIPT_DIR/zeroclaw/config.toml" ]; then
    cp "$SCRIPT_DIR/zeroclaw/config.toml" "$CONFIG_DIR/config.toml"
    ok "Config written to $CONFIG_DIR/config.toml"
  fi

  echo ""
  ok "Run 'zeroclaw agent' to start."
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

  if [[ "${az_method,,}" == "a" ]]; then
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
      rm -f "$INSTALL_DIR/.env.bak"
      ok ".env written to $INSTALL_DIR/.env"
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

  if ! command -v podman &> /dev/null; then
    warn "Podman not found. Install from https://podman.io/getting-started/installation"
    warn "Docker can work as an experimental alternative."
  fi

  if ! command -v terok &> /dev/null; then
    info "Installing Terok…"
    if command -v pipx &> /dev/null; then
      info "Downloading latest Terok wheel from GitHub Releases…"
      TEROK_WHL_URL=$(curl -sf "https://api.github.com/repos/terok-ai/terok/releases/latest" \
        | grep "browser_download_url.*\.whl" | head -1 | cut -d '"' -f 4)
      if [ -n "$TEROK_WHL_URL" ]; then
        TMPWHL="$(mktemp -d)/terok.whl"
        curl -fSL "$TEROK_WHL_URL" -o "$TMPWHL"
        pipx install "$TMPWHL"
        rm -f "$TMPWHL"
      else
        warn "Could not find wheel on GitHub. Trying pip install from source…"
        pipx install "git+https://github.com/terok-ai/terok.git"
      fi
    elif command -v uv &> /dev/null; then
      uv tool install "git+https://github.com/terok-ai/terok.git"
    else
      warn "Neither pipx nor uv found. Install pipx first: pip install pipx"
      warn "Then re-run this setup."
      return 1
    fi
  else
    ok "Terok already installed."
  fi

  echo ""
  ok "Quick start:"
  echo "  terok                           # Start TUI"
  echo "  terok run chat-ai-demo 'Quick repo review' --preset solo"
  echo "  terok run chat-ai-demo 'Review auth module' --preset review"
  echo "  terok run chat-ai-demo 'Add pagination' --preset team"
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

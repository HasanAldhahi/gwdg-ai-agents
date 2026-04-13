# Agent Coding Platforms — GWDG Comprehensive Guide

> **Author:** Hasan Aldahain  
> **Date:** April 2026  
> **Goal:** Document how to use GWDG-hosted LLMs with external coding agent platforms, provide setup guides, config files, and a comparison matrix.

---

## Table of Contents

1. [GWDG AI Infrastructure Overview](#1-gwdg-ai-infrastructure-overview)
2. [Comparison Matrix](#2-comparison-matrix)
3. [OpenCode — Setup & Configuration](#3-opencode)
4. [ZeroClaw — Setup & Configuration](#4-zeroclaw)
5. [Agent Zero — Setup & Configuration](#5-agent-zero)
6. [Terok — Setup & Configuration](#6-terok)
7. [GitHub Spec-Kit — Setup & Configuration](#7-github-spec-kit)
8. [Claude Code with Local/Custom LLM](#8-claude-code-with-custom-llm)
9. [Quick-Start Scripts](#9-quick-start-scripts)
10. [References](#10-references)

---

## 1. GWDG AI Infrastructure Overview

GWDG provides LLM access through the **CoCo AI** service, built on the **SAIA** (Scalable Artificial Intelligence Accelerator) platform.

### API Details

| Property | Value |
|---|---|
| **Base URL** | `https://chat-ai.academiccloud.de/v1` |
| **Protocol** | OpenAI-compatible API |
| **Auth** | SAIA API Key (request via [KISSKI LLM Service](https://docs.hpc.gwdg.de/services/ai-services/saia/index.html)) |
| **Endpoints** | `/chat/completions`, `/completions`, `/embeddings`, `/models` |

### Available Models (as of April 2026)

| Model | Type | Recommended For |
|---|---|---|
| `qwen3-coder-30b-a3b-instruct` | Code | Agentic coding, autocomplete |
| `codestral-22b` | Code | Code completion, editing |
| `qwen2.5-coder-32b-instruct` | Code | Code generation |
| `qwen3-235b-a22b` | General | Complex reasoning |
| `qwen3-30b-a3b-thinking-2507` | Reasoning | Chain-of-thought tasks |
| `deepseek-r1` | Reasoning | Deep analysis |
| `llama-3.3-70b-instruct` | General | Chat, planning |
| `meta-llama-3.1-8b-instruct` | General | Lightweight tasks |
| `mistral-large-instruct` | General | Multilingual tasks |
| `qwq-32b` | Reasoning | Math, logic |

Full list: <https://docs.hpc.gwdg.de/services/ai-services/chat-ai/models/index.html>

### Quick API Test

```bash
curl https://chat-ai.academiccloud.de/v1/chat/completions \
  -H "Authorization: Bearer $SAIA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen3-coder-30b-a3b-instruct",
    "messages": [{"role": "user", "content": "Hello, write a Python hello world"}],
    "temperature": 0.2
  }'
```

---

## 2. Comparison Matrix

| Feature | OpenCode | ZeroClaw | Agent Zero | Terok | Spec-Kit | Claude Code (local LLM) |
|---|---|---|---|---|---|---|
| **Type** | CLI/TUI coding agent | Rust AI agent framework | Multi-agent AI framework | Container manager for agents | Spec-driven dev toolkit | Agentic coding harness |
| **License** | Open Source | Open Source | Open Source (MIT) | Apache 2.0 | Open Source | Proprietary (hackable) |
| **Language** | Go | Rust | Python | Python | Python / Node.js | TypeScript |
| **Interface** | Terminal TUI | CLI / Telegram / Discord / Slack | Web UI + Docker | CLI (`terokctl`) + TUI (`terok`) | CLI (`specify`) | Terminal |
| **OpenAI-compatible API** | Yes (75+ providers) | Yes (22+ providers) | Yes (OpenAI, Anthropic, Ollama, etc.) | Depends on agent inside container | Yes (any LLM provider) | Yes (Anthropic API format) |
| **GWDG CoCo AI compatible** | Yes | Yes | Yes | Yes | Yes | Yes (via proxy/llama.cpp) |
| **Multi-agent** | Dual (Plan + Build) | Single agent w/ rollback | Yes (hierarchical sub-agents) | Yes (solo/review/team presets) | No (workflow tool) | Single agent |
| **Container isolation** | No | No | Yes (Docker sandbox) | Yes (Podman containers) | No | No |
| **MCP support** | Yes | Yes | Yes | N/A | N/A | Yes |
| **Memory/persistence** | Git-backed sessions | SQLite + vector search | FAISS vector + auto-consolidation | Per-container state | Spec files on disk | Session-based |
| **File editing** | Yes | Yes | Yes | Yes (via agent inside) | Generates code from specs | Yes |
| **Browser automation** | No | Yes | Yes (SearXNG) | Yes (Toad TUI) | No | No |
| **Security features** | Standard | Gateway + OTP + workspace scoping | Docker isolation | Egress firewall (`terok-shield`) | N/A | Local-only option |
| **Best for** | Daily coding tasks | Lightweight reliable agents | Complex autonomous workflows | Running agents securely at scale | Structured spec-to-code | Privacy-focused coding |
| **Setup complexity** | Low | Medium | Medium-High | Medium | Low | Medium |
| **Min hardware** | Any terminal | <5MB RAM | Docker + decent CPU/RAM | Podman + Python 3.12 | Python 3.10+ or Node | GPU recommended for local LLM |

### When to Use What

- **OpenCode**: Best starting point for developers wanting a terminal coding assistant with GWDG models. Simple setup, powerful TUI.
- **ZeroClaw**: When you need a lightweight, reliable agent that can run on minimal hardware with built-in state management.
- **Agent Zero**: When you need autonomous multi-agent workflows with Docker isolation—ideal for complex tasks involving web browsing, code execution, and tool use.
- **Terok**: When GWDG wants to provide containerized agent environments to users at scale with security controls.
- **Spec-Kit**: When starting new projects using spec-driven development; pairs with any of the above for implementation.
- **Claude Code + Local LLM**: When privacy is paramount and you want the Claude Code harness with GWDG or local models.

---

## 3. OpenCode

### What It Is

OpenCode is a provider-agnostic AI coding agent that runs as a terminal TUI. It features a dual-agent architecture (Plan + Build) with git-backed session review.

### Installation

```bash
# macOS / Linux
curl -fsSL https://opencode.ai/install | bash

# Or via Go
go install github.com/opencode-ai/opencode@latest
```

### GWDG Configuration

Create or edit `~/.config/opencode/config.toml`:

```toml
[providers.gwdg]
api_key_env = "SAIA_API_KEY"
base_url = "https://chat-ai.academiccloud.de/v1"

[models.default]
provider = "gwdg"
model = "qwen3-coder-30b-a3b-instruct"
```

Set the API key in your shell profile (`~/.bashrc` or `~/.zshrc`):

```bash
export SAIA_API_KEY="your-saia-api-key-here"
```

Alternative — environment variables only (no config file):

```bash
export OPENAI_API_KEY="$SAIA_API_KEY"
export OPENAI_BASE_URL="https://chat-ai.academiccloud.de/v1"
opencode
```

### Usage

```bash
# Start interactive TUI
opencode

# Run a one-shot prompt
opencode run "Explain how closures work in JavaScript"

# Use a specific model
opencode --model qwen2.5-coder-32b-instruct
```

### Key Commands Inside TUI

| Key | Action |
|---|---|
| `/plan` | Switch to Plan agent (read-only analysis) |
| `/build` | Switch to Build agent (makes changes) |
| `/model` | Change model |
| `@file` | Reference a file |
| `/session` | Manage sessions |

---

## 4. ZeroClaw

### What It Is

ZeroClaw is a Rust-based AI agent framework. Single binary (~3.4MB), <10ms cold start, SQLite-backed memory with hybrid keyword/vector retrieval. Supports 22+ AI providers.

### Installation

```bash
# macOS
brew install zeroclaw-labs/tap/zeroclaw

# Linux / other
curl -fsSL https://zeroclaws.io/install.sh | bash

# Requires Rust 1.75+ for building from source
```

### GWDG Configuration

Run the onboarding wizard, then edit the config:

```bash
zeroclaw onboard
```

Edit `~/.config/zeroclaw/config.toml`:

```toml
[provider]
name = "openai-compatible"
api_key_env = "SAIA_API_KEY"
base_url = "https://chat-ai.academiccloud.de/v1"
model = "qwen3-coder-30b-a3b-instruct"
```

Set the API key:

```bash
export SAIA_API_KEY="your-saia-api-key-here"
```

### Usage

```bash
# Interactive chat mode
zeroclaw agent

# Autonomous daemon mode
zeroclaw daemon

# Gateway server
zeroclaw gateway
```

### Key Features for GWDG

- **Snapshot-based memory**: Records agent state on every action; can rollback to last known-good state.
- **Minimal resources**: Can run on very low-end hardware.
- **Multi-channel**: Deploy on CLI, Telegram, Discord, Slack.

---

## 5. Agent Zero

### What It Is

Agent Zero is an open-source multi-agent AI framework. Agents run in isolated Docker containers with a full Linux environment. Features persistent FAISS vector memory, web browsing, and a web UI.

### Installation

```bash
git clone https://github.com/agent0ai/agent-zero.git
cd agent-zero

# Using Docker (recommended)
mkdir -p usr
docker run -d --name agent-zero --restart unless-stopped \
  -p 50001:80 \
  -v "$PWD/.env:/a0/.env" \
  -v "$PWD/usr:/a0/usr" \
  -v "/path/to/spec-kit:/a0/usr/work/spec-kit" \
  agent0ai/agent-zero:latest

# Or manual setup
pip install -r requirements.txt
python main.py
```

Replace `/path/to/spec-kit` with your local [spec-kit](https://github.com/github/spec-kit) clone, or drop that `-v` line if you do not need it.

### GWDG Configuration

Edit the `.env` file or `settings.json` in the Agent Zero directory:

```env
# .env configuration for GWDG
CHAT_API_BASE=https://chat-ai.academiccloud.de/v1
CHAT_API_KEY=your-saia-api-key-here
CHAT_MODEL=qwen3-coder-30b-a3b-instruct

UTILITY_API_BASE=https://chat-ai.academiccloud.de/v1
UTILITY_API_KEY=your-saia-api-key-here
UTILITY_MODEL=meta-llama-3.1-8b-instruct

EMBEDDING_API_BASE=https://chat-ai.academiccloud.de/v1
EMBEDDING_API_KEY=your-saia-api-key-here
EMBEDDING_MODEL=qwen2.5-coder-32b-instruct
```

Alternatively, configure through the web UI at `http://localhost:50001` after starting the container.

### Usage

1. Open the web UI at `http://localhost:50001`
2. Select model provider → set to "OpenAI Compatible"
3. Enter the GWDG base URL and API key
4. Start a conversation — agents will spawn sub-agents as needed

### Key Features for GWDG

- **Docker isolation**: Safe code execution in sandboxed containers — good for untrusted workloads.
- **Multi-agent hierarchy**: Spawns specialized sub-agents for complex tasks.
- **Persistent memory**: Learns from past interactions via FAISS vector store.
- **Web browsing**: Built-in SearXNG for private web search.

---

## 6. Terok

### What It Is

Terok manages Podman containers for AI coding agent projects. It provides security features (egress firewalling), multi-agent presets, and headless execution.

### Installation

```bash
# Requires: Podman, Python 3.12+, OpenSSH client

pip install terok

# Or from source
git clone https://github.com/terok-ai/terok.git
cd terok
pip install -e .
```

### GWDG Configuration

Terok manages containers that run agents inside them. Configure the agent's LLM provider within Terok's project config:

```yaml
# terok project config
provider:
  type: openai-compatible
  base_url: https://chat-ai.academiccloud.de/v1
  api_key_env: SAIA_API_KEY
  model: qwen3-coder-30b-a3b-instruct
```

Set the API key:

```bash
export SAIA_API_KEY="your-saia-api-key-here"
```

### Usage

```bash
# Start TUI
terok

# CLI interface
terokctl start --preset solo

# Available presets
terokctl start --preset solo    # Single agent
terokctl start --preset review  # Agent with code review
terokctl start --preset team    # Multi-agent team

# Headless / autopilot mode
terokctl run --prompt "Refactor the auth module" --headless
```

### Security Modes

| Mode | Description |
|---|---|
| `online` | Full internet access |
| `gatekeeping` | Domain-based allowlists via `terok-shield` |
| `offline` | No external network access |

### Key Features for GWDG

- **Container isolation via Podman**: Ideal for providing secure agent environments to university users.
- **Egress firewalling**: Control what agents can access on the network.
- **Presets**: Quick setup for single or multi-agent workflows.
- **Scalable**: Can be deployed as a service for multiple users.

---

## 7. GitHub Spec-Kit

### What It Is

Spec-Kit is a toolkit for Spec-Driven Development. Instead of prompting an LLM directly, you write specifications that get refined and then implemented. Works with any AI agent (OpenCode, Claude Code, Copilot, etc.).

### Installation

```bash
# Persistent install
uv tool install spec-kit

# One-time usage
uvx spec-kit --help

# Node.js alternative
npx @github/spec-kit --help
```

### GWDG Integration

Spec-Kit generates specs, then hands off to an agent for implementation. Configure the underlying agent to use GWDG models.

Example workflow with OpenCode + GWDG:

```bash
# Step 1: Generate a spec from a description
specify create "A REST API for managing lab equipment inventory"

# Step 2: Review and refine the generated spec
specify plan --stack python-fastapi

# Step 3: Break into tasks
specify tasks

# Step 4: Implement using OpenCode with GWDG models
opencode run "Implement the tasks in .spec/tasks/"
```

### Development Phases

| Phase | Command | Description |
|---|---|---|
| Specify | `specify create` | Generate structured specs from English descriptions |
| Plan | `specify plan` | Create technical plans with stack/architecture constraints |
| Tasks | `specify tasks` | Break into small, reviewable work chunks |
| Implement | Use any agent | Generate production-ready code from specs |

### Key Features for GWDG

- **Model-agnostic**: Works with any LLM backend, including GWDG's CoCo AI.
- **Structured approach**: Better than ad-hoc prompting for complex projects.
- **Reproducible**: Specs are version-controlled artifacts.

---

## 8. Claude Code with Custom LLM

### What It Is

Claude Code is Anthropic's agentic coding harness. It speaks the Anthropic Messages API but doesn't verify the model on the other end — any compatible server works. This lets you use GWDG models or local models.

### Prerequisites

```bash
# Install Claude Code
npm install -g @anthropic-ai/claude-code
```

### GWDG Setup Script

> Based on the approach from the [XDA article](https://www.xda-developers.com/wrote-script-run-claude-code-local-llm-skipping-cloud/)

Since GWDG's SAIA API is OpenAI-compatible (not Anthropic-compatible), you need a translation proxy like `litellm` to bridge the formats:

```bash
# Install litellm
pip install litellm

# Start proxy translating Anthropic format → OpenAI format → GWDG
litellm --model openai/qwen3-coder-30b-a3b-instruct \
        --api_base https://chat-ai.academiccloud.de/v1 \
        --api_key $SAIA_API_KEY \
        --port 8080
```

Then launch Claude Code pointing at the proxy:

```bash
export ANTHROPIC_BASE_URL="http://127.0.0.1:8080"
export ANTHROPIC_AUTH_TOKEN="local"
export ANTHROPIC_API_KEY=""
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1

claude --model "qwen3-coder-30b-a3b-instruct"
```

### Simplified Launch Script (`gwdg-claude`)

Save as `~/.local/bin/gwdg-claude` and `chmod +x`:

```bash
#!/usr/bin/env bash
set -euo pipefail

GWDG_HOST="${GWDG_HOST:-chat-ai.academiccloud.de}"
GWDG_MODEL="${1:-qwen3-coder-30b-a3b-instruct}"
PROXY_PORT="${PROXY_PORT:-8080}"

if [ -z "${SAIA_API_KEY:-}" ]; then
  echo "Error: SAIA_API_KEY not set. Get one at:"
  echo "  https://docs.hpc.gwdg.de/services/ai-services/saia/index.html"
  exit 1
fi

# Check if litellm proxy is already running
if ! curl -sf "http://127.0.0.1:${PROXY_PORT}/health" > /dev/null 2>&1; then
  echo "Starting litellm proxy on port ${PROXY_PORT}..."
  litellm --model "openai/${GWDG_MODEL}" \
          --api_base "https://${GWDG_HOST}/v1" \
          --api_key "$SAIA_API_KEY" \
          --port "$PROXY_PORT" &
  sleep 3
fi

export ANTHROPIC_BASE_URL="http://127.0.0.1:${PROXY_PORT}"
export ANTHROPIC_AUTH_TOKEN="local"
export ANTHROPIC_API_KEY=""
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1

echo "Launching Claude Code with GWDG model: ${GWDG_MODEL}"
exec claude --model "$GWDG_MODEL" "${@:2}"
```

---

## 9. Quick-Start Scripts

### Universal GWDG Environment Setup

Save as `gwdg-ai-env.sh` and source it before using any tool:

```bash
#!/usr/bin/env bash
# Source this file: source gwdg-ai-env.sh

# GWDG CoCo AI / SAIA Configuration
export SAIA_API_KEY="${SAIA_API_KEY:?Set your SAIA API key}"
export GWDG_API_BASE="https://chat-ai.academiccloud.de/v1"
export GWDG_MODEL="${GWDG_MODEL:-qwen3-coder-30b-a3b-instruct}"

# OpenAI-compatible env vars (used by OpenCode, ZeroClaw, etc.)
export OPENAI_API_KEY="$SAIA_API_KEY"
export OPENAI_BASE_URL="$GWDG_API_BASE"

echo "GWDG AI environment configured."
echo "  Base URL: $GWDG_API_BASE"
echo "  Model:    $GWDG_MODEL"
```

### One-Liner Quick Starts

```bash
# OpenCode with GWDG
OPENAI_API_KEY=$SAIA_API_KEY OPENAI_BASE_URL=https://chat-ai.academiccloud.de/v1 opencode

# ZeroClaw with GWDG
SAIA_API_KEY=$SAIA_API_KEY zeroclaw agent

# Agent Zero with GWDG (Docker)
docker run -d --name agent-zero --restart unless-stopped -p 50001:80 \
  -v "$PWD/.env:/a0/.env" -v "$PWD/usr:/a0/usr" \
  -v "/path/to/spec-kit:/a0/usr/work/spec-kit" \
  agent0ai/agent-zero:latest

# Terok solo agent
SAIA_API_KEY=$SAIA_API_KEY terokctl start --preset solo
```

---

## 10. References

| Resource | URL |
|---|---|
| GWDG CoCo AI Docs | <https://docs.hpc.gwdg.de/services/ai-services/coco/index.html> |
| GWDG SAIA API | <https://docs.hpc.gwdg.de/services/ai-services/saia/index.html> |
| GWDG Chat AI Models | <https://docs.hpc.gwdg.de/services/ai-services/chat-ai/models/index.html> |
| OpenCode | <https://opencode.ai/> |
| ZeroClaw | <https://zeroclaws.io/> |
| Agent Zero | <https://www.agent-zero.ai/> / <https://github.com/agent0ai/agent-zero> |
| Terok | <https://github.com/terok-ai/terok> |
| GitHub Spec-Kit | <https://github.com/github/spec-kit> / <https://github.github.com/spec-kit/> |
| XDA: Claude Code + Local LLM | <https://www.xda-developers.com/wrote-script-run-claude-code-local-llm-skipping-cloud/> |
| GWDG OpenCode Examples | <https://gitlab-ce.gwdg.de/gwdg/gwdg-service-usage-examples/-/tree/main/ai-services/coco-ai/opencode> |
| LiteLLM (proxy) | <https://github.com/BerriAI/litellm> |

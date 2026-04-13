# GWDG AI Coding Agents — Setup & Guide

Ready-to-use configurations for running open-source AI coding agents with [GWDG CoCo AI](https://docs.hpc.gwdg.de/services/ai-services/coco/index.html) (SAIA) infrastructure.

## Supported Tools

| Tool | Type | Setup |
|---|---|---|
| [OpenCode](https://opencode.ai/) | Terminal TUI coding agent | `configs/opencode/` |
| [ZeroClaw](https://zeroclaws.io/) | Lightweight Rust AI agent | `configs/zeroclaw/` |
| [Agent Zero](https://www.agent-zero.ai/) | Multi-agent framework (Docker) | `configs/agent-zero/` |
| [Terok](https://github.com/terok-ai/terok) | Container manager for AI agents | `configs/terok/` |
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | Claude Code + GWDG via litellm proxy | `configs/claude-code/` |

## Quick Start

### Prerequisites

1. A **SAIA API key** from GWDG — [request one here](https://docs.hpc.gwdg.de/services/ai-services/saia/index.html)
2. A terminal (macOS / Linux / WSL)

### Interactive Setup

The main script lets you choose which tool to install and configures everything:

```bash
git clone https://github.com/HasanAldhahi/gwdg-ai-agents.git
cd gwdg-ai-agents
bash configs/gwdg-ai-env.sh
```

It will:
1. Prompt for your SAIA API key and validate it
2. Optionally save the key to your shell profile
3. Let you pick which tool(s) to install and configure

### Manual Setup (per tool)

Set your API key first:

```bash
export SAIA_API_KEY="your-key-here"
```

Then run the setup script for the tool you want:

```bash
bash configs/opencode/setup.sh      # OpenCode
bash configs/zeroclaw/setup.sh      # ZeroClaw
bash configs/agent-zero/setup.sh    # Agent Zero
bash configs/terok/setup.sh         # Terok
```

For Claude Code with GWDG models, copy the launcher script:

```bash
cp configs/claude-code/gwdg-claude.sh ~/.local/bin/gwdg-claude
chmod +x ~/.local/bin/gwdg-claude
gwdg-claude
```

## GWDG API Details

| Property | Value |
|---|---|
| **Base URL** | `https://chat-ai.academiccloud.de/v1` |
| **Protocol** | OpenAI-compatible API |
| **Auth** | SAIA API Key (Bearer token) |

### Available Models

| Model | Best For |
|---|---|
| `qwen3-coder-30b-a3b-instruct` | Agentic coding (default) |
| `codestral-22b` | Code completion |
| `qwen2.5-coder-32b-instruct` | Code generation |
| `deepseek-r1` | Deep analysis / reasoning |
| `llama-3.3-70b-instruct` | Chat, planning |
| `qwen3-235b-a22b` | Complex reasoning |

[Full model list](https://docs.hpc.gwdg.de/services/ai-services/chat-ai/models/index.html)

## Documentation

See [`agent-coding-platforms-gwdg.md`](agent-coding-platforms-gwdg.md) for the comprehensive guide with comparison matrix, detailed setup instructions, and architecture notes.

## Repository Structure

```
├── README.md                        # This file
├── agent-coding-platforms-gwdg.md   # Comprehensive guide
└── configs/
    ├── gwdg-ai-env.sh              # Interactive setup (start here)
    ├── opencode/
    │   ├── config.toml              # OpenCode config for GWDG
    │   └── setup.sh                 # OpenCode installer
    ├── zeroclaw/
    │   ├── config.toml              # ZeroClaw config for GWDG
    │   └── setup.sh                 # ZeroClaw installer
    ├── agent-zero/
    │   ├── .env                     # Agent Zero env template
    │   └── setup.sh                 # Agent Zero installer
    ├── terok/
    │   └── setup.sh                 # Terok installer
    └── claude-code/
        └── gwdg-claude.sh           # Claude Code + GWDG launcher
```

## License

MIT

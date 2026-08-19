# OpenCode Dotfiles

Portable, versioned OpenCode setup so Linux and Windows machines stay **identical**.

One git repo is the single source of truth for configs, skills, and plugin wiring.
A small renderer + per-OS setup script materialize it into each machine's OpenCode
discovery directories, substituting OS-appropriate absolute paths.

## What's inside

```
opencode-dotfiles/
├── config/                     # → ~/.config/opencode/  (Linux & Windows: same logical dir)
│   ├── opencode.json.template  # MCP servers, providers, agents, plugins (paths tokenized, keys {env:})
│   ├── AGENTS.md               # context-mode routing rules
│   ├── oh-my-opencode-slim.json# agent/model routing preset
│   ├── tui.json                # plugin enablement
│   ├── package.json            # plugin deps (opencode-ai, caveman, oh-my-openagent, openrtk)
│   └── skills/                 # 69 skills (incl. vendored superpowers)
├── agents-skills/              # → ~/.agents/skills/   (75 skills)
├── claude-skills/              # → ~/.claude/skills/   (11 skills)
├── scripts/
│   └── render-config.mjs       # tokenize opencode.json.template → opencode.json (cross-platform)
├── secrets.env.example         # → copy to secrets.env (git-ignored), fill API keys
├── setup-linux.sh              # bash: prereqs, link assets, render, clone+build open-design, secrets
├── setup-windows.ps1           # PowerShell: same steps for native Windows
└── .gitignore                  # ignores secrets.env, node_modules, dist, open-design/
```

## How path parity works

- The OpenCode config directory is the **same logical path** on both OSes:
  Linux `~/.config/opencode/`, Windows `%USERPROFILE%\.config\opencode\`.
- `opencode.json.template` stores **no absolute paths and no secrets**:
  - `{{OPEN_DESIGN_DIR}}`, `{{AGENTS_SKILLS}}`, `{{HEADROOM_BIN}}` are path tokens.
  - All API keys are `{env:VAR}` placeholders resolved by OpenCode at runtime.
- `scripts/render-config.mjs` substitutes the tokens with the current OS's real
  paths and writes the final `opencode.json` into the config dir.
- Skills are linked (Linux: symlinks; Windows: junctions) into the fixed
  discovery dirs, so the repo stays the only place you edit skills.

## Setup

### Linux / macOS

```bash
cd ~/Koding/opencode-dotfiles
./setup-linux.sh            # prereqs + link assets + render + clone/build open-design + secrets
./setup-linux.sh --prereqs  # only install/verify prerequisites
```

### Windows (native)

Open PowerShell:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
cd C:\path\to\opencode-dotfiles
.\setup-windows.ps1
```

> OpenCode officially recommends WSL on Windows. This repo targets **native
> Windows** (matching how you already installed it); the config dir and skills
> discovery resolve to the same logical locations either way.

### Secrets (both OS)

```bash
cp secrets.env.example secrets.env   # edit, fill real keys
source secrets.env                   # Linux/macOS: add to ~/.bashrc
```

On Windows, set the same variables as User environment variables, or run
opencode with them in scope. OpenCode resolves `{env:VAR}` from these.

## Machine-specific notes (must be replicated per machine)

These are NOT covered by the repo — they are per-host services/binaries:

| Item | Purpose | Where it comes from |
|------|---------|---------------------|
| **9router local proxy** | `provider.9router.baseURL` = `http://127.0.0.1:20128/v1` — the default model router (DeepSeek V4 Flash etc.). It runs **on the machine**, not in config. Windows needs this proxy running on port 20128 or the default agent/model won't connect. | Your local 9router install |
| **codegraph** | MCP server `codegraph serve --mcp` | see https://codegraph.dev — install on Windows |
| **headroom** | MCP server (disabled by default) | `~/.local/bin/headroom`; `{{HEADROOM_BIN}}` |
| **open-design daemon** | MCP server `node .../apps/daemon/dist/cli.js mcp` | cloned + built by setup; daemon must be reachable at `http://127.0.0.1:34215` |

## Editing

- **Skills**: edit files under `config/skills/`, `agents-skills/`, `claude-skills/` and commit. Re-run setup to link new ones.
- **Config**: edit `config/opencode.json.template`, re-run setup to re-render. Keep it free of secrets and absolute paths.

## Security

- `secrets.env` is git-ignored — never commit real API keys.
- `opencode.json.template` contains `{env:VAR}` only. If you add a provider with a key, use `{env:YOUR_KEY}`.
- Before pushing this repo anywhere public, run: `grep -rE 'sk-[A-Za-z0-9]' . --exclude-dir=open-design`

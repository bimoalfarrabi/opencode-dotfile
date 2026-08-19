# OpenCode Dotfiles

> ⚠️ **Personal dotfiles.** Repo ini adalah konfigurasi **pribadi** milik
> `bimoalfarrabi`, bukan template umum/opini publik. Isinya mencerminkan
> preferensi, provider API, model routing, dan skill spesifik yang hanya masuk
> akal bagi pemiliknya. Jangan dipakai apa adanya — fork, buang yang tak relevan,
> dan isi `secrets.env` dengan key kamu sendiri. Detail lengkap ada di
> [Inventory](#inventory).

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

## Inventory

Apa yang sebenarnya dikonfigurasi repo ini.

### Plugins (dimuat via `config/opencode.json.template.plugin` + `config/tui.json`)

| Plugin | Peran |
|--------|-------|
| **superpowers** (`git+…obra/superpowers.git`) | Workflow agentik: brainstorming, TDD, systematic-debugging, subagent-driven development, dll. Skills-nya di-vendor ke `config/skills/` (daftar lengkap di bawah). |
| **context-mode** | Kontrol context window + MCP tools `ctx_*`; aturan routing wajib ada di `AGENTS.md`. |
| **oh-my-opencode-slim** | Framework routing agent/model (preset `opencode-go`): orchestrator, oracle, explorer, librarian, designer, fixer, observer, council — masing-masing di-map ke model/provider tertentu lewat `oh-my-opencode-slim.json`. |

Plugin npm di-install otomatis oleh OpenCode saat startup (via Bun), di-cache ke
`~/.cache/opencode/node_modules/`.

### MCP servers (`config/opencode.json.template.mcp`)

| MCP | Tipe | Status | Fungsi |
|-----|------|--------|--------|
| **open-design** | local | aktif | Daemon Open Design (`apps/daemon/dist/cli.js`); menyajikan artifact/project design. Butuh daemon reachable di `http://127.0.0.1:34215`. |
| **needmcp** | remote | aktif | Toko komponen/desain UI (`https://needmcp.com/mcp`), pakai key `{env:NEEDMCP_API_KEY}`. |
| **codegraph** | local | aktif | Grafik pengetahuan kode (`codegraph serve --mcp`) — query simbol/arsitektur. |
| **headroom** | local | nonaktif | Dimatikan; path binary via `{{HEADROOM_BIN}}`. |

### Providers model (`config/opencode.json.template.provider`)

Semua OpenAI-compatible. Sekelompoknya adalah router/aggregator (banyak model lewat satu baseURL):

| Provider | baseURL | Key | Catatan |
|----------|---------|-----|---------|
| **openagentic** | `openagentic.id/api/v1` | `{env:OPENAGENTIC_API_KEY}` | ~30 model Claude/GPT/Gemini/GLM/Qwen/Kimi/MiniMax/dll |
| **9router** | `http://127.0.0.1:20128/v1` | `{env:NINEROUTER_API_KEY}` | **Proxy lokal** — model default DeepSeek V4 Flash dll. Harus jalan di mesin. |
| **commandcode** | `api.commandcode.ai/provider/v1` | — | DeepSeek, Kimi, GLM, MiniMax, MiMo, Qwen, Tencent |
| **srbyte** | `router.srbyte.dev/v1` | `{env:SRBYTE_API_KEY}` | Claude, DeepSeek, GLM, Qwen + QD/qmodel+ |
| **moyra-server-3** | `api.moyra.my.id/v1` | `{env:MOYRA_API_KEY}` | GPT 5.6, Grok, Claude Opus |
| **yogathedev** | `ai.yogathedev.com/v1` | `{env:YOGATHEDEV_API_KEY}` | GPT 5.6 Terra/Sol/Luna, Claude |
| **agentrouter** | `agentrouter.org/v1` | — | Claude Opus 4.8 |
| **zyloo** | `api.zyloo.io/v1` | — | Claude Sonnet 4.6 |
| **evomap** | `api.evomap.ai/v1` | — | DeepSeek V4 Flash, Claude Opus |
| **atomesus** | `api.atomesus.com/v1` | — | Cipher |
| **openmodel** | `api.openmodel.ai/v1` | — | DeepSeek V4 Flash |
| **databyte** | `ai.databyte.co.id/v1` | — | Databyte M1, DeepSeek V4 Flash |

### Skills

Skill dikelompokkan per direktori sumber (OpenCode auto-discover dari fixed dirs
tersebut; `skills.paths` menambahkan open-design & agents).

#### `config/skills/` — 69 skill (inti + superpowers yang di-vendor)

Kategori kerja:
- **Proses/metodologi**: brainstorming, systematic-debugging, test-driven-development,
  spec-driven-development, source-driven-development, writing-plans, executing-plans,
  subagent-driven-development, dispatching-parallel-agents, doubt-driven-development,
  incremental-implementation, code-simplification, reflect, grill-with-docs
- **Kualitas & review**: code-review-and-quality, requesting-code-review,
  receiving-code-review, verification-before-completion, verification-planning,
  thermo-nuclear-code-quality-review
- **Frontend/UI**: frontend-design, frontend-ui-engineering, design-taste-frontend,
  hallmark, emil-design-eng, make-interfaces-feel-better, review-animations,
  improve-animations, motion-design, ui-ux-pro-max, apple-design
- **Backend/stack**: laravel-specialist, vue-best-practices, svelte-code-writer,
  android-clean-architecture, vercel-react-best-practices
- **Infra/ops**: ci-cd-and-automation, git-workflow-and-versioning,
  performance-optimization, observability-and-instrumentation, shipping-and-launch,
  seo-audit, security-and-hardening, owasp-security, deprecation-and-migration,
  worktrees, using-git-worktrees
- **Riset & arsitektur**: feature-research, code-research, context7-mcp, codemap,
  clonedeps, api-and-interface-design, documentation-and-adrs, find-skills,
  using-agent-skills, using-superpowers
- **Ideasi**: idea-refine, interview-me
- **Lainnya**: customize-opencode, context-engineering, animation-vocabulary,
  browser-testing-with-devtools, oh-my-opencode-slim, writing-skills,
  improve-animations, planning-and-task-breakdown

#### `agents-skills/` — 75 skill (subset terluas, dari `~/.agents/skills`)

Semua di atas **plus** daftar tambahan berikut (yang tak ada di `config/skills/`):
- **Antislop family**: antislop, antislop-code, antislop-copywriting, antislop-human,
  antislop-layoutmobile, antislop-ui
- **Desain visual**: brandkit, gpt-taste, high-end-visual-design, industrial-brutalist-ui,
  minimalist-ui, stitch-design-taste, redesign-existing-projects, image-to-code,
  imagegen-frontend-web, imagegen-frontend-mobile, impeccable, frontend-design (v1: design-taste-frontend-v1)
- **Riset/arsitektur**: explore, feature-research, code-research
- **Keamanan**: ci-security-scanning-with-strix, managed-pentesting-with-strix,
  penetration-testing-with-strix, fix-security-vulnerabilities-with-strix
- **Kualitas output**: full-output-enforcement

#### `claude-skills/` — 11 skill (kompatibel Claude)

antislop (6), codebase-memory, code-research, explore, feature-research, graphify

> Karena `agents-skills/` dan `config/skills/` saling tumpang tindih (source sama,
> nama sama), OpenCode hanya memuat sekali per nama. Repo menyimpan keduanya untuk
> mempertahankan parity persis dengan mesin Linux asli.

### Agents

- `explore` dan `general` → **disabled** (digantikan oleh routing oh-my-opencode-slim).
- `explorer` → subagent khusus codebase exploration, model `9router/kenari/deepseek-v4-flash`.

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

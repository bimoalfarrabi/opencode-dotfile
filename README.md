# OpenCode Dotfiles

> ⚠️ **Dotfiles pribadi.** Repo ini adalah konfigurasi **pribadi** milik
> `bimoalfarrabi`, bukan template umum/opini publik. Isinya mencerminkan
> preferensi, provider API, routing model, dan skill spesifik yang hanya masuk
> akal bagi pemiliknya. Jangan dipakai apa adanya — fork dulu, buang yang tidak
> relevan, dan isi `secrets.env` dengan key milikmu sendiri. Detail lengkap ada
> di [Inventaris](#inventaris).

Setup OpenCode yang portabel dan ber-versi, agar mesin Linux dan Windows tetap
**identik**.

Satu repo git menjadi satu-satunya sumber kebenaran (single source of truth)
untuk konfigurasi, skill, dan wiring plugin. Renderer kecil + script setup per-OS
menyalin semuanya ke direktori discovery OpenCode masing-masing mesin, dengan
mengganti path absolut sesuai sistem operasi.

## Isi repo

```
opencode-dotfiles/
├── config/                     # → ~/.config/opencode/  (Linux & Windows: lokasi logis sama)
│   ├── opencode.json.template  # MCP, providers, agents, plugins (path di-token, key pakai {env:})
│   ├── AGENTS.md               # aturan routing context-mode
│   ├── oh-my-opencode-slim.json# preset routing agent/model
│   ├── tui.json                # pengaktifan plugin
│   ├── package.json            # dependensi plugin (opencode-ai, caveman, oh-my-openagent, openrtk)
│   └── skills/                 # 69 skill (termasuk superpowers yang di-vendor)
├── agents-skills/              # → ~/.agents/skills/   (75 skill)
├── claude-skills/              # → ~/.claude/skills/   (11 skill)
├── scripts/
│   └── render-config.mjs       # ubah opencode.json.template → opencode.json (lintas-platform)
├── secrets.env.example         # → salin ke secrets.env (git-ignored), isi API key
├── setup-linux.sh              # bash: prereqs, tautkan asset, render, clone+build open-design, secrets
├── setup-windows.ps1           # PowerShell: langkah sama untuk Windows native
└── .gitignore                  # abaikan secrets.env, node_modules, dist, open-design/
```

## Cara kerja parity path

- Direktori konfigurasi OpenCode adalah **path logis yang sama** di kedua OS:
  Linux `~/.config/opencode/`, Windows `%USERPROFILE%\.config\opencode\`.
- `opencode.json.template` menyimpan **tanpa path absolut dan tanpa secret**:
  - `{{OPEN_DESIGN_DIR}}`, `{{AGENTS_SKILLS}}`, `{{HEADROOM_BIN}}` adalah token path.
  - Semua API key berupa placeholder `{env:VAR}` yang di-resolve OpenCode saat runtime.
- `scripts/render-config.mjs` mengganti token dengan path asli sesuai OS saat ini
  lalu menulis `opencode.json` final ke direktori config.
- Skill ditautkan (Linux: symlink; Windows: junction) ke direktori discovery yang
  tetap, sehingga repo tetap menjadi satu-satunya tempat mengedit skill.

## Inventaris

Apa yang sebenarnya dikonfigurasi oleh repo ini.

### Plugin (dimuat via `config/opencode.json.template.plugin` + `config/tui.json`)

| Plugin | Peran |
|--------|-------|
| **superpowers** (`git+…obra/superpowers.git`) | Workflow agentik: brainstorming, TDD, systematic-debugging, subagent-driven development, dll. Skill-nya di-vendor ke `config/skills/` (daftar lengkap di bawah). |
| **context-mode** | Kontrol context window + tool MCP `ctx_*`; aturan routing wajib ada di `AGENTS.md`. |
| **oh-my-opencode-slim** | Framework routing agent/model (preset `opencode-go`): orchestrator, oracle, explorer, librarian, designer, fixer, observer, council — masing-masing dipetakan ke model/provider tertentu lewat `oh-my-opencode-slim.json`. |

Plugin npm di-install otomatis oleh OpenCode saat startup (via Bun) dan di-cache
ke `~/.cache/opencode/node_modules/`.

### MCP servers (`config/opencode.json.template.mcp`)

| MCP | Tipe | Status | Fungsi |
|-----|------|--------|--------|
| **open-design** | local | aktif | Daemon Open Design (`apps/daemon/dist/cli.js`); menyajikan artifact/project design. Butuh daemon dapat dijangkau di `http://127.0.0.1:34215`. |
| **needmcp** | remote | aktif | Toko komponen/desain UI (`https://needmcp.com/mcp`), memakai key `{env:NEEDMCP_API_KEY}`. |
| **codegraph** | local | aktif | Grafik pengetahuan kode (`codegraph serve --mcp`) — query simbol/arsitektur. |
| **headroom** | local | nonaktif | Dimatikan; path binary via `{{HEADROOM_BIN}}`. |

### Providers model (`config/opencode.json.template.provider`)

Semua OpenAI-compatible. Sebagian besar adalah router/aggregator (banyak model lewat satu baseURL):

| Provider | baseURL | Key | Catatan |
|----------|---------|-----|---------|
| **openagentic** | `openagentic.id/api/v1` | `{env:OPENAGENTIC_API_KEY}` | ±30 model Claude/GPT/Gemini/GLM/Qwen/Kimi/MiniMax/dll |
| **9router** | `http://127.0.0.1:20128/v1` | `{env:NINEROUTER_API_KEY}` | **Proxy lokal** — model default DeepSeek V4 Flash dll. Harus berjalan di mesin. |
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

Semua di atas **plus** daftar tambahan berikut (yang tidak ada di `config/skills/`):
- **Keluarga antislop**: antislop, antislop-code, antislop-copywriting, antislop-human,
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

> Karena `agents-skills/` dan `config/skills/` saling tumpang tindih (sumber sama,
> nama sama), OpenCode hanya memuat sekali per nama. Repo menyimpan keduanya untuk
> mempertahankan parity persis dengan mesin Linux asli.

### Agents

- `explore` dan `general` → **dinonaktifkan** (digantikan oleh routing oh-my-opencode-slim).
- `explorer` → subagent khusus eksplorasi codebase, model `9router/kenari/deepseek-v4-flash`.

## Setup

### Linux / macOS

```bash
cd ~/Koding/opencode-dotfiles
./setup-linux.sh            # prereqs + tautkan asset + render + clone/build open-design + secrets
./setup-linux.sh --prereqs  # hanya install/verifikasi prasyarat
```

### Windows (native)

Buka PowerShell:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
cd C:\path\to\opencode-dotfiles
.\setup-windows.ps1
```

> OpenCode secara resmi menyarankan WSL di Windows. Repo ini menargetkan **Windows
> native** (sesuai cara kamu menginstalnya); direktori config dan discovery skill
> tetap ter-resolve ke lokasi logis yang sama.

### Secrets (kedua OS)

```bash
cp secrets.env.example secrets.env   # edit, isi key asli
source secrets.env                   # Linux/macOS: tambahkan ke ~/.bashrc
```

Di Windows, set variabel yang sama sebagai User environment variables, atau
jalankan opencode dengan variabel tersebut dalam lingkupnya. OpenCode meresolve
`{env:VAR}` dari variabel-variabel ini.

## Catatan khusus per mesin (harus direplikasi di tiap mesin)

Yang berikut ini **tidak tercakup** oleh repo — ia layanan/binary per-host:

| Item | Tujuan | Sumber |
|------|--------|--------|
| **Proxy lokal 9router** | `provider.9router.baseURL` = `http://127.0.0.1:20128/v1` — router model default (DeepSeek V4 Flash dll). Berjalan **di mesin**, bukan di config. Windows perlu proxy ini berjalan di port 20128, jika tidak agent/model default tidak akan tersambung. | Instalasi 9router lokal |
| **codegraph** | MCP server `codegraph serve --mcp` | lihat https://codegraph.dev — install di Windows |
| **headroom** | MCP server (nonaktif secara default) | `~/.local/bin/headroom`; `{{HEADROOM_BIN}}` |
| **daemon open-design** | MCP server `node .../apps/daemon/dist/cli.js mcp` | di-clone + di-build oleh setup; daemon harus dapat dijangkau di `http://127.0.0.1:34215` |

## Mengedit

- **Skills**: edit file di bawah `config/skills/`, `agents-skills/`, `claude-skills/` lalu commit. Jalankan ulang setup untuk menautkan yang baru.
- **Config**: edit `config/opencode.json.template`, jalankan ulang setup untuk render ulang. Pastikan bebas secret dan path absolut.

## Keamanan

- `secrets.env` di-git-ignore — jangan pernah commit API key asli.
- `opencode.json.template` hanya berisi `{env:VAR}`. Jika menambah provider dengan key, gunakan `{env:YOUR_KEY}`.
- Sebelum push repo ini ke mana pun yang publik, jalankan: `grep -rE 'sk-[A-Za-z0-9]' . --exclude-dir=open-design`

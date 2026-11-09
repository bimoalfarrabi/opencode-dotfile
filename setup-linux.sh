#!/usr/bin/env bash
# ===========================================================================
# OpenCode dotfiles — Linux/macOS setup
#
# Installs prerequisites, links skills + config into the OpenCode discovery
# dirs, renders opencode.json from the template, and builds the open-design
# daemon. Idempotent — safe to re-run.
#
# Usage:
#   ./setup-linux.sh                # link skills/config + render (no secrets)
#   ./setup-linux.sh --secrets      # also prompt/create secrets.env from example
#   ./setup-linux.sh --prereqs      # only install prerequisites
# ===========================================================================
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="${HOME:-$HOME}"

# --- discovery dirs (same as OpenCode uses) ---------------------------------
CONFIG_DIR="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}"
AGENTS_DIR="$HOME/.agents/skills"
CLAUDE_DIR="$HOME/.claude/skills"

log()  { printf '\033[1;32m[setup]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[setup]\033[0m %s\n' "$*"; }

usage() { sed -n 's/^# \{0,1\}//p' "${BASH_SOURCE[0]}" | sed -n '2,14p'; }

MODE="all"
for arg in "$@"; do
  case "$arg" in
    --secrets) MODE="secrets";;
    --prereqs) MODE="prereqs";;
    --help|-h) usage; exit 0;;
    *) warn "unknown flag: $arg";;
  esac
done

# --- prerequisites ----------------------------------------------------------
ensure_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    warn "missing: $1"
    return 1
  fi
  return 0
}

prereqs() {
  log "Checking prerequisites..."
  local ok=1
  ensure_cmd opencode  || { warn "  install opencode: curl -fsSL https://opencode.ai/install | bash"; ok=0; }
  ensure_cmd bun       || { warn "  install bun:     curl -fsSL https://bun.sh/install | bash"; ok=0; }
  ensure_cmd node      || { warn "  install node:    https://nodejs.org"; ok=0; }
  ensure_cmd pnpm      || { warn "  install pnpm:    npm i -g pnpm"; ok=0; }
  ensure_cmd codegraph || { warn "  install codegraph: see https://codegraph.dev (MCP server)"; ok=0; }
  ensure_cmd git       || { warn "  install git"; ok=0; }
  ensure_cmd curl      || { warn "  install curl (obscura release download)"; ok=0; }
  [ "$ok" -eq 1 ] && log "All prerequisites present." || warn "Install missing items above, then re-run."
}

# --- link skills + config into discovery dirs -------------------------------
# Symlink so the repo stays the single source of truth (updates propagate).
link_dir() { # $1=src $2=dst  (rsync-style: ensure dst contains src's contents)
  local src="$1" dst="$2"
  mkdir -p "$dst"
  for entry in "$src"/*; do
    [ -e "$entry" ] || continue
    local name; name="$(basename "$entry")"
    if [ -L "$dst/$name" ] || [ -e "$dst/$name" ]; then
      [ "$(readlink -f "$dst/$name")" = "$(readlink -f "$entry")" ] && continue
      warn "exists, skipping: $dst/$name (already present, not ours)"
      continue
    fi
    ln -s "$entry" "$dst/$name"
  done
}

link_assets() {
  log "Linking skills into discovery dirs..."
  link_dir "$REPO/config/skills" "$CONFIG_DIR/skills"
  link_dir "$REPO/agents-skills" "$AGENTS_DIR"
  link_dir "$REPO/claude-skills" "$CLAUDE_DIR"

  log "Linking config files..."
  mkdir -p "$CONFIG_DIR"
  for f in AGENTS.md oh-my-opencode-slim.json tui.json package.json; do
    if [ ! -e "$CONFIG_DIR/$f" ]; then
      cp "$REPO/config/$f" "$CONFIG_DIR/$f"
      log "  copied $f"
    fi
  done

  log "Installing themes (tui)..."
  if [ -d "$REPO/config/themes" ]; then
    mkdir -p "$CONFIG_DIR/themes"
    for t in "$REPO/config/themes"/*.json; do
      [ -e "$t" ] || continue
      cp "$t" "$CONFIG_DIR/themes/$(basename "$t")"
      log "  copied themes/$(basename "$t")"
    done
  fi
}

# --- render opencode.json ---------------------------------------------------
render() {
  log "Rendering opencode.json..."
  OPENCODE_CONFIG_DIR="$CONFIG_DIR" node "$REPO/scripts/render-config.mjs"
  log "Rendered: $CONFIG_DIR/opencode.json"
}

# --- secrets -----------------------------------------------------------------
secrets() {
  if [ ! -f "$REPO/secrets.env" ]; then
    cp "$REPO/secrets.env.example" "$REPO/secrets.env"
    warn "Created $REPO/secrets.env — edit it and fill in your API keys."
    warn "Then re-run: $0"
    return 1
  fi

  # opencode serve / the background service does not inherit your shell env, so
  # {env:VAR} placeholders only resolve for keys registered in service config.
  # Push every non-empty key from secrets.env into `opencode service set env`.
  if command -v opencode >/dev/null 2>&1; then
    local key value registered=0
    while IFS='=' read -r key value; do
      case "$key" in ''|\#*) continue;; esac
      [ -n "$value" ] || continue
      opencode service set env "$key" "$value" >/dev/null 2>&1 \
        && registered=$((registered + 1)) \
        || warn "  could not register $key in service config"
    done < <(grep -E '^[A-Z_][A-Z0-9_]*=' "$REPO/secrets.env")
    log "Registered $registered key(s) in opencode service env (service.json, mode 600)."
  else
    warn "opencode not on PATH — skipping service env registration."
  fi

  log "secrets.env present. Also usable by sourcing it, or adding to your shell profile:"
  log "  echo 'source $REPO/secrets.env' >> ~/.bashrc"
}

# --- obscura (MCP browser engine) -------------------------------------------
# Obscura is a headless-browser replacement the `obscura` MCP server drives
# (navigate/snapshot/click/screenshot/pdf over CDP). Prebuilt release tarballs
# need no build toolchain, so this stays idempotent and cheap: only the two
# binaries are fetched, and only when they are missing. See docs/obscura.md.
OBSCURA_VERSION="${OBSCURA_VERSION:-0.2.6}"
OBSCURA_BIN_DIR="$HOME/.local/bin"

obscura_install() {
  if command -v obscura >/dev/null 2>&1; then
    log "obscura already installed: $(command -v obscura) ($(obscura --version 2>/dev/null || echo '?'))"
    return 0
  fi

  local arch
  case "$(uname -m)" in
    x86_64|amd64) arch="x86_64" ;;
    aarch64|arm64) arch="aarch64" ;;
    *) warn "obscura: unsupported arch $(uname -m) — skip (build from source: https://github.com/h4ckf0r0day/obscura)"; return 0 ;;
  esac

  # -stealth build: anti-fingerprinting + tracker blocking, still render-capable.
  local asset="obscura-${arch}-linux-stealth.tar.gz"
  local url="https://github.com/h4ckf0r0day/obscura/releases/download/v${OBSCURA_VERSION}/${asset}"
  local tmp
  tmp="$(mktemp -d)"

  log "Downloading obscura v${OBSCURA_VERSION} (${arch}, stealth)..."
  if ! curl -fsSL "$url" -o "$tmp/$asset"; then
    warn "obscura: download failed ($url) — MCP server will not start"
    rm -rf "$tmp"
    return 0
  fi

  tar -xzf "$tmp/$asset" -C "$tmp"
  mkdir -p "$OBSCURA_BIN_DIR"
  # Release archives carry `obscura` + `obscura-worker`; keep them side by side
  # so the parallel `scrape` machinery still finds its helper.
  install -m 0755 "$tmp/obscura" "$OBSCURA_BIN_DIR/obscura"
  if [ -f "$tmp/obscura-worker" ]; then
    install -m 0755 "$tmp/obscura-worker" "$OBSCURA_BIN_DIR/obscura-worker"
  fi
  rm -rf "$tmp"
  log "obscura installed: $OBSCURA_BIN_DIR/obscura"

  case ":$PATH:" in
    *":$OBSCURA_BIN_DIR:"*) ;;
    *) warn "  $OBSCURA_BIN_DIR is not on PATH — add it, or set OBSCURA_BIN=$OBSCURA_BIN_DIR/obscura before rendering" ;;
  esac
}

# --- open-design clone + daemon --------------------------------------------
open_design() {
  if [ ! -d "$REPO/open-design/apps/daemon" ]; then
    log "Cloning open-design (shallow)..."
    git clone --depth 1 https://github.com/nexu-io/open-design.git "$REPO/open-design"
  fi
  if [ ! -f "$REPO/open-design/apps/daemon/dist/cli.js" ]; then
    log "Building open-design daemon..."
    (cd "$REPO/open-design" && pnpm install && pnpm --filter @open-design/daemon run build)
  else
    log "open-design daemon already built."
  fi
}

# --- run ---------------------------------------------------------------------
case "$MODE" in
  prereqs) prereqs;;
  secrets) secrets;;
  all)
    prereqs || true
    link_assets
    obscura_install
    render
    open_design
    secrets || true
    log "Done. Verify: opencode (then /agents, /mcp to confirm)."
    ;;
esac

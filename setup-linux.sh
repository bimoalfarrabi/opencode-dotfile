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
  log "secrets.env present. Source it before running opencode, or add to your shell profile:"
  log "  echo 'source $REPO/secrets.env' >> ~/.bashrc"
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
    render
    open_design
    secrets || true
    log "Done. Verify: opencode (then /agents, /mcp to confirm)."
    ;;
esac

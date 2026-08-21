#!/usr/bin/env bash
# ===========================================================================
# setup-zsh.sh — pasang kustomisasi zsh (WSL Ubuntu) dari repo
#
# Yang dilakukan (idempotent):
#   1. Salin shell/zsh/.zshrc -> ~/.config/zsh/.zshrc + symlink ~/.zshrc
#   2. Clone plugin zsh-users (completions, syntax-highlighting,
#      autosuggestions, history-substring-search) bila belum ada
#   3. Opsional: --p10k untuk clone powerlevel10k (tidak di-source oleh
#      .zshrc saat ini — hanya disediakan untuk eksperimen)
#
# Catatan: .zshrc memuat beberapa path khusus mesin (/home/viasco, $HOME/.bun,
# $HOME/.local/share/lerd/bin, nvm). Sesuaikan bila username/path beda.
#
# Usage:
#   ./setup-zsh.sh            # instal .zshrc + plugin
#   ./setup-zsh.sh --p10k     # + clone powerlevel10k
# ===========================================================================
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ZSHDIR="${HOME}/.config/zsh"

log()  { printf '\033[1;32m[zsh]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[zsh]\033[0m %s\n' "$*"; }

WITH_P10K=0
for arg in "$@"; do
  case "$arg" in
    --p10k) WITH_P10K=1;;
    --help|-h) sed -n 's/^# \{0,1\}//p' "${BASH_SOURCE[0]}" | sed -n '2,14p'; exit 0;;
    *) warn "unknown flag: $arg";;
  esac
done

# --- 1. .zshrc --------------------------------------------------------------
log "Memasang .zshrc ..."
mkdir -p "$ZSHDIR"
cp "$REPO/shell/zsh/.zshrc" "$ZSHDIR/.zshrc"
if [ -e "$HOME/.zshrc" ] && [ ! -L "$HOME/.zshrc" ]; then
  cp "$HOME/.zshrc" "$HOME/.zshrc.bak-zshsetup" && warn "backup ~/.zshrc lama -> ~/.zshrc.bak-zshsetup"
fi
ln -sf "$ZSHDIR/.zshrc" "$HOME/.zshrc"
log "  ~/.zshrc -> $ZSHDIR/.zshrc"

# --- 2. plugin zsh-users ------------------------------------------------------
clone() { # $1=dir $2=url
  if [ -d "$ZSHDIR/$1" ]; then
    log "  plugin $1 sudah ada."
  else
    log "  cloning $1 ..."
    git clone --depth 1 "$2" "$ZSHDIR/$1"
  fi
}

log "Memasang plugin zsh-users ..."
clone "completions"              "https://github.com/zsh-users/zsh-completions.git"
clone "syntax-highlighting"      "https://github.com/zsh-users/zsh-syntax-highlighting.git"
clone "autosuggestions"          "https://github.com/zsh-users/zsh-autosuggestions.git"
clone "history-substring-search" "https://github.com/zsh-users/zsh-history-substring-search.git"

if [ "$WITH_P10K" -eq 1 ]; then
  clone "p10k" "https://github.com/romkatv/powerlevel10k.git"
fi

log "Selesai. Buka zsh baru (atau: source ~/.zshrc)."
warn "Jika username bukan /home/viasco, sesuaikan path di $ZSHDIR/.zshrc (bagian PATH, bun, lerd, nvm)."

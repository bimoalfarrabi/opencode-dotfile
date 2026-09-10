#!/usr/bin/env bash
# ===========================================================================
# setup-zsh.sh — pasang kustomisasi zsh (WSL Ubuntu) dari repo
#
# Yang dilakukan (idempotent):
#   1. Salin shell/zsh/.zshrc -> ~/.config/zsh/.zshrc + symlink ~/.zshrc
#   2. Clone plugin zsh-users (completions, syntax-highlighting,
#      autosuggestions, history-substring-search) bila belum ada
#   3. Install fzf (junegunn/fzf -> ~/.fzf) + fzf-tab (Aloxaf/fzf-tab) untuk
#      fuzzy filesystem completion ala CachyOS (Tab mendeteksi file/dir baru)
#   4. Opsional: --p10k untuk clone powerlevel10k (tidak di-source oleh
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

# --- 3. fzf + fzf-tab (fuzzy filesystem completion ala CachyOS) ---
log "Memasang fzf + fzf-tab ..."

# fzf-tab: plugin zsh — Tab = fuzzy picker atas file/direktori nyata di filesystem
# (termasuk yang belum pernah dibuka). Wajib dimuat setelah compinit, sebelum
# autosuggestions/syntax-highlighting (sudah diatur urutannya di .zshrc).
clone "fzf-tab" "https://github.com/Aloxaf/fzf-tab.git"

# fzf: binary + shell integration (junegunn/fzf, prebuilt, versi terbaru seperti
# CachyOS). .zshrc men-sourckan $HOME/.fzf/shell/* dan menaruh ~/.fzf/bin di PATH.
if [ -x "$HOME/.fzf/bin/fzf" ]; then
  log "  fzf sudah terpasang ($("$HOME/.fzf/bin/fzf" --version | cut -d' ' -f1))."
else
  if [ ! -d "$HOME/.fzf" ]; then
    log "  cloning junegunn/fzf ..."
    git clone --depth 1 "https://github.com/junegunn/fzf.git" "$HOME/.fzf"
  fi
  log "  membangun binary fzf (prebuilt) ..."
  if ! "$HOME/.fzf/install" --bin; then
    warn "  '~/.fzf/install --bin' gagal. Install fzf manual (mis. 'sudo apt install fzf') lalu jalankan ulang."
  fi
fi

if [ "$WITH_P10K" -eq 1 ]; then
  clone "p10k" "https://github.com/romkatv/powerlevel10k.git"
fi

# --- 4. browser handler WSL (Lerd GUI "Open web project" -> Brave Windows) ---
# WSL tanpa DE: xdg-open tidak punya handler, jadi klik Open di Lerd GUI tidak
# terjadi apa-apa. Pasang wrapper + BROWSER (interaktif & portal flatpak).
log "Memasang browser handler (WSL -> Brave Windows) ..."
mkdir -p "$HOME/.local/bin"
cp "$REPO/shell/bin/lerd-browser" "$HOME/.local/bin/lerd-browser"
chmod +x "$HOME/.local/bin/lerd-browser"
log "  ~/.local/bin/lerd-browser (handler \$BROWSER)"

mkdir -p "$HOME/.local/share/applications" "$HOME/.config"
sed "s|__HOME__|$HOME|g" "$REPO/shell/applications/lerd-browser.desktop" > "$HOME/.local/share/applications/lerd-browser.desktop"
cp "$REPO/shell/mimeapps.list" "$HOME/.config/mimeapps.list"
log "  ~/.local/share/applications/lerd-browser.desktop (http/https handler)"
log "  ~/.config/mimeapps.list (default http/https handler)"

mkdir -p "$HOME/.config/environment.d"
cp "$REPO/shell/environment.d/99-lerd-browser.conf" "$HOME/.config/environment.d/99-lerd-browser.conf"
log "  ~/.config/environment.d/99-lerd-browser.conf (portal flatpak)"
if command -v systemctl >/dev/null 2>&1 && systemctl --user is-system-running >/dev/null 2>&1; then
  systemctl --user import-environment BROWSER 2>/dev/null || true
  systemctl --user restart xdg-desktop-portal.service xdg-desktop-portal-gtk.service 2>/dev/null || warn "  restart portal gagal — restart WSL sekali agar portal memakai BROWSER baru."
fi

log "Selesai. Buka zsh baru (atau: source ~/.zshrc)."
warn "Jika username bukan /home/viasco, sesuaikan path di $ZSHDIR/.zshrc (bagian PATH, bun, lerd, nvm)."

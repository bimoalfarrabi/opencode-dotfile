#!/usr/bin/env bash
# ===========================================================================
# setup-lerd.sh — Lerd Desktop (WSLg) customization installer
#
# Installs everything needed for the Lerd dark-mode + title-bar setup on a
# fresh machine, from this repo as the single source of truth:
#   1. App patch (dark frameless title bar + window controls + desktopName)
#   2. Desktop entry (Lerd.desktop) + icons (8 sizes)
#   3. Flatpak override XDG_SESSION_TYPE=wayland (wajib agar app tidak crash
#      di WSLg: launcher --ozone-platform-hint=auto jatuh ke X11 tanpa ini)
#   4. .wslgconfig di profil Windows (WSL2_VM_ID + APP_LIST_PATH)
#   5. Fungsi `lerd` di ~/.zshrc (opsional)
#
# Idempotent — aman dijalankan ulang (mis. setelah `flatpak update` Lerd).
#
# Usage:
#   ./setup-lerd.sh            # install/sync semua
#   ./setup-lerd.sh --help     # bantuan
# ===========================================================================
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LERD="$REPO/lerd"
HOME_DIR="${HOME:-$HOME}"
APP_ID="sh.lerd.Desktop"
FLATPAK_MAIN="$HOME_DIR/.local/share/flatpak/app/$APP_ID/current/active/files/main"

log()  { printf '\033[1;32m[lerd]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[lerd]\033[0m %s\n' "$*"; }

usage() { sed -n 's/^# \{0,1\}//p' "${BASH_SOURCE[0]}" | sed -n '2,16p'; }

for arg in "$@"; do
  case "$arg" in
    --help|-h) usage; exit 0;;
    *) warn "unknown flag: $arg";;
  esac
done

# --- 1. app patch ----------------------------------------------------------
install_patch() {
  if [ ! -d "$FLATPAK_MAIN" ]; then
    warn "Flatpak Lerd belum terpasang ($APP_ID). Lewati patch — install Lerd dulu, lalu jalankan ulang."
    return 0
  fi
  log "Memasang apply-patch.sh ke ~/.local/bin/lerd-dark-titlebar.sh ..."
  mkdir -p "$HOME_DIR/.local/bin"
  ln -sf "$LERD/apply-patch.sh" "$HOME_DIR/.local/bin/lerd-dark-titlebar.sh"
  log "Menjalankan patch (idempotent)..."
  bash "$LERD/apply-patch.sh" || warn "Patch gagal — cek apakah struktur file flatpak Lerd berubah."
}

# --- 2. desktop entry + icons ---------------------------------------------
install_desktop_and_icons() {
  log "Memasang ikon (8 ukuran + svg) ke ~/.local/share/icons/hicolor ..."
  for d in 16x16 24x24 32x32 48x48 64x64 128x128 256x256 512x512; do
    mkdir -p "$HOME_DIR/.local/share/icons/hicolor/$d/apps"
    cp "$LERD/assets/hicolor/$d/apps/Lerd.png" "$HOME_DIR/.local/share/icons/hicolor/$d/apps/Lerd.png"
  done
  mkdir -p "$HOME_DIR/.local/share/icons/hicolor/scalable/apps"
  cp "$LERD/assets/hicolor/scalable/apps/Lerd.svg" "$HOME_DIR/.local/share/icons/hicolor/scalable/apps/Lerd.svg"
  if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f -t "$HOME_DIR/.local/share/icons/hicolor" >/dev/null 2>&1 || true
  fi

  log "Memasang desktop entry Lerd.desktop ..."
  mkdir -p "$HOME_DIR/.local/share/applications"
  sed "s|__HOME__|$HOME_DIR|g" "$LERD/templates/Lerd.desktop" > "$HOME_DIR/.local/share/applications/Lerd.desktop"
  # bersihkan sisa entry lama (key derivasi WSLg "Desktop" dari nama ber-titik)
  rm -f "$HOME_DIR/.local/share/applications/sh.lerd.Desktop.desktop"
}

# --- 3. flatpak override ----------------------------------------------------
install_override() {
  if ! command -v flatpak >/dev/null 2>&1; then
    warn "flatpak tidak terpasang — lewati override."
    return 0
  fi
  log "Memastikan override XDG_SESSION_TYPE=wayland (wajib di WSLg)..."
  flatpak override --user --env=XDG_SESSION_TYPE=wayland "$APP_ID"
}

# --- 4. .wslgconfig (Windows profile) ---------------------------------------
install_wslgconfig() {
  local winuser="" dst=""
  if command -v cmd.exe >/dev/null 2>&1; then
    winuser="$(cmd.exe /c "echo %USERPROFILE%" 2>/dev/null | tr -d '\r\n')"
    dst="$(wslpath -u "$winuser" 2>/dev/null || echo "/mnt/c/Users/$USER")/.wslgconfig"
  else
    dst="/mnt/c/Users/$USER/.wslgconfig"
  fi
  log "Memasang .wslgconfig -> $dst"
  if [ -d "$(dirname "$dst")" ]; then
    sed "s|__USER__|$USER|g" "$LERD/templates/.wslgconfig.example" > "$dst"
  else
    warn "Profil Windows tidak ditemukan — salin manual dari:"
    warn "  $LERD/templates/.wslgconfig.example"
    warn "  ke: C:\\Users\\<kamu>\\.wslgconfig"
  fi
}

# --- 5. zshrc function ------------------------------------------------------
install_zshrc() {
  local rc="$HOME_DIR/.zshrc"
  [ -f "$rc" ] || return 0
  if grep -q '^lerd()' "$rc"; then
    log "Fungsi \`lerd\` sudah ada di .zshrc."
  else
    log "Menambahkan fungsi \`lerd\` ke .zshrc ..."
    cat >> "$rc" <<'EOF'

# ---- Lerd Desktop (dark mode ditangani patch; lihat opencode-dotfile/lerd) ----
# TANPA argumen = buka GUI; DENGAN argumen = CLI asli (lerd update, start, ...).
# (Fungsi menutupi binary ~/.local/bin/lerd — jangan sampai menghalangi CLI.)
lerd() {
  if [ $# -eq 0 ]; then
    flatpak run sh.lerd.Desktop
  else
    "$HOME/.local/bin/lerd" "$@"
  fi
}
EOF
  fi
}

# --- 6. split-DNS fix ----------------------------------------------------------
install_dns() {
  log "Memasang lerd-dns-fix.sh + alias \`lerd-dns\` ..."
  mkdir -p "$HOME_DIR/bin"
  cp "$LERD/dns/lerd-dns-fix.sh" "$HOME_DIR/bin/lerd-dns-fix.sh"
  chmod +x "$HOME_DIR/bin/lerd-dns-fix.sh"
  local rc="$HOME_DIR/.zshrc"
  if [ -f "$rc" ] && ! grep -q '^alias lerd-dns=' "$rc"; then
    printf '\n# ---- Lerd split-DNS fix (jalankan setelah lerd dns:repair / install / restart WSL) ----\nalias lerd-dns='"'"'~/bin/lerd-dns-fix.sh'"'"'\n' >> "$rc"
    log "  alias \`lerd-dns\` ditambahkan ke .zshrc"
  else
    log "  alias \`lerd-dns\` sudah ada."
  fi
}

# --- run ---------------------------------------------------------------------
install_patch
install_desktop_and_icons
install_override
install_wslgconfig
install_zshrc
install_dns

log "Selesai."
log "Setelah flatpak update Lerd, jalankan ulang: $LERD/apply-patch.sh"
log "Catatan ikon taskbar & revert: lihat $LERD/README.md"

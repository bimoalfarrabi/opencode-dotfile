#!/usr/bin/env bash
# ===========================================================================
# setup-wsl2.sh — integrasi Lerd ke Windows (jalur lerd.exe + wsl:setup)
#
# Yang dikerjakan (semua idempoten, aman diulang):
#   1. .wslconfig: [general] instanceIdleTimeout=-1, hostAddressLoopback=true
#      (backup otomatis; TANPA ini distro mati beberapa detik setelah
#      terminal terakhir ditutup dan semua site ikut mati)
#   2. Pastikan lerd.exe ada di ~/.local/bin (lokasi yang dicari wsl:setup)
#   3. lerd node:manage (opsional, --no-node untuk melewati)
#   4. lerd wsl:setup (shim Windows, NRPT .test, firewall lerd LAN, agent)
#   5. Verifikasi
#
# TIDAK memakai Install-Lerd.exe: installer itu hardcode distro
# `Ubuntu-24.04` dan akan membuat distro KEDUA kalau distro-mu bernama lain.
#
# Usage:
#   ./setup-wsl2.sh              # semua
#   ./setup-wsl2.sh --check      # hanya verifikasi, tanpa mengubah apa pun
#   ./setup-wsl2.sh --no-node    # lewati lerd node:manage
# ===========================================================================
set -euo pipefail

LERD_VERSION_FALLBACK="1.38.0"
CHECK_ONLY=0
DO_NODE=1

log()  { printf '\033[1;32m[lerd]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[lerd]\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m[lerd]\033[0m %s\n' "$*" >&2; }
usage() { sed -n 's/^# \{0,1\}//p' "${BASH_SOURCE[0]}" | sed -n '2,20p'; }

for arg in "$@"; do
  case "$arg" in
    --help|-h) usage; exit 0;;
    --check)   CHECK_ONLY=1;;
    --no-node) DO_NODE=0;;
    *) warn "unknown flag: $arg";;
  esac
done

# --- helpers ---------------------------------------------------------------
is_wsl() { grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; }
have() { command -v "$1" >/dev/null 2>&1; }

win_path() { wslpath -u "$1" 2>/dev/null; }

# --- 0. sanity -------------------------------------------------------------
is_wsl || { err "bukan WSL2 (kernel bukan Microsoft). Script ini untuk WSL."; exit 1; }
have lerd || { err "lerd tidak ada di PATH. Install dulu: curl -fsSL https://lerd.sh/install.sh | bash"; exit 1; }

log "lerd $(lerd version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo '?')"

# --- 1. .wslconfig ---------------------------------------------------------
WSLCONFIG="$(win_path "$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')")/.wslconfig"
WSLCONFIG="${WSLCONFIG//\//\/}"

ensure_wslconfig() {
  local file="$1"
  [ -f "$file" ] || { printf '[wsl2]\nnetworkingMode=mirrored\ndnsTunneling=true\nfirewall=true\nautoProxy=true\n' > "$file"; }

  local changed=0
  key_present() { grep -qE "^[[:space:]]*$1[[:space:]]*=" "$file"; }
  section_present() { grep -qE "^[[:space:]]*\[$1\][[:space:]]*$" "$file"; }

  add_section() { section_present "$1" || { printf '\n[%s]\n' "$1" >> "$file"; changed=1; }; }

  # [general] instanceIdleTimeout=-1
  if ! key_present instanceIdleTimeout; then
    add_section general
    printf 'instanceIdleTimeout=-1\n' >> "$file"; changed=1
  elif ! grep -qE '^[[:space:]]*instanceIdleTimeout[[:space:]]*=[[:space:]]*-1' "$file"; then
    warn "instanceIdleTimeout ada tapi bukan -1; perbaiki manual di $file"
  fi

  # [experimental] hostAddressLoopback=true
  if ! key_present hostAddressLoopback; then
    add_section experimental
    printf 'hostAddressLoopback=true\n' >> "$file"; changed=1
  fi

  return $((changed ? 0 : 1))
}

if [ -f "$WSLCONFIG" ]; then
  if [ "$CHECK_ONLY" -eq 0 ]; then
    if grep -qE '^[[:space:]]*instanceIdleTimeout[[:space:]]*=[[:space:]]*-1' "$WSLCONFIG" \
       && grep -qE '^[[:space:]]*hostAddressLoopback' "$WSLCONFIG"; then
      log ".wslconfig sudah benar"
    else
      cp -a "$WSLCONFIG" "$WSLCONFIG.bak-$(date +%Y%m%d-%H%M%S)"
      log "backup .wslconfig dibuat"
      ensure_wslconfig "$WSLCONFIG" || true
      log ".wslconfig diperbarui — jalankan 'wsl --shutdown' dari PowerShell agar berlaku"
    fi
  fi
  grep -qE '^[[:space:]]*instanceIdleTimeout[[:space:]]*=[[:space:]]*-1' "$WSLCONFIG" \
    && log "  ✓ instanceIdleTimeout=-1" || warn "  ✗ instanceIdleTimeout belum -1"
  grep -qE '^[[:space:]]*hostAddressLoopback' "$WSLCONFIG" \
    && log "  ✓ hostAddressLoopback" || warn "  ✗ hostAddressLoopback belum ada"
else
  warn ".wslconfig tidak ditemukan di $WSLCONFIG"
fi

# --- 2. lerd.exe -----------------------------------------------------------
LERD_BIN="$(command -v lerd)"
LERD_DIR="$(dirname "$(readlink -f "$LERD_BIN")")"
[ -f "$LERD_DIR/lerd.exe" ] \
  && log "lerd.exe ada di $LERD_DIR" \
  || warn "lerd.exe TIDAK ada di $LERD_DIR — wsl:setup akan gagal.

  lerd.exe dibundel di dalam tarball Linux (tidak ada aset rilis terpisah).
  Kalau 'lerd update' tidak memasangnya (short-circuit saat sudah versi
  terbaru), ambil manual:

    VER=\$(lerd version | grep -oE '[0-9]+\\.[0-9]+\\.[0-9]+' | head -1)
    tmp=\$(mktemp -d)
    gh release download v\$VER --repo lerd-env/lerd \\
      -p \"lerd_\${VER}_linux_amd64.tar.gz\" -D \"\$tmp\"
    tar -xzf \"\$tmp\"/lerd_\${VER}_linux_amd64.tar.gz -C \"\$tmp\" lerd.exe
    install -m 755 \"\$tmp/lerd.exe\" \"$LERD_DIR/lerd.exe\"
    rm -rf \"\$tmp\"
"

# --- 3. Node + PATH shell --------------------------------------------------
# Shim lerd harus menang atas nvm DAN hanya muncul sekali di $PATH. Di zsh
# blok ini sudah ada di template .zshrc; .bashrc dan .profile tidak punya
# template di repo, jadi ditulis di sini (idempoten).
install_path_block() {
  local file="$1"
  [ -f "$file" ] || return 0
  if grep -q 'local/share/lerd/bin' "$file"; then
    # sudah ada — pastikan bentuknya strip-then-prepend, bukan prepend polos
    if grep -q "grep -v '.local/share/lerd/bin'" "$file"; then
      log "  PATH lerd sudah benar di $(basename "$file")"
      return 0
    fi
    warn "  $(basename "$file") punya PATH lerd bentuk lama (prepend polos)."
    warn "  Perbaiki manual: buang baris itu, lalu tambahkan blok strip-then-prepend."
    return 0
  fi
  log "  menambahkan blok PATH lerd ke $(basename "$file")"
  cat >> "$file" <<'EOF'

# ---- Lerd shim ----
# Menang atas nvm/version manager, dan hanya muncul SEKALI di $PATH.
# Buang duplikat lama lalu prepend. Di .profile ini yang memperbaiki
# `bash -lc`, karena .bashrc punya guard interaktif dan tidak sampai ke sini.
PATH="$(printf '%s' "$PATH" | tr ':' '\n' | grep -v '\.local/share/lerd/bin' | paste -sd:)"
export PATH="$HOME/.local/share/lerd/bin:$PATH"
EOF
}

if [ "$CHECK_ONLY" -eq 0 ]; then
  install_path_block "$HOME/.bashrc"
  install_path_block "$HOME/.profile"
fi

if [ "$DO_NODE" -eq 1 ] && [ "$CHECK_ONLY" -eq 0 ]; then
  if grep -qE '^[[:space:]]*managed:[[:space:]]*true' "${XDG_CONFIG_HOME:-$HOME/.config}/lerd/config.yaml" 2>/dev/null; then
    log "Node sudah dikelola lerd"
  else
    log "lerd node:manage…"
    lerd node:manage
  fi
fi

# --- 4. wsl:setup ----------------------------------------------------------
if [ "$CHECK_ONLY" -eq 0 ]; then
  if [ -f "$LERD_DIR/lerd.exe" ]; then
    log "lerd wsl:setup… (satu prompt admin di Windows untuk DNS + firewall)"
    lerd wsl:setup
  else
    err "lewati wsl:setup: lerd.exe belum ada"
  fi
fi

# --- 5. verifikasi ---------------------------------------------------------
echo
log "verifikasi"
echo "  systemd PID 1 : $(ps -p 1 -o comm= 2>/dev/null || echo '?')"
echo "  linger        : $(loginctl show-user "$USER" -p Linger 2>/dev/null | cut -d= -f2 || echo '?')"
echo "  podman rootless: $(podman info --format '{{.Host.Security.Rootless}}' 2>/dev/null || echo '?')"
echo "  graph driver  : $(podman info --format '{{.Store.GraphDriverName}}' 2>/dev/null || echo '?')"

WINBIN="$(win_path "$(cmd.exe /c 'echo %LOCALAPPDATA%' 2>/dev/null | tr -d '\r')")"
if [ -f "$WINBIN/lerd/bin/lerd-wsl.conf" ]; then
  log "Windows side terpasang"
  sed 's/^/    /' "$WINBIN/lerd/bin/lerd-wsl.conf"
else
  warn "Windows side belum terpasang (jalankan tanpa --check)"
fi

echo
log "selesai. Kalau .wslconfig baru diubah: wsl --shutdown dari PowerShell."

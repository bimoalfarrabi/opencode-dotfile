#!/usr/bin/env bash
# ===========================================================================
# setup-desktop-app.sh — Lerd desktop app (tray + notifikasi toast Windows)
#
# Kenapa script ini ada: lerd tidak menyediakan installer terpisah untuk
# desktop app. Satu-satunya cara resmi adalah Install-Lerd.exe, dan installer
# itu TIDAK bisa dipakai kalau distro-mu bukan bernama persis `Ubuntu-24.04`
# (ia akan membuat distro kedua dan membajak integrasi Windows).
#
# Jadi script ini mereproduksi persis langkah yang ditulis installer:
#   1. Unduh lerd-desktop-win32-<arch>.zip dari release, ekstrak
#   2. Ekstrak lerd.png + lerd.ico dari dalam app.asar (tidak ada di zip)
#   3. Daftarkan (semua HKCU, tanpa admin):
#        AppUserModelId\sh.lerd.Lerd   identitas toast
#        Software\Classes\lerd         skema lerd://
#        Run\lerd-desktop              autostart --hidden
#        Start Menu shortcut           kosmetik
#   4. lerd wsl:setup  -> agent diserahkan ke app (Run key agent dihapus)
#
# Usage:
#   ./setup-desktop-app.sh            # install/repair
#   ./setup-desktop-app.sh --check    # cek keadaan saja
# ===========================================================================
set -euo pipefail

DEST_WIN='%LOCALAPPDATA%\Lerd\desktop'
APP_ID='sh.lerd.Lerd'
CHECK_ONLY=0

log()  { printf '\033[1;32m[lerd]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[lerd]\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m[lerd]\033[0m %s\n' "$*" >&2; }

for arg in "$@"; do
  case "$arg" in
    --help|-h) sed -n 's/^# \{0,1\}//p' "${BASH_SOURCE[0]}" | sed -n '2,26p'; exit 0;;
    --check) CHECK_ONLY=1;;
    *) warn "unknown flag: $arg";;
  esac
done

grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null \
  || { err "bukan WSL2"; exit 1; }

winpath() { wslpath -u "$1" 2>/dev/null; }
LOCALAPPDATA="$(winpath "$(cmd.exe /c 'echo %LOCALAPPDATA%' 2>/dev/null | tr -d '\r')")"
[ -n "$LOCALAPPDATA" ] || { err "tidak bisa resolve %LOCALAPPDATA% (interop mati?)"; exit 1; }
DEST="$LOCALAPPDATA/Lerd/desktop"
EXE="$DEST/lerd-desktop.exe"

psrun() {
  local ps1; ps1="$(mktemp --suffix=.ps1)"
  printf '%s\n' "$1" > "$ps1"
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w "$ps1")" 2>&1 | tr -d '\r'
  rm -f "$ps1"
}

# --- check only ------------------------------------------------------------
if [ "$CHECK_ONLY" -eq 1 ]; then
  echo "  lerd-desktop.exe : $([ -f "$EXE" ] && echo "ada ($(du -h "$EXE" | cut -f1))" || echo "TIDAK ADA")"
  echo "  lerd.png         : $([ -f "$DEST/lerd.png" ] && echo ada || echo TIDAK ADA)"
  echo "  lerd.ico         : $([ -f "$DEST/lerd.ico" ] && echo ada || echo TIDAK ADA)"
  psrun "\$k='HKCU:\Software\Classes\AppUserModelId\\$APP_ID'; if (Test-Path \$k) {'  AppUserModelId  : ' + (Get-ItemProperty \$k).DisplayName} else {'  AppUserModelId  : TIDAK ADA'}
\$c=(Get-ItemProperty 'HKCU:\Software\Classes\lerd\shell\open\command' -ErrorAction SilentlyContinue).'(default)'; if (\$c) {'  lerd://         : ' + \$c} else {'  lerd://         : TIDAK ADA'}
\$r=(Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'lerd-desktop' -ErrorAction SilentlyContinue).'lerd-desktop'; if (\$r) {'  Run             : ' + \$r} else {'  Run             : TIDAK ADA'}
\$a=(Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'lerd' -ErrorAction SilentlyContinue).'lerd'; if (\$a) {'  Run agent (lama): MASIH ADA — jalankan lerd wsl:setup'} else {'  Run agent       : sudah diserahkan ke app'}
\$p=Get-Process lerd-desktop -ErrorAction SilentlyContinue; if (\$p) {'  proses          : ' + \$p.Count + ' (jalan)'} else {'  proses          : tidak jalan'}"
  exit 0
fi

# --- 1. unduh + ekstrak ----------------------------------------------------
if [ -f "$EXE" ]; then
  log "desktop app sudah ada di $DEST"
else
  command -v unzip >/dev/null || { err "butuh 'unzip'"; exit 1; }
  tmp="$(mktemp -d)"
  log "mengunduh lerd-desktop-win32-x64.zip…"
  if command -v gh >/dev/null 2>&1; then
    gh release download --repo lerd-env/lerd-desktop \
      -p 'lerd-desktop-win32-x64.zip' -D "$tmp" --clobber
  else
    curl -fSL --http1.1 --retry 3 -o "$tmp/lerd-desktop-win32-x64.zip" \
      "https://github.com/lerd-env/lerd-desktop/releases/latest/download/lerd-desktop-win32-x64.zip"
  fi
  unzip -tq "$tmp/lerd-desktop-win32-x64.zip" >/dev/null || { err "zip rusak"; rm -rf "$tmp"; exit 1; }
  mkdir -p "$DEST"
  unzip -q -o "$tmp/lerd-desktop-win32-x64.zip" -d "$DEST"
  rm -rf "$tmp"
  log "terekstrak ke $DEST"
fi

# --- 2. ikon dari app.asar -------------------------------------------------
# lerd.png/lerd.ico tidak ada di zip; installer mengambilnya dari project
# source. Di dalam artefak rilis keduanya ada di app.asar, jadi kita ekstrak.
extract_icon() {
  python3 - "$DEST/resources/app.asar" "$DEST" <<'PY'
import json, sys, struct, os
asar, outdir = sys.argv[1], sys.argv[2]
b = open(asar, 'rb').read()
header_size = struct.unpack('<I', b[4:8])[0]
json_size   = struct.unpack('<I', b[8:12])[0]
s = b[16:16+json_size].decode('utf8', 'replace')
s = s.split('\x00', 1)[0]
tree = json.loads(s)
data_start = 8 + header_size

def walk(node, prefix, out):
    for k, v in (node.get('files') or {}).items():
        p = f'{prefix}/{k}' if prefix else k
        if isinstance(v, dict) and 'files' in v:
            walk(v, p, out)
        elif isinstance(v, dict) and 'offset' in v:
            out[p] = v

entries = {}
walk(tree, '', entries)

for src, dst in (
    ('installer/branding/icon-512.png', 'lerd.png'),   # yang dipetakan lerd.iss
    ('assets/icon.ico',                 'lerd.ico'),
):
    e = entries.get(src)
    if not e:
        print(f'  ! {src} tidak ada di asar')
        continue
    off = data_start + int(e['offset'])
    data = b[off:off+int(e['size'])]
    open(os.path.join(outdir, dst), 'wb').write(data)
    print(f'  ✓ {dst} ({len(data)} B)')
PY
}
[ -f "$DEST/lerd.png" ] && [ -f "$DEST/lerd.ico" ] \
  && log "ikon sudah ada" \
  || { log "ekstrak ikon dari app.asar…"; extract_icon; }

# --- 3. registrasi HKCU ----------------------------------------------------
log "registrasi Windows (HKCU, tanpa admin)…"
psrun "
\$ErrorActionPreference='Stop'
\$exe='$EXE'; \$png='$DEST\lerd.png'; \$ico='$DEST\lerd.ico'
\$appId='$APP_ID'

# Identitas toast
\$k='HKCU:\Software\Classes\AppUserModelId\'+\$appId
New-Item -Path \$k -Force | Out-Null
Set-ItemProperty -Path \$k -Name DisplayName -Value 'Lerd'
if (Test-Path \$png) { Set-ItemProperty -Path \$k -Name IconUri -Value \$png }

# Skema lerd://
New-Item -Path 'HKCU:\Software\Classes\lerd' -Force | Out-Null
Set-ItemProperty -Path 'HKCU:\Software\Classes\lerd' -Name '(default)'   -Value 'URL:Lerd'
Set-ItemProperty -Path 'HKCU:\Software\Classes\lerd' -Name 'URL Protocol' -Value ''
New-Item -Path 'HKCU:\Software\Classes\lerd\DefaultIcon' -Force | Out-Null
Set-ItemProperty -Path 'HKCU:\Software\Classes\lerd\DefaultIcon' -Name '(default)' -Value (\$exe + ',0')
New-Item -Path 'HKCU:\Software\Classes\lerd\shell\open\command' -Force | Out-Null
Set-ItemProperty -Path 'HKCU:\Software\Classes\lerd\shell\open\command' -Name '(default)' -Value ('\"' + \$exe + '\" \"%1\"')

# Autostart
\$run='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
if (-not (Test-Path \$run)) { New-Item -Path \$run -Force | Out-Null }
Set-ItemProperty -Path \$run -Name 'lerd-desktop' -Value ('\"' + \$exe + '\" --hidden')

# Start Menu shortcut (kosmetik)
\$dir=Join-Path \$env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Lerd'
New-Item -ItemType Directory -Path \$dir -Force | Out-Null
\$ws=New-Object -ComObject WScript.Shell
\$s=\$ws.CreateShortcut((Join-Path \$dir 'Lerd.lnk'))
\$s.TargetPath=\$exe; \$s.IconLocation=\$ico+',0'; \$s.WorkingDirectory='$DEST'; \$s.Description='Lerd'; \$s.Save()
[Runtime.InteropServices.Marshal]::ReleaseComObject(\$ws) | Out-Null

Write-Output '  ✓ AppUserModelId, lerd://, Run, shortcut'
"

# --- 4. serahkan agent ke app ---------------------------------------------
if [ -f "$(dirname "$(command -v lerd)")/lerd.exe" ] || [ -f "$HOME/.local/bin/lerd.exe" ]; then
  log "lerd wsl:setup — menyerahkan agent ke desktop app…"
  lerd wsl:setup
else
  warn "lewati wsl:setup: lerd.exe tidak ada (jalankan setup-wsl2.sh dulu)"
fi

echo
log "selesai. Tray muncul setelah app dijalankan:"
echo "    powershell.exe -c \"Start-Process '$EXE' -ArgumentList '--hidden'\""
echo
warn "Jangan tutup app lewat Task Manager/Stop-Process -Force: itu membunuh"
warn "agent (DNS .test ikut mati). Pakai Quit di menu tray."

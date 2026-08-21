# Lerd Desktop — kustomisasi (WSLg)

Setup dark mode + title bar untuk **Lerd Desktop** (aplikasi Electron, Flatpak
`sh.lerd.Desktop`, lingkungan PHP lokal ala Herd) di WSLg. Dibuat agar mudah
direplikasi ke mesin baru.

## Yang dipasang

| # | Komponen | Lokasi target | Efek |
|---|----------|---------------|------|
| 1 | Patch app (`apply-patch.sh`) | file di dalam flatpak: `.../files/main/src/main.js`, `src/preload.js`, `package.json` | Title bar Chromium yang terang dihilangkan (`frame: false`) → band title bar gelap 40px sendiri (area drag + tombol **— ▢ ✕**) + dashboard digeser 40px; konten dipaksa gelap (`nativeTheme.themeSource='dark'`); `desktopName` → `Lerd.desktop` (app_id Wayland cocok dengan key app-list WSLg). |
| 2 | Desktop entry | `~/.local/share/applications/Lerd.desktop` | Entry WSLg dengan key `Lerd` (nama file tanpa titik — derivasi key WSLg mengambil segmen setelah titik terakhir, lihat microsoft/wslg#944). |
| 3 | Ikon | `~/.local/share/icons/hicolor/{16..512}x*/apps/Lerd.png` + svg | `Icon=` di desktop entry memakai **absolute path** (direktori ikon user tidak ada di daftar pencarian WSLg). |
| 4 | Flatpak override | `flatpak override --user --env=XDG_SESSION_TYPE=wayland` | **WAJIB** di WSLg: tanpa ini launcher `--ozone-platform-hint=auto` jatuh ke X11 dan crash (`Missing X server`). |
| 5 | `.wslgconfig` (Windows) | `C:\Users\<user>\.wslgconfig` | `WSL2_VM_ID` (fix microsoft/wslg#1388 — env dihapus sejak WSL 2.6.2, weston butuh untuk `is_system_distro()`) + `WESTON_RDPRAIL_SHELL_APP_LIST_PATH` (folder scan desktop file tambahan; default WSLg hanya `/usr/share/applications` dkk). |
| 6 | Fungsi `lerd` | `~/.zshrc` | `lerd() { flatpak run sh.lerd.Desktop "$@"; }` (ditambahkan jika belum ada). |

## Cara pakai (mesin baru)

Prasyarat: Lerd ter-install via flatpak, WSL dengan WSLg (Wayland).

```sh
git clone git@github.com:bimoalfarrabi/opencode-dotfile.git
cd opencode-dotfile
./lerd/setup-lerd.sh        # idempotent — aman dijalankan ulang
```

Lalu **restart WSL sekali** dari Windows: `wsl --shutdown` → buka WSL → jalankan Lerd.

## Setelah update Lerd (`flatpak update`)

Update Lerd menimpa file di dalam flatpak (patch hilang). Jalankan ulang:

```sh
lerd-dark-titlebar.sh        # symlink → repo/lerd/apply-patch.sh (dipasang oleh setup)
# atau langsung:
./lerd/apply-patch.sh
```

File di luar flatpak (desktop entry, ikon, override, `.wslgconfig`) bertahan.

## Ikon taskbar — status & batas

Setup ini membuat ikon Lerd termuat di registry app-list WSLg (terverifikasi di
`/mnt/wslg/weston.log`: `Icon image:0x...` non-nil) dan terkirim ke sisi Windows.
Namun **ikon taskbar window tetap penguin** pada WSLg 1.0.73 (diuji: Wayland dan X11):
jalur asosiasi window→taskbar WSLg mengirim `appIcon: nil`
(`send_associate_window_app_id` — keluarga bug microsoft/wslg#1382, masih open).
Ikon akan muncul otomatis bila WSLg diperbaiki; tidak ada kerja tambahan.

## Revert

```sh
# 1. pulihkan file app (backup otomatis dibuat patch: *.bak-darktb-<ts>)
SRC=~/.local/share/flatpak/app/sh.lerd.Desktop/current/active/files/main
cp "$SRC/src/main.js.bak-darktb-"* "$SRC/src/main.js" 2>/dev/null || true
cp "$SRC/src/preload.js.bak-darktb-"* "$SRC/src/preload.js" 2>/dev/null || true
cp "$SRC/package.json.bak-darktb-"* "$SRC/package.json" 2>/dev/null || true

# 2. override + desktop entry + ikon + wslgconfig
flatpak override --user --reset sh.lerd.Desktop
rm -f ~/.local/share/applications/Lerd.desktop
rm -rf ~/.local/share/icons/hicolor/{16x16,24x24,32x32,48x48,64x64,128x128,256x256,512x512,scalable}/apps/Lerd.{png,svg}
rm -f /mnt/c/Users/$USER/.wslgconfig
```

## Struktur modul

```
lerd/
├── setup-lerd.sh           # orkestrator idempotent (install semua)
├── apply-patch.sh          # patch flatpak app (kanonik; = lerd-dark-titlebar.sh)
├── assets/hicolor/…        # ikon Lerd 8 ukuran + svg (single source of truth)
├── templates/
│   ├── Lerd.desktop        # desktop entry (token __HOME__)
│   └── .wslgconfig.example # konfigurasi Windows (token __USER__)
└── README.md               # dokumen ini
```

Referensi teknis lengkap (riwayat diagnosis title bar + ikon): `lerd/DIAGNOSIS.md`.
Topik terkait di repo: `open-design/`, `agents-skills/`.

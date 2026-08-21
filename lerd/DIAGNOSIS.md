# Lerd Desktop — Dark Mode (Title Bar) Patch

Catatan untuk lingkungan WSLg (Windows + WSL). Terakhir diverifikasi: 2026-08-21.

## Masalah

Title bar Lerd Desktop (aplikasi Electron, Flatpak `sh.lerd.Desktop`) selalu terang,
tidak peduli tema sistem. Strip terang itu adalah **frame bawaan Chromium/Electron** —
bukan bagian dari WSLg. Di stack WSLg + Electron 33, frame ini mengabaikan SEMUA sinyal
tema, sudah dibuktikan dengan 7 percobaan yang gagal:

| Sinyal | Hasil |
|---|---|
| `gsettings color-scheme=prefer-dark` + `gtk-theme=Adwaita-dark` | title bar tetap terang |
| `--force-dark-mode` (flag Chromium) | tetap terang |
| `GTK_THEME=Adwaita-dark` (env, Wayland) | tetap terang |
| `nativeTheme.themeSource='dark'` (dari dalam app) | tetap terang |
| Portal `org.freedesktop.appearance color-scheme` (sudah lapor dark) | tetap terang |
| X11 + `GTK_THEME=Adwaita-dark` | tetap terang |
| X11 + `--force-dark-mode` + `GTK_THEME` | tetap terang |

Uji `frame: false` membuktikan strip itu milik Chromium (hilang saat frameless).

## Solusi

Patch di dalam app: buang frame Chromium + paksa dark + gambar kontrol window sendiri.

1. `src/main.js`: `frame: false`, `nativeTheme.themeSource = 'dark'`, IPC handler
   window controls, suntik `TITLE_BAR_ENHANCER` (drag region + tombol **— ▢ ✕** di kanan atas).
2. `src/preload.js`: expose `window.lerdWin` (minimize/maximize/close).

Lokasi file yang di-patch:

```
~/.local/share/flatpak/app/sh.lerd.Desktop/current/active/files/main/src/{main,preload}.js
```

Backup original: `main.js.bak-darktb`, `preload.js.bak-darktb` (di folder yang sama).

## Setelah `flatpak update` Lerd — WAJIB re-apply

Update Lerd menimpa file di atas dan menghapus patch. Jalankan:

```sh
lerd-dark-titlebar.sh
```

Script idempotent di `~/.local/bin/lerd-dark-titlebar.sh` (menandai: ada tidaknya
`TITLE_BAR_ENHANCER` di `main.js`). Kalau struktur file Lerd berubah drastis dan
patch gagal, script akan melaporkan dan perlu diperbarui manual.

## Flatpak override yang dipasang

```sh
flatpak override --user --env=XDG_SESSION_TYPE=wayland sh.lerd.Desktop
```

Ini menyetel `XDG_SESSION_TYPE=wayland` ke dalam sandbox. Penting karena di sesi WSLg
variabel ini kosong, sehingga hint ozone `auto` di launcher app memilih X11 dan crash
(`Missing X server or $DISPLAY` — socket X11 tidak ter-mount oleh flatpak `fallback-x11`).
Override ini bertahan melewati update app (tidak ikut terhapus).

Hapus bila perlu: `flatpak override --user --reset sh.lerd.Desktop`

## Cara revert penuh

```sh
SRC=~/.local/share/flatpak/app/sh.lerd.Desktop/current/active/files/main/src
cp "$SRC/main.js.bak-darktb" "$SRC/main.js"
cp "$SRC/preload.js.bak-darktb" "$SRC/preload.js"
flatpak override --user --reset sh.lerd.Desktop
```

## Catatan lain

- `~/.zshrc` fungsi `lerd()` disederhanakan jadi `flatpak run sh.lerd.Desktop "$@"`
  (flag hack lama `--ozone-platform=wayland --force-dark-mode` tidak diperlukan lagi).
- gsettings sistem dikembalikan ke default (`color-scheme=default`, `gtk-theme=Adwaita`)
  setelah patch — hanya Lerd yang gelap, aplikasi lain tidak terpengaruh.
- Efek samping frameless: tidak ada strip Chromium; app meng-inject title band gelap 40px sendiri
  (area drag + label "Lerd" + tombol **— ▢ ✕**). Seluruh dashboard digeser 40px ke bawah
  (`body > div:first-child` diberi `margin-top:40px` + `height:calc(100vh - 40px)`), jadi tidak
  ada tumpang-tindih dengan konten dashboard (top bar/search tetap terlihat).

## Ikon taskbar (WSLg)

Ikon yang muncul di taskbar Windows untuk app WSLg diambil dari desktop file
(`Icon=sh.lerd.Desktop`) → theme ikon hicolor, dicocokkan lewat app_id/WM_CLASS
(`StartupWMClass=sh.lerd.Desktop` di desktop file). Logo Lerd (tile ungu, mark putih) sudah
tersedia dan benar:

- `~/.local/share/flatpak/exports/share/icons/hicolor/512x512/apps/sh.lerd.Desktop.png` + `scalable/apps/sh.lerd.Desktop.svg`
- `~/.local/share/icons/hicolor/...` (user theme, salinan cadangan)

Cache theme sudah di-refresh dengan `gtk-update-icon-cache`.

### Status ikon taskbar (per 2026-08-21) — KONFIRMASI BUG WSLg

**Kesimpulan: bug sisi Microsoft, bukan setup lokal.** Setelah `wsl --shutdown` dengan
desktop file user-level + ikon 8 ukuran terpasang, log weston session baru menunjukkan:

```
app list entry failed to update: Key:snap-handle-link   (dll. untuk SEMUA app sistem)
app_list_monitor_thread: loadIconEvent ... entry (nil), image (nil)
```

Registry app_list WSLg gagal meng-update **setiap** desktop entry (termasuk app sistem di
`/usr/share/applications`) → tidak ada ikon yang bisa di-resolve → semua window jatuh ke
ikon default (penguin besar + penguin kecil overlay). Persis regresi
[microsoft/wslg#1382](https://github.com/microsoft/wslg/issues/1382) — muncul sejak
WSL 2.6.2/WSLg 1.0.71, masih open di WSLg 1.0.73.2 (user: 2.7.12).

Yang SUDAH dipasang (siap dipakai begitu WSLg diperbaiki/di-downgrade):
- `~/.local/share/applications/sh.lerd.Desktop.desktop` (`Icon=sh.lerd.Desktop`).
- Ikon 8 ukuran (16–512px) di user theme + flatpak exports, cache di-refresh.

Opsi:
- Upvote + komentar versi di microsoft/wslg#1382.
- Coba `wsl --update` (mungkin ada WSLg lebih baru yang sudah fix).
- Downgrade WSL ke < 2.6.2 / WSLg < 1.0.71 (satu-satunya cara yang terbukti mengembalikan ikon).
- Atau biarkan — ikon penguin hanya kosmetik; app sudah berjalan normal & gelap.

### STATUS AKHIR IKON TASKBAR (2026-08-21) — tetap penguin, ini batas WSLg

**Kesimpulan akhir**: ikon taskbar Lerd tetap menampilkan penguin WSLg, baik di Wayland
maupun X11. Semua jalur yang bisa diperbaiki dari sisi user sudah dicoba dan dibuktikan
berfungsi sampai lapisan terakhir WSLg (entry terdaftar, ikon termuat & terkirim ke peer),
tapi jalur asosiasi window→taskbar di WSLg 1.0.73 mengirim `appIcon: nil` (keluarga bug
microsoft/wslg#1382, masih open). User memutuskan untuk menerima (tidak mengganggu
penggunaan; app gelap & berfungsi normal).

Keadaan yang DIPERTAHANKAN (semua tidak merugikan, sebagian memperbaiki Start Menu):
- App berjalan di **Wayland** (override: `--env=XDG_SESSION_TYPE=wayland` — WAJIB, tanpa
  ini launcher `--ozone-platform-hint=auto` jatuh ke X11 dan crash di WSLg).
- `C:\Users\bimoh\.wslgconfig`: `WSL2_VM_ID=fooo` + `WESTON_RDPRAIL_SHELL_APP_LIST_PATH`
  (perbaiki registrasi app-list & Start Menu).
- `~/.local/share/applications/Lerd.desktop` + ikon 8 ukuran `Lerd.png` di user theme.
- Patch dark title bar (frameless + band) — berfungsi penuh.

Jika suatu saat WSLg diperbaiki (upgrade WSL): ikon akan muncul otomatis tanpa kerja tambahan.
Opsi bila ingin mencoba lagi: `flatpak override --user --socket=x11 --nosocket=wayland
--env=XDG_SESSION_TYPE=x11 sh.lerd.Desktop` (kembalikan: `flatpak override --user --reset`
lalu pasang ulang `--env=XDG_SESSION_TYPE=wayland`).

### Riwayat diagnosis ikon (untuk referensi)

Rantai yang harus cocok di WSLg: **app_id window == key derivasi dari nama desktop file**
(segmen setelah titik terakhir, bug microsoft/wslg#944) → entry ketemu → `Icon=` di-resolve
(mendukung absolute path) dari direktori pencarian terbatas (icon_folder: /usr/share/pixmaps,
/usr/share/icons/hicolor/{96,128,48,...}x, /var/lib/flatpak/...).

Empat hal yang dipasang agar cocok:

1. **`package.json` (di flatpak): `"desktopName": "Lerd.desktop"`** — inilah sumber app_id
   Wayland (bukan setName/FLATPAK_ID). → app_id window = `Lerd`.
2. **`~/.local/share/applications/Lerd.desktop`** — nama file tanpa titik → key derivasi = `Lerd`
   (cocok dengan app_id). `Icon=` = **absolute path**
   `/home/viasco/.local/share/icons/hicolor/128x128/apps/Lerd.png` (karena direktori
   `~/.local/share/icons/hicolor` TIDAK ada di daftar pencarian ikon WSLg).
3. **Ikon 8 ukuran (16–512px) sebagai `Lerd.png`** di `~/.local/share/icons/hicolor/{size}/apps/`.
4. **`C:\Users\bimoh\.wslgconfig`**:
   ```ini
   [system-distro-env]
   WSL2_VM_ID=fooo
   WESTON_RDPRAIL_SHELL_APP_LIST_PATH=/home/viasco/.local/share/applications:/home/viasco/.local/share/flatpak/exports/share/applications
   ```
   (`WSL2_VM_ID` untuk is_system_distro — hilang sejak WSL 2.6.2, issue #1388;
   `WESTON_RDPRAIL_SHELL_APP_LIST_PATH` menambah folder scan desktop file — default hanya
   `/usr/share/applications` dkk, lokasi Lerd tidak di-scan.)

Verifikasi di `/mnt/wslg/weston.log`:
```
appId: Lerd
Icon name:/home/viasco/.local/share/icons/hicolor/128x128/apps/Lerd.png
Icon image:0x7af9c0002450   (non-nil = ikon termuat)
appIcon: 0x7af9c0002450
```

Catatan: overlay penguin kecil di pojok ikon taskbar adalah bawaan WSLg
(`WESTON_RDPRAIL_SHELL_BLEND_OVERLAY_ICON_TASKBAR`), bukan kesalahan.
File di dalam flatpak (`main.js`, `preload.js`, `package.json`) hilang saat `flatpak update`
→ jalankan `lerd-dark-titlebar.sh` lagi (sudah mencakup ketiganya). File di luar flatpak
(desktop file, ikon, .wslgconfig) bertahan.

Catatan: kalau suatu saat WSL di-update dan Start Menu/taskbar jadi aneh, hapus file ini
(workaround bisa bentrok dengan fix resmi yang memakai nilai WSL2_VM_ID asli).

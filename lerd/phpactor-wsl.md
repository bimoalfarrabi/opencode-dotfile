# PHPactor di WSL — LSP Zed lewat container lerd

Dokumentasi perbaikan language server **phpactor** saat Zed (remote, berjalan di
WSL) gagal memulai phpactor. Ini masalah **per-host** (binary PHP/phpactor bukan
bagian repo), jadi ditulis agar mudah direplikasi ke mesin WSL baru.

## Gejala

Zed menampilkan error pada language server phpactor:

```
failed to spawn command Command(cd ".../simasiwa" && ... "C:/Users/bimoh/AppData/Roaming/Composer/vendor/bin/phpactor.bat")
  ... No such file or directory (os error 2)
```

Ciri khasnya: path `.bat` **Windows** yang dijahit salah (path `C:/...` di
prefiks `/home/...`), dan error `os error 2` (file tidak ada).

## Akar masalah

- Zed dijalankan sebagai **remote di WSL** (`ZED_ENVIRONMENT=worktree-shell`).
- PATH di dalam WSL mencakup direktori **Windows** — termasuk
  `/mnt/c/Users/<user>/AppData/Roaming/Composer/vendor/bin` — sehingga
  `which phpactor` memilih **`phpactor.bat`** (wrapper Windows).
- WSL **tidak bisa mengeksekusi `.bat`**, dan path `C:/...` tidak valid di WSL →
  spawn gagal.
- Konteks tambahan: WSL pada mesin ini **tidak punya PHP asli**. PHP dijalankan
  lewat shim `~/.local/share/lerd/bin/php` yang meneruskan ke container
  `lerd-php<ver>-fpm` (di sini PHP 8.2).

## Solusi: phpactor di home composer terpisah + shim lerd

Prinsip: instal phpactor **di dalam container PHP** via `lerd`, di **home
composer khusus** (bukan global `laravel/installer`), lalu lerd otomatis membuat
shim Linux yang mengeksekusi phpactor di container. Shim ini **mendahului**
direktori Windows di PATH, sehingga Zed memakai yang benar.

### Kenapa home terpisah

`~/.config/composer` (global lerd) berisi `laravel/installer` yang sudah
membutuhkan PHP 8.3+ (lewat `illuminate/filesystem`). Instalasi phpactor di sana
gagal karena container berjalan PHP 8.2. Pakai `COMPOSER_HOME` sendiri agar tidak
bentrok.

### Langkah (idempotent)

```sh
# 1. Buat home composer khusus
mkdir -p ~/.lerd-phpactor
cat > ~/.lerd-phpactor/composer.json <<'EOF'
{
    "minimum-stability": "dev",
    "prefer-stable": true
}
EOF

# 2. Instal phpactor di home itu, DARI konteks situs yang ter-link,
#    supaya lerd pakai container PHP 8.2 (bukan PHP host yang salah versi).
#    Catatan: phpactor versi terbaru menarik dependensi dev-master, jadi
#    minimum-stability: dev + prefer-stable: true wajib.
cd /path/ke/situs      # contoh: ~/Koding/simasiwa
COMPOSER_HOME="$HOME/.lerd-phpactor" \
  ~/.local/bin/lerd composer global require phpactor/phpactor --no-interaction
```

Setelah selesai, lerd **otomatis** membuat shim Linux:

```sh
# ~/.local/share/lerd/bin/phpactor  (isi contoh)
#!/bin/sh
# lerd-managed composer global shim
exec "/home/viasco/.local/bin/lerd" php "/home/viasco/.lerd-phpactor/vendor/bin/phpactor" "$@"
```

Karena `~/.local/share/lerd/bin` muncul **sebelum** folder Windows di PATH,
`which phpactor` di WSL memilih shim ini (yang menjalankan phpactor di dalam
container PHP 8.2 — konsisten dengan versi project).

> ⚠️ **PATH saja tidak cukup.** Jika GUI Zed berjalan di **Windows** dan remote
> server-nya di WSL, Zed me-resolve binary phpactor dari **sisi Windows**
> (memilih `phpactor.bat`) dan me-join path `C:/...` ke cwd WSL — PATH di WSL
> **tidak** dipakai untuk resolusi ini. Maka **wajib** memaksa binary path lewat
> config Zed (lihat di bawah), selain shim di PATH.

## Template config Zed (`~/.config/zed/settings.json`)

Tulis di sisi **WSL/Linux** tempat remote server berjalan (bukan sisi Windows):

```json
{
  "lsp": {
    "phpactor": {
      "binary": {
        "path": "/home/<user>/.local/share/lerd/bin/phpactor",
        "arguments": []
      }
    }
  }
}
```

- Key LSP **`phpactor`** dan shape `binary → path/arguments` dikonfirmasi dari
  source Zed (`crates/settings_content/src/project.rs`, struct `BinarySettings`).
- Ganti `<user>` dengan user WSL (contoh: `/home/viasco/...`).
- Berlaku per-mesin: file ini **bukan** bagian repo dotfile (berisi path absolut).
- File ini dibuat manual; tidak ada script setup yang menuliskannya.

## Verifikasi

```sh
which -a phpactor
# → /home/viasco/.local/share/lerd/bin/phpactor   (Linux shim, harus yang pertama)
# → /mnt/c/Users/bimoh/AppData/Roaming/Composer/vendor/bin/phpactor  (jangan dipakai)

~/.local/share/lerd/bin/phpactor --version   # → Phpactor 2026.07.22.0

# STDIO passthrough (dipakai protokol LSP):
printf '<?php echo "OK\\n"; ?>' | ~/.local/bin/lerd php

# Handshake LSP initialize:
printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"processId":null,"rootUri":"file:///home/...","capabilities":{}}}\n' \
  | ~/.local/share/lerd/bin/phpactor language-server
```

Lalu di Zed: **restart Zed** (atau reload jendela / `Zed: Restart Language
Server`) agar config WSL-side terbaca dan binary di-resolve ulang. Pastikan
config `~/.config/zed/settings.json` (template di atas) sudah ada — karena Zed
GUI berjalan di Windows, solusi PATH saja tidak menjamin binary yang benar.

## Batasan

- phpactor berjalan **di container lerd** → butuh lerd aktif (`lerd start`).
  Setelah `lerd stop`, LSP phpactor mati sampai container dijalankan ulang.
- Versi PHP phpactor mengikuti container situs yang dipakai saat `composer global
  require` (di sini 8.2). Bila project berganti PHP version, re-install di
  konteks yang sesuai bila diperlukan.

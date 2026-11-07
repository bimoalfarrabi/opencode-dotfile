# Lerd di WSL2 — setup lengkap

Modul ini menyimpan seluruh setup Lerd di mesin ini: integrasi Windows
(`lerd.exe`, `wsl:setup`, tray + toast), shell/PATH, trust HTTPS, DNS, dan
opsional GUI Flatpak sebagai cadangan.

**Status terverifikasi:** `lerd doctor` → `All checks passed.`

## Urutan setup (mesin baru)

Prasyarat: Ubuntu 22.04+ / Debian 12+ di WSL2 dengan **systemd** aktif.

```sh
git clone git@github.com:bimoalfarrabi/opencode-dotfile.git
cd opencode-dotfile
```

### 1. Lerd di dalam distro

```sh
curl -fsSL https://lerd.sh/install.sh | bash
```

Saat installer bertanya soal DNS: pilih **Yes** (`.test` + HTTPS).

> **JANGAN pakai `Install-Lerd.exe`.** Installer itu hardcode
> `const Distro = 'Ubuntu-24.04'` dan memanggil
> `wsl --install -d Ubuntu-24.04 --no-launch --web-download` tanpa cabang.
> Kalau distro-mu bernama lain (mis. `Ubuntu`), ia akan membuat distro **kedua
> yang kosong**, lalu `wsl:setup` di dalamnya membajak integrasi Windows —
> `lerd-wsl.conf` menunjuk distro kosong, NRPT rule di-replace, PATH dan Run key
> ditimpa. Site-mu tertinggal di distro lama dan tak terlihat dari Windows.

### 2. Integrasi Windows

```sh
./lerd/setup-wsl2.sh          # .wslconfig, lerd.exe, node:manage, wsl:setup
```

Lalu dari **PowerShell**:

```powershell
wsl --shutdown
```

(Satu-satunya langkah yang tidak bisa dilakukan dari dalam distro.)

### 3. Desktop app Windows — tray + notifikasi toast

```sh
./lerd/setup-desktop-app.sh
```

### 4. Shell, browser, DNS

```sh
./shell/setup-zsh.sh          # PATH, BROWSER, environment.d, completions
./lerd/dns/lerd-dns-fix.sh    # kalau resolusi internet di WSL bermasalah
```

Trust CA di browser: lihat `nss-ca-trust.md`. Verifikasi dengan
`bash -lc 'lerd doctor'`.

---

## Tiga jalur yang berbeda — jangan tertukar

| Jalur | Apa | Status di repo ini |
|---|---|---|
| **Windows-native** (`lerd.exe` + `wsl:setup`) | CLI `lerd`/`php`/`node` dari Windows, DNS `.test` via NRPT, firewall Hyper-V, agent di HKCU Run | **Utama.** `setup-wsl2.sh` |
| **Desktop app Windows** | Tray icon + notifikasi toast, agent disupervisi app | **Utama.** `setup-desktop-app.sh` |
| **Flatpak Linux (WSLg)** | GUI Electron di dalam WSL, dark title bar hasil patch | **Cadangan.** `setup-lerd.sh` |

Ketiganya bisa hidup bersama. Flatpak tidak jalan otomatis; buka dengan
`lerd-dashboard` kalau perlu.

---

## Yang dipasang `setup-wsl2.sh`

| # | Komponen | Lokasi | Efek |
|---|----------|--------|------|
| 1 | `.wslconfig` | `C:\Users\<user>\.wslconfig` | `[general] instanceIdleTimeout=-1` + `[experimental] hostAddressLoopback=true`. **Tanpa `instanceIdleTimeout=-1` distro dimatikan beberapa detik setelah terminal terakhir ditutup dan semua site ikut mati.** Backup otomatis dibuat. |
| 2 | `lerd.exe` | `~/.local/bin/lerd.exe` | Sisi Windows: path shim + agent login. **Dibundel di dalam tarball Linux**, tidak ada aset rilis terpisah. |
| 3 | `lerd node:manage` | `~/.config/lerd/config.yaml` | `node.managed: true`, default 22 — supaya build di shell memakai Node yang sama dengan worker. **Ikut menulis shim `node`/`npm`/`npx` ke `~/.local/share/lerd/bin`, yang membelokkan `npm i -g` ke prefix lerd.** |
| 4 | `lerd wsl:setup` | `%LOCALAPPDATA%\lerd\bin` | 19 shim (`lerd.exe`, `php.exe`, `node.exe`, …), `lerd-wsl.conf`, NRPT rule `.test`, firewall Hyper-V `lerd-lan`, agent. |

Langkah 3 bisa dilewati dengan `./setup-wsl2.sh --no-node`; konsekuensinya
dibahas di [Node yang dimanage lerd vs CLI global dari nvm](#node-yang-dimanage-lerd-vs-cli-global-dari-nvm).

`wsl:setup` idempoten dan **tidak** membuat backup `.wslconfig` / `/etc/wsl.conf`
/ `containers.conf` — file ditulis truncating. Karena itu `setup-wsl2.sh`
membuat backup `.wslconfig` sendiri.

### Detail `lerd.exe` yang sering bikin bingung

`lerd update` **seharusnya** memulihkan `lerd.exe` (`companionBinaries()`
mengembalikan `{"lerd-tray","lerd.exe"}` di WSL), tapi `runUpdate` berhenti
lebih awal saat sudah versi terbaru, sehingga `replaceCompanion` tidak pernah
jalan. Selain itu `replaceCompanion` **diam-diam return** kalau file sumber
tidak ada.

Jadi kalau `wsl:setup` gagal dengan:

```
✗ Windows integration: lerd.exe is not installed next to /home/…/.local/bin/lerd
```

ambil manual dari tarball:

```sh
VER=$(lerd version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
tmp=$(mktemp -d)
gh release download "v$VER" --repo lerd-env/lerd \
  -p "lerd_${VER}_linux_amd64.tar.gz" -D "$tmp"
tar -xzf "$tmp/lerd_${VER}_linux_amd64.tar.gz" -C "$tmp" lerd.exe
install -m 755 "$tmp/lerd.exe" ~/.local/bin/lerd.exe
rm -rf "$tmp"
```

Catatan: `lerd.exe` ada **di dalam tarball Linux** (`.goreleaser.yml`
membundelnya lewat `files: src: dist/lerd-windows-amd64_…/lerd.exe`). Kalau
unduhan terputus, `tar -tzf` tetap bisa membaca header dan `lerd.exe` biasanya
sudah lengkap di depan arsip — ukuran harus `3160064` byte.

---

## Yang dipasang `setup-desktop-app.sh`

Tidak ada installer terpisah untuk desktop app — hanya zip. Script ini
mereproduksi langkah `lerd.iss` (yang ikut dipaketkan di dalam `app.asar`).

| Key (semua HKCU, tanpa admin) | Nilai | Fungsi |
|---|---|---|
| `Software\Classes\AppUserModelId\sh.lerd.Lerd` | `DisplayName=Lerd`, `IconUri=…\lerd.png` | identitas toast |
| `Software\Classes\lerd` | `URL:Lerd` + `URL Protocol` | skema `lerd://` |
| `Software\Classes\lerd\DefaultIcon` | `<exe>,0` | ikon |
| `Software\Classes\lerd\shell\open\command` | `<exe> "%1"` | handler |
| `…\CurrentVersion\Run\lerd-desktop` | `<exe> --hidden` | autostart tray |
| `%APPDATA%\…\Start Menu\Programs\Lerd\Lerd.lnk` | — | kosmetik |

Lokasi: `%LOCALAPPDATA%\Lerd\desktop` (bukan `C:\Program Files\Lerd` — tidak
butuh admin dan tidak bentrok dengan wizard).

**Ikon tidak ada di zip.** `lerd.png` dan `lerd.ico` diekstrak dari dalam
`resources/app.asar` (`installer/branding/icon-512.png` dan `assets/icon.ico`),
persis seperti `lerd.iss` memetakan `branding\icon-512.png` → `{app}\lerd.png`.
Script melakukannya dengan parser asar kecil (Python, tanpa dependensi).

### Handover agent

Setelah registrasi, `lerd wsl:setup` melaporkan:

```
✓ the Lerd desktop app runs the lerd agent
```

Run key `lerd` (agent mandiri) **dihapus**, tersisa `lerd-desktop`. Ini
disengaja: komentar di `src/agent.js` menyebut exe agent unsigned di Run key
dibaca Defender sebagai malware yang membuat dirinya persisten, dan Defender
pernah mengarantinanya.

### Cara kerja notifikasi

App membuka `ws://127.0.0.1:7073/api/desktop/ws`. Selama app jalan, lerd-ui
menyerahkan toast lewat socket itu; app menampilkannya di bawah
AppUserModelID `sh.lerd.Lerd`. Kalau app tidak jalan, **toast PowerShell
mengambil alih**.

Karena itu `notifications.target` **tetap `native`**. Bantuan
`lerd notify target` berbunyi "Native is Linux only for now", tapi di WSL
maksudnya toast Windows via PowerShell — dan app yang running menimpanya.
`browser` justru menghilangkan fallback itu.

### Jangan tutup app lewat Task Manager

`Stop-Process -Force` membunuh **agent sebagai child process**, dan DNS `.test`
mati sampai app dinyalakan lagi. **Quit dari menu tray tidak begitu** —
`main.js` hanya menyetel flag di `before-quit`, dan `agent.js` menegaskan:

> The agent outlives this app on purpose: quitting the tray must not take DNS
> for the sites with it.

---

## Shell & PATH

`lerd` memasang shim (`php`, `composer`, `node`, `mysql`, …) di
`~/.local/share/lerd/bin`. Shim **harus menang** atas nvm/version manager, dan
hanya boleh muncul **sekali** di `$PATH`.

Pola yang dipakai di `.bashrc`, `.zshrc`, dan `.profile`:

```sh
# buang duplikat lama, lalu prepend
PATH="$(printf '%s' "$PATH" | tr ':' '\n' | grep -v '\.local/share/lerd/bin' | paste -sd:)"
export PATH="/home/viasco/.local/share/lerd/bin:$PATH"
```

Posisi penting:

- `.zshrc` — blok ini diletakkan **setelah** nvm di-source, kalau tidak nvm
  menang di login bersih.
- `.profile` — **ini yang memperbaiki `bash -lc`**, karena `.bashrc` punya guard
  interaktif (`case $- in *i*) ;; *) return;; esac`) sehingga login shell
  non-interaktif tidak pernah sampai baris PATH di sana.

### Jangan bungkus `lerd` dengan fungsi shell

Dulu ada:

```sh
lerd() { if [ $# -eq 0 ]; then flatpak run sh.lerd.Desktop; else "$HOME/.local/bin/lerd" "$@"; fi; }
```

Fungsi itu **menutupi binary CLI** dan rawan membuat `lerd update` / `lerd start`
membuka GUI. Sudah dihapus. GUI sekarang:

```sh
alias lerd-dashboard='flatpak run sh.lerd.Desktop'
```

Ini juga penting karena shim `lerd.exe` di Windows memanggil CLI lewat
`wsl.exe` — fungsi shell tidak akan terpakai.

---

## Node yang dimanage lerd vs CLI global dari nvm

`lerd node:manage` menaruh shim `node`, `npm`, dan `npx` di
`~/.local/share/lerd/bin`, lalu blok PATH di `.zshrc` menaikkannya di atas nvm.
Shim `npm` itu bukan npm biasa — ia memanggil `lerd npm`, yang menetapkan
`npm_config_prefix=$HOME/.local/share/lerd/node-global`.

Akibatnya `npm i -g <paket>` punya dua tujuan berbeda, tergantung shim mana yang
menang saat perintah itu dijalankan:

| Perintah dijalankan dengan | Prefix tujuan | `which <cli>` sesudahnya |
|---|---|---|
| Shim lerd menang (`node.managed: true`) | `~/.local/share/lerd/node-global` | `~/.local/share/lerd/bin/<cli>` |
| nvm menang (lerd unmanage, atau shell tanpa blok PATH lerd) | `~/.nvm/versions/node/<ver>` | `~/.nvm/versions/node/<ver>/bin/<cli>` |

Dua salinan itu tidak saling mengetahui. CLI yang dipanggil dari terminal
mengikuti shim yang menang, bukan salinan yang terakhir di-upgrade.

### Gejala: versi terlihat "turun sendiri"

Paket yang di-upgrade saat shim lerd menang masuk ke prefix lerd. Begitu shell
baru memuat PATH, atau lerd menulis ulang shim-nya, `which` bisa berpindah ke
salinan lain yang umurnya berbulan-bulan. Yang berubah bukan versi paketnya —
yang berubah prefix yang ditunjuk.

Cek kedua salinan sebelum menyimpulkan ada rollback:

```sh
which -a 9router
npm root -g
node -p "require('$HOME/.local/share/lerd/node-global/lib/node_modules/9router/package.json').version" 2>/dev/null
for d in ~/.nvm/versions/node/*/lib/node_modules/9router; do node -p "require('$d/package.json').version"; done
```

### Gejala: `zsh: killed` saat CLI dijalankan

Bukan zsh yang membunuh, dan bukan OOM. Launcher 9router memanggil
`killAllAppProcesses` setiap start: `kill -9` untuk setiap proses node yang
cmdline-nya berisi `9router` dengan `cli.js`/`/9router`, ditambah apa pun yang
cmdline-nya mengandung `next-server`. Jadi menyalakan instance kedua selalu
mematikan instance pertama, termasuk yang sedang dipakai. Perintah shell yang
kebetulan menyebut `next-server` (mis. `grep next-server`) ikut kena. `tmux`
sendiri tidak membunuh apa pun — yang membunuh adalah instance baru di dalamnya.

Cek apakah ada dua instance:

```sh
ps -eo pid,ppid,pgid,tty,stat,cmd | grep -E '9router|next-server' | grep -v grep
```

### Gejala: `Error: EIO error` saat tombol panah ditekan

Menu TUI membaca stdin mentah. `read()` dari controlling terminal hanya sah
untuk foreground process group; kalau prosesnya berada di process group lain
yang sudah orphan, kernel mengembalikan `EIO` dan `cli.js` mencetaknya sebagai
`Error: EIO error`.

Bandingkan `PGID` dengan `TPGID`. Keduanya harus sama:

```sh
ps -o pid,pgid,tpgid,tty,stat,cmd -p $(pgrep -f 'bin/9router$')
```

`Sl+` berarti foreground. `Sl` tanpa `+` dengan `TPGID` berbeda berarti proses
itu tidak boleh membaca terminal, dan panah akan gagal. Pemicunya: dijalankan
sebagai job background (`&`), lewat `nohup`, atau lewat wrapper yang keluar
sebelum 9router selesai (`zsh -c '9router'`, subshell).

Jalankan di foreground:

```sh
9router
```

Untuk background tanpa TUI, pakai mode tray yang tidak membaca stdin:

```sh
nohup 9router --tray --skip-update >/tmp/9router.log 2>&1 &
```

### Memilih satu pemilik

Supaya hanya ada satu salinan yang dipakai, pilih salah satu:

**lerd yang memiliki Node** — semua `npm i -g` masuk prefix lerd, konsisten
dengan worker:

```sh
lerd node:manage
9router --version
```

**nvm yang memiliki Node** — shim dan versi fnm milik lerd dilepas; `npm i -g`
kembali ke nvm:

```sh
lerd node:unmanage
hash -r
which 9router
```

`node:unmanage` mengubah `node.managed` menjadi `false` dan menghapus
`node`/`npm`/`npx` dari `~/.local/share/lerd/bin`, jadi worker lerd yang butuh
Node harus memakai Node sistem atau bun. Direktori prefix
`~/.local/share/lerd/node-global` tidak ikut dihapus; isinya tetap ada dan tetap
dipakai lagi kalau `node:manage` dijalankan ulang, jadi upgrade yang sudah
dilakukan di sana tidak hilang.

---

## Browser di WSL

`~/.local/bin/lerd-browser` meneruskan URL ke Brave Origin (Linux/WSLg), dengan
fallback Brave Windows, lalu **path absolut** `cmd.exe`:

```sh
WIN_CMD="/mnt/c/Windows/System32/cmd.exe"
```

Path absolut supaya tetap jalan kalau `/etc/wsl.conf` memakai
`[interop] appendWindowsPath = false`.

Dipasang lewat `BROWSER` di `~/.zshrc` **dan**
`~/.config/environment.d/99-lerd-browser.conf` (untuk portal Flatpak).

Untuk trust sertifikat di browser, lihat **`nss-ca-trust.md`** — nickname-nya
harus `mkcert development CA <serial desimal>`, bukan `Lerd mkcert (viasco)`.

---

## DNS (split-DNS WSL)

**Masalah**: Lerd memakai dnsmasq di port `5300` (link `lerd0`) untuk `*.test`,
dan menulis `/etc/systemd/resolved.conf.d/lerd.conf`. Saat `lerd dns:repair`
(atau `lerd install`) berjalan, file itu bisa ditimpa menjadi **hanya**
`127.0.0.1:5300` sebagai DNS global → semua resolusi internet di WSL gagal.

**Solusi**: `dns/lerd-dns-fix.sh` menulis ulang konfigurasi yang benar:

```
*.test        -> link lerd0     -> 127.0.0.1:5300  (Lerd dnsmasq)
domain lain   -> Global DNS     -> 1.1.1.1 / 8.8.8.8 (internet)
```

Jalankan saat:
- Baru selesai `lerd dns:repair` / `lerd install` / update lerd;
- Internet di WSL tidak bisa resolve setelah restart;
- `resolvectl dns` menunjukkan DNS global hanya `127.0.0.1:5300`.

```sh
./lerd/dns/lerd-dns-fix.sh
```

Script butuh sudo. Verifikasi sendiri: uji `lerd-probe.test` (harus 200) dan
`raw.githubusercontent.com`. Catatan: `127.0.0.1:5300` yang muncul di baris
`Global:` adalah artefak tampilan systemd-resolved (DNS per-link `lerd0`),
bukan DNS global kedua.

**Catatan kaki**: alias `lerd-dns` di `.zshrc` sudah dihapus — jalankan
script-nya langsung supaya jelas apa yang dieksekusi.

---

## Update Lerd — dua kanal

| Kanal | Perintah | Yang diperbarui |
|---|---|---|
| CLI | `lerd update` | binary di `~/.local/bin/lerd`, `lerd-tray`, dan `lerd.exe` (kalau tidak short-circuit) |
| Flatpak | `flatpak update sh.lerd.Desktop` lalu `./lerd/apply-patch.sh` | GUI Linux; **patch dark title bar harus di-apply ulang** |

Diagnosa versi:

```sh
lerd version
curl -s http://127.0.0.1:7073/api/version
```

Dashboard yang menampilkan versi lama setelah `lerd update` biasanya karena
`lerd-ui` masih proses lama:

```sh
systemctl --user restart lerd-ui
```

---

## Verifikasi cepat

```sh
bash -lc 'lerd doctor'                 # harus: All checks passed.
bash -lc 'node -v; php -v | head -1'   # 22.x, 8.5.x (shim lerd; 22.x hanya bila node:manage aktif)
zsh  -ic 'node -v'                     # 22.x dengan node:manage, versi nvm bila unmanage
curl -sS -o /dev/null -w '%{http_code}\n' https://titit.test   # 302/200
```

Dari PowerShell:

```powershell
lerd --version
Resolve-DnsName titit.test      # ::1 + 127.0.0.1
curl.exe https://titit.test     # 200
```

`curl.exe` menolak sertifikat `.test` karena meminta revocation check —
itu normal, browser tetap aman. Pakai `--ssl-no-revoke` kalau perlu.

---

## Struktur modul

```
lerd/
├── README.md                 # dokumen ini
├── setup-wsl2.sh             # .wslconfig + lerd.exe + node:manage + wsl:setup
├── setup-desktop-app.sh      # tray + toast Windows (ekstrak asar, registrasi HKCU)
├── nss-ca-trust.md           # trust HTTPS di browser (nickname mkcert)
├── DIAGNOSIS.md              # catatan debug historis (dark title bar, ikon WSLg)
├── setup-lerd.sh             # [cadangan] Flatpak WSLg: patch + desktop entry + ikon
├── apply-patch.sh            # [cadangan] patch dark title bar di dalam flatpak
├── dns/lerd-dns-fix.sh       # split-DNS WSL
├── phpactor-wsl.md           # LSP phpactor via container lerd
├── assets/hicolor/           # ikon untuk Flatpak desktop entry
└── templates/                # Lerd.desktop + .wslgconfig.example
```

## Revert

**Integrasi Windows:**

```sh
lerd wsl:setup      # idempoten; tidak ada perintah revert khusus
```

Hapus manual kalau perlu: `%LOCALAPPDATA%\lerd`, entri PATH User, NRPT rule
ber-`Comment=lerd`, firewall `lerd-lan`, dan key `HKCU\Software\Classes\lerd`.

**Desktop app:**

```powershell
Remove-Item 'HKCU:\Software\Classes\AppUserModelId\sh.lerd.Lerd' -Recurse
Remove-Item 'HKCU:\Software\Classes\lerd' -Recurse
Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'lerd-desktop'
Remove-Item "$env:LOCALAPPDATA\Lerd" -Recurse -Force
```

lalu jalankan `lerd wsl:setup` supaya agent kembali ke Run key sendiri.

**Flatpak:** lihat bagian Revert di `DIAGNOSIS.md`.

---

### Resolusi *.test di Windows

Agent DNS Windows (`lerd.exe --agent`) bind `127.0.0.1:53`, tapi **NextDNS**
(`NextDNSService`, "DNS53 to DoH proxy", plus driver WFP `NextDNSEngine.sys`)
mencegat setiap query DNS yang sah di port 53 sebelum sampai ke socket — lerd
tidak punya cara mendeteksinya, sehingga `*.test` tidak pernah resolve di sisi
Windows. Di mesin ini `NextDNSService` sudah di-stop dan di-Disable, jadi agent
bekerja native. Workaround di bawah tetap dipakai karena Brave memakai secure
DoH yang melewati resolver sistem:
`bash lerd/sync-windows-hosts.sh` menulis semua domain site terdaftar dari
`sites.yaml` sebagai `127.0.0.1` di hosts Windows dalam blok bertanda
`# >>> lerd` (satu prompt UAC, backup + flushdns otomatis). Dengan mirrored
networking, `127.0.0.1:443` Windows menjangkau nginx di WSL, jadi entri hosts
cukup. Pakai `--check` untuk cek drift tanpa menulis, `--dry-run` untuk
melihat bloknya. **Jalankan ulang setiap kali menambah atau mengganti nama
site.**

Diagnosis lengkap + bukti bisect-nya (kenapa agent DNS Windows tidak menerima
query yang sah, dan kenapa `dnsTunneling=true` sengaja tidak diubah):
`windows-dns-diagnosis.md`.

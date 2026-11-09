# Obscura — mesin browser headless untuk MCP

[Obscura](https://github.com/h4ckf0r0day/obscura) adalah browser engine headless
yang ditulis dalam **Rust**. Ia menjalankan JavaScript sungguhan lewat **V8**,
bicara **Chrome DevTools Protocol (CDP)**, dan menyediakan **MCP server** sendiri.
Repo ini memakainya sebagai pengganti headless Chrome untuk tugas browsing agent:
buka halaman, snapshot, klik, isi form, ambil teks/markdown, screenshot, PDF.

Ringkasnya: **bukan pengganti Playwright** (Playwright tetap dipakai kalau butuh
test suite penuh), tapi pengganti *browser-nya* — lebih ringan, tanpa unduhan
Chromium 300 MB, dan fingerprint-nya sudah dibersihkan.

## Kenapa dipakai di sini

| | Obscura | Chromium headless |
|---|---|---|
| RAM (mode MCP, idle → halaman termuat) | **19 MB → 51 MB** | ±450 MB |
| RAM (mode `serve` + CDP) | 136 MB (4 proses) | 434 MB (6 proses) |
| Startup dingin | 3.6 s | 1.4 s |
| Navigasi kedua (warm) | 293 ms | 208 ms |
| Unduhan | binary 72 MB | Chromium ±300 MB + Node |
| Anti-fingerprint | bawaan (`--stealth`) | tidak ada |

Angka di atas diukur di mesin WSL2 (Ubuntu 26.04, 16 core) pada halaman yang sama
(`news.ycombinator.com` lalu `example.com`), bukan angka brosur. Kesimpulannya:
**menang di memori dan kesederhanaan, kalah di startup dingin.** Untuk agent yang
membuka satu-dua halaman per tugas, itu trade-off yang bagus karena browser
di-reuse sepanjang sesi MCP.

## Instalasi

### Linux / WSL2

`setup-linux.sh` sudah menanganinya (idempoten — dilewati kalau `obscura` sudah
ada di PATH):

```sh
./setup-linux.sh
```

Manual:

```sh
mkdir -p ~/.local/bin
curl -fsSL https://github.com/h4ckf0r0day/obscura/releases/download/v0.2.6/obscura-x86_64-linux-stealth.tar.gz \
  | tar -xz -C /tmp
install -m 0755 /tmp/obscura /tmp/obscura-worker ~/.local/bin/
obscura --version    # 0.2.6
```

Arsitektur lain: ganti `x86_64` dengan `aarch64`.

### Windows (native)

`setup-windows.ps1` mengunduh zip, menaruhnya di
`%LOCALAPPDATA%\obscura\bin`, dan menambahkannya ke user PATH:

```powershell
.\setup-windows.ps1
```

Manual: unduh `obscura-x86_64-windows-stealth.zip` dari
[Releases](https://github.com/h4ckf0r0day/obscura/releases), ekstrak, tambahkan
folder itu ke PATH. **Tidak butuh** Visual Studio build tools.

### Varian rilis

| Suffix arsip | Rendering (screenshot/PDF) | Stealth (anti-detect + tracker block) |
|---|---|---|
| *(tanpa suffix)* | ya | tidak |
| `-stealth` | ya | **ya** ← yang dipakai repo ini |
| `-no-render` | tidak | tidak |
| `-no-render-stealth` | tidak | ya |

Repo ini memakai **`-stealth`**: butuh screenshot/PDF *dan* ingin fingerprint bersih.

## Wiring MCP

Entri di `config/opencode.json.template`:

```json
"obscura": {
  "type": "local",
  "command": ["{{OBSCURA_BIN}}", "mcp", "--stealth", "--allow-private-network"],
  "enabled": true
}
```

- `{{OBSCURA_BIN}}` di-resolve `scripts/render-config.mjs`: `~/.local/bin/obscura`
  kalau ada, kalau tidak nama polos `obscura` (biar PATH yang menentukan — penting
  di Windows, karena binary-nya `.exe`). Override lewat env `OBSCURA_BIN`.
- `--stealth` — fingerprint randomization + blokir 3.520 domain tracker/analytics.
- `--allow-private-network` — **wajib** kalau agent perlu membuka dev server lokal
  (`http://127.0.0.1:3000`, site lerd `*.test`). Tanpa flag ini SSRF guard menolak
  loopback/RFC1918 secara default:

  ```
  Error: Access to private/internal IP address 127.0.0.1 is not allowed
  ```

  Kalau tidak butuh, hapus saja flag-nya — lebih aman.

Setelah render + restart OpenCode, server muncul di `/mcp` dengan **38 tool**.

## Tool yang tersedia

Dikelompokkan biar gampang dipilih:

- **Navigasi**: `browser_navigate`, `browser_back`, `browser_forward`, `browser_reload`
- **Baca halaman**: `browser_snapshot` (URL + title + ref elemen + teks terlihat),
  `browser_markdown`, `browser_links`, `browser_extract`, `browser_search`,
  `browser_count`, `browser_get_attribute`
- **Interaksi**: `browser_click`, `browser_fill`, `browser_type`,
  `browser_press_key`, `browser_select_option`, `browser_fill_form`,
  `browser_detect_forms`, `browser_scroll`, `browser_interactive_elements`
- **Tunggu**: `browser_wait_for`, `browser_wait_for_text`, `browser_wait_for_function`
- **Tab**: `browser_tab_new`, `browser_tab_list`, `browser_tab_switch`, `browser_tab_close`
- **Sesi/auth**: `browser_get_cookies`, `browser_set_cookie`,
  `browser_clear_cookies`, `browser_storage_state`, `browser_set_storage_state`
- **Diagnostik**: `browser_evaluate`, `browser_console_messages`,
  `browser_network_requests`
- **Output**: `browser_screenshot` (PNG), `browser_pdf`
- **Lain**: `browser_close`

`browser_snapshot` mengembalikan **ref** (`ref=e1-1`) yang dipakai tool interaksi —
jauh lebih hemat token daripada mengirim HTML penuh.

## Verifikasi cepat

```sh
# Lewat CLI, tanpa MCP
obscura fetch https://example.com --dump text
obscura fetch https://news.ycombinator.com --dump markdown

# Cek fingerprint
obscura serve --port 9222 --stealth
# lalu dari sesi OpenCode: browser_evaluate → navigator.webdriver (harus false)
```

Hasil uji di mesin ini (`bot.sannysoft.com`):

| Cek | Hasil |
|---|---|
| WebDriver (new) | missing (passed) |
| WebDriver advanced | passed |
| `navigator.webdriver` | `false` |
| UA | `Mozilla/5.0 (Windows NT 10.0; Win64; x64) … Chrome/145.0.0.0` |
| `navigator.plugins.length` | 5 |
| `userAgentData` | brands + platform lengkap |
| `Function.prototype.toString.call(...)` | `function querySelector() { [native code] }` |

Uji halaman nyata: `react.dev` (SPA, render penuh), `x.com` (halaman login tampil,
tidak kena bot wall), `github.com` (504 — dari GitHub sendiri, Chromium asli juga 504).

## Pakai sebagai CDP server (Playwright/Puppeteer)

Untuk scraping terprogram yang tidak lewat MCP:

```sh
obscura serve --port 9222 --stealth
```

```js
import { chromium } from 'playwright-core';
const browser = await chromium.connectOverCDP('http://127.0.0.1:9222');
const page = (browser.contexts()[0] || await browser.newContext()).newPage();
await page.goto('https://example.com');
```

Ini **parity API**: kode Playwright yang sudah ada jalan tanpa diubah, hanya
endpoint-nya yang beda.

## Batasan & catatan

- **Startup dingin lebih lambat** (V8 init ±3.6 s). Untuk MCP tidak terasa karena
  prosesnya hidup sepanjang sesi; untuk `obscura fetch` sekali pakai, terasa.
- **Bukan test runner.** Tidak ada `expect`, fixture, atau trace viewer. Kalau butuh
  E2E test suite, tetap pakai Playwright dengan Chromium.
- **Rendering lebih sederhana** dari Blink. Halaman dengan CSS sangat rumit, WebGL
  berat, atau WebRTC bisa tampil beda. Screenshot boleh, jangan jadikan patokan
  pixel-perfect.
- **`--allow-private-network` membuka SSRF.** Aktif di config ini demi dev server
  lokal. Matikan kalau agent hanya perlu internet publik.
- **Tracker blocking bisa merusak situs** yang bergantung pada script analytics-nya
  sendiri. Kalau ada halaman yang gagal render, coba tanpa `--stealth` dulu.
- **`obey-robots` tidak diaktifkan.** Tambahkan `--obey-robots` kalau scraping situs
  yang robots.txt-nya jelas.
- Verifikasi versi: `obscura --version`. Naikkan `OBSCURA_VERSION` saat setup untuk
  memaksa versi lain (default `0.2.6`).

## Referensi

- Repo: https://github.com/h4ckf0r0day/obscura
- Docs: https://github.com/h4ckf0r0day/obscura/tree/main/docs
- Situs: https://obscura.sh

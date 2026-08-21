# oh-my-opencode-slim — preset agent & model

Dokumentasi preset routing agent/model **oh-my-opencode-slim** (OMO-Slim) di repo ini:
penjelasan per role, daftar model aktif, dan cara mengganti model.

## Apa itu OMO-Slim

Plugin `oh-my-opencode-slim` (diaktifkan lewat `config/tui.json` →
`"plugin": ["oh-my-opencode-slim"]`) membaca **satu file preset JSON** dan men-generate
definisi agent + model di OpenCode saat start. Artinya: semua routing role → model
dikendalikan dari satu file, bukan per-command.

File:
- **Source of truth (repo):** `config/oh-my-opencode-slim.json`
- **Live (dipakai OpenCode):** `~/.config/opencode/oh-my-opencode-slim.json`
  (disalin oleh `setup-linux.sh` — jaga keduanya sinkron; sesuaikan live bila edit manual).

## Struktur preset

```jsonc
{
  "preset": "opencode-go",        // preset yang AKTIF (openai | opencode-go)
  "presets": {
    "openai":      { "<role>": { "model": "openai/...", "variant": "...", "skills": [], "mcps": [] } },
    "opencode-go": { "<role>": { "model": "9router/...",  "variant": "...", "skills": [], "mcps": [] } }
  },
  "council": { "presets": { "default": { "alpha": {"model": "kenari/..."}, /* beta, gamma, delta */ } } },
  "disabled_agents": []
}
```

- `preset` — preset aktif (default: `opencode-go`, pakai router `9router`; preset alternatif
  `openai` memakai provider OpenAI langsung).
- `variant` — "lebar konteks" role (opsional): `low` / `medium` / `high` / `xhigh` / `max`.
- `skills` — skill yang dimuat untuk role (`"*"` = semua, `[]` = tidak ada).
- `mcps` — MCP servers yang boleh diakses role (`"*"` = semua, `"!context7"` = kecualikan).

## Peran (role) & model aktif — preset `opencode-go`

| Role | Fungsi / kapan dipakai | Model (default aktif) | Variant | Akses |
|------|------------------------|----------------------|---------|-------|
| **orchestrator** | Koordinator utama: rencana, routing, delegasi antar role, integrasi hasil. | `9router/kenari/deepseek-v4-flash` | xhigh | semua skill; semua MCP kecuali context7 |
| **oracle** | Penasihat arsitektur & review: keputusan besar, debugging kompleks, simplifikasi. | `9router/sr-prod/opus-2` | max | skill `simplify` saja |
| **explorer** | Recon kodebase cepat (lokasi file/simbol/pola) — murah & cepat. | `9router/pen-prod/deepseek-v4-flash-0731` | high | – |
| **librarian** | Riset dokumentasi/library eksternal (API, contoh, bug). | `9router/kenari/deepseek-v4-flash` | high | MCP `context7`, `gh_grep` |
| **designer** | UI/UX: layout, styling, polish visual. | `9router/pen-prod/glm-5.2` | – | – |
| **fixer** | Eksekusi implementasi terbatas (tugas mekanis yang jelas). | `9router/kenari/gpt-5-6-luna` | xhigh | – |
| **observer** | Analisis visual media (gambar/PDF/screenshot) — hasil terstruktur. | `9router/moyra-prod/moyra/claude-opus-4.8` | – | – |
| **council** | Konsensus multi-model (sintesis laporan). | `9router/pen-prod/kimi-k3` | – | – |

### Council seats (multi-model)

Untuk mode council, tiap "kursi" memakai model berbeda (ada di
`council.presets.default`):

| Seat | Model |
|------|-------|
| alpha | `kenari/glm-5-2` |
| beta | `kenari/kimi-k2-7-code` |
| gamma | `kenari/gpt-5-6-luna` |
| delta | `kenari/deepseek-v4-flash` |

> Catatan: model council seat ditulis **tanpa** prefix provider (`kenari/...`), berbeda
> dari role preset yang memakai prefix (`9router/...` / `openai/...`).

## Cara ganti model

### 1. Per role (preset aktif)

Edit `config/oh-my-opencode-slim.json` → blok `presets."opencode-go".<role>.model`:

```jsonc
"fixer": { "model": "9router/kenari/gpt-5-6-luna", "variant": "xhigh" }
// ganti menjadi, mis.:
"fixer": { "model": "9router/kenari/deepseek-v4-flash", "variant": "xhigh" }
```

**Syarat model id**: harus valid untuk provider yang dikonfigurasi. Format
`<provider>/<model-id>` — untuk `9router/...` model harus ada di
`provider.9router.models` (lihat `config/opencode.json.template`), untuk `openai/...`
di `provider.openai.models`. Model yang belum didaftarkan tidak akan dipakai.

### 2. Ganti seluruh preset (ke OpenAI)

Ubah nilai `"preset"`:

```jsonc
"preset": "openai"   // memakai provider OpenAI (gpt-5.6-terra dll)
```

### 3. Ganti model council seat

```jsonc
"council": { "presets": { "default": { "alpha": { "model": "kenari/glm-5-2" } } } }
```

### 4. Terapkan perubahan

1. Edit file **repo** (`config/oh-my-opencode-slim.json`), lalu sinkronkan ke live:
   ```sh
   cp config/oh-my-opencode-slim.json ~/.config/opencode/oh-my-opencode-slim.json
   # atau jalankan ulang setup: ./setup-linux.sh   (menyalin config)
   ```
2. **Restart OpenCode** — plugin membaca preset saat start (perubahan tidak hot-reload).
3. Verifikasi: panggil role tertentu (`/agent fixer`, dst.) dan cek model di baris prompt.

### Override sementara (tanpa mengedit preset)

- Pilih role saat menjalankan: `opencode --agent <role>`
- Override model satu pemanggilan: `opencode --agent <role> --model <model-id>`
- Di sesi interaktif: perintah `/agent` / `/model`.

## Tips

- **Biaya/kecepatan**: role "berat" (oracle, council) memakai model besar (opus/kimi);
  role "ringan" (explorer, librarian, fixer) memakai model murah-cepat (deepseek/gpt-5-6-luna).
  Sesuaikan di sini tanpa menyentuh kode.
- **Variant** tidak wajib; hilangkan bila tidak perlu mengatur lebar konteks.
- Simpan perubahan preset di **repo** supaya ikut migrasi (`setup-linux.sh` menyalinnya).
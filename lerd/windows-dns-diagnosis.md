# Windows DNS untuk `*.test` — diagnosis

Tanggal: 2026-11-06. Gejala: `https://project-management.test/` di browser Windows →
`DNS_PROBE_POSSIBLE` / "DNS address could not be found". Di WSL (Brave Origin) normal.

## Ringkas

| Lapisan | Status |
|---|---|
| nginx + PHP di WSL | **sehat** — `curl https://project-management.test` → 200 |
| Transport Windows → WSL | **sehat** — `curl.exe --resolve project-management.test:443:127.0.0.1` → **HTTP 200**, cert verify 0 |
| CA lerd di Windows | dipercaya (verify result 0 pada request yang berhasil) |
| Agent DNS lerd (`lerd.exe --agent`) | hidup, memegang `127.0.0.1:53`, tapi **tidak pernah menjawab query DNS yang sah** |
| Windows DNS client / NRPT | gagal resolve, karena query-nya tidak pernah dijawab |
| Brave | tambahan: secure DoH aktif → melewati NRPT sepenuhnya |

Jadi masalahnya **hanya** di resolusi `*.test` pada sisi Windows. Bukan nginx, bukan TLS,
bukan WSL.

## Bukti kunci

Agent hidup dan socket-nya benar:

```
lerd.exe pid=7520  C:\Users\bimoh\AppData\Local\lerd\bin\lerd.exe --agent
127.0.0.1:53   pid=7520  lerd
0.0.0.0:53     pid=2576  svchost
log: "2026/11/06 20:12:00 answering *.test on 127.0.0.1:53"
```

Query DNS **sah** (QDCOUNT=1) tidak pernah dijawab — `nslookup`, `Resolve-DnsName -Server
127.0.0.1`, dan klien UDP mentah, semuanya timeout. Tapi query **cacat** dijawab seketika oleh
agent yang sama. Bisect satu field per perubahan (3x tiap varian, hasil konsisten):

| Paket | Hasil |
|---|---|
| QDCOUNT=256, qtype=256 | **dijawab** (NOERROR, ancount=0) |
| QDCOUNT=**1**, qtype=256 | **timeout** |
| QDCOUNT=256, flags RD=1 | dijawab |
| QDCOUNT=256, qtype=**A** | dijawab — `ancount=1`, A=127.0.0.1 |
| QDCOUNT=256, qclass=IN | dijawab |
| **QDCOUNT=1** (query normal) | **timeout** |

Satu-satunya field yang membunuh jawaban adalah **QDCOUNT=1** — yaitu bentuk query DNS yang
dikirim semua klien sungguhan. Kontrol: kedua paket yang sama dikirim ke listener UDP biasa di
`127.0.0.1:5399` dan **keduanya sampai**, jadi pengirimnya bukan penyebab.

Artinya `winshim.Answer` (lerd) tidak pernah menerima query yang sah; datagram-nya ditelan
sesuatu lebih dulu. Kandidat: listener wildcard `0.0.0.0:53` milik `svchost` (host HNS /
iphlpsvc / SharedAccess). Menjalankan `Stop-Service SharedAccess` (elevated) **tidak**
menghilangkan endpoint itu dan tidak memperbaiki apa pun; ICS juga tidak sedang membagi koneksi
(tidak ada `192.168.137.1`), jadi ICS bukan penyebabnya.

## Kenapa WSL tidak terpengaruh

WSL memakai jalur sendiri: `systemd-resolved` → `lerd0` (`~test`) → `lerd dns-serve` di
`127.0.0.1:5300`, yang menjawab `A 127.0.0.1` untuk semua nama di bawah TLD. Itu resolver yang
**berbeda** dari agent Windows, di port yang berbeda, dan tidak tersentuh masalah port 53.

`/etc/wsl.conf` sudah `generateResolvConf=false`, dan `resolv.conf` dikelola systemd-resolved —
jadi WSL **tidak** bergantung pada `dnsTunneling`.

## Dua perbaikan

### 1. Menyingkirkan benturan port 53 (perbaikan akar)

`networkingMode=mirrored` + `dnsTunneling=true` adalah default yang ditulis lerd sendiri
(`internal/wsl/wsl.go:113-114`, `docs/getting-started/wsl2.md:96-121`). Di mesin ini
`0.0.0.0:53` dipegang `svchost`, di atas socket agent yang sudah bind ke `127.0.0.1:53`.

Calon terkuat: `dnsTunneling` (HNS). Karena WSL tidak memakai tunneling (lihat di atas),
mematikannya berbiaya rendah:

```ini
[wsl2]
networkingMode=mirrored
dnsTunneling=false     ; ← tambahan
firewall=true
autoProxy=true
```

lalu `wsl --shutdown` dari Windows. Kalau setelah itu `Resolve-DnsName titit.test` mengembalikan
`127.0.0.1`, akarnya terkonfirmasi dan semua aplikasi Windows (browser apa pun, curl, PHP CLI)
ikut sembuh.

### 2. Bypass di level browser (tanpa restart, tanpa risiko)

`--host-resolver-rules` diproses **sebelum** DNS dan sebelum DoH, jadi `*.test` tidak pernah
masuk ke resolver sama sekali:

```
brave.exe --host-resolver-rules="MAP *.test 127.0.0.1"
```

Dibuktikan setara oleh `curl.exe --resolve project-management.test:443:127.0.0.1` → **HTTP 200**.
Ini juga menembus DoH Brave yang sedang `secure` (kalau DoH dibiarkan, `.test` tetap gagal
walaupun DNS sistem sudah benar — `secure` memakai DoH eksklusif dan tidak menghormati NRPT).

## Catatan untuk laporan upstream

Belum ada issue yang cocok di `lerd-env/lerd` (sudah dicari: `mirrored networking`, `DNS
timeout`, `port 53`, `agent not answering`, `dnsTunneling`). Dua celah nyata:

- Agent bind ke `127.0.0.1:53` tanpa `SO_EXCLUSIVEADDRUSE`; kalau ada socket wildcard
  `0.0.0.0:53`, agent **bind berhasil** tapi tidak menerima apa pun. `serveDNS` hanya
  mendeteksi "port dipakai" lewat error `ListenPacket` (`cmd/lerd-windows/main.go:172-175`),
  jadi keadaan ini tidak pernah terlihat.
- Jalan keluar yang ada cuma `grep` di log agent yang **tidak mencatat query masuk** — tidak
  ada cara membedakan "agent menjawab normal" dari "agent tidak menerima apa-apa".

Reproduksi minim: paket DNS sah (QDCOUNT=1) ke `127.0.0.1:53` tidak dijawab, sementara paket
cacat (QDCOUNT=256) dijawab — bukti socket hidup tapi datagram sah tidak sampai.

## Berkas diagnostik

`/tmp/opencode/dns-*.ps1` (probe, bisect, echo control), hasil elevated di
`C:\Users\bimoh\lerd-dns-elev.txt`.

## Status penerapan

**Sudah dipasang (tanpa admin, tanpa restart):** shortcut desktop
`Brave - lerd (.test).lnk` dengan argumen
`--host-resolver-rules="MAP *.test 127.0.0.1"`.

Cara pakai: **tutup Brave sepenuhnya lebih dulu** (tray → Exit, cek Task Manager tidak ada
`brave.exe`). Kalau tidak, peluncuran baru akan menempel ke instance lama dan flag-nya
diabaikan — perilaku single-instance Chromium.

Kalau berhasil, flag ini juga menembus DoH Brave yang sedang `secure`, jadi DoH tidak perlu
dimatikan. Cakupannya hanya Brave; `nslookup`/`Resolve-DnsName`/aplikasi Windows lain tetap
gagal sampai perbaikan akar dilakukan.

**Belum dipasang (perbaikan akar):** `dnsTunneling=false` di `C:\Users\bimoh\.wslconfig`.
Perlu `wsl --shutdown` dari Windows — distro restart, jadi ini menunggu keputusan pemilik mesin.
Kalau ternyata bukan HNS yang memegang `0.0.0.0:53`, perubahan ini tidak menolong dan harus
dikembalikan (backup `.wslconfig.bak-*` sudah ada dari sesi alignment).

Catatan: dua shortcut Brave lain (`C:\Users\Public\Desktop\Brave.lnk` dan
`C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Brave.lnk`) TIDAK diubah karena butuh
admin. Shortcut Quick Launch milik user juga tidak diubah supaya perilaku lama tidak berubah
diam-diam.

## Solusi final (terpasang 2026-11-06 21:17)

`dnsTunneling=false` **tidak dipakai** — `dnsTunneling=true` adalah nilai yang lerd sendiri
tulis dan rekomendasikan di `docs/getting-started/wsl2.md` ("Mirrored networking (recommended)").
Mengubahnya berarti menyimpang dari dokumen yang justru sedang diselaraskan.

Yang dipakai: **entri hosts Windows**, karena `127.0.0.1:443` Windows sudah terbukti menjangkau
nginx WSL lewat mirrored loopback.

Bukti yang mengarah ke sana: resolver WSL (`lerd dns-serve`) **bisa dijangkau dari Windows** di
`127.0.0.1:5300` dan menjawab benar untuk semua nama, termasuk `google.com` yang diteruskan ke
upstream. Jadi resolver-nya sehat; yang tidak mungkin hanyalah mengarahkan NRPT ke port selain 53.

Terpasang:

- Blok bertanda di `C:\Windows\System32\drivers\etc\hosts` (baris 5727–5749), 21 domain → `127.0.0.1`.
  Backup: `hosts.bak-20261106-211621` dan `hosts.bak-20261106-211752`.
- Atribut **ReadOnly** pada hosts dilepas saat menulis lalu dikembalikan. Ini yang menggagalkan
  percobaan pertama: ACL sudah Full untuk Administrators, jadi `WriteAllText` hanya perlu
  ReadOnly dibersihkan.
- `lerd/sync-windows-hosts.sh` di repo dotfiles (209 baris) + bagian README
  `### Resolusi *.test di Windows`. Mendukung `--check` dan `--dry-run`.

Verifikasi dari Windows, tanpa override apa pun:

```
curl https://project-management.test/   -> HTTP 200  ip=127.0.0.1
curl https://titit.test/                -> HTTP 302
ping project-management.test            -> 127.0.0.1
Resolve-DnsName project-management.test -> 127.0.0.1
```

`nslookup` tetap tidak bisa resolve `*.test` — itu memang tidak membaca hosts, bukan indikasi
kerusakan.

CA lerd sudah ada di `CurrentUser\Root` (thumbprint `9B3200260E66852B104F77401E409A539A3EA6AB`),
jadi Brave memercayainya. `curl.exe` tanpa `-k` gagal karena memakai CA bundle sendiri, bukan
store Windows — juga bukan masalah browser.

Konsekuensi: entri hosts **statis**. Setelah menambah atau mengganti nama site, jalankan ulang
`bash lerd/sync-windows-hosts.sh`; `--check` melaporkan drift.

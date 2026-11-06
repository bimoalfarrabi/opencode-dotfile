# Trust HTTPS `.test` di browser (NSS) — nickname mkcert

Berlaku untuk browser berbasis Chromium/Firefox di Linux (termasuk Brave Origin
via WSLg) yang membaca store NSS di `~/.pki/nssdb`.

## Kenapa `Lerd mkcert (viasco)` TIDAK cukup

Ini kesalahan yang sempat ada di dokumentasi lama. `lerd doctor` memberi:

```
⚠ browser HTTPS trust  the lerd root CA is missing from ~/.pki/nssdb ...
```

padahal CA-nya **ada** dengan fingerprint yang persis sama. Yang salah adalah
**nickname**.

Dari source `internal/certs/browser_trust.go`:

```go
// caNSSNickname is the nickname mkcert stores the root CA under: its own label
// followed by the certificate's serial in decimal. Deriving it the way mkcert
// does is what lets the lookup ask for the CA lerd signs with today rather than
// for whatever certificate happens to wear the mkcert name.
func caNSSNickname(der []byte) string {
	cert, err := x509.ParseCertificate(der)
	if err != nil {
		return ""
	}
	return "mkcert development CA " + cert.SerialNumber.String()
}
```

Pengecekannya bukan sekadar "ada cert bernama X", tapi **verifikasi SSL CA**:

```go
// The check mkcert -install ran: verify the CA for SSL CA use.
if runCertutil("-V", "-d", "sql:"+dir, "-u", "L", "-n", nickname) == nil {
	continue
}
```

Jadi nickname yang benar adalah `mkcert development CA <serial desimal>`,
bukan `Lerd mkcert (viasco)`.

## Perangkap: `certutil -A` gagal senyap

Menambahkan cert yang **sudah ada di wallet** dengan nickname berbeda akan
keluar dengan **exit 0 tetapi tidak menambah apa pun**. Tidak ada peringatan.
Ini yang membuat percobaan "tambahkan saja tanpa menghapus" tampak berhasil
padahal tidak.

## Perbaikan

```sh
CA="${CAROOT:-$HOME/.local/share/mkcert}/rootCA.pem"
SERIAL_HEX=$(openssl x509 -in "$CA" -noout -serial | cut -d= -f2)
SERIAL_DEC=$(printf '%d' "0x$SERIAL_HEX")
NICK="mkcert development CA $SERIAL_DEC"

cp -a "$HOME/.pki/nssdb" "$HOME/.pki/nssdb.bak-$(date +%Y%m%d-%H%M%S)"   # backup dulu

# hapus nickname lama (kalau ada) supaya DER-nya bisa didaftarkan ulang
certutil -D -d sql:"$HOME/.pki/nssdb" -n "Lerd mkcert (viasco)" 2>/dev/null || true

# daftarkan dengan nickname yang diharapkan lerd
certutil -A -d sql:"$HOME/.pki/nssdb" -t "C,," -n "$NICK" -i "$CA"

# verifikasi — HARUS "certificate is valid"
certutil -V -d sql:"$HOME/.pki/nssdb" -u L -n "$NICK"
```

Kalau `certutil -V` bilang `certificate is valid`, `lerd doctor` akan
melaporkan `✓ browser HTTPS trust`.

Lalu **restart browser** (Chromium membaca NSS db saat start).

## Kalau CA dibuat ulang

Serial berubah, jadi nickname berubah. Ulangi blok di atas dari awal —
script `lerd/setup-wsl2.sh` menanganinya lewat `lerd dns:repair`? **Tidak.**
`dns:repair` menulis ulang `resolved.conf.d/lerd.conf` dan me-restart
`systemd-resolved`; itu ranah DNS, bukan NSS. Jalankan blok di atas.

## Jangan pakai `lerd dns:repair` untuk masalah ini

`dns:repair` memperbaiki *resolusi* `.test`, bukan trust sertifikat. Di setup
split-DNS WSL (lihat `README.md` bagian DNS) ia justru bisa menimpa konfigurasi
resolver yang sudah benar.

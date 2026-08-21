#!/usr/bin/env bash
# =============================================================================
# lerd-dns-fix.sh — Perbaiki split-DNS Lerd di WSL (systemd-resolved)
#
# Desain yang diterapkan:
#   *.test        -> lerd0 link  -> 127.0.0.1:5300  (Lerd dnsmasq)
#   domain lain   -> Global DNS  -> 1.1.1.1 / 8.8.8.8 (internet)
#
# Kapan dipakai: setelah `lerd dns:repair` / `lerd install` menimpa
# /etc/systemd/resolved.conf.d/lerd.conf kembali ke 127.0.0.1:5300,
# atau saat internet di WSL tidak bisa resolve setelah restart.
# Idempoten — aman dijalankan berulang kali.
# =============================================================================
set -euo pipefail

LERD_CONF="/etc/systemd/resolved.conf.d/lerd.conf"
LINK="lerd0"

echo "[1/4] Menulis $LERD_CONF (Global DNS = 1.1.1.1/8.8.8.8) ..."
printf '[Resolve]\nDNS=1.1.1.1 8.8.8.8\n' | sudo -n tee "$LERD_CONF" >/dev/null \
    || { echo "GAGAL: butuh sudo untuk menulis $LERD_CONF (coba tanpa -n, atau masukkan password)." >&2; exit 1; }

echo "[2/4] Restart systemd-resolved ..."
sudo -n systemctl restart systemd-resolved

echo "[3/4] Pasang ulang routing *.test di link $LINK ..."
# Link dummy dibuat & dikonfigurasi lerd-dns-link.service saat boot.
if ! ip link show "$LINK" >/dev/null 2>&1; then
    echo "  WARN: link $LINK belum ada — restart WSL (wsl --shutdown) agar lerd-dns-link.service membuatnya, lalu jalankan ulang skrip ini." >&2
fi
sudo -n resolvectl dns "$LINK" 127.0.0.1:5300
sudo -n resolvectl domain "$LINK" '~test'

echo "[4/4] Verifikasi ..."
echo "--- resolvectl dns ---"
resolvectl dns
echo "--- uji .test ---"
curl -sS -o /dev/null -m 8 -w "  lerd-probe.test -> %{http_code}\n" http://lerd-probe.test || echo "  lerd-probe.test -> GAGAL"
echo "--- uji internet ---"
curl -sS -o /dev/null -m 10 -w "  raw.githubusercontent.com -> %{http_code}\n" https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.6/install.sh || echo "  internet -> GAGAL"

echo ""
echo "Selesai. Catatan: 127.0.0.1:5300 yang ikut tampil di baris 'Global:' adalah DNS per-link $LINK (artifact tampilan systemd-resolved), bukan DNS global kedua."

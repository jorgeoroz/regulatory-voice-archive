#!/usr/bin/env bash

set -u

FAIL=0
WARN=0

ok()   { printf '[ OK ] %s\n' "$1"; }
warn() { printf '[WARN] %s\n' "$1"; WARN=$((WARN + 1)); }
fail() { printf '[FAIL] %s\n' "$1"; FAIL=$((FAIL + 1)); }

printf '\nRVA prerequisite check\n======================\n'

for cmd in bash mariadb tshark ffmpeg ffprobe tcpdump setfacl flock xxd awk tr; do
    if command -v "$cmd" >/dev/null 2>&1; then
        ok "$cmd disponible"
    else
        fail "$cmd no encontrado"
    fi
done

if command -v ffmpeg >/dev/null 2>&1 && ffmpeg -decoders 2>/dev/null | grep -qi g729; then
    ok "FFmpeg incluye decoder G.729"
else
    fail "FFmpeg no reporta decoder G.729"
fi

if [ -x /usr/local/sbin/voipmonitor ] || command -v voipmonitor >/dev/null 2>&1; then
    ok "VoIPmonitor encontrado"
else
    fail "VoIPmonitor no encontrado"
fi

if systemctl list-unit-files mariadb.service >/dev/null 2>&1; then
    ok "MariaDB instalado"
else
    warn "No se detectó mariadb.service"
fi

if systemctl list-unit-files apache2.service >/dev/null 2>&1; then
    ok "Apache instalado"
else
    warn "Apache no instalado (opcional para scripts; requerido para el portal web)"
fi

if command -v cloudcmd >/dev/null 2>&1; then
    ok "Cloud Commander instalado (opcional)"
else
    warn "Cloud Commander no instalado (opcional)"
fi

printf '\nResultado: %s fallo(s), %s advertencia(s)\n' "$FAIL" "$WARN"

if [ "$FAIL" -gt 0 ]; then
    exit 2
elif [ "$WARN" -gt 0 ]; then
    exit 1
else
    exit 0
fi

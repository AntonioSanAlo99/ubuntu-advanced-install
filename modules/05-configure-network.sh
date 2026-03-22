#!/bin/bash
# MÓDULO 05: Configurar NetworkManager

set -e
[ -f "$(dirname "$0")/../partition.info" ] && source "$(dirname "$0")/../partition.info"

# Verificar que TARGET está montado y el chroot es funcional
if ! mountpoint -q "${TARGET:-/mnt/ubuntu}" 2>/dev/null; then
    echo "ERROR: TARGET=${TARGET:-/mnt/ubuntu} no está montado." >&2
    exit 1
fi
if [ ! -x "${TARGET:-/mnt/ubuntu}/usr/bin/apt-get" ]; then
    echo "ERROR: Chroot en ${TARGET:-/mnt/ubuntu} sin apt-get." >&2
    exit 1
fi


echo "Configurando NetworkManager..."

arch-chroot "$TARGET" /bin/bash << CHROOTEOF
export DEBIAN_FRONTEND=noninteractive

apt-get install -y network-manager

# CRÍTICO: Crear configuración para que NM gestione todas las interfaces
mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/10-globally-managed-devices.conf << 'EOF'
[keyfile]
unmanaged-devices=none
EOF

# ── systemd-resolved — DNS configuración ──────────────────────────────────
# Si PERF_DNS_OVER_TLS=true: DNS cifrado con Cloudflare+Quad9, fallback Google.
# Si false: systemd-resolved con defaults (DNS del DHCP/router).
if [ "${PERF_DNS_OVER_TLS:-true}" = "true" ]; then
    mkdir -p /etc/systemd/resolved.conf.d
    cat > /etc/systemd/resolved.conf.d/50-dns-over-tls.conf << 'DNSEOF'
[Resolve]
DNS=1.1.1.1#cloudflare-dns.com 1.0.0.1#cloudflare-dns.com 9.9.9.9#dns.quad9.net
FallbackDNS=8.8.8.8#dns.google 8.8.4.4#dns.google
DNSOverTLS=opportunistic
DNSSEC=allow-downgrade
Cache=yes
DNSEOF
fi

ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

systemctl enable NetworkManager
systemctl enable systemd-resolved

CHROOTEOF

echo "✓  NetworkManager configurado"
if [ "${PERF_DNS_OVER_TLS:-true}" = "true" ]; then
    echo "✓  systemd-resolved: DNS-over-TLS (Cloudflare + Quad9)"
else
    echo "✓  systemd-resolved: DNS defaults (DHCP/router)"
fi

exit 0

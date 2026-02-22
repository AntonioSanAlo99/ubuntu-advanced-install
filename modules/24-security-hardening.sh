#!/bin/bash
# Módulo 24: Hardening de seguridad

set -eo pipefail  # Detectar errores en pipelines

source "$(dirname "$0")/../config.env"

echo "Aplicando hardening de seguridad..."

arch-chroot "$TARGET" /bin/bash << 'CHROOTEOF'


# === HARDENING DEL KERNEL ===
cat > /etc/sysctl.d/99-security-hardening.conf << 'SYSCTL_EOF'
# Hardening de seguridad del kernel

# Protección contra IP spoofing
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# No aceptar ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0

# Protección SYN flood
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2

# Log paquetes sospechosos
net.ipv4.conf.all.log_martians = 1

# Ignorar ICMP broadcasts
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1

# ASLR
kernel.randomize_va_space = 2

# Restringir acceso a información del kernel
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
SYSCTL_EOF

# Habilitar actualizaciones automáticas
apt install -y unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades

echo "✓ Hardening de seguridad aplicado"
CHROOTEOF

echo "✓ Sistema endurecido (protecciones de red y kernel)"

exit 0

#!/bin/bash
# Módulo 23: Minimizar systemd

source "$(dirname "$0")/../config.env"

echo "Minimizando componentes de systemd..."

arch-chroot "$TARGET" /bin/bash << 'CHROOTEOF'
# FIX: Perl locale warnings
export LANG=es_ES.UTF-8; export LC_ALL=es_ES.UTF-8; export LANGUAGE=es_ES

# Deshabilitar componentes systemd innecesarios
echo "Deshabilitando servicios systemd innecesarios..."

# systemd-networkd (usamos NetworkManager)
systemctl disable systemd-networkd 2>/dev/null || true
systemctl mask systemd-networkd 2>/dev/null || true

# systemd-resolved ya está en uso, no deshabilitar

# Servicios opcionales
DISABLE_SERVICES="
    systemd-networkd-wait-online.service
    systemd-hostnamed.service
    systemd-localed.service
"

for service in $DISABLE_SERVICES; do
    systemctl disable $service 2>/dev/null || true
    echo "✓ Deshabilitado: $service"
done

# Prevenir instalación de paquetes systemd opcionales
cat > /etc/apt/preferences.d/99-no-systemd-extras << 'PREFS_EOF'
Package: systemd-homed
Pin: release *
Pin-Priority: -1

Package: systemd-container
Pin: release *
Pin-Priority: -1

Package: systemd-journal-remote
Pin: release *
Pin-Priority: -1

Package: systemd-coredump
Pin: release *
Pin-Priority: -1
PREFS_EOF

# Optimizar journald
mkdir -p /etc/systemd/journald.conf.d/
cat > /etc/systemd/journald.conf.d/99-minimal.conf << 'JOURNAL_EOF'
[Journal]
SystemMaxUse=100M
SystemMaxFileSize=10M
RuntimeMaxUse=50M
MaxRetentionSec=1week
MaxFileSec=1day
Storage=volatile
Compress=yes
MaxLevelStore=warning
MaxLevelSyslog=warning
JOURNAL_EOF

echo "✓ Componentes systemd minimizados"
CHROOTEOF

echo "✓ Systemd optimizado (5 servicios deshabilitados)"

#!/bin/bash
# Módulo 21: Optimizar para laptop

source "$(dirname "$0")/../config.env"

echo "Aplicando optimizaciones para laptop..."

APT_FLAGS=""
[ "$USE_NO_INSTALL_RECOMMENDS" = "true" ] && APT_FLAGS="--no-install-recommends"

arch-chroot "$TARGET" /bin/bash << 'CHROOTEOF'
export DEBIAN_FRONTEND=noninteractive
# FIX: Perl locale warnings
export LANG=es_ES.UTF-8; export LC_ALL=es_ES.UTF-8; export LANGUAGE=es_ES
APT_FLAGS="--no-install-recommends"

# Instalar TLP y thermald
apt install -y $APT_FLAGS \
    tlp \
    tlp-rdw \
    thermald \
    cpufrequtils

# Configurar TLP
cat > /etc/tlp.d/99-laptop-custom.conf << 'TLP_EOF'
# Configuración TLP para laptop

# CPU
CPU_BOOST_ON_AC=1
CPU_BOOST_ON_BAT=1
CPU_SCALING_GOVERNOR_ON_AC=schedutil
CPU_SCALING_GOVERNOR_ON_BAT=schedutil
CPU_ENERGY_PERF_POLICY_ON_AC=balance_performance
CPU_ENERGY_PERF_POLICY_ON_BAT=balance_power

# Disco
AHCI_RUNTIME_PM_ON_AC=on
AHCI_RUNTIME_PM_ON_BAT=auto

# Red
WIFI_PWR_ON_AC=off
WIFI_PWR_ON_BAT=on

# USB
USB_AUTOSUSPEND=1
TLP_EOF

# Configurar CPU governor
cat > /etc/default/cpufrequtils << 'CPU_EOF'
GOVERNOR="schedutil"
CPU_EOF

# Habilitar servicios
systemctl enable tlp.service
systemctl enable thermald.service
systemctl mask power-profiles-daemon.service 2>/dev/null || true

echo "✓ TLP y thermald configurados"
CHROOTEOF

echo "✓ Optimizaciones de laptop aplicadas"

#!/bin/bash
# Módulo 21: Optimizar para laptop

set -e  # Exit on error  # Detectar errores en pipelines

# Variables se pasan desde install.sh via environment
# source "$(dirname "$0")/../config.env"

echo "════════════════════════════════════════════════════════════════"
echo "  OPTIMIZACIONES PARA LAPTOP"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Opciones de gestión de energía:"
echo "  1) power-profiles-daemon - Integración GNOME simple (recomendado)"
echo "  2) TLP - Máximo control y optimización"
echo ""
echo "power-profiles-daemon:"
echo "  + Integración nativa con GNOME Settings"
echo "  + Tres perfiles simples (Performance/Balanced/Power Saver)"
echo "  + Más simple y automático"
echo "  + Interfaz gráfica"
echo "  - Menos opciones de configuración"
echo ""
echo "TLP:"
echo "  + Configuración detallada (AC/BAT diferenciados)"
echo "  + Optimización agresiva de batería"
echo "  + Control fino de CPU, disco, USB, WiFi"
echo "  - Más complejo, requiere terminal"
echo ""

if [ -z "$POWER_MANAGER" ]; then
    read -p "Selecciona opción [1]: " POWER_OPTION
    POWER_OPTION=${POWER_OPTION:-1}
else
    POWER_OPTION="$POWER_MANAGER"
fi

APT_FLAGS=""
[ "$USE_NO_INSTALL_RECOMMENDS" = "true" ] && APT_FLAGS="--no-install-recommends"

if [ "$POWER_OPTION" = "1" ]; then
    # ========================================================================
    # OPCIÓN 1: power-profiles-daemon (PREDETERMINADO)
    # ========================================================================
    
    arch-chroot "$TARGET" /bin/bash << 'CHROOTEOF'
export DEBIAN_FRONTEND=noninteractive

echo ""
echo "Instalando power-profiles-daemon..."

apt install -y power-profiles-daemon thermald

# Habilitar servicios
systemctl enable power-profiles-daemon.service
systemctl enable thermald.service

# Asegurar que TLP no interfiera
systemctl mask tlp.service 2>/dev/null || true
systemctl mask tlp-sleep.service 2>/dev/null || true

echo "✓ power-profiles-daemon configurado"
echo ""
echo "Perfiles disponibles:"
echo "  • Performance - Máximo rendimiento"
echo "  • Balanced - Equilibrado (predeterminado)"
echo "  • Power Saver - Máxima duración de batería"
echo ""
echo "Acceso: GNOME Settings → Power → Power Mode"
CHROOTEOF

    echo ""
    echo "✓ power-profiles-daemon instalado"
    
else
    # ========================================================================
    # OPCIÓN 2: TLP
    # ========================================================================
    
    arch-chroot "$TARGET" /bin/bash << 'CHROOTEOF'
export DEBIAN_FRONTEND=noninteractive

APT_FLAGS="--no-install-recommends"

echo ""
echo "Instalando TLP..."

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

# Deshabilitar power-profiles-daemon (conflicto con TLP)
systemctl mask power-profiles-daemon.service 2>/dev/null || true

echo "✓ TLP y thermald configurados"
echo ""
echo "Configuración:"
echo "  • AC: balance_performance + WiFi full power"
echo "  • Batería: balance_power + WiFi power save"
echo "  • USB autosuspend habilitado"
echo ""
echo "Comandos útiles:"
echo "  tlp-stat    - Ver estado"
echo "  tlp start   - Aplicar configuración"
CHROOTEOF

    echo ""
    echo "✓ TLP instalado y configurado"
fi

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓ OPTIMIZACIONES DE LAPTOP COMPLETADAS"
echo "════════════════════════════════════════════════════════════════"
echo ""

exit 0

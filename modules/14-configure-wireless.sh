#!/bin/bash
# Módulo 14: Configurar WiFi, Bluetooth y periféricos gaming

set -e  # Exit on error  # Detectar errores en pipelines

# Cargar variables de particionado
[ -f "$(dirname "$0")/../partition.info" ] && source "$(dirname "$0")/../partition.info"


# Variables se pasan desde install.sh via environment
# source "$(dirname "$0")/../config.env"

echo "════════════════════════════════════════════════════════════════"
echo "  CONFIGURACIÓN INALÁMBRICA"
echo "════════════════════════════════════════════════════════════════"
echo ""

# ============================================================================
# DETECCIÓN DE HARDWARE
# ============================================================================

echo "Detectando hardware inalámbrico..."
echo ""

WIFI_DETECTED="false"
BLUETOOTH_DETECTED="false"

# Detectar WiFi
if lspci | grep -i "network\|wireless\|wifi" > /dev/null 2>&1; then
    WIFI_DETECTED="true"
    echo "📡 WiFi detectado:"
    lspci | grep -i "network\|wireless\|wifi" | sed 's/^/   /'
    
    # Identificar chipset
    if lspci | grep -i "intel.*wireless\|intel.*wifi" > /dev/null 2>&1; then
        echo "   Chipset: Intel"
    elif lspci | grep -i "realtek.*wireless\|realtek.*wifi\|rtl" > /dev/null 2>&1; then
        echo "   Chipset: Realtek"
    elif lspci | grep -i "broadcom.*wireless\|broadcom.*wifi" > /dev/null 2>&1; then
        echo "   Chipset: Broadcom"
    elif lspci | grep -i "atheros.*wireless\|atheros.*wifi\|qualcomm atheros" > /dev/null 2>&1; then
        echo "   Chipset: Atheros"
    elif lspci | grep -i "mediatek\|mtk" > /dev/null 2>&1; then
        echo "   Chipset: MediaTek"
    fi
    
elif lsusb | grep -i "wireless\|wifi\|802.11" > /dev/null 2>&1; then
    WIFI_DETECTED="true"
    echo "📡 WiFi USB detectado:"
    lsusb | grep -i "wireless\|wifi\|802.11" | sed 's/^/   /'
    
    # Identificar chipset USB
    if lsusb | grep -i "realtek\|rtl" > /dev/null 2>&1; then
        echo "   Chipset: Realtek"
    elif lsusb | grep -i "mediatek\|mtk" > /dev/null 2>&1; then
        echo "   Chipset: MediaTek"
    fi
fi

# Detectar Bluetooth
if lsusb | grep -i "bluetooth" > /dev/null 2>&1; then
    BLUETOOTH_DETECTED="true"
    echo "🔵 Bluetooth detectado:"
    lsusb | grep -i "bluetooth" | sed 's/^/   /'
elif hciconfig 2>/dev/null | grep -q "UP RUNNING"; then
    BLUETOOTH_DETECTED="true"
    echo "🔵 Bluetooth activo:"
    hciconfig 2>/dev/null | grep "BD Address" | sed 's/^/   /'
fi

if [ "$WIFI_DETECTED" = "false" ] && [ "$BLUETOOTH_DETECTED" = "false" ]; then
    echo "⚠ ️  No se detectó hardware inalámbrico"
fi

echo ""
echo "Configuración solicitada:"
echo "  HAS_WIFI=${HAS_WIFI:-false}"
echo "  HAS_BLUETOOTH=${HAS_BLUETOOTH:-false}"
echo ""

# ============================================================================
# INSTALACIÓN
# ============================================================================

APT_FLAGS=""
[ "$USE_NO_INSTALL_RECOMMENDS" = "true" ] && APT_FLAGS="--no-install-recommends"

chroot "$TARGET" /bin/bash << CHROOTEOF
export DEBIAN_FRONTEND=noninteractive

APT_FLAGS="$APT_FLAGS"
HAS_WIFI="${HAS_WIFI:-false}"
HAS_BLUETOOTH="${HAS_BLUETOOTH:-false}"

# ============================================================================
# WIFI
# ============================================================================

if [ "\$HAS_WIFI" = "true" ]; then
    echo ""
    echo "Instalando WiFi..."
    
    apt install -y \$APT_FLAGS \
        wireless-tools \
        wpasupplicant \
        iw \
        rfkill
    
    echo "✓  WiFi instalado"
    echo "  Nota: Firmware WiFi instalado en módulo 03-install-firmware"
else
    echo ""
    echo "⊗ WiFi omitido (HAS_WIFI=false)"
fi

# ============================================================================
# BLUETOOTH
# ============================================================================

if [ "\$HAS_BLUETOOTH" = "true" ]; then
    echo ""
    echo "Instalando Bluetooth..."
    
    # blueman eliminado: GNOME 42+ gestiona Bluetooth nativamente
    # a través de gnome-bluetooth incluido en el escritorio
    apt install -y \$APT_FLAGS \
        bluez \
        bluez-tools
    
    # Habilitar Bluetooth
    systemctl enable bluetooth
    
    echo "✓  Bluetooth instalado y habilitado"
else
    echo ""
    echo "⊗ Bluetooth omitido (HAS_BLUETOOTH=false)"
fi

CHROOTEOF

# ============================================================================
# CONFIRMACIÓN FINAL
# ============================================================================

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓  CONFIGURACIÓN INALÁMBRICA COMPLETADA"
echo "════════════════════════════════════════════════════════════════"
echo ""

echo "Hardware detectado:"
if [ "$WIFI_DETECTED" = "true" ]; then
    echo "  📡 WiFi: Sí"
else
    echo "  📡 WiFi: No detectado"
fi

if [ "$BLUETOOTH_DETECTED" = "true" ]; then
    echo "  🔵 Bluetooth: Sí"
else
    echo "  🔵 Bluetooth: No detectado"
fi

echo ""
echo "Software instalado:"
if [ "${HAS_WIFI:-false}" = "true" ]; then
    echo "  ✅ WiFi: Instalado"
else
    echo "  ⊗ WiFi: Omitido"
fi

if [ "${HAS_BLUETOOTH:-false}" = "true" ]; then
    echo "  ✅ Bluetooth: Instalado y habilitado"
else
    echo "  ⊗ Bluetooth: Omitido"
fi

echo ""

exit 0

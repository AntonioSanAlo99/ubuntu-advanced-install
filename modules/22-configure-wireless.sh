#!/bin/bash
# MÓDULO 22: Configurar WiFi, Bluetooth y periféricos gaming

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

arch-chroot "$TARGET" /bin/bash << CHROOTEOF
export DEBIAN_FRONTEND=noninteractive

HAS_WIFI="${HAS_WIFI:-false}"
HAS_BLUETOOTH="${HAS_BLUETOOTH:-false}"

# ============================================================================
# WIFI
# ============================================================================

if [ "\$HAS_WIFI" = "true" ]; then
    echo ""
    echo "Instalando WiFi..."
    
    apt-get install -y \
        wireless-tools \
        wpasupplicant \
        iw \
        rfkill \
        wireless-regdb crda

    # ── Regulatory domain ────────────────────────────────────────────────────
    # Sin configurar, Linux usa country 00 (restricciones genéricas) que
    # bloquea canales 5GHz/6GHz y limita potencia de transmisión.
    # Configurar el país correcto desbloquea todos los canales legales.
    # Derivamos el código de país del locale configurado en el sistema.
    WIFI_COUNTRY=""
    if [ -f /etc/default/locale ]; then
        # Extraer código de país del locale (es_ES.UTF-8 → ES)
        WIFI_COUNTRY=\$(grep "^LANG=" /etc/default/locale 2>/dev/null \
            | sed 's/.*_\([A-Z]\{2\}\).*/\1/' || echo "")
    fi
    WIFI_COUNTRY="\${WIFI_COUNTRY:-ES}"

    # Configurar en wireless-regdb
    if [ -f /etc/default/crda ]; then
        sed -i "s/^REGDOMAIN=.*/REGDOMAIN=\$WIFI_COUNTRY/" /etc/default/crda
    else
        echo "REGDOMAIN=\$WIFI_COUNTRY" > /etc/default/crda
    fi

    # También en conf.d si existe
    if [ -f /etc/conf.d/wireless-regdom ]; then
        sed -i "s/^#*WIRELESS_REGDOM=.*/WIRELESS_REGDOM=\"\$WIFI_COUNTRY\"/" /etc/conf.d/wireless-regdom
    fi

    # iw reg set para aplicar inmediatamente (si el módulo está cargado)
    iw reg set "\$WIFI_COUNTRY" 2>/dev/null || true

    echo "✓  WiFi instalado"
    echo "  ✓ Regulatory domain: \$WIFI_COUNTRY (canales 5GHz/6GHz desbloqueados)"
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
    apt-get install -y \
        bluez \
        bluez-tools

    # Habilitar bluetooth.service en el arranque del sistema
    systemctl enable bluetooth

    # Asegurar que bluetoothd activa los adaptadores al arrancar
    if [ -f /etc/bluetooth/main.conf ]; then
        sed -i 's/^#\?AutoEnable=.*/AutoEnable=true/' /etc/bluetooth/main.conf
        grep -q "AutoEnable" /etc/bluetooth/main.conf || \
            sed -i '/^\[Policy\]/a AutoEnable=true' /etc/bluetooth/main.conf
    fi

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

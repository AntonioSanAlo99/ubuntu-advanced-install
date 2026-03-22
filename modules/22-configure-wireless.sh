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

# Usar autodetección del host (ya hecha arriba) en vez de variables manuales
HAS_WIFI="$WIFI_DETECTED"
HAS_BLUETOOTH="$BLUETOOTH_DETECTED"

# ============================================================================
# WIFI
# ============================================================================

if [ "\$HAS_WIFI" = "true" ]; then
    echo ""
    echo "Instalando WiFi..."
    
    # Paquetes mínimos estilo Ubiquity:
    #   iw:            herramienta moderna de configuración WiFi (reemplaza wireless-tools)
    #   rfkill:        gestión de bloqueo hardware/software de radios
    #   wireless-regdb: base de datos de regulación WiFi por país
    # NetworkManager (instalado en módulo 05) ya incluye wpasupplicant como dependencia.
    # wireless-tools y crda están deprecados (crda obsoleto desde kernel 4.15+).
    apt-get install -y \
        iw \
        rfkill \
        wireless-regdb

    # ── Regulatory domain ────────────────────────────────────────────────────
    # Sin configurar, Linux usa country 00 (restricciones genéricas) que
    # bloquea canales 5GHz/6GHz y limita potencia de transmisión.
    # El kernel 4.15+ carga la regulatory database directamente de wireless-regdb.
    WIFI_COUNTRY=""
    if [ -f /etc/default/locale ]; then
        WIFI_COUNTRY=\$(grep "^LANG=" /etc/default/locale 2>/dev/null \
            | sed 's/.*_\([A-Z]\{2\}\).*/\1/' || echo "")
    fi
    WIFI_COUNTRY="\${WIFI_COUNTRY:-ES}"

    # Configurar regulatory domain persistente
    mkdir -p /etc/default
    echo "REGDOMAIN=\$WIFI_COUNTRY" > /etc/default/crda 2>/dev/null || true

    # iw reg set para aplicar inmediatamente
    iw reg set "\$WIFI_COUNTRY" 2>/dev/null || true

    echo "✓  WiFi instalado (iw + rfkill + wireless-regdb)"
    echo "  ✓ Regulatory domain: \$WIFI_COUNTRY"
else
    echo ""
    echo "⊗ WiFi omitido (HAS_WIFI=false)"
fi

# ============================================================================
# BLUETOOTH
# ============================================================================

if [ "\$HAS_BLUETOOTH" = "true" ]; then
    echo ""
    echo "Configurando Bluetooth..."
    
    # bluez ya instalado como dependencia transitiva de gnome-shell:
    #   gnome-shell → gir1.2-gnomebluetooth-3.0 → gnome-bluetooth-3-common → bluez
    # Solo necesitamos habilitar el servicio y configurar auto-encendido.

    # Habilitar bluetooth.service en el arranque del sistema
    systemctl enable bluetooth 2>/dev/null || true

    # Asegurar que bluetoothd activa los adaptadores al arrancar
    if [ -f /etc/bluetooth/main.conf ]; then
        sed -i 's/^#\?AutoEnable=.*/AutoEnable=true/' /etc/bluetooth/main.conf
        grep -q "AutoEnable" /etc/bluetooth/main.conf || \
            sed -i '/^\[Policy\]/a AutoEnable=true' /etc/bluetooth/main.conf
    fi

    echo "✓  Bluetooth configurado (bluez via gnome-shell, AutoEnable=true)"
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

echo ""
echo "Software configurado:"
if [ "$WIFI_DETECTED" = "true" ]; then
    echo "  ✅ WiFi: configurado (autodetectado)"
else
    echo "  ⊗ WiFi: no detectado — omitido"
fi

if [ "$BLUETOOTH_DETECTED" = "true" ]; then
    echo "  ✅ Bluetooth: configurado (autodetectado)"
else
    echo "  ⊗ Bluetooth: no detectado — omitido"
fi

echo ""

exit 0

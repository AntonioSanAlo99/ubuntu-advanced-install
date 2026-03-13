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

arch-chroot "$TARGET" /bin/bash << CHROOTEOF
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

    # Habilitar bluetooth.service en el arranque del sistema
    systemctl enable bluetooth

    # ── Evitar "spa-bluez5: BlueZ system service is not available" ───────────
    # WirePlumber corre como servicio de sesión de usuario y arranca antes
    # de que bluetooth.service haya publicado su interfaz D-Bus en el bus
    # del sistema. El resultado es que spa-bluez5 no puede conectar a BlueZ
    # y el audio Bluetooth no funciona hasta reiniciar WirePlumber manualmente.
    #
    # Solución: override de systemd que añade After=bluetooth.service y
    # Wants=bluetooth.service a wireplumber.service (usuario).
    # Esto se aplica en /etc/skel para que afecte al usuario desde el primer login.
    # También se configura bluetooth.service para que active su interfaz D-Bus
    # lo antes posible con AutoEnable=true.

    # Asegurar que bluetoothd expone D-Bus lo antes posible
    if [ -f /etc/bluetooth/main.conf ]; then
        sed -i 's/^#\?AutoEnable=.*/AutoEnable=true/' /etc/bluetooth/main.conf
        grep -q "AutoEnable" /etc/bluetooth/main.conf || \
            sed -i '/^\[Policy\]/a AutoEnable=true' /etc/bluetooth/main.conf
    fi

    # ── Evitar "spa-bluez5: BlueZ system service is not available" ───────────
    # WirePlumber corre como servicio de systemd user session y puede arrancar
    # antes de que bluetooth.service haya publicado su interfaz D-Bus en el
    # bus del sistema.
    #
    # La ubicación correcta para un override que aplique a todos los usuarios
    # es /usr/lib/systemd/user/wireplumber.service.d/ — systemd user lee
    # los drop-ins del sistema desde ahí sin necesitar copia en cada $HOME.
    # (GNOME 44+ gestiona sesiones via systemd user, no gnome-session.)
    mkdir -p /usr/lib/systemd/user/wireplumber.service.d
    cat > /usr/lib/systemd/user/wireplumber.service.d/bluetooth-wait.conf << 'WPOVERRIDE'
[Unit]
After=bluetooth.service
Wants=bluetooth.service
WPOVERRIDE

    # Eliminar el override incorrecto de skel si existía de una instalación previa
    rm -rf /etc/skel/.config/systemd/user/wireplumber.service.d

    echo "✓  Bluetooth instalado y habilitado"
    echo "   WirePlumber: drop-in en /usr/lib/systemd/user/ (todos los usuarios)"
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

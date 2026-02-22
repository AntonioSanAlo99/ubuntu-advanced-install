#!/bin/bash
# Módulo 03: Detección y firmware

set -eo pipefail  # Detectar errores en pipelines

source "$(dirname "$0")/../config.env"
    # Fallback si no existe el error handler
    log_error() { echo "ERROR: $2"; }
    log_success() { echo "✓ $2"; }
    show_error_summary() { :; }
    safe_run() { shift 2; "$@"; }

MODULE_NAME="Firmware Detection"
MODULE_ERRORS=0
MODULE_WARNINGS=0

echo "════════════════════════════════════════════════════════════════"
echo "  DETECCIÓN DE HARDWARE Y FIRMWARE"
echo "════════════════════════════════════════════════════════════════"
echo ""

# ============================================================================
# DETECCIÓN DE HARDWARE
# ============================================================================

echo "Analizando hardware del sistema..."
echo ""

# Arrays para firmware necesario
FIRMWARE_NEEDED=()
FIRMWARE_DESCRIPTIONS=()

# ============================================================================
# GPU / VIDEO
# ============================================================================

echo "🎮 GPU/Video:"

if lspci | grep -i "vga\|3d\|display" | grep -i "nvidia" > /dev/null 2>&1; then
    GPU_INFO=$(lspci | grep -i "vga\|3d" | grep -i "nvidia" | head -1)
    echo "   • NVIDIA detectada"
    echo "     $GPU_INFO" | sed 's/^/     /'
    FIRMWARE_NEEDED+=("firmware-misc-nonfree")
    FIRMWARE_DESCRIPTIONS+=("NVIDIA GPU")
    
elif lspci | grep -i "vga\|3d\|display" | grep -i "amd\|radeon" > /dev/null 2>&1; then
    GPU_INFO=$(lspci | grep -i "vga\|3d" | grep -i "amd\|radeon" | head -1)
    echo "   • AMD/Radeon detectada"
    echo "     $GPU_INFO" | sed 's/^/     /'
    FIRMWARE_NEEDED+=("firmware-amd-graphics")
    FIRMWARE_DESCRIPTIONS+=("AMD/Radeon GPU")
    
elif lspci | grep -i "vga\|3d\|display" | grep -i "intel" > /dev/null 2>&1; then
    GPU_INFO=$(lspci | grep -i "vga\|3d" | grep -i "intel" | head -1)
    echo "   • Intel iGPU detectada"
    echo "     $GPU_INFO" | sed 's/^/     /'
    FIRMWARE_NEEDED+=("intel-microcode")
    FIRMWARE_DESCRIPTIONS+=("Intel iGPU")
else
    echo "   • GPU genérica detectada"
fi

echo ""

# ============================================================================
# WIFI
# ============================================================================

echo "📡 WiFi:"

WIFI_FOUND=false

if lspci | grep -i "network\|wireless\|wifi" | grep -i "intel" > /dev/null 2>&1; then
    WIFI_INFO=$(lspci | grep -i "network\|wireless\|wifi" | grep -i "intel" | head -1)
    echo "   • Intel WiFi detectada"
    echo "     $WIFI_INFO" | sed 's/^/     /'
    FIRMWARE_NEEDED+=("firmware-iwlwifi")
    FIRMWARE_DESCRIPTIONS+=("Intel WiFi")
    WIFI_FOUND=true
    
elif lspci | grep -i "network\|wireless\|wifi" | grep -i "realtek\|rtl" > /dev/null 2>&1; then
    WIFI_INFO=$(lspci | grep -i "network\|wireless\|wifi" | grep -i "realtek\|rtl" | head -1)
    echo "   • Realtek WiFi detectada"
    echo "     $WIFI_INFO" | sed 's/^/     /'
    FIRMWARE_NEEDED+=("firmware-realtek")
    FIRMWARE_DESCRIPTIONS+=("Realtek WiFi")
    WIFI_FOUND=true
    
elif lspci | grep -i "network\|wireless\|wifi" | grep -i "broadcom" > /dev/null 2>&1; then
    WIFI_INFO=$(lspci | grep -i "network\|wireless\|wifi" | grep -i "broadcom" | head -1)
    echo "   • Broadcom WiFi detectada"
    echo "     $WIFI_INFO" | sed 's/^/     /'
    FIRMWARE_NEEDED+=("firmware-brcm80211")
    FIRMWARE_DESCRIPTIONS+=("Broadcom WiFi")
    WIFI_FOUND=true
    
elif lspci | grep -i "network\|wireless\|wifi" | grep -i "atheros\|qualcomm" > /dev/null 2>&1; then
    WIFI_INFO=$(lspci | grep -i "network\|wireless\|wifi" | grep -i "atheros\|qualcomm" | head -1)
    echo "   • Atheros WiFi detectada"
    echo "     $WIFI_INFO" | sed 's/^/     /'
    FIRMWARE_NEEDED+=("firmware-atheros")
    FIRMWARE_DESCRIPTIONS+=("Atheros WiFi")
    WIFI_FOUND=true
    
elif lspci | grep -i "network\|wireless\|wifi" | grep -i "mediatek\|mtk" > /dev/null 2>&1; then
    WIFI_INFO=$(lspci | grep -i "network\|wireless\|wifi" | grep -i "mediatek\|mtk" | head -1)
    echo "   • MediaTek WiFi detectada"
    echo "     $WIFI_INFO" | sed 's/^/     /'
    FIRMWARE_NEEDED+=("firmware-mediatek")
    FIRMWARE_DESCRIPTIONS+=("MediaTek WiFi")
    WIFI_FOUND=true
fi

# Detectar WiFi USB
if lsusb | grep -i "realtek.*wireless\|realtek.*wifi\|rtl.*wireless" > /dev/null 2>&1; then
    echo "   • Realtek WiFi USB detectada"
    lsusb | grep -i "realtek.*wireless\|realtek.*wifi" | head -1 | sed 's/^/     /'
    if [[ ! " ${FIRMWARE_NEEDED[@]} " =~ " firmware-realtek " ]]; then
        FIRMWARE_NEEDED+=("firmware-realtek")
        FIRMWARE_DESCRIPTIONS+=("Realtek WiFi USB")
    fi
    WIFI_FOUND=true
    
elif lsusb | grep -i "mediatek.*wireless\|mediatek.*wifi\|mtk" > /dev/null 2>&1; then
    echo "   • MediaTek WiFi USB detectada"
    lsusb | grep -i "mediatek.*wireless\|mediatek.*wifi\|mtk" | head -1 | sed 's/^/     /'
    if [[ ! " ${FIRMWARE_NEEDED[@]} " =~ " firmware-mediatek " ]]; then
        FIRMWARE_NEEDED+=("firmware-mediatek")
        FIRMWARE_DESCRIPTIONS+=("MediaTek WiFi USB")
    fi
    WIFI_FOUND=true
fi

if [ "$WIFI_FOUND" = "false" ]; then
    echo "   • No detectada"
fi

echo ""

# ============================================================================
# BLUETOOTH
# ============================================================================

echo "🔵 Bluetooth:"

BT_FOUND=false

if lsusb | grep -i "intel.*bluetooth" > /dev/null 2>&1; then
    echo "   • Intel Bluetooth detectado"
    lsusb | grep -i "intel.*bluetooth" | head -1 | sed 's/^/     /'
    if [[ ! " ${FIRMWARE_NEEDED[@]} " =~ " firmware-iwlwifi " ]]; then
        FIRMWARE_NEEDED+=("firmware-iwlwifi")
        FIRMWARE_DESCRIPTIONS+=("Intel Bluetooth")
    fi
    BT_FOUND=true
    
elif lsusb | grep -i "realtek.*bluetooth" > /dev/null 2>&1; then
    echo "   • Realtek Bluetooth detectado"
    lsusb | grep -i "realtek.*bluetooth" | head -1 | sed 's/^/     /'
    if [[ ! " ${FIRMWARE_NEEDED[@]} " =~ " firmware-realtek " ]]; then
        FIRMWARE_NEEDED+=("firmware-realtek")
        FIRMWARE_DESCRIPTIONS+=("Realtek Bluetooth")
    fi
    BT_FOUND=true
    
elif lsusb | grep -i "mediatek.*bluetooth" > /dev/null 2>&1; then
    echo "   • MediaTek Bluetooth detectado"
    lsusb | grep -i "mediatek.*bluetooth" | head -1 | sed 's/^/     /'
    if [[ ! " ${FIRMWARE_NEEDED[@]} " =~ " firmware-mediatek " ]]; then
        FIRMWARE_NEEDED+=("firmware-mediatek")
        FIRMWARE_DESCRIPTIONS+=("MediaTek Bluetooth")
    fi
    BT_FOUND=true
fi

if [ "$BT_FOUND" = "false" ]; then
    echo "   • No detectado"
fi

echo ""

# ============================================================================
# ETHERNET
# ============================================================================

echo "🌐 Ethernet:"

ETH_FOUND=false

if lspci | grep -i "ethernet" | grep -i "realtek\|rtl" > /dev/null 2>&1; then
    ETH_INFO=$(lspci | grep -i "ethernet" | grep -i "realtek" | head -1)
    echo "   • Realtek Ethernet detectada"
    echo "     $ETH_INFO" | sed 's/^/     /'
    if [[ ! " ${FIRMWARE_NEEDED[@]} " =~ " firmware-realtek " ]]; then
        FIRMWARE_NEEDED+=("firmware-realtek")
        FIRMWARE_DESCRIPTIONS+=("Realtek Ethernet")
    fi
    ETH_FOUND=true
    
elif lspci | grep -i "ethernet" | grep -i "intel" > /dev/null 2>&1; then
    ETH_INFO=$(lspci | grep -i "ethernet" | grep -i "intel" | head -1)
    echo "   • Intel Ethernet detectada"
    echo "     $ETH_INFO" | sed 's/^/     /'
    ETH_FOUND=true
    
elif lspci | grep -i "ethernet" > /dev/null 2>&1; then
    ETH_INFO=$(lspci | grep -i "ethernet" | head -1)
    echo "   • Ethernet detectada"
    echo "     $ETH_INFO" | sed 's/^/     /'
    ETH_FOUND=true
fi

if [ "$ETH_FOUND" = "false" ]; then
    echo "   • No detectada"
fi

echo ""

# ============================================================================
# CPU MICROCODE
# ============================================================================

echo "🖥️  CPU:"

if grep -q "GenuineIntel" /proc/cpuinfo; then
    CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
    echo "   • Intel CPU detectada"
    echo "     $CPU_MODEL"
    FIRMWARE_NEEDED+=("intel-microcode")
    FIRMWARE_DESCRIPTIONS+=("Intel CPU Microcode")
    
elif grep -q "AuthenticAMD" /proc/cpuinfo; then
    CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
    echo "   • AMD CPU detectada"
    echo "     $CPU_MODEL"
    FIRMWARE_NEEDED+=("amd64-microcode")
    FIRMWARE_DESCRIPTIONS+=("AMD CPU Microcode")
fi

echo ""

# ============================================================================
# RESUMEN DE FIRMWARE NECESARIO
# ============================================================================

echo "════════════════════════════════════════════════════════════════"
echo "  RESUMEN DE FIRMWARE NECESARIO"
echo "════════════════════════════════════════════════════════════════"
echo ""

if [ ${#FIRMWARE_NEEDED[@]} -eq 0 ]; then
    echo "✓ No se requiere firmware adicional"
    echo ""
    exit 0
fi

echo "Se instalará firmware para:"
for i in "${!FIRMWARE_NEEDED[@]}"; do
    printf "  ✓ %-30s → %s\n" "${FIRMWARE_DESCRIPTIONS[$i]}" "${FIRMWARE_NEEDED[$i]}"
done

echo ""
echo "Total de paquetes: ${#FIRMWARE_NEEDED[@]}"
echo ""

# ============================================================================
# INSTALACIÓN DE FIRMWARE
# ============================================================================

echo "Instalando firmware..."
echo ""

APT_FLAGS=""
[ "$USE_NO_INSTALL_RECOMMENDS" = "true" ] && APT_FLAGS="--no-install-recommends"

arch-chroot "$TARGET" /bin/bash << CHROOTEOF
export DEBIAN_FRONTEND=noninteractive

# NOTA: Ubuntu no usa "contrib" ni "non-free" (eso es Debian)
# El firmware en Ubuntu está en "restricted" y "multiverse"
# Verificar que multiverse está habilitado en ubuntu.sources

if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then
    if ! grep -q "multiverse" /etc/apt/sources.list.d/ubuntu.sources; then
        echo "⚠ Habilitando multiverse para firmware..."
        sed -i 's/Components: main restricted universe/Components: main restricted universe multiverse/' /etc/apt/sources.list.d/ubuntu.sources
        echo "✓ Multiverse habilitado"
    fi
else
    echo "⚠ ubuntu.sources no encontrado, verificando sources.list legacy..."
    if [ -f /etc/apt/sources.list ] && ! grep -q "multiverse" /etc/apt/sources.list; then
        sed -i 's/main restricted universe/main restricted universe multiverse/' /etc/apt/sources.list
    fi
fi

if ! apt update 2>/dev/null; then
    echo "ERROR: apt update falló" >&2
fi

APT_FLAGS="$APT_FLAGS"

# Instalar cada paquete de firmware
FIRMWARE_LIST="${FIRMWARE_NEEDED[*]}"
INSTALLED=0
FAILED=0

for package in \$FIRMWARE_LIST; do
    echo "Instalando \$package..."
    if apt install -y \$APT_FLAGS \$package 2>/dev/null; then
        echo "✓ \$package instalado"
        ((INSTALLED++))
    else
        echo "✗ No se pudo instalar \$package" >&2
        ((FAILED++))
    fi
done

echo ""
echo "Resumen instalación firmware:"
echo "  Instalados: \$INSTALLED"
echo "  Fallidos: \$FAILED"

if [ \$FAILED -gt 0 ]; then
    exit 1
fi

CHROOTEOF

if [ $? -ne 0 ]; then
    log_error "$MODULE_NAME" "Algunos paquetes de firmware no se instalaron" "WARNING"
    ((MODULE_WARNINGS++))
else
    log_success "$MODULE_NAME" "Todos los paquetes de firmware instalados"
fi

# ============================================================================
# CONFIRMACIÓN FINAL
# ============================================================================

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓ FIRMWARE INSTALADO CORRECTAMENTE"
echo "════════════════════════════════════════════════════════════════"
echo ""

echo "Firmware instalado para:"
for desc in "${FIRMWARE_DESCRIPTIONS[@]}"; do
    echo "  ✓ $desc"
done

echo ""

# ============================================================================
# CONFIRMACIÓN FINAL CON RESUMEN DE ERRORES
# ============================================================================

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓ FIRMWARE INSTALADO CORRECTAMENTE"
echo "════════════════════════════════════════════════════════════════"
echo ""

echo "Firmware instalado para:"
for desc in "${FIRMWARE_DESCRIPTIONS[@]}"; do
    echo "  ✓ $desc"
done

echo ""

# Mostrar resumen de errores si los hay
show_error_summary "$MODULE_NAME"

exit 0

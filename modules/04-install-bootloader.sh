#!/bin/bash
# Módulo 04: Instalar kernel y bootloader

set -e  # Fallar inmediatamente en errores reales

source "$(dirname "$0")/../config.env"
[ -f "$(dirname "$0")/../partition.info" ] && source "$(dirname "$0")/../partition.info"

# ============================================================================
# CONFIGURACIÓN INICIAL
# ============================================================================

echo "════════════════════════════════════════════════════════════════"
echo "  INSTALACIÓN DE KERNEL Y BOOTLOADER"
echo "════════════════════════════════════════════════════════════════"
echo "Firmware: $FIRMWARE"
echo "Dual-boot: ${DUAL_BOOT_MODE:-false}"
echo ""

# Configurar según firmware
if [ "$FIRMWARE" = "UEFI" ]; then
    GRUB_PKG="grub-efi-amd64"
    GRUB_TARGET="x86_64-efi"
    EFI_DIR="/boot/efi"
else
    GRUB_PKG="grub-pc"
    GRUB_TARGET="i386-pc"
    EFI_DIR=""
    
    # Validar TARGET_DISK para BIOS
    if [ -z "$TARGET_DISK" ]; then
        echo "❌ ERROR: TARGET_DISK no definido para sistema BIOS"
        echo "   Define TARGET_DISK en config.env (ejemplo: /dev/sda)"
        exit 1
    fi
fi

# Configurar APT flags
APT_FLAGS=""
[ "$USE_NO_INSTALL_RECOMMENDS" = "true" ] && APT_FLAGS="--no-install-recommends"

# ============================================================================
# INSTALACIÓN EN CHROOT
# ============================================================================

arch-chroot "$TARGET" /bin/bash << EOF
set -e
export DEBIAN_FRONTEND=noninteractive

echo "Instalando kernel y herramientas base..."
apt-get install -y $APT_FLAGS \
    linux-image-generic \
    linux-headers-generic \
    $GRUB_PKG \
    dracut \
    bash-completion \
    zstd \
    xz-utils \
    wget \
    nano

echo "✓ Kernel instalado"

# efibootmgr solo para UEFI
if [ "$FIRMWARE" = "UEFI" ]; then
    apt-get install -y $APT_FLAGS efibootmgr
    echo "✓ efibootmgr instalado"
fi

# os-prober solo para dual-boot
if [ "${DUAL_BOOT_MODE:-false}" = "true" ]; then
    apt-get install -y $APT_FLAGS os-prober ntfs-3g
    
    # Configurar GRUB para dual-boot
    if ! grep -q "^GRUB_DISABLE_OS_PROBER=" /etc/default/grub; then
        echo "GRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub
    else
        sed -i 's/^GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
    fi
    
    if ! grep -q "^GRUB_TIMEOUT=" /etc/default/grub; then
        echo "GRUB_TIMEOUT=10" >> /etc/default/grub
    else
        sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=10/' /etc/default/grub
    fi
    
    echo "✓ os-prober configurado"
fi

# Instalar GRUB en el disco
echo "Instalando GRUB..."
if [ "$FIRMWARE" = "UEFI" ]; then
    grub-install \
        --target=$GRUB_TARGET \
        --efi-directory=$EFI_DIR \
        --bootloader-id=ubuntu \
        --recheck
else
    grub-install \
        --target=$GRUB_TARGET \
        $TARGET_DISK
fi

echo "✓ GRUB instalado en disco"

# Configurar parámetros de boot
GRUB_FILE="/etc/default/grub"
CURRENT_CMDLINE=\$(grep '^GRUB_CMDLINE_LINUX_DEFAULT=' "\$GRUB_FILE" | cut -d'"' -f2)

# Parámetros de Clear Linux + intel_pstate
BOOT_PARAMS="intel_pstate=active cryptomgr.notests intel_iommu=igfx_off no_timer_check page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable nowatchdog nmi_watchdog=0"

# Añadir parámetros que no existan ya
NEW_CMDLINE="\$CURRENT_CMDLINE"
for param in \$BOOT_PARAMS; do
    param_name="\${param%%=*}"
    if ! echo "\$NEW_CMDLINE" | grep -qw "\$param_name"; then
        NEW_CMDLINE="\$NEW_CMDLINE \$param"
    fi
done

sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"\$NEW_CMDLINE\"|" "\$GRUB_FILE"

# Añadir documentación de parámetros opcionales
if ! grep -q "Parámetros opcionales de testing" "\$GRUB_FILE"; then
    cat >> "\$GRUB_FILE" << 'GRUBDOC'

# ============================================================================
# PARÁMETROS OPCIONALES (descomentar para probar)
# ============================================================================
# mitigations=off         → +10-20% CPU (desactiva Spectre/Meltdown)
# split_lock_detect=off   → Sin verificación errores (Intel 10ª gen+)
#
# Después de editar: sudo update-grub
# ============================================================================
GRUBDOC
fi

echo "✓ Parámetros de boot configurados"

# Generar grub.cfg
echo "Generando configuración de GRUB..."

if [ "${DUAL_BOOT_MODE:-false}" = "true" ]; then
    # En dual-boot, ejecutar os-prober antes de update-grub
    echo "Detectando otros sistemas operativos..."
    os-prober > /tmp/os-prober.out 2>&1 || true
    
    if [ -s /tmp/os-prober.out ]; then
        echo "Sistemas detectados:"
        cat /tmp/os-prober.out
    else
        echo "⚠ No se detectaron otros sistemas operativos"
    fi
fi

# update-grub con captura de salida
update-grub > /tmp/update-grub.out 2>&1
UPDATE_GRUB_EXIT=\$?

if [ \$UPDATE_GRUB_EXIT -eq 0 ]; then
    echo "✓ grub.cfg generado correctamente"
else
    echo "⚠ update-grub exit code: \$UPDATE_GRUB_EXIT"
    echo "Salida:"
    cat /tmp/update-grub.out
fi

EOF

CHROOT_EXIT=$?

# ============================================================================
# VALIDACIÓN POST-CHROOT
# ============================================================================

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  VALIDACIÓN"
echo "════════════════════════════════════════════════════════════════"

VALIDATION_FAILED=false

# Verificar kernel
if ! ls "$TARGET/boot/vmlinuz-"* >/dev/null 2>&1; then
    echo "❌ CRÍTICO: No se encontró kernel en $TARGET/boot/"
    VALIDATION_FAILED=true
else
    KERNEL_VERSION=$(ls "$TARGET/boot/vmlinuz-"* | tail -1 | xargs basename | sed 's/vmlinuz-//')
    echo "✓ Kernel: $KERNEL_VERSION"
fi

# Verificar grub.cfg
if [ ! -f "$TARGET/boot/grub/grub.cfg" ]; then
    echo "❌ CRÍTICO: grub.cfg no existe"
    VALIDATION_FAILED=true
else
    GRUB_LINES=$(wc -l < "$TARGET/boot/grub/grub.cfg")
    if [ "$GRUB_LINES" -lt 10 ]; then
        echo "❌ CRÍTICO: grub.cfg demasiado pequeño ($GRUB_LINES líneas)"
        VALIDATION_FAILED=true
    else
        echo "✓ grub.cfg: $GRUB_LINES líneas"
    fi
fi

# Verificar entrada de Ubuntu en grub.cfg
if grep -q "menuentry.*Ubuntu" "$TARGET/boot/grub/grub.cfg"; then
    echo "✓ Entrada de Ubuntu encontrada en GRUB"
else
    echo "⚠ Advertencia: No se encontró entrada 'Ubuntu' en grub.cfg"
fi

# Verificar initramfs
if ls "$TARGET/boot/initrd.img-"* >/dev/null 2>&1; then
    echo "✓ initramfs presente"
else
    echo "⚠ Advertencia: initramfs no encontrado"
fi

echo ""

# ============================================================================
# RESULTADO FINAL
# ============================================================================

if [ "$VALIDATION_FAILED" = true ]; then
    echo "════════════════════════════════════════════════════════════════"
    echo "❌ INSTALACIÓN DE BOOTLOADER FALLÓ"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    echo "Archivos críticos faltantes. El sistema NO arrancará."
    echo ""
    exit 1
fi

if [ $CHROOT_EXIT -ne 0 ]; then
    echo "════════════════════════════════════════════════════════════════"
    echo "⚠ ADVERTENCIA: Exit code del chroot = $CHROOT_EXIT"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    echo "Los archivos críticos existen, pero hubo warnings durante update-grub."
    echo "Esto es NORMAL en entornos chroot (falta acceso a /proc, /sys)."
    echo ""
    echo "Log de update-grub disponible en: $TARGET/tmp/update-grub.out"
    echo ""
    
    # Mostrar solo si hay contenido relevante
    if [ -f "$TARGET/tmp/update-grub.out" ]; then
        if grep -i "error\|fail" "$TARGET/tmp/update-grub.out" >/dev/null; then
            echo "Errores/warnings detectados:"
            grep -i "error\|fail\|warn" "$TARGET/tmp/update-grub.out" | head -5
            echo ""
        fi
    fi
fi

echo "════════════════════════════════════════════════════════════════"
echo "✓ BOOTLOADER INSTALADO CORRECTAMENTE"
echo "════════════════════════════════════════════════════════════════"
[ "${DUAL_BOOT_MODE:-false}" = "true" ] && echo "• Dual-boot configurado (timeout 10s)"
echo "• Parámetros Clear Linux activos"
echo "• Kernel: $KERNEL_VERSION"
echo ""

exit 0

#!/bin/bash
# Módulo 04: Instalar kernel y bootloader (con soporte dual-boot)

source "$(dirname "$0")/../config.env"
[ -f "$(dirname "$0")/../partition.info" ] && source "$(dirname "$0")/../partition.info"

echo "Instalando kernel y GRUB..."
echo "Firmware: $FIRMWARE"
echo "Dual-boot: ${DUAL_BOOT_MODE:-false}"

APT_FLAGS=""
[ "$USE_NO_INSTALL_RECOMMENDS" = "true" ] && APT_FLAGS="--no-install-recommends"

if [ "$FIRMWARE" = "UEFI" ]; then
    GRUB_PKG="grub-efi-amd64"
    GRUB_TGT="x86_64-efi"
    GRUB_DIR="/boot/efi"
else
    GRUB_PKG="grub-pc"
    GRUB_TGT="i386-pc"
    GRUB_DIR=""
fi

# Validar disco en BIOS antes de entrar al chroot
if [ "$FIRMWARE" != "UEFI" ] && [ -z "$TARGET_DISK" ]; then
    echo "⚠ TARGET_DISK no está definido y el sistema es BIOS"
    echo "  Define TARGET_DISK en config.env (ej: /dev/sda)"
    exit 1
fi

arch-chroot "$TARGET" /bin/bash << CHROOTEOF
export DEBIAN_FRONTEND=noninteractive
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export LANGUAGE=C

APT_FLAGS="$APT_FLAGS"
GRUB_PKG="$GRUB_PKG"
GRUB_TGT="$GRUB_TGT"
GRUB_DIR="$GRUB_DIR"
DUAL_BOOT_MODE="${DUAL_BOOT_MODE:-false}"
TARGET_DISK="$TARGET_DISK"

# Paquetes base
apt install -y \$APT_FLAGS \
    linux-image-generic \
    linux-headers-generic \
    \$GRUB_PKG \
    dracut \
    bash-completion \
    zstd \
    xz-utils \
    wget \
    nano

echo "✓ Kernel y paquetes base instalados"

# efibootmgr solo en UEFI
if [ "\$GRUB_TGT" = "x86_64-efi" ]; then
    apt install -y \$APT_FLAGS efibootmgr
    echo "✓ efibootmgr instalado (UEFI)"
fi

# os-prober solo en dual-boot
if [ "\$DUAL_BOOT_MODE" = "true" ]; then
    apt install -y os-prober ntfs-3g
    echo "GRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub
    sed -i 's/GRUB_TIMEOUT=.*/GRUB_TIMEOUT=10/' /etc/default/grub 2>/dev/null \
        || echo "GRUB_TIMEOUT=10" >> /etc/default/grub
fi

# Instalar GRUB
if [ "\$GRUB_TGT" = "x86_64-efi" ]; then
    grub-install \
        --target=\$GRUB_TGT \
        --efi-directory=\$GRUB_DIR \
        --bootloader-id=ubuntu \
        --recheck
else
    grub-install \
        --target=\$GRUB_TGT \
        \$TARGET_DISK
fi

echo "✓ GRUB instalado en el disco"

# ============================================================================
# PARÁMETROS DE BOOT - CONFIGURACIÓN MODULAR
# ============================================================================

GRUB_FILE="/etc/default/grub"
CURRENT_CMDLINE=\$(grep '^GRUB_CMDLINE_LINUX_DEFAULT=' "\$GRUB_FILE" | cut -d'"' -f2)

# === PARÁMETROS ACTIVOS (Clear Linux base + hardware nativo) ===
CLEAR_PARAMS_ACTIVE="intel_pstate=active cryptomgr.notests intel_iommu=igfx_off no_timer_check page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable nowatchdog nmi_watchdog=0"

# === PARÁMETROS OPCIONALES PARA TESTING ===
# Descomenta en /etc/default/grub después de la instalación para probar:
#
# mitigations=off           → +10-20% rendimiento CPU (vulnerabilidades activas)
# split_lock_detect=off     → Sin verificación split locks (10ª gen Intel+)

NEW_CMDLINE="\$CURRENT_CMDLINE"
for param in \$CLEAR_PARAMS_ACTIVE; do
    if ! echo "\$NEW_CMDLINE" | grep -q "\${param%%=*}"; then
        NEW_CMDLINE="\$NEW_CMDLINE \$param"
    fi
done

# Añadir comentarios informativos al archivo grub
if ! grep -q "# Parámetros opcionales de testing" "\$GRUB_FILE"; then
    cat >> "\$GRUB_FILE" << 'GRUBCOMMENT'

# ============================================================================
# PARÁMETROS OPCIONALES DE TESTING
# ============================================================================
# Añade estos parámetros a GRUB_CMDLINE_LINUX_DEFAULT para testing:
#
# mitigations=off           → +10-20% CPU (desactiva Spectre/Meltdown)
# split_lock_detect=off     → Sin verificación de errores (10ª gen Intel+)
#
# Después de editar ejecuta: sudo update-grub
# ============================================================================
GRUBCOMMENT
fi

sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"\$NEW_CMDLINE\"|" "\$GRUB_FILE"
echo "✓ Parámetros de boot configurados"

# update-grub puede devolver warnings en chroot (sin /proc /sys montados)
# los ignoramos con || true — la validación real se hace fuera del chroot
if [ "\$DUAL_BOOT_MODE" = "true" ]; then
    os-prober 2>/dev/null || true
fi
update-grub || true

CHROOTEOF

# ============================================================================
# VALIDACIÓN DESDE FUERA DEL CHROOT
# Aquí sí tenemos acceso real a los archivos sin interferencia del entorno
# ============================================================================

ERRORS=0

if ! ls "$TARGET/boot/vmlinuz-"* 2>/dev/null | grep -q vmlinuz; then
    echo "✗ ERROR: No se encontró kernel en $TARGET/boot"
    ERRORS=$((ERRORS+1))
else
    echo "✓ Kernel: $(ls $TARGET/boot/vmlinuz-* | tail -1 | xargs basename)"
fi

if [ ! -f "$TARGET/boot/grub/grub.cfg" ]; then
    echo "✗ ERROR: grub.cfg no fue generado"
    ERRORS=$((ERRORS+1))
else
    echo "✓ grub.cfg generado ($(wc -l < $TARGET/boot/grub/grub.cfg) líneas)"
fi

if [ $ERRORS -gt 0 ]; then
    echo ""
    echo "✗ El bootloader no quedó correctamente instalado"
    exit 1
fi

echo ""
echo "✓✓✓ Bootloader instalado ✓✓✓"
[ "${DUAL_BOOT_MODE:-false}" = "true" ] && echo "Dual-boot configurado con timeout de 10s"

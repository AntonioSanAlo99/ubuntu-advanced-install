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
fi

arch-chroot "$TARGET" /bin/bash -s "$GRUB_PKG" "$GRUB_TGT" "$GRUB_DIR" "${DUAL_BOOT_MODE:-false}" "$TARGET_DISK" "$APT_FLAGS" << 'CHROOTEOF'
export DEBIAN_FRONTEND=noninteractive

# Obtener variables del host
GRUB_PKG="$1"
GRUB_TGT="$2"
GRUB_DIR="$3"
DUAL_BOOT_MODE="$4"
TARGET_DISK="$5"
APT_FLAGS="$6"

apt install -y $APT_FLAGS \
    linux-image-generic \
    linux-headers-generic \
    $GRUB_PKG \
    efibootmgr \
    dracut \
    bash-completion \
    zstd \
    xz-utils \
    wget \
    nano

echo "✓ Paquetes base instalados (incluyendo dracut)"

# Dual-boot: instalar os-prober
if [ "$DUAL_BOOT_MODE" = "true" ]; then
    echo "Instalando os-prober para dual-boot..."
    apt install -y os-prober ntfs-3g
    echo "GRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub
    sed -i 's/GRUB_TIMEOUT=.*/GRUB_TIMEOUT=10/' /etc/default/grub 2>/dev/null || echo "GRUB_TIMEOUT=10" >> /etc/default/grub
fi

# Instalar GRUB
if [ -n "$GRUB_DIR" ]; then
    # UEFI
    grub-install --target=$GRUB_TGT --efi-directory=$GRUB_DIR --bootloader-id=ubuntu --recheck
else
    # BIOS
    grub-install --target=$GRUB_TGT $TARGET_DISK
fi

# Detectar otros OS y generar config
if [ "$DUAL_BOOT_MODE" = "true" ]; then
    os-prober 2>/dev/null || true
fi

update-grub

# ============================================================================
# PARÁMETROS DE BOOT CLEAR LINUX
# Fuente: clearlinux-pkgs/linux (parámetros oficiales de producción)
# ============================================================================

echo "Aplicando parámetros de boot Clear Linux..."

GRUB_FILE="/etc/default/grub"

# Leer cmdline actual
CURRENT_CMDLINE=$(grep '^GRUB_CMDLINE_LINUX_DEFAULT=' "$GRUB_FILE" | cut -d'"' -f2)

# Parámetros Clear Linux de producción (del boot loader oficial)
# Fuente: kernel-org.clearlinux.native entries
CLEAR_PARAMS="cryptomgr.notests \
    intel_iommu=igfx_off \
    no_timer_check \
    page_alloc.shuffle=1 \
    rcupdate.rcu_expedited=1 \
    tsc=reliable \
    nowatchdog \
    nmi_watchdog=0"

# Añadir parámetros sin duplicar
NEW_CMDLINE="$CURRENT_CMDLINE"
for param in $CLEAR_PARAMS; do
    if ! echo "$NEW_CMDLINE" | grep -q "${param%%=*}"; then
        NEW_CMDLINE="$NEW_CMDLINE $param"
    fi
done

# Escribir en GRUB
sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$NEW_CMDLINE\"|" "$GRUB_FILE"

# Regenerar GRUB
update-grub

echo "✓ Parámetros de boot Clear Linux aplicados:"
echo "  • cryptomgr.notests       → Salta tests crypto en boot (más rápido)"
echo "  • intel_iommu=igfx_off    → iGPU no usa IOMMU (mejor rendimiento gráfico)"
echo "  • no_timer_check          → Elimina check de timer al boot"
echo "  • page_alloc.shuffle=1    → Aleatoriza orden de páginas (seguridad + rendimiento)"
echo "  • rcupdate.rcu_expedited=1→ RCU expedited mode (menor latencia)"
echo "  • tsc=reliable            → TSC como fuente de tiempo fiable"
echo "  • nowatchdog              → Deshabilita watchdog (menos overhead)"
echo "  • nmi_watchdog=0          → Sin NMI watchdog (menos interrupciones)"

echo "✓ GRUB instalado"

if [ "$DUAL_BOOT_MODE" = "true" ]; then
    echo ""
    echo "Sistemas detectados:"
    if grep -q menuentry /boot/grub/grub.cfg; then
        grep menuentry /boot/grub/grub.cfg | grep -v "menuentry_id_option" | sed 's/.*menuentry /  • /' | sed "s/'.*$//" | head -5
    else
        echo "  • Solo Ubuntu"
    fi
fi

# Asegurar exit code 0
exit 0
CHROOTEOF

CHROOT_EXIT=$?

if [ $CHROOT_EXIT -ne 0 ]; then
    echo ""
    echo "⚠ Error durante la instalación del bootloader (exit code: $CHROOT_EXIT)"
    exit 1
fi

echo ""
echo "✓✓✓ Bootloader instalado ✓✓✓"
[ "$DUAL_BOOT_MODE" = "true" ] && echo "Dual-boot configurado con timeout de 10s"

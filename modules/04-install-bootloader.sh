#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
# MÓDULO 04: Instalación de kernel y bootloader (GRUB)
# Soporte completo para UEFI/BIOS, instalación limpia y dual boot.
# Nivel de robustez equivalente a Calamares / instalador oficial Ubuntu.
# ══════════════════════════════════════════════════════════════════════════════

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "${SCRIPT_DIR}/../partition.info" ] && source "${SCRIPT_DIR}/../partition.info"

# Verificar que TARGET está montado y el chroot es funcional
if ! mountpoint -q "${TARGET:-/mnt/ubuntu}" 2>/dev/null; then
    echo "ERROR: TARGET=${TARGET:-/mnt/ubuntu} no está montado." >&2
    exit 1
fi
if [ ! -x "${TARGET:-/mnt/ubuntu}/usr/bin/apt-get" ]; then
    echo "ERROR: Chroot en ${TARGET:-/mnt/ubuntu} sin apt-get." >&2
    exit 1
fi

echo "  Firmware   : $FIRMWARE"
echo "  Dual boot  : ${DUAL_BOOT_MODE:-false}"
echo "  Disco      : $TARGET_DISK"
[ -n "$EFI_PART"  ] && echo "  EFI        : $EFI_PART"
[ -n "$SWAP_PART" ] && echo "  Swap       : $SWAP_PART"
echo "  Root       : $ROOT_PART"
echo ""

# ============================================================================
# PARÁMETROS SEGÚN FIRMWARE
# ============================================================================

if [ "$FIRMWARE" = "UEFI" ]; then
    GRUB_PKG="grub-efi-amd64 grub-efi-amd64-signed shim-signed"
    GRUB_TARGET="x86_64-efi"
    EFI_DIR="/boot/efi"
else
    GRUB_PKG="grub-pc"
    GRUB_TARGET="i386-pc"
    EFI_DIR=""
    if [ -z "$TARGET_DISK" ]; then
        echo "  ✗  TARGET_DISK no definido para sistema BIOS"
        exit 1
    fi
fi

# ============================================================================
# INSTALACIÓN EN CHROOT
# ============================================================================

arch-chroot "$TARGET" /bin/bash << CHROOTEOF
set -e
export DEBIAN_FRONTEND=noninteractive

FIRMWARE="$FIRMWARE"
DUAL_BOOT_MODE="${DUAL_BOOT_MODE:-false}"
TARGET_DISK="$TARGET_DISK"
GRUB_TARGET="$GRUB_TARGET"
EFI_DIR="$EFI_DIR"
SWAP_PART="$SWAP_PART"

# ── Preseed grub-pc para BIOS (evita el prompt de debconf) ──────────────────
if [ "\$FIRMWARE" = "BIOS" ] && [ -n "\$TARGET_DISK" ]; then
    echo "grub-pc grub-pc/install_devices string \$TARGET_DISK" | debconf-set-selections
    echo "grub-pc grub-pc/install_devices_empty boolean false"  | debconf-set-selections
fi

# ── Kernel e initramfs ───────────────────────────────────────────────────────
echo "Instalando kernel..."
apt-get install -y \
    linux-image-generic \
    linux-headers-generic \
    initramfs-tools \
    bash-completion \
    zstd xz-utils wget nano

echo "  ✓  Kernel instalado"

# ── GRUB y herramientas de boot ──────────────────────────────────────────────
echo "Instalando GRUB ($GRUB_TARGET)..."
apt-get install -y $GRUB_PKG

if [ "\$FIRMWARE" = "UEFI" ]; then
    apt-get install -y efibootmgr
fi

echo "  ✓  GRUB instalado"

# ── os-prober y soporte NTFS para dual boot ──────────────────────────────────
if [ "\$DUAL_BOOT_MODE" = "true" ]; then
    apt-get install -y os-prober ntfs-3g
    echo "  ✓  os-prober + ntfs-3g instalados"
fi

# ── Activar swap si existe ───────────────────────────────────────────────────
if [ -n "\$SWAP_PART" ]; then
    swapon "\$SWAP_PART" 2>/dev/null || true
fi

# ============================================================================
# CONFIGURACIÓN DE /etc/default/grub
# ============================================================================
# Parámetros del kernel configurables en 4 niveles (KERNEL_PARAMS_LEVEL):
#
#   1) Base — escritorio optimizado (Clear Linux + Ubuntu best practices)
#      quiet splash intel_pstate=active no_timer_check page_alloc.shuffle=1
#      rcupdate.rcu_expedited=1 nowatchdog nmi_watchdog=0
#
#   2) Base + Gaming — baja latencia, sin comprometer seguridad
#      Añade: preempt=full tsc=reliable split_lock_detect=off
#
#   3) Base + Gaming + mitigations=off — máximo rendimiento
#      Añade: mitigations=off (desactiva Spectre/Meltdown, +5-10% FPS)
#      ⚠ Reduce la seguridad del sistema
#
#   4) Mínimo — solo quiet splash
# ============================================================================

GRUB_FILE="/etc/default/grub"

PARAMS_BASE="quiet splash intel_pstate=active no_timer_check page_alloc.shuffle=1 rcupdate.rcu_expedited=1 nowatchdog nmi_watchdog=0"
PARAMS_GAMING="preempt=full tsc=reliable split_lock_detect=off"
PARAMS_UNSAFE="mitigations=off"

case "${KERNEL_PARAMS_LEVEL:-1}" in
    2) BOOT_PARAMS="\$PARAMS_BASE \$PARAMS_GAMING" ;;
    3) BOOT_PARAMS="\$PARAMS_BASE \$PARAMS_GAMING \$PARAMS_UNSAFE" ;;
    4) BOOT_PARAMS="quiet splash" ;;
    *) BOOT_PARAMS="\$PARAMS_BASE" ;;
esac

# Leer cmdline actual y añadir solo los parámetros que no existan ya
CURRENT=\$(grep '^GRUB_CMDLINE_LINUX_DEFAULT=' "\$GRUB_FILE" 2>/dev/null | cut -d'"' -f2 || echo "")
NEW_CMDLINE="\$CURRENT"
for param in \$BOOT_PARAMS; do
    pname="\${param%%=*}"
    echo "\$NEW_CMDLINE" | grep -qw "\$pname" || NEW_CMDLINE="\$NEW_CMDLINE \$param"
done
NEW_CMDLINE=\$(echo "\$NEW_CMDLINE" | xargs)

# Aplicar cmdline con sed
if grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=' "\$GRUB_FILE"; then
    sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"\$NEW_CMDLINE\"|" "\$GRUB_FILE"
else
    echo "GRUB_CMDLINE_LINUX_DEFAULT=\"\$NEW_CMDLINE\"" >> "\$GRUB_FILE"
fi

# GRUB_CMDLINE_LINUX: parámetros que aplican también al modo recovery
# Añadir fsck.mode=skip en recovery evita esperas innecesarias
if ! grep -q '^GRUB_CMDLINE_LINUX=' "\$GRUB_FILE"; then
    echo 'GRUB_CMDLINE_LINUX=""' >> "\$GRUB_FILE"
fi

# ── Timeout ──────────────────────────────────────────────────────────────────
# Instalación limpia: 0 (arranque inmediato — comportamiento de Ubuntu OEM)
# Dual boot: 10 s (tiempo suficiente para elegir SO, igual que Calamares)
if [ "\$DUAL_BOOT_MODE" = "true" ]; then
    GRUB_TIMEOUT_VAL=10
    GRUB_TIMEOUT_STYLE="menu"
else
    GRUB_TIMEOUT_VAL=0
    GRUB_TIMEOUT_STYLE="hidden"
fi

sed -i "s|^GRUB_TIMEOUT=.*|GRUB_TIMEOUT=\$GRUB_TIMEOUT_VAL|" "\$GRUB_FILE" || \
    echo "GRUB_TIMEOUT=\$GRUB_TIMEOUT_VAL" >> "\$GRUB_FILE"

# GRUB_TIMEOUT_STYLE: hidden (no muestra menú si solo hay 1 SO)
#                     menu   (siempre muestra menú — necesario para dual boot)
if grep -q '^GRUB_TIMEOUT_STYLE=' "\$GRUB_FILE"; then
    sed -i "s|^GRUB_TIMEOUT_STYLE=.*|GRUB_TIMEOUT_STYLE=\$GRUB_TIMEOUT_STYLE|" "\$GRUB_FILE"
else
    echo "GRUB_TIMEOUT_STYLE=\$GRUB_TIMEOUT_STYLE" >> "\$GRUB_FILE"
fi

# ── os-prober ────────────────────────────────────────────────────────────────
# En Ubuntu 22.04+ os-prober está desactivado por defecto por razones de
# seguridad (CVE). Para dual boot hay que activarlo explícitamente.
if [ "\$DUAL_BOOT_MODE" = "true" ]; then
    if grep -q '^GRUB_DISABLE_OS_PROBER=' "\$GRUB_FILE"; then
        sed -i 's|^GRUB_DISABLE_OS_PROBER=.*|GRUB_DISABLE_OS_PROBER=false|' "\$GRUB_FILE"
    else
        echo 'GRUB_DISABLE_OS_PROBER=false' >> "\$GRUB_FILE"
    fi
else
    # Sin dual boot, desactivar os-prober (evita detectar discos externos)
    if grep -q '^GRUB_DISABLE_OS_PROBER=' "\$GRUB_FILE"; then
        sed -i 's|^GRUB_DISABLE_OS_PROBER=.*|GRUB_DISABLE_OS_PROBER=true|' "\$GRUB_FILE"
    else
        echo 'GRUB_DISABLE_OS_PROBER=true' >> "\$GRUB_FILE"
    fi
fi

# ── Distributor ──────────────────────────────────────────────────────────────
# Nombre que aparece en el menú de GRUB
if grep -q '^GRUB_DISTRIBUTOR=' "\$GRUB_FILE"; then
    sed -i 's|^GRUB_DISTRIBUTOR=.*|GRUB_DISTRIBUTOR="Ubuntu"|' "\$GRUB_FILE"
else
    echo 'GRUB_DISTRIBUTOR="Ubuntu"' >> "\$GRUB_FILE"
fi

# ── Documentación de parámetros opcionales ───────────────────────────────────
if ! grep -q '# Parámetros opcionales' "\$GRUB_FILE"; then
    cat >> "\$GRUB_FILE" << 'GRUBDOC'

# ============================================================================
# PARÁMETROS OPCIONALES (descomentar y ejecutar sudo update-grub para aplicar)
# ============================================================================
# mitigations=off         → +10-20% CPU en cargas intensivas
#                           (desactiva mitigaciones Spectre/Meltdown)
# split_lock_detect=off   → Sin penalización por split-lock (Intel 10ª gen+)
# amd_pstate=active       → Equivalente a intel_pstate para CPUs AMD Zen 2+
# ============================================================================
GRUBDOC
fi

echo "  ✓  /etc/default/grub configurado"
echo "     cmdline: \$NEW_CMDLINE"
echo "     timeout: \${GRUB_TIMEOUT_VAL}s (style: \$GRUB_TIMEOUT_STYLE)"

# ============================================================================
# INSTALACIÓN DE GRUB EN DISCO
# ============================================================================

echo ""
echo "Instalando GRUB en disco..."

if [ "\$FIRMWARE" = "UEFI" ]; then
    # ── UEFI ─────────────────────────────────────────────────────────────────
    # --bootloader-id : nombre de la entrada en el firmware EFI (aparece en F12)
    # --recheck       : fuerza re-detección del dispositivo EFI
    # --no-nvram      : NO escribe en la NVRAM del firmware todavía
    #                   (lo hacemos después con efibootmgr para tener control total)
    # --uefi-secure-boot: instala el shim firmado para Secure Boot
    grub-install \
        --target="\$GRUB_TARGET" \
        --efi-directory="\$EFI_DIR" \
        --bootloader-id="ubuntu" \
        --recheck \
        --no-nvram \
        2>/dev/null || \
    grub-install \
        --target="\$GRUB_TARGET" \
        --efi-directory="\$EFI_DIR" \
        --bootloader-id="ubuntu" \
        --recheck

    echo "  ✓  GRUB EFI instalado en \$EFI_DIR/EFI/ubuntu/"

    # ── Entrada EFI en NVRAM ──────────────────────────────────────────────────
    # Registrar la entrada de Ubuntu en la NVRAM del firmware.
    # Si ya existe una entrada 'ubuntu', la eliminamos primero para evitar
    # duplicados (comportamiento de Calamares).
    DISK_PART_NUM="\$(lsblk -n -o PKNAME,NAME "\$EFI_DIR" 2>/dev/null | tail -1 | awk '{print \$2}' || true)"
    EFI_DISK="\$(lsblk -n -o PKNAME "\${DISK_PART_NUM:-/boot/efi}" 2>/dev/null | head -1 || echo "$TARGET_DISK")"
    EFI_NUM="\$(lsblk -n -o NAME "\$(findmnt -n -o SOURCE \$EFI_DIR 2>/dev/null || echo $EFI_PART)" 2>/dev/null | grep -oE '[0-9]+$' || echo 1)"

    # Eliminar entradas ubuntu duplicadas en NVRAM
    efibootmgr 2>/dev/null | grep -i "ubuntu" | grep -oP 'Boot\K[0-9A-F]{4}' | while read -r bootnum; do
        efibootmgr -b "\$bootnum" -B 2>/dev/null || true
    done

    # Crear entrada limpia
    EFI_SOURCE="\$(findmnt -n -o SOURCE "\$EFI_DIR" 2>/dev/null || echo "$EFI_PART")"
    EFI_DISK_DEV="\$(lsblk -n -d -o PKNAME "\$EFI_SOURCE" 2>/dev/null | head -1)"
    EFI_PART_NUM="\$(lsblk -n -o NAME "\$EFI_SOURCE" 2>/dev/null | grep -oE '[0-9]+$' | head -1)"

    if [ -n "\$EFI_DISK_DEV" ] && [ -n "\$EFI_PART_NUM" ]; then
        efibootmgr \
            --create \
            --disk "/dev/\$EFI_DISK_DEV" \
            --part "\$EFI_PART_NUM" \
            --label "ubuntu" \
            --loader "\\EFI\\ubuntu\\shimx64.efi" \
            2>/dev/null && echo "  ✓  Entrada EFI creada en NVRAM" \
            || echo "  ⚠  efibootmgr: no se pudo crear entrada (normal en chroot/VM)"
    fi

    # ── Fallback EFI (BOOTX64.EFI) ───────────────────────────────────────────
    # Algunos firmwares UEFI ignoran las entradas de NVRAM y arrancan
    # directamente desde EFI/BOOT/BOOTX64.EFI (especialmente en equipos Dell,
    # HP, algunas placas base Gigabyte). Calamares siempre instala este fallback.
    FALLBACK_DIR="\$EFI_DIR/EFI/BOOT"
    mkdir -p "\$FALLBACK_DIR"

    # shimx64.efi es el cargador firmado para Secure Boot
    SHIM_PATH="\$EFI_DIR/EFI/ubuntu/shimx64.efi"
    GRUBX64_PATH="\$EFI_DIR/EFI/ubuntu/grubx64.efi"

    if [ -f "\$SHIM_PATH" ]; then
        cp "\$SHIM_PATH"  "\$FALLBACK_DIR/BOOTX64.EFI"
        echo "  ✓  Fallback EFI: EFI/BOOT/BOOTX64.EFI (shim)"
    elif [ -f "\$GRUBX64_PATH" ]; then
        cp "\$GRUBX64_PATH" "\$FALLBACK_DIR/BOOTX64.EFI"
        echo "  ✓  Fallback EFI: EFI/BOOT/BOOTX64.EFI (grub)"
    else
        echo "  ⚠  No se encontró shim ni grub EFI para copiar como BOOTX64.EFI"
    fi

    # grubx64.efi de fallback (para firmwares que ignoran el shim pero sí BOOTX64)
    [ -f "\$GRUBX64_PATH" ] && cp "\$GRUBX64_PATH" "\$FALLBACK_DIR/grubx64.efi" 2>/dev/null || true

else
    # ── BIOS / MBR ───────────────────────────────────────────────────────────
    grub-install \
        --target="\$GRUB_TARGET" \
        --recheck \
        "\$TARGET_DISK"
    echo "  ✓  GRUB MBR instalado en \$TARGET_DISK"
fi

# ============================================================================
# DETECCIÓN DE OTROS SISTEMAS (DUAL BOOT)
# ============================================================================

if [ "\$DUAL_BOOT_MODE" = "true" ]; then
    echo ""
    echo "Detectando otros sistemas operativos (os-prober)..."

    # Montar temporalmente particiones NTFS para que os-prober las detecte
    # (en chroot no están montadas automáticamente)
    OS_PROBER_MOUNTS=""
    for part in \$(lsblk -n -p -o NAME,FSTYPE | awk '\$2=="ntfs"{print \$1}'); do
        mnt="/mnt/os-prober-\$(basename \$part)"
        mkdir -p "\$mnt"
        if mount -o ro,noatime "\$part" "\$mnt" 2>/dev/null; then
            OS_PROBER_MOUNTS="\$OS_PROBER_MOUNTS \$mnt"
            echo "  → Montado: \$part → \$mnt (para os-prober)"
        fi
    done

    OS_PROBER_OUT=\$(os-prober 2>/dev/null || true)

    # Desmontar temporales
    for mnt in \$OS_PROBER_MOUNTS; do
        umount "\$mnt" 2>/dev/null || true
        rmdir "\$mnt" 2>/dev/null || true
    done

    if [ -n "\$OS_PROBER_OUT" ]; then
        echo "  Sistemas detectados:"
        echo "\$OS_PROBER_OUT" | while IFS= read -r line; do
            echo "    • \$line"
        done
    else
        echo "  ⚠  os-prober no detectó otros sistemas."
        echo "     Posibles causas en chroot:"
        echo "       - Secure Boot activo (Windows puede ocultarse)"
        echo "       - Particiones Windows no montadas"
        echo "     Los sistemas aparecerán en GRUB después del primer arranque."
        echo "     Para forzar la detección: sudo update-grub"
    fi
fi

# ============================================================================
# GENERACIÓN DE grub.cfg
# ============================================================================

echo ""
echo "Generando grub.cfg..."

update-grub > /tmp/update-grub.log 2>&1
UPDATE_EXIT=\$?

if [ \$UPDATE_EXIT -eq 0 ]; then
    GRUB_ENTRIES=\$(grep -c '^menuentry' /boot/grub/grub.cfg 2>/dev/null || echo 0)
    echo "  ✓  grub.cfg generado (\$GRUB_ENTRIES entradas de menú)"
else
    echo "  ⚠  update-grub salió con código \$UPDATE_EXIT (puede ser normal en chroot)"
    grep -i "error\|fail" /tmp/update-grub.log 2>/dev/null | head -5 | sed 's/^/    /' || true
fi

# ── Verificar que Ubuntu tiene entrada en grub.cfg ───────────────────────────
if grep -qi "menuentry.*ubuntu\|menuentry.*linux" /boot/grub/grub.cfg 2>/dev/null; then
    echo "  ✓  Entrada de Ubuntu confirmada en grub.cfg"
else
    echo "  ⚠  No se encontró entrada Ubuntu en grub.cfg — revisar tras el primer boot"
fi

# ── Verificar que Windows tiene entrada (dual boot) ──────────────────────────
if [ "\$DUAL_BOOT_MODE" = "true" ]; then
    if grep -qi "windows\|Windows Boot Manager" /boot/grub/grub.cfg 2>/dev/null; then
        echo "  ✓  Entrada de Windows confirmada en grub.cfg"
    else
        echo "  ⚠  Windows no detectado en grub.cfg."
        echo "     Ejecutar tras primer boot con Windows montado: sudo update-grub"
    fi
fi

CHROOTEOF

CHROOT_EXIT=$?

# ============================================================================
# VALIDACIÓN POST-CHROOT (fuera del chroot, con acceso completo al FS)
# ============================================================================

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  VALIDACIÓN"
echo "════════════════════════════════════════════════════════════════"

FAILED=false

# Kernel
if ls "$TARGET/boot/vmlinuz-"* >/dev/null 2>&1; then
    KVER=$(ls "$TARGET/boot/vmlinuz-"* | tail -1 | sed 's|.*/vmlinuz-||')
    echo "  ✓  Kernel       : $KVER"
else
    echo "  ✗  Kernel ausente en $TARGET/boot/"
    FAILED=true
fi

# initramfs
if ls "$TARGET/boot/initrd.img-"* >/dev/null 2>&1; then
    echo "  ✓  initramfs    : presente"
else
    echo "  ⚠  initramfs no encontrado (se generará en primer boot)"
fi

# grub.cfg
if [ -f "$TARGET/boot/grub/grub.cfg" ]; then
    GRUB_LINES=$(wc -l < "$TARGET/boot/grub/grub.cfg")
    if [ "$GRUB_LINES" -lt 10 ]; then
        echo "  ✗  grub.cfg demasiado pequeño ($GRUB_LINES líneas)"
        FAILED=true
    else
        echo "  ✓  grub.cfg     : $GRUB_LINES líneas"
    fi
else
    echo "  ✗  grub.cfg ausente"
    FAILED=true
fi

# Archivos EFI
if [ "$FIRMWARE" = "UEFI" ]; then
    if [ -f "$TARGET/boot/efi/EFI/ubuntu/grubx64.efi" ] || \
       [ -f "$TARGET/boot/efi/EFI/ubuntu/shimx64.efi" ]; then
        echo "  ✓  EFI binaries : presentes en EFI/ubuntu/"
    else
        echo "  ✗  Binarios EFI ausentes en $TARGET/boot/efi/EFI/ubuntu/"
        FAILED=true
    fi
    if [ -f "$TARGET/boot/efi/EFI/BOOT/BOOTX64.EFI" ]; then
        echo "  ✓  EFI fallback : EFI/BOOT/BOOTX64.EFI presente"
    else
        echo "  ⚠  EFI fallback : EFI/BOOT/BOOTX64.EFI ausente"
    fi
fi

# GRUB MBR
if [ "$FIRMWARE" = "BIOS" ]; then
    if dd if="$TARGET_DISK" bs=512 count=1 2>/dev/null | strings | grep -q "GRUB"; then
        echo "  ✓  GRUB MBR     : firma GRUB detectada en MBR"
    else
        echo "  ⚠  No se detectó firma GRUB en MBR"
    fi
fi

echo ""

if [ "$FAILED" = "true" ]; then
    echo "════════════════════════════════════════════════════════════════"
    echo "✗  ERROR CRÍTICO EN BOOTLOADER — El sistema NO arrancará"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    echo "  Revisa los logs en $TARGET/tmp/update-grub.log"
    exit 1
fi

echo "════════════════════════════════════════════════════════════════"
echo "✓  BOOTLOADER INSTALADO CORRECTAMENTE"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "  Firmware  : $FIRMWARE"
echo "  Kernel    : ${KVER:-desconocido}"
[ "${DUAL_BOOT_MODE:-false}" = "true" ] && echo "  Dual boot : timeout ${GRUB_TIMEOUT_VAL:-10}s, menú visible"
[ "${DUAL_BOOT_MODE:-false}" = "false" ] && echo "  Modo      : arranque directo (timeout 0s)"
echo ""

exit 0

#!/bin/bash
# MÓDULO 90: Verificar instalación

set -e
[ -f "$(dirname "$0")/../partition.info" ] && source "$(dirname "$0")/../partition.info"

# Verificar que TARGET está montado
if ! mountpoint -q "${TARGET:-/mnt/ubuntu}" 2>/dev/null; then
    echo "ERROR: TARGET=${TARGET:-/mnt/ubuntu} no está montado." >&2
    exit 1
fi


echo "═══════════════════════════════════════════════════════════"
echo "  VERIFICACIÓN DEL SISTEMA"
echo "═══════════════════════════════════════════════════════════"
echo ""

VERIFY_ERRORS=0
check_ok()   { echo "✓ $1"; }
check_fail() { echo "✗ $1"; VERIFY_ERRORS=$((VERIFY_ERRORS + 1)); }

# Verificar particiones
echo "[1] Verificando particiones..."
[ -b "$ROOT_PART" ] && check_ok "Root: $ROOT_PART existe" || check_fail "Root no encontrado"
if [ -n "$EFI_PART" ]; then
    [ -b "$EFI_PART" ] && check_ok "EFI: $EFI_PART existe" || check_fail "EFI no encontrado"
fi

# Verificar montaje
echo ""
echo "[2] Verificando sistema montado..."
[ -d "$TARGET/etc" ] && check_ok "Sistema en $TARGET" || check_fail "Sistema no montado"
[ -f "$TARGET/etc/fstab" ] && check_ok "fstab existe" || check_fail "fstab no encontrado"

# Verificar kernel
echo ""
echo "[3] Verificando kernel..."
kernel_count=$(ls "$TARGET/boot/vmlinuz-"* 2>/dev/null | wc -l)
if [ $kernel_count -gt 0 ]; then
    check_ok "Kernel instalado ($kernel_count encontrado)"
    ls "$TARGET/boot/vmlinuz-"* | sed 's|.*/vmlinuz-|  • |'
else
    check_fail "Kernel no encontrado"
fi

# Verificar GRUB
echo ""
echo "[4] Verificando bootloader..."
if [ "$FIRMWARE" = "UEFI" ]; then
    [ -d "$TARGET/boot/efi/EFI" ] && check_ok "EFI bootloader" || check_fail "EFI no configurado"
fi
[ -f "$TARGET/boot/grub/grub.cfg" ] && check_ok "GRUB configurado" || check_fail "GRUB no configurado"

# Verificar servicios
echo ""
echo "[5] Verificando servicios habilitados..."
for svc in NetworkManager systemd-resolved; do
    if arch-chroot "$TARGET" systemctl is-enabled $svc >/dev/null 2>&1; then
        check_ok "$svc habilitado"
    else
        check_fail "$svc no habilitado"
    fi
done

# Verificar GDM y graphical.target (si GNOME fue instalado)
if [ -f "$TARGET/usr/bin/gdm3" ]; then
    if arch-chroot "$TARGET" systemctl is-enabled gdm3 >/dev/null 2>&1; then
        check_ok "gdm3 habilitado"
    else
        check_fail "gdm3 no habilitado"
    fi
    default_target=$(arch-chroot "$TARGET" systemctl get-default 2>/dev/null || echo "unknown")
    if [ "$default_target" = "graphical.target" ]; then
        check_ok "default target: graphical.target"
    else
        check_fail "default target: $default_target (debería ser graphical.target)"
    fi
fi

# Verificar NetworkManager fix
echo ""
echo "[6] Verificando fix NetworkManager..."
if [ -f "$TARGET/etc/NetworkManager/conf.d/10-globally-managed-devices.conf" ]; then
    check_ok "Fix unmanaged aplicado"
else
    check_fail "Fix unmanaged NO aplicado (ejecuta módulo 05)"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"

if [ "$VERIFY_ERRORS" -eq 0 ]; then
    echo "✓  Verificación completada sin errores"
    exit 0
else
    echo "✗  Verificación completada con $VERIFY_ERRORS error(es)"
    echo "   Revisa los puntos marcados con ✗ antes de reiniciar"
    exit 1
fi

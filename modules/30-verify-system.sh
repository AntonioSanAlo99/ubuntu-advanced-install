#!/bin/bash
# Módulo 30: Verificar instalación

set -eo pipefail  # Detectar errores en pipelines

# Variables se pasan desde install.sh via environment
# source "$(dirname "$0")/../config.env"
[ -f "$(dirname "$0")/../partition.info" ] && source "$(dirname "$0")/../partition.info"

echo "═══════════════════════════════════════════════════════════"
echo "  VERIFICACIÓN DEL SISTEMA"
echo "═══════════════════════════════════════════════════════════"
echo ""

check_ok() { echo "✓ $1"; }
check_fail() { echo "✗ $1"; }

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

exit 0

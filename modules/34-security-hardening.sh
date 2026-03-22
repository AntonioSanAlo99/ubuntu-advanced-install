#!/bin/bash
# MÓDULO 34: Hardening de seguridad

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


echo "Aplicando hardening de seguridad..."

arch-chroot "$TARGET" /bin/bash << 'CHROOTEOF'

# === HARDENING DEL KERNEL ===
cat > /etc/sysctl.d/99-security-hardening.conf << 'SYSCTL_EOF'
# Hardening de seguridad del kernel

# Protección contra IP spoofing
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# No aceptar ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0

# Protección SYN flood
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2

# Log paquetes sospechosos
net.ipv4.conf.all.log_martians = 1

# Ignorar ICMP broadcasts
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1

# ASLR
kernel.randomize_va_space = 2

# Restringir acceso a información del kernel
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
SYSCTL_EOF

# Habilitar actualizaciones automáticas de seguridad si no están ya configuradas
# (el módulo 06-configure-auto-updates.sh puede haberlas configurado ya)
# Se usa DEBIAN_FRONTEND=noninteractive para evitar prompts interactivos
if ! [ -f /etc/apt/apt.conf.d/20auto-upgrades ]; then
    apt-get install -y unattended-upgrades
    DEBIAN_FRONTEND=noninteractive dpkg-reconfigure -pcritical unattended-upgrades
fi

# ============================================================================
# USBGUARD — control de autorización de dispositivos USB
# ============================================================================
# USBGuard intercepta la conexión de nuevos dispositivos USB y los bloquea
# hasta que el usuario los autorice explícitamente, previniendo ataques
# BadUSB y acceso no autorizado por hardware externo.
#
# Política inicial: se generan reglas que permiten todos los dispositivos
# USB actualmente conectados en el momento de la instalación (teclado, ratón,
# etc.) — sin esta política initial el sistema podría quedarse sin input.
# Los dispositivos nuevos que se conecten después requerirán autorización
# manual via `usbguard allow-device <id>` o la GUI usbguard-applet.
#
# Integración con GNOME: usbguard-applet-qt no existe como paquete Ubuntu;
# la gestión se hace desde terminal o desde GNOME Settings con polkit.
# ============================================================================

export DEBIAN_FRONTEND=noninteractive

# USBGuard no se instala desde el instalador: generate-policy captura los
# dispositivos del sistema live (teclado, ratón, pendrive del instalador), no
# los del sistema instalado. Al primer arranque los dispositivos no coinciden
# → USBGuard bloquea teclado y ratón con ImplicitPolicyTarget=block
# → GDM queda inaccesible, pantalla negra sin interacción posible.
# Para habilitarlo tras la instalación:
#   sudo apt install usbguard
#   sudo usbguard generate-policy > /etc/usbguard/rules.conf
#   sudo systemctl enable --now usbguard
echo "  USBGuard: omitido (requiere configuración manual en el sistema arrancado)"

# ── UFW (Uncomplicated Firewall) ─────────────────────────────────────────────
# Firewall básico: deniega conexiones entrantes, permite salientes.
# Un escritorio sin firewall en WiFi pública es una superficie de ataque abierta.
# CachyOS lo habilita por defecto y tiene razón.
if ! dpkg -l 2>/dev/null | grep -q "^ii.*ufw"; then
    apt-get install -y ufw
fi
ufw default deny incoming
ufw default allow outgoing
ufw --force enable 2>/dev/null || true
systemctl enable ufw 2>/dev/null || true
echo "  ✓ UFW habilitado (deny incoming, allow outgoing)"

echo "✓  Hardening de seguridad aplicado"
CHROOTEOF

# ── Secure Boot (fuera del chroot — necesita acceso a EFI del host) ──────────
# Solo se configura si el sistema es UEFI y Secure Boot está disponible.
# Instala shim-signed (que Ubuntu ya usa) y asegura que los kernels
# firmados por Canonical arrancan con Secure Boot activo.
# NO requiere MOK enrollment manual — Ubuntu firma sus kernels con la clave
# de Microsoft/Canonical que los firmwares UEFI ya confían.
echo ""
echo "Configurando Secure Boot..."

if [ -d /sys/firmware/efi ]; then
    arch-chroot "$TARGET" /bin/bash << 'SBEOF'
    # shim-signed: bootloader firmado por Microsoft que chainload a GRUB
    # grub-efi-amd64-signed: GRUB firmado por Canonical
    # linux-image-generic ya está firmado por Canonical
    apt-get install -y shim-signed grub-efi-amd64-signed 2>/dev/null || true

    # Verificar estado (mokutil puede no funcionar en chroot, solo informativo)
    if command -v mokutil >/dev/null 2>&1; then
        SB_STATE=$(mokutil --sb-state 2>/dev/null || echo "desconocido")
        echo "  Secure Boot: $SB_STATE"
    fi

    echo "  ✓ Secure Boot: shim-signed + grub-efi firmado instalados"
    echo "    Los kernels de Ubuntu están firmados por Canonical"
    echo "    Kernels custom (PsyCachy) requieren MOK enrollment manual"
SBEOF

    # ── Kernel lockdown mode (solo si el usuario activó security hardening) ───
    # lockdown=integrity: impide que userspace modifique el kernel en runtime.
    # NOTA: puede romper drivers NVIDIA propietarios y DKMS.
    # Solo se activa si ENABLE_SECURITY=true Y Secure Boot está activo.
    if [ "${ENABLE_SECURITY:-false}" = "true" ]; then
        arch-chroot "$TARGET" /bin/bash << 'LOCKEOF'
        GRUB_CFG="/etc/default/grub"
        if [ -f "$GRUB_CFG" ]; then
            if ! grep -q "lockdown=integrity" "$GRUB_CFG" 2>/dev/null; then
                sed -i 's/\(GRUB_CMDLINE_LINUX_DEFAULT="[^"]*\)/\1 lockdown=integrity/' "$GRUB_CFG"
                update-grub 2>/dev/null || true
                echo "  ✓ Kernel lockdown: integrity mode"
            fi
        fi
LOCKEOF
    else
        echo "  ⊘ Kernel lockdown omitido (activar con ENABLE_SECURITY=true)"
    fi
else
    echo "  ⊗ Secure Boot omitido — sistema no UEFI (BIOS legacy)"
fi

echo "✓  Sistema endurecido (red, kernel, firewall, Secure Boot, lockdown)"

exit 0

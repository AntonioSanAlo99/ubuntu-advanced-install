#!/bin/bash
# Módulo 10: GNOME Core - Instalación esencial (sin personalización)

source "$(dirname "$0")/../config.env"

echo "════════════════════════════════════════════════════════════════"
echo "  INSTALACIÓN DE GNOME CORE"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Este módulo instala ÚNICAMENTE los componentes esenciales."
echo "Personalización (tema, fuentes, apps) se configura después."
echo ""

APT_FLAGS=""
[ "$USE_NO_INSTALL_RECOMMENDS" = "true" ] && APT_FLAGS="--no-install-recommends"

arch-chroot "$TARGET" /bin/bash << CHROOTEOF
export DEBIAN_FRONTEND=noninteractive
APT_FLAGS="$APT_FLAGS"

# ============================================================================
# GNOME SHELL Y CORE (componentes esenciales)
# ============================================================================

echo "Instalando GNOME Shell y componentes core..."

apt install -y \$APT_FLAGS \
    gnome-shell \
    gnome-session \
    gnome-settings-daemon \
    gnome-control-center \
    gnome-terminal \
    nautilus \
    nautilus-admin \
    xdg-terminal-exec \
    gdm3 \
    plymouth \
    plymouth-theme-spinner \
    bolt \
    gnome-keyring

echo "✓ GNOME Shell instalado"

# ============================================================================
# UTILIDADES ESENCIALES
# ============================================================================

echo "Instalando utilidades esenciales..."

apt install -y \$APT_FLAGS \
    gnome-calculator \
    gnome-logs \
    gnome-font-viewer \
    baobab \
    lxtask \
    file-roller \
    gedit \
    evince \
    viewnior \
    gnome-disk-utility \
    gnome-tweaks \
    gnome-shell-extension-manager \
    zenity

echo "✓ Utilidades instaladas"

# ============================================================================
# GESTIÓN DE SOFTWARE
# ============================================================================

echo "Instalando gestión de software..."

apt install -y \$APT_FLAGS \
    software-properties-gtk \
    gdebi \
    update-notifier \
    update-manager

echo "✓ Gestión de software instalada"

# ============================================================================
# EXTENSIONES ESENCIALES
# ============================================================================

echo "Instalando extensiones esenciales..."

apt install -y \$APT_FLAGS \
    gnome-shell-extension-appindicator \
    gnome-shell-extension-desktop-icons-ng \
    gnome-shell-extension-ubuntu-dock

echo "✓ Extensiones instaladas"

# ============================================================================
# SYSTEMD-OOMD (protección contra OOM)
# ============================================================================

echo ""
echo "Instalando systemd-oomd..."

if apt-cache show systemd-oomd &>/dev/null; then
    apt-get install -y systemd-oomd
    systemctl enable systemd-oomd
    echo "✓ systemd-oomd instalado y habilitado"
else
    echo "⚠ systemd-oomd no disponible en esta versión"
fi

# ============================================================================
# TEMA DE ICONOS (parte esencial de GNOME)
# ============================================================================

echo ""
echo "Instalando tema de iconos..."

apt install -y \$APT_FLAGS elementary-icon-theme

echo "✓ Elementary icon theme instalado"

# ============================================================================
# HABILITAR GDM
# ============================================================================

echo ""
echo "Habilitando GDM..."

systemctl enable gdm3

echo "✓ GDM habilitado"

CHROOTEOF

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓ GNOME CORE INSTALADO"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Componentes instalados:"
echo "  • GNOME Shell + Session"
echo "  • GDM3 (display manager)"
echo "  • Nautilus + Terminal"
echo "  • Utilidades esenciales (12 paquetes)"
echo "  • Extensiones base (3)"
echo "  • systemd-oomd (protección OOM)"
echo ""
echo "NO incluido (se configura en otros módulos):"
echo "  ✗ Personalización (tema, fuentes, apps ancladas)"
echo "  ✗ Optimizaciones de memoria"
echo "  ✗ Tema transparente"
echo ""

# ============================================================================
# VALIDACIÓN POST-EJECUCIÓN
# ============================================================================

source "$(dirname "$0")/../lib/validate-module.sh" 2>/dev/null || {
    echo "⚠ Sistema de validación no disponible"
    exit 0
}

validate_start "10-install-gnome-core"

# Paquetes críticos
validate_package "gnome-shell" "$TARGET"
validate_package "gnome-session" "$TARGET"
validate_package "gnome-settings-daemon" "$TARGET"
validate_package "gdm3" "$TARGET"
validate_package "nautilus" "$TARGET"
validate_package "gnome-terminal" "$TARGET"

# Extensiones
validate_package "gnome-shell-extension-appindicator" "$TARGET"
validate_package "gnome-shell-extension-desktop-icons-ng" "$TARGET"
validate_package "gnome-shell-extension-ubuntu-dock" "$TARGET"

# Servicios
validate_service "gdm3" "$TARGET"

# systemd-oomd (opcional pero recomendado)
if arch-chroot "$TARGET" systemctl is-enabled systemd-oomd &>/dev/null; then
    validate_ok "systemd-oomd habilitado"
else
    validate_warning "systemd-oomd no habilitado (no crítico)"
fi

# Tema de iconos
validate_package "elementary-icon-theme" "$TARGET"

# Comandos esenciales
validate_command "gnome-shell" "$TARGET"
validate_command "nautilus" "$TARGET"

validate_report

exit 0

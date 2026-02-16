#!/bin/bash
# Módulo 10: Instalar GNOME por componentes (sin metapaquetes)

source "$(dirname "$0")/../config.env"

echo "Instalando GNOME Shell por componentes..."

APT_FLAGS=""
[ "$USE_NO_INSTALL_RECOMMENDS" = "true" ] && APT_FLAGS="--no-install-recommends"

arch-chroot "$TARGET" /bin/bash << CHROOTEOF
export DEBIAN_FRONTEND=noninteractive

echo "Instalando core de GNOME..."
apt install -y $APT_FLAGS \
    gnome-shell \
    gnome-session \
    gnome-settings-daemon \
    gnome-control-center \
    gnome-terminal \
    nautilus \
    gdm3

echo "Instalando utilidades GNOME..."
apt install -y $APT_FLAGS \
    gnome-keyring \
    lxtask \
    gnome-disk-utility \
    gnome-tweaks \
    gnome-shell-extension-manager \
    zenity

echo "Instalando extensiones de GNOME..."
apt install -y $APT_FLAGS \
    gnome-shell-extension-appindicator \
    gnome-shell-extension-desktop-icons-ng

# Aplicar tema de iconos
apt install -y $APT_FLAGS elementary-icon-theme

# Configurar tema por defecto
mkdir -p /etc/dconf/db/local.d
cat > /etc/dconf/db/local.d/00-icon-theme << 'EOF'
[org/gnome/desktop/interface]
icon-theme='elementary'
EOF

# Actualizar base de datos dconf
dconf update

# Habilitar GDM
systemctl enable gdm3

echo "✓ GNOME instalado (sin metapaquetes)"
CHROOTEOF

echo "✓ GNOME Shell instalado por componentes"

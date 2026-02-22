#!/bin/bash
# Módulo 03: Configurar sistema base - BASADO EN DATOS REALES

set -e

# Cargar variables de particionado
[ -f "$(dirname "$0")/../partition.info" ] && source "$(dirname "$0")/../partition.info"

echo "Configurando sistema base..."

# Hostname
echo "$HOSTNAME" > "$TARGET/etc/hostname"
cat > "$TARGET/etc/hosts" << EOF
127.0.0.1   localhost
127.0.1.1   $HOSTNAME
::1         localhost ip6-localhost ip6-loopback
EOF

echo "✓ Hostname: $HOSTNAME"

# Configurar todo dentro del chroot
arch-chroot "$TARGET" /bin/bash << 'CHROOT_EOF'
export DEBIAN_FRONTEND=noninteractive

# ============================================================================
# LOCALES - MÉTODO OFICIAL DEBIAN
# ============================================================================
# Usar dpkg-reconfigure con debconf-set-selections
# Este es el método OFICIAL que usa Debian/Ubuntu
# Configura CORRECTAMENTE todas las variables LC_*
# ============================================================================

echo "Configurando locale español (método Debian oficial)..."

# Instalar debconf-utils (para debconf-set-selections)
apt-get install -y debconf-utils 2>/dev/null || true

# Pre-configurar respuestas para locales
debconf-set-selections << DEBCONF_LOCALES
locales locales/locales_to_be_generated multiselect es_ES.UTF-8 UTF-8
locales locales/default_environment_locale select es_ES.UTF-8
DEBCONF_LOCALES

# Reconfigurare locales (método oficial Debian)
# Esto hace:
# 1. Edita /etc/locale.gen
# 2. Ejecuta locale-gen
# 3. Configura /etc/default/locale con TODAS las variables
# 4. Actualiza /etc/environment
dpkg-reconfigure -f noninteractive locales 2>&1 | grep -v "^locale:" || true

echo "✓ Locale: es_ES.UTF-8 (configurado con dpkg-reconfigure)"

# ============================================================================
# TIMEZONE
# ============================================================================
ln -sf /usr/share/zoneinfo/Europe/Madrid /etc/localtime
hwclock --systohc 2>/dev/null || true

echo "✓ Timezone: Europe/Madrid"

# ============================================================================
# REPOSITORIOS
# ============================================================================
echo "Configurando repositorios..."

RELEASE=$(cat /etc/os-release | grep VERSION_CODENAME | cut -d'=' -f2)

mkdir -p /etc/apt/sources.list.d

cat > /etc/apt/sources.list.d/ubuntu.sources << SOURCES_EOF
Types: deb
URIs: http://archive.ubuntu.com/ubuntu/
Suites: $RELEASE ${RELEASE}-updates
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: http://security.ubuntu.com/ubuntu/
Suites: ${RELEASE}-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
SOURCES_EOF

apt update

echo "✓ Repositorios actualizados"

# ============================================================================
# LANGUAGE PACKS
# ============================================================================
echo "Instalando traducciones..."

apt install -y \
    language-pack-es \
    language-pack-es-base \
    language-pack-gnome-es \
    language-pack-gnome-es-base

echo "✓ Language packs instalados"

# ============================================================================
# TECLADO - MÉTODO OFICIAL DEBIAN
# ============================================================================
# Usar dpkg-reconfigure con debconf-set-selections
# Este es el método OFICIAL para configurar teclado
# ============================================================================

echo "Configurando teclado español (método Debian oficial)..."

# Pre-configurar respuestas para teclado
debconf-set-selections << DEBCONF_KEYBOARD
keyboard-configuration keyboard-configuration/layoutcode string es
keyboard-configuration keyboard-configuration/model select pc105
keyboard-configuration keyboard-configuration/variant select Spain
keyboard-configuration keyboard-configuration/xkb-keymap select es
DEBCONF_KEYBOARD

# Reconfigurare keyboard-configuration (método oficial)
# Esto configura:
# 1. /etc/default/keyboard
# 2. /etc/X11/xorg.conf.d/00-keyboard.conf
# 3. Aplica configuración con setupcon
dpkg-reconfigure -f noninteractive keyboard-configuration

echo "✓ Teclado: Español (configurado con dpkg-reconfigure)"

CHROOT_EOF

# ============================================================================
# USUARIO
# ============================================================================
echo "Creando usuario $USERNAME..."

if [ -n "$USER_PASSWORD" ] && [ -n "$ROOT_PASSWORD" ]; then
    # Contraseñas desde config.env
    arch-chroot "$TARGET" /bin/bash << USEREOF
useradd -m -G sudo,adm,audio,video,plugdev -s /bin/bash $USERNAME
echo "$USERNAME:$USER_PASSWORD" | chpasswd
echo "root:$ROOT_PASSWORD" | chpasswd
USEREOF
    
    echo "✓ Usuario: $USERNAME (contraseña configurada)"
    echo "⚠ Elimina config.env después: rm config.env"
else
    # Pedir contraseñas
    arch-chroot "$TARGET" /bin/bash << USEREOF
useradd -m -G sudo,adm,audio,video,plugdev -s /bin/bash $USERNAME
echo ""
echo "Contraseña para $USERNAME:"
passwd $USERNAME
echo ""
echo "Contraseña para root:"
passwd root
USEREOF
    
    echo "✓ Usuario: $USERNAME creado"
fi

echo ""
echo "✓ Sistema base configurado"
echo "  Hostname: $HOSTNAME"
echo "  Usuario: $USERNAME"
echo "  Locale: es_ES.UTF-8 (generado y configurado)"
echo "  Timezone: Europe/Madrid"
echo "  Teclado: Español (cambiado de us→es)"
echo ""

exit 0

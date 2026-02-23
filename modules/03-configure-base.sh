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
# CONFIGURACIÓN DE LOCALES - PERFECTA DESDE EL INICIO
# ============================================================================
# Configurar ANTES de instalar paquetes para evitar warnings
# ============================================================================

echo "Configurando locales (es_ES.UTF-8)..."

# 1. CONFIGURAR LOCALE MÍNIMO PRIMERO (evita warnings iniciales)
export LANG=C.UTF-8
export LC_ALL=C.UTF-8

# 2. GENERAR LOCALE ESPAÑOL INMEDIATAMENTE
echo "es_ES.UTF-8 UTF-8" > /etc/locale.gen
locale-gen es_ES.UTF-8 >/dev/null 2>&1

# 3. CONFIGURAR COMO DEFAULT
cat > /etc/default/locale << 'LOCALE_EOF'
LANG=es_ES.UTF-8
LANGUAGE=es_ES:es
LC_ALL=
LOCALE_EOF

# 4. ACTUALIZAR ENVIRONMENT
cat > /etc/environment << 'ENV_EOF'
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin"
LANG=es_ES.UTF-8
LANGUAGE=es_ES:es
ENV_EOF

# 5. ACTIVAR INMEDIATAMENTE (para resto de instalación)
export LANG=es_ES.UTF-8
export LANGUAGE=es_ES:es
export LC_ALL=

echo "✓ Locale: es_ES.UTF-8 configurado y activo"

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
echo "Instalando paquetes de idioma español..."

apt install -y \
    language-pack-es \
    language-pack-es-base \
    language-pack-gnome-es \
    language-pack-gnome-es-base

echo "✓ Language packs instalados"

# ============================================================================
# TECLADO ESPAÑOL
# ============================================================================
echo "Configurando teclado español..."

# Configurar teclado de consola
cat > /etc/default/keyboard << 'KBD_EOF'
XKBMODEL="pc105"
XKBLAYOUT="es"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
KBD_EOF

# Aplicar configuración de teclado
setupcon -k --force 2>/dev/null || true

# Configurar para X11/Wayland
mkdir -p /etc/X11/xorg.conf.d
cat > /etc/X11/xorg.conf.d/00-keyboard.conf << 'X11KBD_EOF'
Section "InputClass"
    Identifier "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout" "es"
    Option "XkbModel" "pc105"
EndSection
X11KBD_EOF

echo "✓ Teclado: Español (es) configurado"

# ============================================================================
# CONFIGURACIÓN REGIONAL ADICIONAL
# ============================================================================
# Configurar formatos regionales españoles para aplicaciones
cat > /etc/locale.conf << 'LOCALE_CONF_EOF'
LANG=es_ES.UTF-8
LANGUAGE=es_ES:es
LC_CTYPE=es_ES.UTF-8
LC_NUMERIC=es_ES.UTF-8
LC_TIME=es_ES.UTF-8
LC_COLLATE=es_ES.UTF-8
LC_MONETARY=es_ES.UTF-8
LC_MESSAGES=es_ES.UTF-8
LC_PAPER=es_ES.UTF-8
LC_NAME=es_ES.UTF-8
LC_ADDRESS=es_ES.UTF-8
LC_TELEPHONE=es_ES.UTF-8
LC_MEASUREMENT=es_ES.UTF-8
LC_IDENTIFICATION=es_ES.UTF-8
LOCALE_CONF_EOF

echo "✓ Configuración regional completa"

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

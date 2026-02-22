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
# LOCALES - BASADO EN INVESTIGACIÓN REAL
# ============================================================================
# Estado después de debootstrap:
# - /etc/default/locale: vacío (solo comentario)
# - LANG=en_US.UTF-8 configurado en /etc/environment
# - Pero en_US.UTF-8 NO está generado
# - Solo existe C.utf8
# - /etc/locale.gen: todos comentados
#
# Acción: Generar es_ES.UTF-8 y configurar como default
# ============================================================================

echo "Configurando locale español..."

# Habilitar es_ES.UTF-8 en locale.gen
sed -i 's/^# *es_ES.UTF-8/es_ES.UTF-8/' /etc/locale.gen
grep -q "^es_ES.UTF-8" /etc/locale.gen || echo "es_ES.UTF-8 UTF-8" >> /etc/locale.gen

# Generar locale
echo "Generando es_ES.UTF-8..."
locale-gen es_ES.UTF-8

# Configurar como default del sistema
update-locale LANG=es_ES.UTF-8 LANGUAGE=es_ES:es

# También actualizar /etc/environment (que tiene en_US.UTF-8)
cat > /etc/environment << 'ENV_EOF'
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin"
LANG=es_ES.UTF-8
ENV_EOF

echo "✓ Locale: es_ES.UTF-8"

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

apt update -qq

echo "✓ Repositorios actualizados"

# ============================================================================
# LANGUAGE PACKS
# ============================================================================
echo "Instalando traducciones..."

apt install -y -qq \
    language-pack-es \
    language-pack-es-base \
    language-pack-gnome-es \
    language-pack-gnome-es-base

echo "✓ Language packs instalados"

# ============================================================================
# TECLADO
# ============================================================================
# Estado después de debootstrap:
# - /etc/default/keyboard: XKBLAYOUT="us" (inglés)
# - keyboard-configuration ya instalado
#
# Acción: Cambiar a español
# ============================================================================

echo "Configurando teclado español..."

# Cambiar teclado de "us" a "es"
cat > /etc/default/keyboard << 'KBD_EOF'
XKBMODEL="pc105"
XKBLAYOUT="es"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
KBD_EOF

setupcon -k --force 2>/dev/null || true

# Configuración para Wayland/X11
mkdir -p /etc/X11/xorg.conf.d
cat > /etc/X11/xorg.conf.d/00-keyboard.conf << 'X11_EOF'
Section "InputClass"
    Identifier "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout" "es"
    Option "XkbModel" "pc105"
EndSection
X11_EOF

echo "✓ Teclado: Español (es)"

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

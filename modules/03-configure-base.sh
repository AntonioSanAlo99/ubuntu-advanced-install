#!/bin/bash
# Módulo 03: Configurar sistema base

set -e  # Exit on error  # Detectar errores en pipelines

# Cargar funciones de debug
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/debug-functions.sh" 2>/dev/null || {
    debug() { debug " $*"; }
    step() { step " $*"; }
    error() { echo "✗ $*"; }
    warn() { warn " $*"; }
}

# Variables se pasan desde install.sh via environment
# source "$(dirname "$0")/../config.env"

echo "Configurando sistema base..."

# Hostname
echo "$HOSTNAME" > "$TARGET/etc/hostname"
cat > "$TARGET/etc/hosts" << EOF
127.0.0.1   localhost
127.0.1.1   $HOSTNAME
::1         localhost ip6-localhost ip6-loopback
EOF

step " Hostname configurado: $HOSTNAME"

# Verificar y actualizar repositorios
arch-chroot "$TARGET" /bin/bash << 'CHROOT_EOF'
export DEBIAN_FRONTEND=noninteractive

# ============================================================================
# LOCALES - Método Oficial Ubuntu
# ============================================================================
# Documentación: https://wiki.ubuntu.com/UbuntuDevelopment/Internationalisation
# 
# ORDEN CRÍTICO para evitar warnings de Perl:
# 1. Editar /etc/locale.gen (sin configurar LANG todavía)
# 2. Generar locale (locale-gen puede mostrar warning - es normal)
# 3. Configurar LANG en /etc/default/locale
# 4. Después usar apt (sin warnings)
#
# Ubuntu distingue entre:
# - Locale (formato de fecha, número, moneda) → locale-gen
# - Traducciones de aplicaciones (gettext) → language-pack-*
# ============================================================================
echo "Configurando locales (método oficial Ubuntu)..."

# PASO 1: Activar locale en /etc/locale.gen (sin configurar LANG)
sed -i 's/^# *es_ES.UTF-8/es_ES.UTF-8/' /etc/locale.gen
grep -q "^es_ES.UTF-8" /etc/locale.gen || echo "es_ES.UTF-8 UTF-8" >> /etc/locale.gen

# PASO 2: Generar locale (ANTES de configurar LANG)
# Puede mostrar warnings de Perl - es normal porque aún no hay locale
locale-gen
step " Locale es_ES.UTF-8 generado"

# PASO 3: Configurar LANG (DESPUÉS de generar)
# Ahora que el locale existe, lo configuramos como predeterminado
cat > /etc/default/locale << 'LOCALE_EOF'
LANG=es_ES.UTF-8
LANGUAGE=es_ES:es
LOCALE_EOF

# PASO 4: update-locale (comando oficial Ubuntu)
# Actualiza /etc/default/locale de forma segura
update-locale LANG=es_ES.UTF-8 LANGUAGE=es_ES:es

step " Configuración de locale completada"
echo "  LANG=es_ES.UTF-8"
echo "  LANGUAGE=es_ES:es"

# ============================================================================
# VCONSOLE (teclado consola)
# ============================================================================
cat > /etc/vconsole.conf << 'VCONSOLE_EOF'
KEYMAP=es
FONT=eurlatgr
VCONSOLE_EOF

# ============================================================================
# AHORA SÍ: apt update y repositorios
# ============================================================================
echo "Verificando repositorios..."

# Verificar que ubuntu.sources existe y tiene todos los componentes
if [ ! -f /etc/apt/sources.list.d/ubuntu.sources ] || \
   ! grep -q "universe" /etc/apt/sources.list.d/ubuntu.sources; then
    warn " Repositorios incompletos, actualizando en formato DEB822..."
    RELEASE=$(cat /etc/os-release | grep VERSION_CODENAME | cut -d'=' -f2)
    
    mkdir -p /etc/apt/sources.list.d
    
    cat > /etc/apt/sources.list.d/ubuntu.sources << SOURCES_EOF
# Ubuntu - Repositorios oficiales
# Formato DEB822 (APT 3.0+)

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
    
    step " Repositorios actualizados a formato DEB822"
fi

apt update -qq
step " Índice de paquetes actualizado"

# Instalar paquete locales si debootstrap no lo incluyó
if ! dpkg -l locales 2>/dev/null | grep -q "^ii"; then
    echo "Instalando paquete locales..."
    apt install -y locales
fi

# ============================================================================
# LANGUAGE PACKS - Traducciones de Aplicaciones
# ============================================================================
# Documentación: https://wiki.ubuntu.com/LanguagePacks
#
# Ubuntu separa LOCALE (formato) de TRADUCCIONES (gettext):
#
# locale-gen → Genera locale para libc/Perl
#   - Define formato de fecha: "20/02/2026"
#   - Define formato de número: "1.234,56"
#   - Define símbolo moneda: "€"
#
# language-pack-* → Provee traducciones de aplicaciones
#   - Archivos .mo en /usr/share/locale/es_ES/LC_MESSAGES/
#   - Cada paquete tiene su "domain" (nombre de traducción)
#   - Sistema gettext() busca traducciones aquí
#
# SIN language packs:
#   - Locale: ✅ Español (formato correcto)
#   - Apps: ❌ Inglés (sin traducciones)
#
# Paquetes:
# - language-pack-es: Traducciones principales
# - language-pack-es-base: Traducciones base (siempre instalado)
# - language-pack-gnome-es: Traducciones específicas de GNOME
# - language-pack-gnome-es-base: Traducciones GNOME base
# ============================================================================
echo "Instalando language packs (traducciones)..."

apt install -y \
    language-pack-es \
    language-pack-es-base \
    language-pack-gnome-es \
    language-pack-gnome-es-base \
    hunspell-es \
    hyphen-es \
    mythes-es

step " Language packs instalados"
echo "  Traducciones en: /usr/share/locale/es_ES/LC_MESSAGES/"
echo "  Sistema gettext buscará aquí las traducciones de cada aplicación"

CHROOT_EOF

# Timezone y locale
arch-chroot "$TARGET" /bin/bash << 'LOCALE_EOF'
export DEBIAN_FRONTEND=noninteractive
ln -sf /usr/share/zoneinfo/Europe/Madrid /etc/localtime
hwclock --systohc 2>/dev/null || true
step " Timezone configurado: Europe/Madrid"
LOCALE_EOF

# ============================================================================
# CONFIGURACIÓN DE TECLADO
# ============================================================================
# Ubuntu usa dos sistemas para el teclado:
#
# 1. Consola (TTY): /etc/default/keyboard + /etc/vconsole.conf
#    - Para terminales virtuales (Ctrl+Alt+F1-F6)
#    - keyboard-configuration (paquete Debian/Ubuntu)
#    - vconsole.conf (systemd)
#
# 2. Servidor gráfico: /etc/X11/xorg.conf.d/
#    - Para X11 y Wayland
#    - GNOME leerá esta configuración
#
# Archivos:
# - /etc/default/keyboard: Configuración Debian/Ubuntu (método oficial)
# - /etc/vconsole.conf: Configuración systemd (complementario)
# - /etc/X11/xorg.conf.d/00-keyboard.conf: Configuración X11/Wayland
# ============================================================================

echo "Configurando distribución de teclado..."

arch-chroot "$TARGET" /bin/bash << 'KEYBOARD_EOF'
export DEBIAN_FRONTEND=noninteractive

# Instalar paquetes necesarios
apt-get install -y keyboard-configuration console-setup

# ============================================================================
# Método 1: /etc/default/keyboard (Ubuntu oficial)
# ============================================================================
# Este archivo es leído por:
# - setupcon (configuración de consola)
# - X11/Wayland (vía /etc/X11/xorg.conf.d/)
# - GNOME Settings (configuración gráfica)
cat > /etc/default/keyboard << 'KBD_EOF'
# KEYBOARD CONFIGURATION FILE
# Consult the keyboard(5) manual page.

XKBMODEL="pc105"
XKBLAYOUT="es"
XKBVARIANT=""
XKBOPTIONS=""

BACKSPACE="guess"
KBD_EOF

# ============================================================================
# Aplicar configuración de teclado
# ============================================================================
# setupcon: Comando Debian/Ubuntu para aplicar keyboard-configuration
# - Lee /etc/default/keyboard
# - Configura consola (TTY)
# - Carga mapa de teclado y fuente
setupcon -k --force || true

# ============================================================================
# Método 2: /etc/vconsole.conf (systemd)
# ============================================================================
# Alternativa systemd para consola virtual
# - Leído por systemd-vconsole-setup.service al arrancar
# - Redundante con /etc/default/keyboard, pero asegura compatibilidad
cat > /etc/vconsole.conf << 'VCONSOLE_EOF'
KEYMAP=es
FONT=eurlatgr
VCONSOLE_EOF

# ============================================================================
# Método 3: Configuración X11/Wayland
# ============================================================================
# Para servidor gráfico (GNOME, KDE, etc.)
# - GNOME leerá esta configuración
# - También funciona en Wayland
mkdir -p /etc/X11/xorg.conf.d
cat > /etc/X11/xorg.conf.d/00-keyboard.conf << 'X11_EOF'
Section "InputClass"
    Identifier "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout" "es"
    Option "XkbModel" "pc105"
EndSection
X11_EOF

step " Teclado configurado: Español"
echo "  Consola (TTY): /etc/default/keyboard + vconsole.conf"
echo "  Gráfico: /etc/X11/xorg.conf.d/00-keyboard.conf"
echo ""
echo "NOTA: localectl no se ejecuta en chroot (requiere systemd corriendo)"
echo "      Los archivos de configuración están creados correctamente."

KEYBOARD_EOF

step " Distribución de teclado: es (España)"

# Crear usuario con contraseña
echo "Creando usuario $USERNAME..."

if [ -n "$USER_PASSWORD" ] && [ -n "$ROOT_PASSWORD" ]; then
    # Contraseñas desde config.env
    echo "Usando contraseñas de config.env..."
    
    arch-chroot "$TARGET" /bin/bash << USEREOF
useradd -m -G sudo,adm,audio,video,plugdev -s /bin/bash $USERNAME

# Establecer contraseñas automáticamente
echo "$USERNAME:$USER_PASSWORD" | chpasswd
echo "root:$ROOT_PASSWORD" | chpasswd

step " Usuario $USERNAME creado con contraseña configurada"
step " Contraseña de root configurada"
USEREOF

    echo ""
    echo -e "\033[0;33m⚠ SEGURIDAD: Elimina config.env después de la instalación\033[0m"
    echo -e "\033[0;33m  rm $(dirname "$0")/../config.env\033[0m"
    
else
    # Pedir contraseñas interactivamente
    arch-chroot "$TARGET" /bin/bash << USEREOF
useradd -m -G sudo,adm,audio,video,plugdev -s /bin/bash $USERNAME

echo ""
echo "Establecer contraseña para $USERNAME:"
passwd $USERNAME

echo ""
echo "Establecer contraseña para root:"
passwd root

step " Usuario $USERNAME creado"
USEREOF
fi

echo ""
step "✓✓ Sistema base configurado ✓✓✓"
echo ""
echo "Configuración aplicada:"
echo "  • Hostname: $HOSTNAME"
echo "  • Usuario: $USERNAME"
echo "  • Locale: es_ES.UTF-8"
echo "  • Timezone: Europe/Madrid"
echo "  • Teclado: Español (es)"
echo "  • Repositorios: main, restricted, universe, multiverse"
echo ""

# ============================================================================

exit 0

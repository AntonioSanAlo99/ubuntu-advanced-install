#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
# MÓDULO 03: Configuración del sistema base
# DESCRIPCIÓN: Configuración del sistema base: locale, timezone, teclado, usuario
# DEPENDENCIAS: 02-debootstrap.sh
# VARIABLES REQUERIDAS: TARGET, HOSTNAME, USERNAME
# ══════════════════════════════════════════════════════════════════════════════
#
# ARQUITECTURA DE LOCALE (método estándar Debian):
#   1. install.sh::run_module exporta LC_ALL=C.UTF-8 al entorno del host;
#      arch-chroot lo hereda → apt no genera warnings "Cannot set LC_*"
#      durante la instalación del paquete locales (que aún no tiene locale)
#   2. debconf-set-selections declara es_ES.UTF-8 como locale a generar
#   3. dpkg-reconfigure locales ejecuta locale-gen + update-locale + setupcon
#      en un solo paso estándar — igual que haría el instalador de Debian
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

C_OK='\033[0;32m'; C_WARN='\033[0;33m'; C_INFO='\033[0;34m'
C_HIGH='\033[0;36m'; C_RESET='\033[0m'; C_BOLD='\033[1m'


# ── Hostname (en el host, sin chroot) ─────────────────────────────────────────
echo "$HOSTNAME" > "$TARGET/etc/hostname"
cat > "$TARGET/etc/hosts" << EOF
127.0.0.1   localhost
127.0.1.1   $HOSTNAME
::1         localhost ip6-localhost ip6-loopback
EOF
echo -e "${C_OK}✓${C_RESET}  Hostname: $HOSTNAME"

# ══════════════════════════════════════════════════════════════════════════════

# ── Configurar barra de progreso apt en el chroot ────────────────────────────
# Se hace aquí porque 03 es el primer módulo que usa apt dentro del chroot.
# debootstrap crea el directorio /etc/apt/apt.conf.d pero puede estar vacío.
mkdir -p "$TARGET/etc/apt/apt.conf.d"
cat > "$TARGET/etc/apt/apt.conf.d/99-installer-progress" << 'APT_CONF'
// Barra de progreso dpkg — activada por ubuntu-advanced-install
Dpkg::Progress-Fancy "1";
APT::Color "1";
APT_CONF
echo -e "${C_OK}✓${C_RESET}  Barra de progreso apt configurada"

# BLOQUE 1 — LOCALE ANTES DE CUALQUIER APT
# Esto es lo que elimina los warnings "Cannot set LC_*"
# Debe ser el primer bloque chroot del módulo, sin ningún apt previo
# Heredoc sin comillas: necesita $TARGET implícitamente vía chroot
# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${C_INFO}ℹ${C_RESET}  Configurando locale antes de cualquier instalación de paquetes..."

# Método estándar Debian:
#   1. instalar locales + console-setup (con LC_ALL=C.UTF-8 heredado → sin warnings)
#   2. debconf-set-selections declara qué locale generar
#   3. dpkg-reconfigure locales ejecuta locale-gen + update-locale internamente
#      y llama a setupcon si console-setup está instalado, configurando
#      la fuente y charset del TTY acorde al locale — ciclo completo estándar
arch-chroot "$TARGET" /bin/bash << 'LOCALE_FIRST'
export DEBIAN_FRONTEND=noninteractive
# LC_ALL=C.UTF-8 heredado del host — apt no genera warnings
apt-get install -y locales console-setup

# Declarar locale via debconf — forma estándar, no escribir locale.gen a mano
debconf-set-selections << DEBCONF
locales locales/locales_to_be_generated multiselect es_ES.UTF-8 UTF-8
locales locales/default_environment_locale select es_ES.UTF-8
DEBCONF

# dpkg-reconfigure llama a locale-gen + update-locale internamente.
# update-locale escribe /etc/default/locale.
# setupcon (de console-setup) configura fuente y charset del TTY.
dpkg-reconfigure -f noninteractive locales

echo "✓  Locale es_ES.UTF-8 generado y activo (método estándar Debian)"
LOCALE_FIRST

echo -e "${C_OK}✓${C_RESET}  Locale configurado"

# ══════════════════════════════════════════════════════════════════════════════
# BLOQUE 2 — TIMEZONE, TECLADO Y PAQUETES DE IDIOMA
# A partir de aquí apt ya trabaja con es_ES.UTF-8 activo
# Heredoc sin comillas: mismo razonamiento
# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${C_INFO}ℹ${C_RESET}  Configurando timezone, teclado y paquetes de idioma..."

arch-chroot "$TARGET" /bin/bash << 'BASE_CONFIG'
export DEBIAN_FRONTEND=noninteractive
export LANG=es_ES.UTF-8
export LANGUAGE=es_ES:es

# ── Timezone ──────────────────────────────────────────────────────────────────
ln -sf /usr/share/zoneinfo/Europe/Madrid /etc/localtime
hwclock --systohc 2>/dev/null || true
echo "✓  Timezone: Europe/Madrid"

# ── Repositorios ──────────────────────────────────────────────────────────────
RELEASE=$(grep VERSION_CODENAME /etc/os-release | cut -d= -f2)

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

apt-get update
echo "✓  Repositorios actualizados"

# ── Actualización completa del sistema base ───────────────────────────────────
# Se ejecuta tras configurar repositorios y antes de instalar cualquier paquete.
# Garantiza que el sistema arranque sin actualizaciones pendientes.
# full-upgrade en lugar de upgrade: resuelve cambios de dependencias entre paquetes.
DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y
echo "✓  Sistema base actualizado a la última versión disponible"

# ── Teclado de consola (TTY) ──────────────────────────────────────────────────
# console-setup ya instalado en el bloque anterior junto con locales.
# keyboard-configuration: gestiona /etc/default/keyboard para setupcon
# console-data: mapas de teclado para TTY
apt-get install -y console-data keyboard-configuration

cat > /etc/default/keyboard << 'KBD_EOF'
XKBMODEL="pc105"
XKBLAYOUT="es"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
KBD_EOF

# Aplicar configuración de teclado en consola
setupcon -k --force 2>/dev/null || true

# Teclado para X11/Wayland
mkdir -p /etc/X11/xorg.conf.d
cat > /etc/X11/xorg.conf.d/00-keyboard.conf << 'X11KBD_EOF'
Section "InputClass"
    Identifier "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout" "es"
    Option "XkbModel" "pc105"
EndSection
X11KBD_EOF

echo "✓  Teclado: Español (es) — TTY y X11/Wayland"

# ── Language packs y gettext en español ──────────────────────────────────────
# language-pack-es: traducciones de aplicaciones del sistema
# language-pack-gnome-es: traducciones específicas de aplicaciones GNOME
# gettext: herramienta base del sistema de traducción (normalmente ya instalada)
# Juntos garantizan que las aplicaciones muestren mensajes en español
apt-get install -y \
    language-pack-es \
    language-pack-es-base \
    language-pack-gnome-es \
    language-pack-gnome-es-base \
    gettext

# Actualizar traducciones instaladas
update-locale LANG=es_ES.UTF-8 LANGUAGE=es_ES:es

echo "✓  Language packs y gettext instalados"

# ── chrony — cliente NTP ─────────────────────────────────────────────────────
# Reemplaza systemd-timesyncd con un cliente NTP más robusto y preciso.
# chrony arranca su propio servicio (chronyd) y no necesita systemd-timedated.
# Ventajas sobre timesyncd: mejor manejo de drift, funciona offline,
# sincronización más rápida tras hibernación/suspensión.
apt-get install -y chrony

# Desactivar systemd-timesyncd para evitar conflicto con chrony
systemctl disable systemd-timesyncd 2>/dev/null || true
systemctl mask systemd-timesyncd 2>/dev/null || true

# chrony se habilita automáticamente por su postinst, verificar
systemctl enable chrony 2>/dev/null || true

echo "✓  chrony instalado (NTP — reemplaza systemd-timesyncd)"

BASE_CONFIG

echo -e "${C_OK}✓${C_RESET}  Timezone, teclado e idioma configurados"

# ══════════════════════════════════════════════════════════════════════════════
# BLOQUE 3 — /etc/skel BASE
# Se prepara ANTES de useradd -m para que useradd copie la estructura
# completa con permisos correctos en el momento de la creación del usuario.
# Esto es el mecanismo estándar de Debian/Ubuntu: skel → useradd → home listo.
# Los módulos posteriores (GNOME, gaming, etc.) escriben también en skel
# y sincronizan al home del usuario con sync_skel_to_user (definido abajo).
# ══════════════════════════════════════════════════════════════════════════════

arch-chroot "$TARGET" /bin/bash << 'SKEL_SETUP'
# Estructura XDG base que necesitan todas las apps de escritorio
# Permisos estándar Linux: .local 700, subdirectorios 755
install -d -m 0700 /etc/skel/.local
install -d -m 0755 /etc/skel/.local/share
install -d -m 0755 /etc/skel/.local/share/applications
install -d -m 0755 /etc/skel/.local/share/gnome-shell
install -d -m 0755 /etc/skel/.local/share/gnome-shell/extensions
install -d -m 0755 /etc/skel/.config
install -d -m 0755 /etc/skel/.config/autostart
install -d -m 0700 /etc/skel/.cache
install -d -m 0755 /etc/skel/.cache/thumbnails
install -d -m 0755 /etc/skel/.cache/thumbnails/normal
install -d -m 0755 /etc/skel/.cache/thumbnails/large
install -d -m 0755 /etc/skel/.cache/thumbnails/fail
install -d -m 0755 /etc/skel/.themes

# Marcar setup inicial de GNOME como completado (evita el asistente de bienvenida)
echo "yes" > /etc/skel/.config/gnome-initial-setup-done

echo "✓  /etc/skel base preparado"
SKEL_SETUP

echo -e "${C_OK}✓${C_RESET}  /etc/skel base preparado"

# ══════════════════════════════════════════════════════════════════════════════
# BLOQUE 4 — USUARIO
# useradd -m copia /etc/skel al home del usuario con chown automático.
# En este punto skel ya tiene la estructura XDG completa → home listo
# sin ningún chown manual posterior.
# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${C_INFO}ℹ${C_RESET}  Creando usuario $USERNAME..."

arch-chroot "$TARGET" useradd -m -G sudo,adm,audio,video,plugdev -s /bin/bash "$USERNAME"

if [ -n "${USER_PASSWORD:-}" ] && [ -n "${ROOT_PASSWORD:-}" ]; then
    printf '%s:%s\n' "$USERNAME" "$USER_PASSWORD" | arch-chroot "$TARGET" chpasswd
    printf '%s:%s\n' "root"     "$ROOT_PASSWORD"  | arch-chroot "$TARGET" chpasswd
    echo -e "${C_OK}✓${C_RESET}  Usuario: $USERNAME"
else
    # Pedir interactivamente
    arch-chroot "$TARGET" /bin/bash << USEREOF
echo ""
echo "Contraseña para $USERNAME:"
passwd "$USERNAME"
echo ""
echo "Contraseña para root:"
passwd root
USEREOF
    echo -e "${C_OK}✓${C_RESET}  Usuario: $USERNAME creado"
fi

echo ""
echo -e "${C_HIGH}${C_BOLD}════════════════════════════════════════════════════════════════${C_RESET}"
echo -e "${C_OK}✓${C_RESET}  SISTEMA BASE CONFIGURADO"
echo -e "${C_HIGH}${C_BOLD}════════════════════════════════════════════════════════════════${C_RESET}"
echo ""
echo "  Hostname:  $HOSTNAME"
echo "  Usuario:   $USERNAME"
echo "  Locale:    es_ES.UTF-8"
echo "  Timezone:  Europe/Madrid"
echo "  Teclado:   Español pc105 (TTY + X11/Wayland)"
echo ""

exit 0

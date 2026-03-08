#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
# MÓDULO 17: Instalar AM / AppMan
# AM (Application Manager) — gestor de AppImages y apps portables para Linux
# https://github.com/ivan-hc/AM
# ══════════════════════════════════════════════════════════════════════════════
# DEPENDENCIAS: 10-install-gnome-core.sh (libfuse2, ~/Applications, MIME)
# VARIABLES REQUERIDAS: TARGET, USERNAME
# ══════════════════════════════════════════════════════════════════════════════
#
# AM vs AppMan:
#   - AM:     instalación system-wide (root). Apps en /opt/, binarios en
#             /usr/local/bin/, .desktop en /usr/share/applications/.
#             Comando: am
#   - AppMan: instalación por usuario (sin root). Apps en ~/Applications/,
#             binarios en ~/.local/bin/, .desktop en ~/.local/share/applications/.
#             Mismo código que AM, renombrado como 'appman'.
#
# Este módulo instala AM (system-wide) dentro del chroot.
# El usuario puede añadir el alias 'appman' si prefiere gestión por usuario.
# ══════════════════════════════════════════════════════════════════════════════

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "${SCRIPT_DIR}/../partition.info" ] && source "${SCRIPT_DIR}/../partition.info"

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  AM APPLICATION MANAGER"
echo "════════════════════════════════════════════════════════════════"
echo ""

arch-chroot "$TARGET" /bin/bash << CHROOTEOF
export DEBIAN_FRONTEND=noninteractive
USERNAME="$USERNAME"

# ============================================================================
# DEPENDENCIAS
# ============================================================================
# AM necesita: curl, wget, git, zsync (actualizaciones delta de AppImages),
# binutils (ar — para extraer .deb), tar, unzip.
# libfuse2 se instala en 10-install-gnome-core.sh pero se asegura aquí también.
# ============================================================================

echo "Verificando dependencias de AM..."

apt install -y --no-install-recommends \
    curl wget git \
    zsync \
    binutils \
    tar unzip \
    xdg-utils 2>/dev/null || true

# libfuse2 — necesario para ejecutar AppImages (FUSE v2)
apt install -y libfuse2t64 2>/dev/null \
    || apt install -y libfuse2 2>/dev/null \
    || true

echo "✓  Dependencias verificadas"

# ============================================================================
# INSTALAR AM
# ============================================================================
# El script INSTALL oficial de AM detecta el usuario actual para configurar
# rutas. En chroot corremos como root, así que SUDO_USER debe apuntar al
# usuario del sistema para que AM configure correctamente ~/Applications.
# ============================================================================

echo ""
echo "Instalando AM Application Manager..."

export SUDO_USER="\$USERNAME"
cd /tmp

AM_INSTALLED=false
if wget --timeout=20 --tries=2 -q \
    https://raw.githubusercontent.com/ivan-hc/AM/main/INSTALL \
    -O /tmp/am-install.sh 2>/dev/null; then

    chmod +x /tmp/am-install.sh
    /tmp/am-install.sh
    rm -f /tmp/am-install.sh

    if command -v am >/dev/null 2>&1; then
        AM_VER=\$(am --version 2>/dev/null | head -1 || echo "versión desconocida")
        echo "✓  AM instalado: \$AM_VER"
        AM_INSTALLED=true
    else
        echo "⚠  AM: instalador ejecutado pero 'am' no encontrado en PATH"
        echo "   Verificar tras primer boot: am --version"
    fi
else
    echo "⚠  AM: descarga del instalador falló (sin red o GitHub no responde)"
    echo "   Instalar tras primer boot:"
    echo "   wget -q https://raw.githubusercontent.com/ivan-hc/AM/main/INSTALL && chmod +x INSTALL && sudo ./INSTALL"
fi

# ============================================================================
# DIRECTORIOS DE USUARIO
# ============================================================================
# AM system-wide instala apps en /opt/ y binarios en /usr/local/bin/.
# ~/Applications/ es el directorio convencional para AppImages de usuario.
# Se crea aquí para que el usuario lo encuentre disponible desde el primer login.
# ============================================================================

if [ -n "\$USERNAME" ]; then
    USER_HOME="/home/\$USERNAME"
    mkdir -p "\$USER_HOME/Applications"

    UID_VAL=\$(id -u "\$USERNAME" 2>/dev/null || echo 1000)
    GID_VAL=\$(id -g "\$USERNAME" 2>/dev/null || echo 1000)
    chown "\$UID_VAL:\$GID_VAL" "\$USER_HOME/Applications"

    echo "✓  ~/Applications/ listo"
fi

# ============================================================================
# MIME TYPE PARA APPIMAGES
# ============================================================================
# Registrar AppImage como tipo MIME para que el gestor de archivos (Nautilus)
# las reconozca y permita ejecutarlas con doble click.
# Si ya fue registrado por 10-install-gnome-core.sh, update-mime-database
# es idempotente y no causa problemas.
# ============================================================================

MIME_FILE="/usr/share/mime/packages/appimage.xml"
if [ ! -f "\$MIME_FILE" ]; then
    cat > "\$MIME_FILE" << 'MIME_XML'
<?xml version="1.0" encoding="UTF-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
    <mime-type type="application/vnd.appimage">
        <comment>AppImage application bundle</comment>
        <glob pattern="*.appimage"/>
        <glob pattern="*.AppImage"/>
    </mime-type>
</mime-info>
MIME_XML
    update-mime-database /usr/share/mime 2>/dev/null || true
    echo "✓  MIME type AppImage registrado"
fi

# ============================================================================
# RESUMEN
# ============================================================================

echo ""
echo "════════════════════════════════════════════════════════════════"
if [ "\$AM_INSTALLED" = "true" ]; then
    echo "✓  AM INSTALADO"
    echo ""
    echo "  Uso básico:"
    echo "    am -l                  listar apps disponibles"
    echo "    am -i <app>            instalar app (system-wide, requiere sudo)"
    echo "    am -u                  actualizar todas las apps instaladas"
    echo "    am -R <app>            desinstalar app"
    echo "    am -q <búsqueda>       buscar apps"
    echo ""
    echo "  Para gestión por usuario (sin sudo):"
    echo "    ln -s \$(which am) ~/.local/bin/appman"
    echo "    appman -i <app>        instala en ~/Applications/"
else
    echo "⚠  AM NO INSTALADO — instalar manualmente tras primer boot"
fi
echo "════════════════════════════════════════════════════════════════"
echo ""

CHROOTEOF

exit 0

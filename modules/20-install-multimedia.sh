#!/bin/bash
# MÓDULO 20: Instalar multimedia (códecs, reproductores y thumbnailers)

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



arch-chroot "$TARGET" /bin/bash << CHROOTEOF
set -e

export DEBIAN_FRONTEND=noninteractive

# ============================================================================
# CÓDECS MULTIMEDIA
# ============================================================================

echo "Instalando códecs multimedia..."

apt-get install -y \
    ffmpeg \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-ugly \
    gstreamer1.0-libav \
    libavcodec-extra \
    ubuntu-restricted-addons \
    gstreamer1.0-vaapi \
    libgav1-1 \
    libdav1d7

echo "✓  Códecs instalados (incl. restricted-addons, VP8/VP9, AV1)"

# ============================================================================
# THUMBNAILERS - Miniaturas para todos los formatos
# ============================================================================

echo ""
echo "Instalando thumbnailers (miniaturas)..."

# Thumbnailers base
apt-get install -y \
    ffmpegthumbnailer \
    gnome-epub-thumbnailer \
    libgdk-pixbuf2.0-bin \
    ghostscript \
    poppler-utils

# Thumbnailers adicionales para formatos específicos
apt-get install -y \
    webp-pixbuf-loader \
    libheif-gdk-pixbuf \
    || true

# ── icoextract — miniaturas de .exe y .dll (iconos PE de Windows) ─────────────
# Paquete en repositorios Ubuntu desde 22.04. Incluye exe-thumbnailer y
# registra automáticamente el .thumbnailer en /usr/share/thumbnailers/.
# CRÍTICO: debe instalarse system-wide (no pip --user) — el proceso de
# thumbnailing corre con permisos del gestor de archivos, no del usuario,
# y no tiene acceso a ~/.local/lib/python*/site-packages/.
apt-get install -y icoextract \
    && echo "✓  icoextract instalado (thumbnailer para .exe/.dll)" \
    || echo "⚠  icoextract: no disponible en este Ubuntu — omitido"

# ── appimage-thumbnailer (kem-a) — miniaturas de AppImages ───────────────────
# Binario C compilado: extrae el icono embebido en la sección .DirIcon del
# AppImage sin ejecutarlo (seguro). Dependencias: GLib/GIO, GdkPixbuf, librsvg, Cairo.
# Se descarga el .deb de la release fija v4.0.0 y se instala con dpkg.
# apt-get -f install resuelve cualquier dependencia faltante tras dpkg -i.
echo ""
echo "Instalando appimage-thumbnailer (kem-a v4.0.0)..."
APPIMG_THUMB_URL="https://github.com/kem-a/appimage-thumbnailer/releases/download/v4.0.0/appimage-thumbnailer_v4.0.0_amd64.deb"
APPIMG_THUMB_DEB="/tmp/appimage-thumbnailer.deb"

if wget --timeout=30 --tries=2 -q "\$APPIMG_THUMB_URL" -O "\$APPIMG_THUMB_DEB" 2>/dev/null; then
    dpkg -i "\$APPIMG_THUMB_DEB" || true
    # Resolver dependencias rotas que dpkg -i pueda haber dejado pendientes
    apt-get install -f -y 2>/dev/null || true
    rm -f "\$APPIMG_THUMB_DEB"

    if dpkg -l 2>/dev/null | grep -q "^ii.*appimage-thumbnailer"; then
        echo "✓  appimage-thumbnailer instalado"
    else
        echo "⚠  appimage-thumbnailer: dpkg -i falló — instalar manualmente:"
        echo "   wget \$APPIMG_THUMB_URL && sudo dpkg -i appimage-thumbnailer_v4.0.0_amd64.deb"
    fi
else
    echo "⚠  appimage-thumbnailer: descarga falló — instalar manualmente:"
    echo "   https://github.com/kem-a/appimage-thumbnailer/releases"
fi

# ── Totem — thumbnailers de audio (temporal) ─────────────────────────────────
# GNOME planea publicar un paquete dedicado de thumbnailers de audio en 2026.
# Hasta entonces, Totem es la única forma de obtener miniaturas de archivos
# de audio en Nautilus. Se instala y se oculta del menú de aplicaciones.
echo ""
echo "Instalando Totem (requerido para thumbnailers de audio)..."
apt-get install -y \
    totem \
    totem-plugins \
    gir1.2-totem-1.0 \
    || true

# Configurar cache de thumbnails
# Directorios de thumbnails en skel con permisos correctos.
# .cache: 700 (privado); subdirectorios: 755 (freedesktop thumbnail spec).
# Ya no hace falta: 03-configure-base crea /etc/skel/.cache con modo 0700.
install -d -m 0755 /etc/skel/.cache/thumbnails
install -d -m 0755 /etc/skel/.cache/thumbnails/normal
install -d -m 0755 /etc/skel/.cache/thumbnails/large
install -d -m 0755 /etc/skel/.cache/thumbnails/fail

# Ocultar Totem del menú de aplicaciones (solo se usa para thumbnailers)
# Forzar NoDisplay=true directamente en el .desktop del sistema.
# CRÍTICO: usar sed insert-after en [Desktop Entry], no echo >> al final.
# Totem tiene secciones adicionales ([NewWindow], etc.) y GNOME ignora
# NoDisplay si no está dentro del bloque [Desktop Entry].
if [ -f /usr/share/applications/org.gnome.Totem.desktop ]; then
    sed -i '/^NoDisplay=/d' /usr/share/applications/org.gnome.Totem.desktop
    sed -i '/^\[Desktop Entry\]/a NoDisplay=true' /usr/share/applications/org.gnome.Totem.desktop
    echo "✓  Totem oculto del menú (solo thumbnailers)"
else
    # Crear override mínimo si el .desktop no existe aún
    printf '[Desktop Entry]\nNoDisplay=true\nType=Application\nName=Videos\nExec=totem %%U\nIcon=org.gnome.Totem\n' \
        > /usr/share/applications/org.gnome.Totem.desktop
    echo "✓  Totem: .desktop override creado con NoDisplay=true"
fi

# ============================================================================
# REPRODUCTORES MULTIMEDIA
# ============================================================================

echo ""
echo "Instalando reproductores multimedia..."

# VLC
apt-get install -y vlc

echo "✓  VLC instalado"

# ============================================================================
# FOOYIN — reproductor de audio (.deb desde GitHub releases)
# ============================================================================
# Pre-instalar dependencias Qt6 y FFmpeg antes del .deb para evitar que
# dpkg -i falle en un chroot donde apt-get -f no siempre resuelve todo.

echo ""
echo "Instalando Fooyin..."

UBUNTU_CODENAME=\$(lsb_release -cs 2>/dev/null)

case "\$UBUNTU_CODENAME" in
    noble|plucky|questing|oracular)

        # ── Dependencias Qt6 (runtime) ──
        echo "Instalando dependencias Qt6..."
        apt-get install -y \
            libqt6core6t64 libqt6gui6 libqt6widgets6 \
            libqt6concurrent6 libqt6network6 libqt6sql6 libqt6svg6 \
            qt6-svg-plugins qt6-qpa-plugins qt6-wayland \
            qt6-image-formats-plugins \
            libgl1 libxkbcommon0 \
            || true

        # ── Dependencias FFmpeg + audio ──
        # Sin números de versión hardcodeados — cada release de Ubuntu tiene
        # sufijos diferentes (libavcodec60 en 24.04, libavcodec61 en 25.04, etc.)
        echo "Instalando dependencias multimedia..."
        apt-get install -y \
            ffmpeg libavcodec-extra \
            libpipewire-0.3-0 libebur128-1 \
            || true
        # libtag: nombre varía según Ubuntu
        apt-get install -y libtag1v5-vanilla \
            || apt-get install -y libtag1v5 \
            || true

        # ── Descargar e instalar Fooyin ──
        FOOYIN_VERSION=\$(curl --max-time 15 -s https://api.github.com/repos/fooyin/fooyin/releases/latest \
            | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
        FOOYIN_VERSION="\${FOOYIN_VERSION:-0.9.2}"

        FOOYIN_URL="https://github.com/fooyin/fooyin/releases/download/v\${FOOYIN_VERSION}/fooyin_\${FOOYIN_VERSION}-\${UBUNTU_CODENAME}_amd64.deb"

        if wget --timeout=30 --tries=2 -q "\$FOOYIN_URL" -O /tmp/fooyin.deb 2>/dev/null \
           && [ -s /tmp/fooyin.deb ]; then
            dpkg -i /tmp/fooyin.deb || true
            apt-get install -f -y
            rm -f /tmp/fooyin.deb

            if dpkg -l fooyin 2>/dev/null | grep -q "^ii"; then
                echo "✓  Fooyin v\${FOOYIN_VERSION} instalado"
            else
                echo "⚠  Fooyin: dpkg -i falló"
            fi
        else
            echo "⚠  Fooyin: descarga falló — https://github.com/fooyin/fooyin/releases"
        fi
        ;;
    *)
        echo "⚠  Fooyin no disponible para \$UBUNTU_CODENAME (soporta: noble, plucky, questing, oracular)"
        ;;
esac

CHROOTEOF

# ============================================================================
# SPOTIFY (OPCIONAL)
# ============================================================================

echo ""
echo "════════════════════════════════════════════════════════════════"

if [ -z "$INSTALL_SPOTIFY" ]; then
    read -p "¿Deseas instalar Spotify? (s/N): " INSTALL_SPOTIFY
fi

echo "════════════════════════════════════════════════════════════════"

if [ "$INSTALL_SPOTIFY" = "s" ] || [ "$INSTALL_SPOTIFY" = "S" ]; then
    echo ""
    echo "Instalando Spotify desde repositorio oficial..."

    arch-chroot "$TARGET" /bin/bash << 'SPOTIFY_EOF'
# Clave GPG actual (pubkey_5384CE82BA52C83A) — actualizada por Spotify en 2024
curl -sS https://download.spotify.com/debian/pubkey_5384CE82BA52C83A.asc \
    | gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/spotify.gpg

# Repositorio oficial — https desde 2024
echo "deb [signed-by=/etc/apt/trusted.gpg.d/spotify.gpg] https://repository.spotify.com stable non-free" \
    > /etc/apt/sources.list.d/spotify.list

apt-get update
apt-get install -y spotify-client

# ── Modo de ejecución: forzar X11 vía XWayland ───────────────────────────────
#
# Spotify en Wayland nativo muestra una barra CSD azul propia (CEF) que no
# integra con el tema de GNOME y no es eliminable desde fuera.
# Con --ozone-platform=x11, Spotify corre en XWayland y Mutter le aplica
# Server-Side Decorations — la titlebar estándar del sistema, sin CSD propia.
#
# El texto borroso con escalado fraccional en XWayland se resuelve activando
# xwayland-native-scaling en GNOME experimental-features (ver 10-user-config.sh).
#
# sed: busca la línea Exec= y añade el flag antes del primer espacio que sigue
# al ejecutable, preservando cualquier flag existente (--uri=%u, etc.)
SPOTIFY_DESKTOP="/usr/share/applications/spotify.desktop"
if [ -f "\$SPOTIFY_DESKTOP" ]; then
    # Eliminar flag previo si existe, luego insertar tras "spotify"
    sed -i 's|--ozone-platform=[^ ]*||g' "\$SPOTIFY_DESKTOP"
    sed -i 's|^Exec=spotify|Exec=spotify --ozone-platform=x11|' "\$SPOTIFY_DESKTOP"
    echo "✓  Spotify: --ozone-platform=x11 aplicado (titlebar del sistema)"
fi

echo "✓  Spotify instalado"
SPOTIFY_EOF

else
    echo ""
    echo "Spotify no instalado (se omitió)"
fi

echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Componentes instalados:"
echo "  ✓ Códecs: ffmpeg, gstreamer (completo), restricted-addons, VP8/VP9/AV1"
echo "  ✓ Thumbnailers: ffmpeg, epub, pdf, webp, heif, .exe/.dll (icoextract), AppImages"
echo "  ✓ Totem (solo para thumbnailers de audio, oculto del menú)"
echo "  ✓ VLC"
echo "  Fooyin: verificar con 'dpkg -l fooyin' tras primer boot"
[ "$INSTALL_SPOTIFY" = "s" ] || [ "$INSTALL_SPOTIFY" = "S" ] && echo "  ✓ Spotify"
echo ""

exit 0

#!/bin/bash
# Módulo 12: Instalar multimedia (códecs, reproductores y thumbnailers)

source "$(dirname "$0")/../config.env"

echo "Instalando multimedia..."

APT_FLAGS=""
[ "$USE_NO_INSTALL_RECOMMENDS" = "true" ] && APT_FLAGS="--no-install-recommends"

arch-chroot "$TARGET" /bin/bash << CHROOTEOF
export DEBIAN_FRONTEND=noninteractive
# FIX: Perl locale warnings
export LANG=es_ES.UTF-8; export LC_ALL=es_ES.UTF-8; export LANGUAGE=es_ES
APT_FLAGS="$APT_FLAGS"

echo "Instalando códecs multimedia..."

# Códecs multimedia
apt install -y \$APT_FLAGS \
    ffmpeg \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-ugly \
    gstreamer1.0-libav

echo "✓ Códecs instalados"

# Reproductores multimedia
echo "Instalando reproductores multimedia..."

# VLC
apt install -y \$APT_FLAGS vlc

echo "✓ VLC instalado"

# Fooyin - Reproductor de audio moderno
echo "Instalando Fooyin desde GitHub..."

# Detectar versión de Ubuntu para descargar el .deb correcto
UBUNTU_CODENAME=\$(lsb_release -cs)

echo "Versión detectada: \$UBUNTU_CODENAME"

# El nombre del .deb varía según la versión de Ubuntu
# noble (24.04) → ubuntu-24.04 / plucky (25.04) → ubuntu-25.04
case "\$UBUNTU_CODENAME" in
    noble)
        FOOYIN_SUPPORTED=true
        FOOYIN_DISTRO="noble"
        ;;
    plucky)
        FOOYIN_SUPPORTED=true
        FOOYIN_DISTRO="plucky"
        ;;
    questing)
        FOOYIN_SUPPORTED=true
        FOOYIN_DISTRO="questing"
        ;;
    *)
        FOOYIN_SUPPORTED=false
        echo "⚠ Fooyin no está disponible para \$UBUNTU_CODENAME"
        echo "  Versiones soportadas: noble (24.04), plucky (25.04), questing (25.10)"
        ;;
esac

if [ "\$FOOYIN_SUPPORTED" = "true" ]; then

    # Obtener última versión de Fooyin
    FOOYIN_VERSION=\$(curl -s https://api.github.com/repos/fooyin/fooyin/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')

    if [ -z "\$FOOYIN_VERSION" ]; then
        echo "⚠ No se pudo obtener versión de Fooyin, usando v0.9.2"
        FOOYIN_VERSION="0.9.2"
    fi

    FOOYIN_DEB="fooyin_\${FOOYIN_VERSION}-\${FOOYIN_DISTRO}_amd64.deb"
    FOOYIN_URL="https://github.com/fooyin/fooyin/releases/download/v\${FOOYIN_VERSION}/\${FOOYIN_DEB}"

    echo "Descargando Fooyin v\$FOOYIN_VERSION para \$FOOYIN_DISTRO..."

    # Instalar dependencias REALES en tiempo de ejecución (no paquetes -dev)
    # Fuente: dependencias identificadas en Ubuntu 25.04 (linuxlinks.com) + PR #620
    apt install -y \$APT_FLAGS \
        libavcodec-extra \
        libavformat60 \
        libavutil58 \
        libtag1v5 \
        libqt6concurrent6 \
        qt6-image-formats-plugins \
        libicu74 \
        || apt install -y \$APT_FLAGS \
        libavcodec-extra \
        libavformat59 \
        libavutil57 \
        libtag1v5 \
        libqt6concurrent6 \
        qt6-image-formats-plugins \
        || true

    cd /tmp
    if wget -q "\$FOOYIN_URL" -O fooyin.deb; then
        echo "✓ Fooyin descargado"

        if dpkg -i fooyin.deb; then
            echo "✓ Fooyin instalado"
        else
            echo "Resolviendo dependencias rotas..."
            apt --fix-broken install -y
            echo "✓ Fooyin instalado"
        fi

        rm fooyin.deb
    else
        echo "⚠ No se pudo descargar Fooyin v\$FOOYIN_VERSION para \$FOOYIN_DISTRO"
        echo "  URL intentada: \$FOOYIN_URL"
        echo "  Puedes instalarlo manualmente desde:"
        echo "  https://github.com/fooyin/fooyin/releases"
    fi

    cd /
fi

# Thumbnailers
echo "Instalando thumbnailers..."

apt install -y \$APT_FLAGS \
    ffmpegthumbnailer \
    gnome-epub-thumbnailer \
    libgdk-pixbuf2.0-bin \
    ghostscript \
    poppler-utils

echo "✓ Thumbnailers instalados"

CHROOTEOF

echo ""
echo "✓✓✓ Multimedia instalado ✓✓✓"
echo ""
echo "Paquetes instalados:"
echo "  • Códecs: ffmpeg, gstreamer (completo)"
echo "  • Reproductores: VLC, Fooyin"
echo "  • Thumbnailers: ffmpeg, epub, pdf, imágenes"


#!/bin/bash
# Módulo 12: Instalar multimedia (códecs, reproductores y thumbnailers)

source "$(dirname "$0")/../config.env"

echo "Instalando multimedia..."

APT_FLAGS=""
[ "$USE_NO_INSTALL_RECOMMENDS" = "true" ] && APT_FLAGS="--no-install-recommends"

arch-chroot "$TARGET" /bin/bash << CHROOTEOF
export DEBIAN_FRONTEND=noninteractive
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
UBUNTU_VERSION=\$(lsb_release -rs)
UBUNTU_CODENAME=\$(lsb_release -cs)

echo "Versión detectada: Ubuntu \$UBUNTU_VERSION (\$UBUNTU_CODENAME)"

# Obtener última versión de Fooyin
FOOYIN_VERSION=\$(curl -s https://api.github.com/repos/ludouzi/fooyin/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')

if [ -z "\$FOOYIN_VERSION" ]; then
    echo "⚠ No se pudo obtener versión de Fooyin, usando v0.7.3"
    FOOYIN_VERSION="0.7.3"
fi

echo "Descargando Fooyin v\$FOOYIN_VERSION..."

# Mapear versiones de Ubuntu a nombres de paquete Fooyin
case "\$UBUNTU_CODENAME" in
    noble|oracular|plucky|questing|resolute)
        # Ubuntu 24.04+ / 24.10 / 25.04 / 25.10 / 26.04
        FOOYIN_DEB="fooyin_\${FOOYIN_VERSION}_amd64_ubuntu-24.04.deb"
        ;;
    jammy|kinetic|lunar|mantic)
        # Ubuntu 22.04/22.10/23.04/23.10
        FOOYIN_DEB="fooyin_\${FOOYIN_VERSION}_amd64_ubuntu-22.04.deb"
        ;;
    focal|impish|hirsute)
        # Ubuntu 20.04/20.10/21.04
        FOOYIN_DEB="fooyin_\${FOOYIN_VERSION}_amd64_ubuntu-20.04.deb"
        ;;
    *)
        echo "⚠ Versión de Ubuntu no reconocida, intentando con Ubuntu 24.04"
        FOOYIN_DEB="fooyin_\${FOOYIN_VERSION}_amd64_ubuntu-24.04.deb"
        ;;
esac

FOOYIN_URL="https://github.com/ludouzi/fooyin/releases/download/v\${FOOYIN_VERSION}/\${FOOYIN_DEB}"

echo "URL: \$FOOYIN_URL"

# Descargar e instalar
cd /tmp
if wget -q "\$FOOYIN_URL" -O fooyin.deb; then
    echo "✓ Fooyin descargado"
    
    # Instalar dependencias
    apt install -y \$APT_FLAGS \
        libavcodec-extra \
        libavformat-dev \
        libavutil-dev \
        libtag1v5 \
        libkdsingleapplication1 \
        || true
    
    # Instalar Fooyin
    if dpkg -i fooyin.deb 2>/dev/null; then
        echo "✓ Fooyin instalado"
    else
        echo "Instalando dependencias faltantes..."
        apt-get install -f -y
        dpkg -i fooyin.deb
        echo "✓ Fooyin instalado"
    fi
    
    rm fooyin.deb
else
    echo "⚠ No se pudo descargar Fooyin"
    echo "  Puedes instalarlo manualmente desde:"
    echo "  https://github.com/ludouzi/fooyin/releases"
fi

cd /

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


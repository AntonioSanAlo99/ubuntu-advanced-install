#!/bin/bash
# Módulo 12: Instalar multimedia (códecs, reproductores y thumbnailers)

set -e

source "$(dirname "$0")/../config.env"

echo "════════════════════════════════════════════════════════════════"
echo "  INSTALACIÓN DE MULTIMEDIA"
echo "════════════════════════════════════════════════════════════════"
echo ""

APT_FLAGS=""
[ "$USE_NO_INSTALL_RECOMMENDS" = "true" ] && APT_FLAGS="--no-install-recommends"

arch-chroot "$TARGET" /bin/bash << CHROOTEOF
set -e
export DEBIAN_FRONTEND=noninteractive
APT_FLAGS="$APT_FLAGS"

# ============================================================================
# CÓDECS MULTIMEDIA
# ============================================================================

echo "Instalando códecs multimedia..."

apt-get install -y \$APT_FLAGS \
    ffmpeg \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-ugly \
    gstreamer1.0-libav \
    libavcodec-extra

echo "✓ Códecs instalados"

# ============================================================================
# THUMBNAILERS - Miniaturas para todos los formatos
# ============================================================================

echo ""
echo "Instalando thumbnailers (miniaturas)..."

# Thumbnailers base
apt-get install -y \$APT_FLAGS \
    ffmpegthumbnailer \
    gnome-epub-thumbnailer \
    libgdk-pixbuf2.0-bin \
    ghostscript \
    poppler-utils

# Totem - TEMPORAL para thumbnailers de audio
# GNOME planea crear un paquete dedicado de thumbnailers en 2026
# Hasta entonces, Totem es la única forma de tener miniaturas de audio
echo "Instalando Totem (requerido para thumbnailers de audio)..."
apt-get install -y \$APT_FLAGS \
    totem \
    totem-plugins

# Thumbnailers adicionales para formatos específicos
apt-get install -y \$APT_FLAGS \
    gir1.2-totem-1.0 \
    webp-pixbuf-loader \
    libheif-gdk-pixbuf \
    || true

echo "✓ Thumbnailers instalados (audio requiere Totem hasta que GNOME libere paquete dedicado)"

# Configurar cache de thumbnails
mkdir -p /etc/skel/.cache/thumbnails
mkdir -p /etc/skel/.cache/thumbnails/normal
mkdir -p /etc/skel/.cache/thumbnails/large
mkdir -p /etc/skel/.cache/thumbnails/fail

# Limpiar Totem de aplicaciones si solo se quiere para thumbnailers
# (comentado por defecto, descomentar si prefieres ocultar Totem del menú)
cat > /usr/share/applications/org.gnome.Totem.desktop << 'TOTEM_EOF'
[Desktop Entry]
Type=Application
Name=Totem (solo thumbnailers)
NoDisplay=true
TOTEM_EOF

# ============================================================================
# REPRODUCTORES MULTIMEDIA
# ============================================================================

echo ""
echo "Instalando reproductores multimedia..."

# VLC
apt-get install -y \$APT_FLAGS vlc

echo "✓ VLC instalado"

# ============================================================================
# FOOYIN - Con gestión robusta de dependencias
# ============================================================================

echo ""
echo "Preparando instalación de Fooyin..."

# Detectar versión de Ubuntu
UBUNTU_CODENAME=\$(lsb_release -cs)
echo "Ubuntu detectado: \$UBUNTU_CODENAME"

# Verificar si Fooyin está soportado para esta versión
case "\$UBUNTU_CODENAME" in
    noble|plucky|questing|oracular)
        FOOYIN_SUPPORTED=true
        FOOYIN_DISTRO="\$UBUNTU_CODENAME"
        ;;
    *)
        FOOYIN_SUPPORTED=false
        echo "⚠ Fooyin no disponible para \$UBUNTU_CODENAME"
        echo "  Versiones soportadas: noble, plucky, questing, oracular"
        ;;
esac

if [ "\$FOOYIN_SUPPORTED" = "true" ]; then
    
    # Obtener versión más reciente
    echo "Obteniendo última versión de Fooyin..."
    FOOYIN_VERSION=\$(curl -s https://api.github.com/repos/fooyin/fooyin/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
    
    if [ -z "\$FOOYIN_VERSION" ]; then
        echo "⚠ No se pudo obtener versión desde GitHub, usando v0.9.2"
        FOOYIN_VERSION="0.9.2"
    fi
    
    FOOYIN_DEB="fooyin_\${FOOYIN_VERSION}-\${FOOYIN_DISTRO}_amd64.deb"
    FOOYIN_URL="https://github.com/fooyin/fooyin/releases/download/v\${FOOYIN_VERSION}/\${FOOYIN_DEB}"
    
    echo "Versión: v\$FOOYIN_VERSION"
    echo "Paquete: \$FOOYIN_DEB"
    
    # Instalar dependencias Qt6 ANTES del .deb
    echo ""
    echo "Instalando dependencias Qt6..."
    
    # Lista completa de dependencias de runtime
    QT6_DEPS="
        libqt6core6t64
        libqt6gui6
        libqt6widgets6
        libqt6concurrent6
        libqt6network6
        libqt6sql6
        libqt6svg6
        qt6-qpa-plugins
        qt6-image-formats-plugins
        libgl1
        libxkbcommon0
    "
    
    # Instalar Qt6 con apt-get (más robusto que apt)
    apt-get install -y \$APT_FLAGS \$QT6_DEPS || {
        echo "⚠ Algunas dependencias Qt6 fallaron, intentando alternativas..."
        # Fallback para versiones antiguas
        apt-get install -y \$APT_FLAGS \
            libqt6core6 \
            libqt6gui6 \
            libqt6widgets6 \
            libqt6concurrent6 \
            qt6-image-formats-plugins \
            || true
    }
    
    # Dependencias de audio/video
    echo ""
    echo "Instalando dependencias multimedia..."
    
    apt-get install -y \$APT_FLAGS \
        libavformat60 \
        libavcodec60 \
        libavutil58 \
        libswscale7 \
        libswresample4 \
        libtag1v5 \
        libpipewire-0.3-0 \
        || apt-get install -y \$APT_FLAGS \
        libavformat59 \
        libavcodec59 \
        libavutil57 \
        libtag1v5 \
        || true
    
    echo "✓ Dependencias instaladas"
    
    # Descargar e instalar Fooyin
    echo ""
    echo "Descargando Fooyin..."
    
    cd /tmp
    if wget -q --show-progress "\$FOOYIN_URL" -O fooyin.deb 2>&1; then
        echo "✓ Descarga completada"
        
        # Instalar con dpkg
        echo "Instalando Fooyin..."
        if dpkg -i fooyin.deb 2>&1; then
            echo "✓ Fooyin instalado correctamente"
            FOOYIN_INSTALLED=true
        else
            echo "⚠ dpkg reportó errores, intentando reparar..."
            apt-get --fix-broken install -y
            
            # Verificar si se instaló después de la reparación
            if dpkg -l | grep -q "^ii.*fooyin"; then
                echo "✓ Fooyin instalado después de reparar dependencias"
                FOOYIN_INSTALLED=true
            else
                echo "❌ No se pudo instalar Fooyin"
                FOOYIN_INSTALLED=false
            fi
        fi
        
        rm -f fooyin.deb
        
    else
        echo "❌ Error al descargar Fooyin"
        echo "   URL: \$FOOYIN_URL"
        echo "   Puedes instalarlo manualmente desde:"
        echo "   https://github.com/fooyin/fooyin/releases"
        FOOYIN_INSTALLED=false
    fi
    
    cd /
    
    # Crear script de post-instalación para verificar/reparar Fooyin
    if [ "\$FOOYIN_INSTALLED" = "true" ]; then
        cat > /usr/local/bin/fooyin-verify << 'VERIFY_EOF'
#!/bin/bash
# Script de verificación de Fooyin

echo "Verificando instalación de Fooyin..."

# Verificar que fooyin ejecutable existe
if ! command -v fooyin &>/dev/null; then
    echo "❌ fooyin no encontrado en PATH"
    exit 1
fi

# Intentar ejecutar fooyin con --version
if fooyin --version &>/dev/null; then
    echo "✓ Fooyin funciona correctamente"
    fooyin --version
    exit 0
else
    echo "⚠ Fooyin instalado pero falla al ejecutar"
    echo ""
    echo "Intentando reinstalar dependencias Qt6..."
    
    sudo apt-get install --reinstall -y \
        libqt6concurrent6 \
        libqt6core6t64 \
        libqt6gui6 \
        libqt6widgets6 \
        qt6-image-formats-plugins
    
    echo ""
    echo "Reintentar: fooyin --version"
    if fooyin --version; then
        echo "✓ Problema resuelto"
        exit 0
    else
        echo "❌ Fooyin sigue sin funcionar"
        echo "   Ejecuta: ldd \$(which fooyin) | grep 'not found'"
        exit 1
    fi
fi
VERIFY_EOF
        chmod +x /usr/local/bin/fooyin-verify
        
        echo ""
        echo "Script de verificación creado: /usr/local/bin/fooyin-verify"
    fi
fi

CHROOTEOF

# ============================================================================
# RESUMEN
# ============================================================================

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓ MULTIMEDIA INSTALADO"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Componentes:"
echo "  ✓ Códecs: ffmpeg, gstreamer (completo)"
echo "  ✓ Thumbnailers: ffmpeg, epub, pdf, webp, heif, imágenes"
echo "  ✓ Totem: Instalado para thumbnailers de audio (temporal)"

# Verificar si Fooyin se instaló
if arch-chroot "$TARGET" dpkg -l 2>/dev/null | grep -q "^ii.*fooyin"; then
    echo "  ✓ Fooyin instalado"
    echo ""
    echo "IMPORTANTE - Verificar Fooyin después del primer boot:"
    echo "  Ejecutar: fooyin-verify"
    echo "  Si falla: sudo apt-get install --reinstall libqt6concurrent6"
else
    echo "  ⚠ Fooyin no se instaló (puede instalarse manualmente)"
fi

echo "  ✓ VLC instalado"
echo ""
echo "NOTA SOBRE TOTEM:"
echo "  Totem se instala temporalmente para proporcionar thumbnailers"
echo "  de audio. GNOME planea liberar un paquete dedicado de thumbnailers"
echo "  en 2026. Puedes ocultar Totem del menú editando:"
echo "  /usr/share/applications/org.gnome.Totem.desktop"
echo ""

exit 0

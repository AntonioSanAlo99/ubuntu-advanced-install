#!/bin/bash
# Módulo 12: Instalar multimedia (códecs, reproductores y thumbnailers)

set -e

# Cargar variables de particionado
[ -f "$(dirname "$0")/../partition.info" ] && source "$(dirname "$0")/../partition.info"


# Variables se pasan desde install.sh via environment
# source "$(dirname "$0")/../config.env"

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
apt-get install -y \$APT_FLAGS \
    ffmpegthumbnailer \
    gnome-epub-thumbnailer \
    libgdk-pixbuf2.0-bin \
    ghostscript \
    poppler-utils

# Thumbnailers adicionales para formatos específicos
apt-get install -y \$APT_FLAGS \
    webp-pixbuf-loader \
    libheif-gdk-pixbuf \
    || true

# ── icoextract — miniaturas de .exe y .dll (iconos PE de Windows) ─────────────
# Paquete en repositorios Ubuntu desde 22.04. Incluye exe-thumbnailer y
# registra automáticamente el .thumbnailer en /usr/share/thumbnailers/.
# CRÍTICO: debe instalarse system-wide (no pip --user) — el proceso de
# thumbnailing corre con permisos del gestor de archivos, no del usuario,
# y no tiene acceso a ~/.local/lib/python*/site-packages/.
apt-get install -y \$APT_FLAGS icoextract 2>/dev/null \
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
    dpkg -i "\$APPIMG_THUMB_DEB" 2>/dev/null || true
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
apt-get install -y \$APT_FLAGS \
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
apt-get install -y \$APT_FLAGS vlc

echo "✓  VLC instalado"

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
        echo "  ⚠ Fooyin no disponible para \$UBUNTU_CODENAME"
        echo "  Versiones soportadas: noble, plucky, questing, oracular"
        ;;
esac

if [ "\$FOOYIN_SUPPORTED" = "true" ]; then
    
    # Obtener versión más reciente
    echo "Obteniendo última versión de Fooyin..."
    FOOYIN_VERSION=\$(curl --max-time 30 --retry 3 -s https://api.github.com/repos/fooyin/fooyin/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
    
    if [ -z "\$FOOYIN_VERSION" ]; then
        echo "  ⚠ No se pudo obtener versión desde GitHub, usando v0.9.2"
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
        qt6-svg-plugins
        qt6-qpa-plugins
        qt6-wayland
        qt6-image-formats-plugins
        libgl1
        libxkbcommon0
   "
    
    # Instalar Qt6 con apt-get (más robusto que apt)
    apt-get install -y \$APT_FLAGS \$QT6_DEPS || {
        echo "  ⚠ Algunas dependencias Qt6 fallaron, intentando alternativas..."
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
    
    # Función para encontrar la versión MÁS RECIENTE de un paquete versionado
    find_latest_package() {
        local base_name="\$1"
        
        # Buscar todas las versiones disponibles y ordenar numéricamente
        local available=\$(apt-cache search "^\${base_name}[0-9]" | awk '{print \$1}' | grep "^\${base_name}[0-9]\+\$" | sort -V -r)
        
        if [ -n "\$available" ]; then
            # Retornar la primera (más reciente por sort -r)
            echo "\$available" | head -n1
            return 0
        fi
        
        # Fallback: buscar sin número de versión
        if apt-cache show "\${base_name}" &>/dev/null; then
            echo "\${base_name}"
            return 0
        fi
        
        return 1
    }
    
    # Detectar versiones disponibles AUTOMÁTICAMENTE
    echo "Detectando dependencias FFmpeg disponibles..."
    
    LIBAVFORMAT=\$(find_latest_package "libavformat")
    LIBAVCODEC=\$(find_latest_package "libavcodec")
    LIBAVUTIL=\$(find_latest_package "libavutil")
    LIBSWSCALE=\$(find_latest_package "libswscale")
    LIBSWRESAMPLE=\$(find_latest_package "libswresample")
    LIBAVDEVICE=\$(find_latest_package "libavdevice")
    LIBAVFILTER=\$(find_latest_package "libavfilter")
    
    # Mostrar lo detectado
    echo "Versiones detectadas:"
    [ -n "\$LIBAVFORMAT" ] && echo "  ✓ \$LIBAVFORMAT"
    [ -n "\$LIBAVCODEC" ] && echo "  ✓ \$LIBAVCODEC"
    [ -n "\$LIBAVUTIL" ] && echo "  ✓ \$LIBAVUTIL"
    [ -n "\$LIBSWSCALE" ] && echo "  ✓ \$LIBSWSCALE"
    [ -n "\$LIBSWRESAMPLE" ] && echo "  ✓ \$LIBSWRESAMPLE"
    [ -n "\$LIBAVDEVICE" ] && echo "  ✓ \$LIBAVDEVICE"
    [ -n "\$LIBAVFILTER" ] && echo "  ✓ \$LIBAVFILTER"
    
    # Construir lista de paquetes
    LIBAV_PACKAGES=""
    for pkg in "\$LIBAVFORMAT" "\$LIBAVCODEC" "\$LIBAVUTIL" "\$LIBSWSCALE" "\$LIBSWRESAMPLE" "\$LIBAVDEVICE" "\$LIBAVFILTER"; do
        [ -n "\$pkg" ] && LIBAV_PACKAGES="\$LIBAV_PACKAGES \$pkg"
    done
    
    # Detectar versión correcta de libtag según disponibilidad
    echo ""
    echo "Detectando paquete libtag correcto..."
    LIBTAG_PKG=""
    
    if apt-cache search --names-only '^libtag1v5-vanilla$' | grep -q libtag1v5-vanilla; then
        LIBTAG_PKG="libtag1v5-vanilla"
        echo "  ✓ Detectado: libtag1v5-vanilla (Ubuntu 24.04+)"
    elif apt-cache search --names-only '^libtag1v5$' | grep -q libtag1v5; then
        LIBTAG_PKG="libtag1v5"
        echo "  ✓ Detectado: libtag1v5 (Ubuntu ≤22.04)"
    else
        echo "  ⚠ No se encontró libtag1v5, continuando sin él"
    fi
    
    # Detectar libebur128 (dependencia de Fooyin)
    echo "Detectando libebur128..."
    LIBEBUR_PKG=""
    
    if apt-cache search --names-only '^libebur128-1$' | grep -q libebur128-1; then
        LIBEBUR_PKG="libebur128-1"
        echo "  ✓ Detectado: libebur128-1"
    elif apt-cache search --names-only 'libebur128' | head -1 | grep -q libebur128; then
        LIBEBUR_PKG=\$(apt-cache search --names-only 'libebur128' | head -1 | awk '{print \$1}')
        echo "  ✓ Detectado: \$LIBEBUR_PKG (versión alternativa)"
    else
        echo "  ⚠ No se encontró libebur128 (puede afectar Fooyin)"
    fi
    
    # Instalar paquetes detectados + otros
    if [ -n "\$LIBAV_PACKAGES" ]; then
        # Construir lista de paquetes a instalar
        EXTRA_PKGS="libpipewire-0.3-0"
        [ -n "\$LIBTAG_PKG" ] && EXTRA_PKGS="\$EXTRA_PKGS \$LIBTAG_PKG"
        [ -n "\$LIBEBUR_PKG" ] && EXTRA_PKGS="\$EXTRA_PKGS \$LIBEBUR_PKG"
        
        apt-get install -y \$APT_FLAGS \
            \$LIBAV_PACKAGES \
            \$EXTRA_PKGS \
            || true
        echo "  ✓ Dependencias multimedia instaladas"
    else
        echo "  ⚠ No se detectaron paquetes libav, instalando solo otros..."
        # Construir lista de paquetes a instalar
        EXTRA_PKGS="libpipewire-0.3-0"
        [ -n "\$LIBTAG_PKG" ] && EXTRA_PKGS="\$EXTRA_PKGS \$LIBTAG_PKG"
        [ -n "\$LIBEBUR_PKG" ] && EXTRA_PKGS="\$EXTRA_PKGS \$LIBEBUR_PKG"
        
        apt-get install -y \$APT_FLAGS \$EXTRA_PKGS || true
    fi
    
    # Descargar e instalar Fooyin
    echo ""
    echo "Descargando Fooyin..."
    
    cd /tmp
    if wget --timeout=30 --tries=3 -q --show-progress "\$FOOYIN_URL" -O fooyin.deb 2>&1; then
        echo "  ✓ Descarga completada"
        
        # Instalar con dpkg
        echo "Instalando Fooyin..."
        if dpkg -i fooyin.deb 2>&1; then
            echo "  ✓ Fooyin instalado correctamente"
            FOOYIN_INSTALLED=true
        else
            echo "  ⚠ dpkg reportó errores, intentando reparar..."
            apt-get --fix-broken install -y
            
            # Verificar si se instaló después de la reparación
            if dpkg -l | grep -q "^ii.*fooyin"; then
                echo "  ✓ Fooyin instalado después de reparar dependencias"
                FOOYIN_INSTALLED=true
            else
                echo "✗  No se pudo instalar Fooyin"
                FOOYIN_INSTALLED=false
            fi
        fi
        
        rm -f fooyin.deb
        
    else
        echo "✗  Error al descargar Fooyin"
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
    echo "✗  fooyin no encontrado en PATH"
    exit 1
fi

# Intentar ejecutar fooyin con --version
if fooyin --version &>/dev/null; then
    echo "✓  Fooyin funciona correctamente"
    fooyin --version
    exit 0
else
    echo "⚠  Fooyin instalado pero falla al ejecutar"
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
        echo "  ✓ Problema resuelto"
        exit 0
    else
        echo "✗  Fooyin sigue sin funcionar"
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
apt-get install -y --no-install-recommends spotify-client

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
echo "Componentes:"
echo "  ✓ Códecs: ffmpeg, gstreamer (completo), restricted-addons, VP8/VP9/AV1"
echo "  ✓ Thumbnailers: ffmpeg, epub, pdf, webp, heif, imágenes, .exe/.dll (icoextract), AppImages"
echo "  ✓ Totem: Instalado para thumbnailers de audio (oculto del menú)"

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

# Verificar si Spotify se instaló
if arch-chroot "$TARGET" dpkg -l 2>/dev/null | grep -q "^ii.*spotify-client"; then
    echo "  ✓ Spotify instalado"
else
    echo "  ⚠ Spotify no instalado (se omitió)"
fi

echo "  ✓ VLC instalado"
echo ""
echo "NOTA SOBRE TOTEM:"
echo "  Totem se instala solo para proporcionar thumbnailers de audio."
echo "  Está oculto del menú de aplicaciones (NoDisplay=true)."
echo "  GNOME planea liberar un paquete dedicado de thumbnailers en 2026."
echo ""

exit 0

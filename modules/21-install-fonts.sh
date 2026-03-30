#!/bin/bash
# MÓDULO 21: Instalar fuentes (sistema + Microsoft completas)
# REQUIERE: TARGET
# PRODUCE:  Fuentes sistema + MS + Nerd Fonts

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


echo "Instalando fuentes..."

arch-chroot "$TARGET" /bin/bash << CHROOTEOF
export DEBIAN_FRONTEND=noninteractive
export LANG=es_ES.UTF-8; export LC_ALL=es_ES.UTF-8; export LANGUAGE=es_ES

# ============================================================================
# FUENTES DEL SISTEMA
# ============================================================================
# FUENTES DEL SISTEMA - DETECCIÓN AUTOMÁTICA
# ============================================================================

echo "Instalando fuentes del sistema..."

# Detectar paquetes de fuentes disponibles
echo "Detectando paquetes de fuentes..."

# fonts-noto (metapaquete en versiones antiguas, dividido en nuevas)
NOTO_PKGS=""
if apt-cache search --names-only '^fonts-noto$' | grep -q fonts-noto; then
    NOTO_PKGS="fonts-noto"
    echo "  ✓ Detectado: fonts-noto (metapaquete)"
else
    # En versiones nuevas, usar paquetes específicos
    NOTO_PKGS="fonts-noto-core fonts-noto-ui-core"
    echo "  ✓ Usando: fonts-noto-core fonts-noto-ui-core (Ubuntu reciente)"
fi

# fonts-dejavu (similar a noto)
DEJAVU_PKGS=""
if apt-cache search --names-only '^fonts-dejavu$' | grep -q fonts-dejavu; then
    DEJAVU_PKGS="fonts-dejavu"
    echo "  ✓ Detectado: fonts-dejavu (metapaquete)"
else
    # En versiones nuevas, usar paquetes específicos
    DEJAVU_PKGS="fonts-dejavu-core fonts-dejavu-extra"
    echo "  ✓ Usando: fonts-dejavu-core fonts-dejavu-extra (Ubuntu reciente)"
fi

# Instalar fuentes detectadas + otras
apt-get install -y \
    fonts-liberation \
    \$DEJAVU_PKGS \
    \$NOTO_PKGS \
    fonts-noto-color-emoji \
    fonts-font-awesome \
    fonts-hack \
    fonts-inconsolata \
    fonts-ubuntu \
    curl \
    console-setup

echo "✓  Fuentes del sistema instaladas"

# ============================================================================
# MICROSOFT CORE TRUETYPE FONTS (ttf-mscorefonts-installer)
# Andale Mono, Arial, Comic Sans, Courier New, Georgia,
# Impact, Times New Roman, Trebuchet, Verdana, Webdings
# Fuente: multiverse repository
# ============================================================================

echo "Instalando Microsoft Core TrueType Fonts..."

# Aceptar EULA automáticamente (evita el diálogo interactivo)
echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true" \
    | debconf-set-selections

apt-get install -y ttf-mscorefonts-installer

echo "✓  MS Core Fonts instaladas (Arial, Times New Roman, Verdana...)"
echo "  Ubicación: /usr/share/fonts/truetype/msttcorefonts/"

# ============================================================================
# FUENTES ADICIONALES DE MICROSOFT
# Nota: Las siguientes fuentes NO están en ttf-mscorefonts-installer
# y NO sobrescriben las fuentes core. Van a un directorio diferente.
# ============================================================================

# Directorio para fuentes adicionales (NO conflictúa con msttcorefonts)
FONTS_DIR="/usr/local/share/fonts/microsoft-additional"
mkdir -p "\$FONTS_DIR"

BASE_URL="https://lexics.github.io/assets/downloads/fonts"

# ============================================================================
# MICROSOFT CLEARTYPE FONTS
# Calibri, Cambria, Candara, Consolas, Constantia, Corbel
# Fuente: lexics.github.io
# ============================================================================

echo "Instalando Microsoft ClearType Fonts..."
echo "  (Calibri, Cambria, Candara, Consolas, Constantia, Corbel)"

mkdir -p "\$FONTS_DIR/cleartype"

CLEARTYPE_FONTS=(
    calibri.ttf calibrib.ttf calibrii.ttf calibriz.ttf
    cambria.ttf cambriab.ttf cambriai.ttf cambriaz.ttf cambriamath.ttf
    candara.ttf candarab.ttf candarai.ttf candaraz.ttf
    consola.ttf consolab.ttf consolai.ttf consolaz.ttf
    constan.ttf constanb.ttf constani.ttf constanz.ttf
    corbel.ttf corbelb.ttf corbeli.ttf corbelz.ttf
)

# Descargar todas en paralelo
for font in "\${CLEARTYPE_FONTS[@]}"; do
    curl -sf -o "\$FONTS_DIR/cleartype/\$font" "\$BASE_URL/clearTypeFonts/\$font" &
done
wait
OK=\$(ls "\$FONTS_DIR/cleartype/"*.ttf 2>/dev/null | wc -l)
FAIL=\$(( \${#CLEARTYPE_FONTS[@]} - OK ))
echo "  ✓ ClearType: \$OK instaladas, \$FAIL fallidas"

# ============================================================================
# TAHOMA
# Fuente: lexics.github.io
# ============================================================================

echo "Instalando Tahoma..."

mkdir -p "\$FONTS_DIR/tahoma"

TAHOMA_FONTS=( tahoma.ttf tahomabd.ttf )

for font in "\${TAHOMA_FONTS[@]}"; do
    curl -sf -o "\$FONTS_DIR/tahoma/\$font" "\$BASE_URL/tahoma/\$font" &
done
wait
OK=\$(ls "\$FONTS_DIR/tahoma/"*.ttf 2>/dev/null | wc -l)
FAIL=\$(( \${#TAHOMA_FONTS[@]} - OK ))
echo "  ✓ Tahoma: \$OK instaladas, \$FAIL fallidas"

# ============================================================================
# SEGOE UI
# Fuente: lexics.github.io
# ============================================================================

echo "Instalando Segoe UI..."

mkdir -p "\$FONTS_DIR/segoeui"

SEGOE_FONTS=(
    segoeui.ttf segoeuib.ttf segoeuii.ttf segoeuiz.ttf
    segoeuil.ttf segoeuisl.ttf
    seguili.ttf seguisb.ttf seguisbi.ttf seguisli.ttf
)

for font in "\${SEGOE_FONTS[@]}"; do
    curl -sf -o "\$FONTS_DIR/segoeui/\$font" "\$BASE_URL/segoeUI/\$font" &
done
wait
OK=\$(ls "\$FONTS_DIR/segoeui/"*.ttf 2>/dev/null | wc -l)
FAIL=\$(( \${#SEGOE_FONTS[@]} - OK ))
echo "  ✓ Segoe UI: \$OK instaladas, \$FAIL fallidas"

# ============================================================================
# OTRAS FUENTES ESENCIALES
# mtextra, symbol, webdings, wingdings 1/2/3
# Fuente: lexics.github.io
# ============================================================================

echo "Instalando fuentes esenciales (símbolos y wingdings)..."

mkdir -p "\$FONTS_DIR/other"

OTHER_FONTS=(
    mtextra.ttf
    symbol.ttf
    webdings.ttf
    wingding.ttf
    wingdng2.ttf
    wingdng3.ttf
)

for font in "\${OTHER_FONTS[@]}"; do
    curl -sf -o "\$FONTS_DIR/other/\$font" "\$BASE_URL/other-essential-fonts/\$font" &
done
wait
OK=\$(ls "\$FONTS_DIR/other/"*.ttf 2>/dev/null | wc -l)
FAIL=\$(( \${#OTHER_FONTS[@]} - OK ))
echo "  ✓ Otras esenciales: \$OK instaladas, \$FAIL fallidas"

# ============================================================================
# NERD FONTS (fuentes parcheadas para terminales y desarrollo)
# Solo las más populares para no ocupar espacio excesivo (~50MB total)
# Fuente: GitHub releases
# ============================================================================

echo "Instalando Nerd Fonts populares..."

mkdir -p "\$FONTS_DIR/nerdfonts"
cd /tmp

NERD_VERSION="v3.1.1"
NERD_BASE="https://github.com/ryanoasis/nerd-fonts/releases/download/\$NERD_VERSION"

# Lista de Nerd Fonts populares (selección curada)
NERD_FONTS=(
    "FiraCode"           # Fira Code con ligaduras
    "JetBrainsMono"      # JetBrains Mono
    "Hack"               # Hack parcheada
    "Meslo"              # Meslo (popular en Oh My Zsh)
    "UbuntuMono"         # Ubuntu Mono parcheada
    "DejaVuSansMono"     # DejaVu Sans Mono
)

OK=0; FAIL=0

# Descargar todos los zips en paralelo
echo "  Descargando 6 Nerd Fonts en paralelo..."
for font in "\${NERD_FONTS[@]}"; do
    wget --timeout=30 --tries=3 -q "\$NERD_BASE/\${font}.zip" -O "/tmp/\${font}.zip" 2>/dev/null &
done
wait

# Descomprimir secuencialmente (I/O, no se beneficia de paralelizar)
for font in "\${NERD_FONTS[@]}"; do
    if [ -s "/tmp/\${font}.zip" ]; then
        unzip -q -o "/tmp/\${font}.zip" -d "\$FONTS_DIR/nerdfonts/\${font}" 2>/dev/null
        rm -f "/tmp/\${font}.zip"
        OK=\$((OK+1))
    else
        rm -f "/tmp/\${font}.zip"
        echo "    ⚠ No se pudo descargar \$font"
        FAIL=\$((FAIL+1))
    fi
done

echo "  ✓ Nerd Fonts: \$OK instaladas, \$FAIL fallidas"

cd /

# ============================================================================
# REGENERAR CACHÉ DE FUENTES
# ============================================================================

echo "Regenerando caché de fuentes..."
fc-cache
echo "✓  Caché actualizada"

# ============================================================================
# RESUMEN
# ============================================================================

echo ""
echo "✓ ✓✓ Fuentes instaladas ✓✓✓"
echo ""
echo "Fuentes del sistema:"
echo "  • Liberation, DejaVu, Noto, Ubuntu, Hack, Inconsolata"
echo ""
echo "Microsoft Core TrueType (ttf-mscorefonts-installer):"
echo "  • Arial, Times New Roman, Courier New, Georgia"
echo "  • Verdana, Trebuchet, Impact, Comic Sans, Webdings"
echo "  • Ubicación: /usr/share/fonts/truetype/msttcorefonts/"
echo ""
echo "Microsoft ClearType (adicionales - NO sobrescriben Core):"
echo "  • Calibri, Cambria, Candara, Consolas, Constantia, Corbel"
echo "  • Ubicación: /usr/local/share/fonts/microsoft-additional/"
echo ""
echo "Microsoft adicionales:"
echo "  • Tahoma, Segoe UI (todas las variantes)"
echo ""
echo "Símbolos y especiales:"
echo "  • Symbol, MT Extra, Wingdings 1/2/3"
echo ""
echo "Nerd Fonts (terminales y desarrollo):"
echo "  • FiraCode, JetBrainsMono, Hack, Meslo"
echo "  • UbuntuMono, DejaVuSansMono"
echo "  • Incluyen glifos de Powerline, iconos de Font Awesome, etc."

exit 0
CHROOTEOF

echo ""
echo "✓  Módulo de fuentes completado"

exit 0

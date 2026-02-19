#!/bin/bash
# Módulo 13: Instalar fuentes (sistema + Microsoft completas)

source "$(dirname "$0")/../config.env"

echo "Instalando fuentes..."

APT_FLAGS=""
[ "$USE_NO_INSTALL_RECOMMENDS" = "true" ] && APT_FLAGS="--no-install-recommends"

arch-chroot "$TARGET" /bin/bash << CHROOTEOF
export DEBIAN_FRONTEND=noninteractive
export LANG=es_ES.UTF-8; export LC_ALL=es_ES.UTF-8; export LANGUAGE=es_ES
APT_FLAGS="$APT_FLAGS"

# ============================================================================
# FUENTES DEL SISTEMA
# ============================================================================

echo "Instalando fuentes del sistema..."

apt install -y \$APT_FLAGS \
    fonts-liberation \
    fonts-dejavu \
    fonts-noto \
    fonts-noto-color-emoji \
    fonts-font-awesome \
    fonts-hack \
    fonts-inconsolata \
    fonts-ubuntu \
    curl \
    console-setup

echo "✓ Fuentes del sistema instaladas"

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

apt install -y \$APT_FLAGS ttf-mscorefonts-installer

echo "✓ MS Core Fonts instaladas (Arial, Times New Roman, Verdana...)"

# Directorio de fuentes del sistema para todas las instalaciones siguientes
FONTS_DIR="/usr/local/share/fonts/microsoft"
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

OK=0; FAIL=0
for font in "\${CLEARTYPE_FONTS[@]}"; do
    if curl -sf -o "\$FONTS_DIR/cleartype/\$font" "\$BASE_URL/clearTypeFonts/\$font"; then
        OK=\$((OK+1))
    else
        FAIL=\$((FAIL+1))
    fi
done
echo "  ✓ ClearType: \$OK instaladas, \$FAIL fallidas"

# ============================================================================
# TAHOMA
# Fuente: lexics.github.io
# ============================================================================

echo "Instalando Tahoma..."

mkdir -p "\$FONTS_DIR/tahoma"

TAHOMA_FONTS=( tahoma.ttf tahomabd.ttf )

OK=0; FAIL=0
for font in "\${TAHOMA_FONTS[@]}"; do
    if curl -sf -o "\$FONTS_DIR/tahoma/\$font" "\$BASE_URL/tahoma/\$font"; then
        OK=\$((OK+1))
    else
        FAIL=\$((FAIL+1))
    fi
done
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

OK=0; FAIL=0
for font in "\${SEGOE_FONTS[@]}"; do
    if curl -sf -o "\$FONTS_DIR/segoeui/\$font" "\$BASE_URL/segoeUI/\$font"; then
        OK=\$((OK+1))
    else
        FAIL=\$((FAIL+1))
    fi
done
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

OK=0; FAIL=0
for font in "\${OTHER_FONTS[@]}"; do
    if curl -sf -o "\$FONTS_DIR/other/\$font" "\$BASE_URL/other-essential-fonts/\$font"; then
        OK=\$((OK+1))
    else
        FAIL=\$((FAIL+1))
    fi
done
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
for font in "\${NERD_FONTS[@]}"; do
    echo "  Descargando \$font..."
    if wget -q --show-progress "\$NERD_BASE/\${font}.zip" -O "\${font}.zip" 2>/dev/null; then
        unzip -q -o "\${font}.zip" -d "\$FONTS_DIR/nerdfonts/\${font}" 2>/dev/null
        rm "\${font}.zip"
        OK=\$((OK+1))
    else
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
fc-cache -f
echo "✓ Caché actualizada"

# ============================================================================
# RESUMEN
# ============================================================================

echo ""
echo "✓✓✓ Fuentes instaladas ✓✓✓"
echo ""
echo "Fuentes del sistema:"
echo "  • Liberation, DejaVu, Noto, Ubuntu, Hack, Inconsolata"
echo ""
echo "Microsoft Core TrueType (ttf-mscorefonts-installer):"
echo "  • Arial, Times New Roman, Courier New, Georgia"
echo "  • Verdana, Trebuchet, Impact, Comic Sans, Webdings"
echo ""
echo "Microsoft ClearType:"
echo "  • Calibri, Cambria, Candara, Consolas, Constantia, Corbel"
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

CHROOTEOF

echo ""
echo "✓ Módulo de fuentes completado"

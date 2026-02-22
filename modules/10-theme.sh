#!/bin/bash
# Módulo 10-theme: Tema transparente GNOME (totalmente opcional)

set -eo pipefail  # Detectar errores en pipelines

# Variables se pasan desde install.sh via environment
# source "$(dirname "$0")/../config.env"

echo "════════════════════════════════════════════════════════════════"
echo "  TEMA TRANSPARENTE GNOME (OPCIONAL)"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "⚠  Este módulo es completamente opcional"
echo ""
echo "Tema Adwaita-Transparent:"
echo "  • Basado en Adwaita vanilla (tema por defecto)"
echo "  • Añade transparencias sutiles a:"
echo "    - Quick Settings (panel superior derecho)"
echo "    - Calendar (al hacer clic en fecha/hora)"
echo "  • El resto del sistema permanece igual"
echo ""
echo "Recomendación: [NO] - El tema por defecto es excelente"
echo ""

read -p "¿Aplicar tema transparente? (s/n) [n]: " APPLY_THEME
APPLY_THEME=${APPLY_THEME:-n}

if [ "$APPLY_THEME" != "s" ] && [ "$APPLY_THEME" != "S" ]; then
    echo ""
    echo "✓ Tema transparente omitido"
    echo "  El sistema usará Adwaita por defecto (recomendado)"
    exit 0
fi

arch-chroot "$TARGET" /bin/bash << CHROOTEOF

USERNAME="$USERNAME"

echo ""
echo "Instalando extensión User Themes..."

apt install -y gnome-shell-extension-user-theme

echo "✓ User Themes instalado"

echo ""
echo "Creando tema Adwaita-Transparent..."

USERNAME="$USERNAME"

if [ -z "$USERNAME" ]; then
    echo "⚠ Variable USERNAME no definida"
    exit 1
fi

# Crear tema directamente en el home del usuario (no en /etc/skel/)
# El usuario ya existe (se creó en módulo 03)
USER_HOME="/home/$USERNAME"

if [ ! -d "$USER_HOME" ]; then
    echo "⚠ Directorio home no existe: $USER_HOME"
    exit 1
fi

mkdir -p "$USER_HOME/.themes/Adwaita-Transparent/gnome-shell"

cat > "$USER_HOME/.themes/Adwaita-Transparent/gnome-shell/gnome-shell.css" << 'THEME'
/* Adwaita-Transparent: Vanilla Adwaita con transparencias mínimas */
@import url("resource:///org/gnome/shell/theme/gnome-shell.css");

.quick-settings {
    background-color: rgba(0, 0, 0, 0.15) !important;

.calendar {
    background-color: rgba(0, 0, 0, 0.15) !important;
THEME

# Ajustar permisos
chown -R $USERNAME:$USERNAME "$USER_HOME/.themes"

echo "✓ Tema creado en $USER_HOME/.themes/"

CHROOTEOF

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓ TEMA TRANSPARENTE CONFIGURADO"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Tema creado en: /home/$USERNAME/.themes/Adwaita-Transparent/"
echo "Se aplicará automáticamente en el primer login del usuario."
echo "(El script 10-gnome-user-config.sh detectará y aplicará el tema)"
echo ""

exit 0

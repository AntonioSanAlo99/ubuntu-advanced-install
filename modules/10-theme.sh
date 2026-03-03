#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
# MÓDULO: 10-theme.sh (Refactor GNOME 46–50)
# DESCRIPCIÓN: Tema GNOME transparente compatible con cambios de selectores
# REQUIERE: TARGET, USERNAME
# COMPATIBLE: Ubuntu 24.04 → 25.10 / GNOME 46+
# ══════════════════════════════════════════════════════════════════════════════

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "${SCRIPT_DIR}/../partition.info" ] && source "${SCRIPT_DIR}/../partition.info"

if [ -z "$TARGET" ] || [ -z "$USERNAME" ]; then
    echo "ERROR: TARGET o USERNAME no definidos"
    exit 1
fi

echo "════════════════════════════════════════════════════════════"
echo "  TEMA GNOME — ADWAITA TRANSPARENT (REFactor)"
echo "════════════════════════════════════════════════════════════"
echo ""

# ------------------------------------------------------------------------------
# Instalar extensión user-theme
# ------------------------------------------------------------------------------

arch-chroot "$TARGET" /bin/bash << 'EOF'
export DEBIAN_FRONTEND=noninteractive
apt-get install -y gnome-shell-extension-user-theme
EOF

# ------------------------------------------------------------------------------
# Detectar versión GNOME
# ------------------------------------------------------------------------------

GNOME_VERSION=$(arch-chroot "$TARGET" gnome-shell --version 2>/dev/null | grep -oP '\d+' | head -1)

if [ -z "$GNOME_VERSION" ]; then
    echo "No se pudo detectar versión GNOME. Continuando en modo genérico."
else
    echo "GNOME detectado: $GNOME_VERSION"
fi

# ------------------------------------------------------------------------------
# Crear estructura del tema
# ------------------------------------------------------------------------------

arch-chroot "$TARGET" /bin/bash << CHROOTEOF

USER_HOME="/home/$USERNAME"
THEME_DIR="\$USER_HOME/.themes/Adwaita-Transparent/gnome-shell"

mkdir -p "\$THEME_DIR"

cat > "\$THEME_DIR/gnome-shell.css" << 'CSSEOF'
/* ══════════════════════════════════════════════════════════════
   Adwaita-Transparent (Compat GNOME 46–50)
   ══════════════════════════════════════════════════════════════ */

@import url("resource:///org/gnome/shell/theme/gnome-shell.css");

/* --------------------------------------------------------------
   PANEL SUPERIOR
   -------------------------------------------------------------- */

#panel {
    background-color: transparent !important;
    box-shadow: none !important;
    border: none !important;
}

#panel .panel-button {
    background-color: transparent;
}

/* --------------------------------------------------------------
   QUICK SETTINGS (Compat múltiples versiones)
   -------------------------------------------------------------- */

.quick-settings,
.quick-settings-box,
.quick-settings-menu,
.quick-settings-container {
    background-color: rgba(36,36,36,0.88) !important;
    border-radius: 22px !important;
    box-shadow: none !important;
}

/* --------------------------------------------------------------
   NOTIFICACIONES
   -------------------------------------------------------------- */

.notification,
.notification-banner,
.message,
.message-list-item {
    background-color: rgba(36,36,36,0.88) !important;
    border-radius: 14px !important;
    box-shadow: none !important;
}

/* --------------------------------------------------------------
   DASH / DOCK
   -------------------------------------------------------------- */

.dash-background {
    background-color: rgba(36,36,36,0.4) !important;
    border-radius: 18px !important;
    box-shadow: none !important;
}

/* --------------------------------------------------------------
   OVERVIEW (Compat GNOME 46–50)
   -------------------------------------------------------------- */

#overviewGroup,
.overview,
.overview-controls,
.background-group {
    background: transparent !important;
}

/* Workspaces nuevas y antiguas */

.workspace,
.workspace-thumbnail,
.workspace-thumbnail-background,
.workspace-preview {
    background: transparent !important;
    box-shadow: none !important;
    border: none !important;
}

/* --------------------------------------------------------------
   APP GRID (Compat GNOME 46–50)
   -------------------------------------------------------------- */

.app-display,
.app-view,
.icon-grid,
.grid-layout {
    background: transparent !important;
}

.app-well-app:hover,
.app-well-app:focus {
    background-color: rgba(255,255,255,0.08) !important;
    border-radius: 12px !important;
}

/* Carpetas nuevas */

.app-folder-dialog,
.app-folder-popup,
.app-folder-view {
    background-color: rgba(36,36,36,0.88) !important;
    border-radius: 16px !important;
    box-shadow: none !important;
}

/* --------------------------------------------------------------
   CALENDARIO
   -------------------------------------------------------------- */

.calendar {
    background-color: rgba(36,36,36,0.88) !important;
    border-radius: 14px !important;
    box-shadow: none !important;
}

/* --------------------------------------------------------------
   POPUPS GENERALES
   -------------------------------------------------------------- */

.popup-menu-content {
    background: rgba(36,36,36,0.88) !important;
    box-shadow: none !important;
    border: none !important;
}
CSSEOF

chown -R $USERNAME:$USERNAME "\$USER_HOME/.themes"
chmod -R u=rwX,go=rX "\$USER_HOME/.themes"

echo "Tema creado en \$THEME_DIR"
CHROOTEOF

echo ""
echo "✓ Tema instalado correctamente"
echo ""

# ------------------------------------------------------------------------------
# Nota importante
# ------------------------------------------------------------------------------

echo "NOTA:"
echo "Si estás en VM sin aceleración 3D, la transparencia real puede no mostrarse."
echo "En QEMU usar:"
echo "  -device virtio-vga-gl -display gtk,gl=on"
echo ""

exit 0

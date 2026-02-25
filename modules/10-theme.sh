#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
# MÓDULO: 10-theme.sh
# DESCRIPCIÓN: Tema GNOME con transparencias y configuración visual completa
# DEPENDENCIAS: 10-install-gnome-core.sh (usuario y GNOME instalados)
# VARIABLES REQUERIDAS: TARGET, USERNAME
# ══════════════════════════════════════════════════════════════════════════════
#
# CAMBIOS vs versión anterior:
#   - Corregido bug de sintaxis CSS: bloques sin cierre de llave
#   - CSS expandido: panel, quicksettings, calendario, notificaciones,
#     appgrid, carpetas — todos con transparencia rgba(0,0,0,X)
#   - Eliminada la pregunta de opt-in: el tema es parte del CORE visual
#   - Extensión user-theme sigue siendo necesaria para aplicar CSS de shell
#   - Permisos corregidos al final del bloque
# ══════════════════════════════════════════════════════════════════════════════

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "${SCRIPT_DIR}/../partition.info" ] && source "${SCRIPT_DIR}/../partition.info"

# Colores para output
C_OK='\033[0;32m'; C_WARN='\033[0;33m'; C_INFO='\033[0;34m'
C_HIGH='\033[0;36m'; C_RESET='\033[0m'; C_BOLD='\033[1m'

echo ""
echo -e "${C_HIGH}${C_BOLD}════════════════════════════════════════════════════════════════${C_RESET}"
echo -e "${C_HIGH}${C_BOLD}  TEMA VISUAL GNOME — TRANSPARENCIAS Y CONFIGURACIÓN${C_RESET}"
echo -e "${C_HIGH}${C_BOLD}════════════════════════════════════════════════════════════════${C_RESET}"
echo ""
echo -e "${C_INFO}ℹ${C_RESET}  Aplicando tema con transparencias sobre fondo oscuro"
echo -e "${C_INFO}ℹ${C_RESET}  Elementos: panel, quicksettings, calendario, appgrid, carpetas"
echo ""

# Instalar extensión user-theme dentro del chroot (necesaria para CSS de shell)
# Heredoc sin comillas: no necesita variables del host aquí
arch-chroot "$TARGET" /bin/bash << 'EOF'
export DEBIAN_FRONTEND=noninteractive
apt-get install -y gnome-shell-extension-user-theme 2>/dev/null
echo "✓  gnome-shell-extension-user-theme instalado"
EOF

# Crear el tema CSS en el home del usuario
# Heredoc sin comillas: necesita $USERNAME y $TARGET del host — expansión requerida
arch-chroot "$TARGET" /bin/bash << CHROOTEOF

if [ -z "$USERNAME" ]; then
    echo "⚠  Variable USERNAME no definida — abortando módulo de tema"
    exit 1
fi

USER_HOME="/home/$USERNAME"

if [ ! -d "\$USER_HOME" ]; then
    echo "⚠  Directorio home no existe: \$USER_HOME"
    exit 1
fi

mkdir -p "\$USER_HOME/.themes/Adwaita-Transparent/gnome-shell"

# ── CSS del tema ──────────────────────────────────────────────────────────────
# Importa el tema base de GNOME y sobreescribe solo lo necesario.
# Opacidades elegidas para mantener texto blanco legible:
#   Panel superior:       0.40  (siempre visible, necesita más opacidad)
#   Quick Settings:       0.55  (panel de controles, texto denso)
#   Calendario/notif.:    0.50  (contenido mixto)
#   App Grid fondo:       0.35  (de fondo, iconos dan el contraste)
#   Carpetas App Grid:    0.45  (elemento flotante sobre el grid)
# ──────────────────────────────────────────────────────────────────────────────
cat > "\$USER_HOME/.themes/Adwaita-Transparent/gnome-shell/gnome-shell.css" << 'CSSEOF'
/* ══════════════════════════════════════════════════════════════════════════════
   Adwaita-Transparent — Tema de shell para ubuntu-advanced-install
   Base: Adwaita vanilla + transparencias sobre fondo oscuro
   Texto: blanco — requiere wallpaper oscuro o semidark para máxima legibilidad
   ══════════════════════════════════════════════════════════════════════════════ */

@import url("resource:///org/gnome/shell/theme/gnome-shell.css");

/* ── Panel superior ──────────────────────────────────────────────────────── */
#panel {
    background-color: rgba(0, 0, 0, 0.40) !important;
    transition: background-color 0.3s ease;
}

/* ── Quick Settings (panel derecho: wifi, volumen, brillo...) ────────────── */
.quick-settings {
    background-color: rgba(0, 0, 0, 0.55) !important;
    border-radius: 12px;
}

.quick-settings-system-item {
    background-color: rgba(0, 0, 0, 0.30) !important;
    border-radius: 10px;
}

/* ── Calendario y panel de notificaciones ────────────────────────────────── */
.calendar-today {
    background-color: rgba(255, 255, 255, 0.15) !important;
}

.datemenu-today-button {
    background-color: rgba(0, 0, 0, 0.50) !important;
    border-radius: 10px;
}

.message-list {
    background-color: rgba(0, 0, 0, 0.50) !important;
}

.notification-banner {
    background-color: rgba(0, 0, 0, 0.55) !important;
    border-radius: 12px;
}

/* ── App Grid (fondo del overview de aplicaciones) ───────────────────────── */
.apps-scroll-view {
    background-color: rgba(0, 0, 0, 0.35) !important;
    border-radius: 16px;
}

/* ── Carpetas del App Grid ───────────────────────────────────────────────── */
.app-folder-popup {
    background-color: rgba(0, 0, 0, 0.45) !important;
    border-radius: 16px;
}

.app-folder-popup-title {
    color: rgba(255, 255, 255, 0.90) !important;
}

/* ── Overview (fondo al presionar Super) ─────────────────────────────────── */
.overview-controls {
    background-color: transparent !important;
}
CSSEOF

# Permisos correctos
chown -R "$USERNAME":"$USERNAME" "\$USER_HOME/.themes"
chmod -R u=rwX,go=rX "\$USER_HOME/.themes"

echo "✓  Tema CSS creado en \$USER_HOME/.themes/Adwaita-Transparent/"
CHROOTEOF

echo ""
echo -e "${C_OK}✓${C_RESET}  Tema creado: /home/${USERNAME}/.themes/Adwaita-Transparent/"
echo -e "${C_INFO}ℹ${C_RESET}  Se aplicará en el primer login del usuario"
echo -e "${C_INFO}ℹ${C_RESET}  Requiere wallpaper oscuro para máxima legibilidad del texto"
echo ""

exit 0

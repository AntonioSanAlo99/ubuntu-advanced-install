#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
# MÓDULO 13: Tema GNOME con transparencias — Adwaita-Transparent
# DESCRIPCIÓN: Tema GNOME con transparencias — Adwaita-Transparent
# DEPENDENCIAS: 10-install-gnome-core.sh (usuario y GNOME instalados)
# VARIABLES REQUERIDAS: TARGET, USERNAME
# ══════════════════════════════════════════════════════════════════════════════

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "${SCRIPT_DIR}/../partition.info" ] && source "${SCRIPT_DIR}/../partition.info"

# Verificar que TARGET está montado y el chroot es funcional
if ! mountpoint -q "${TARGET:-/mnt/ubuntu}" 2>/dev/null; then
    echo "ERROR: TARGET=${TARGET:-/mnt/ubuntu} no está montado." >&2
    exit 1
fi
if [ ! -x "${TARGET:-/mnt/ubuntu}/usr/bin/apt-get" ]; then
    echo "ERROR: Chroot en ${TARGET:-/mnt/ubuntu} sin apt-get." >&2
    exit 1
fi

C_OK='\033[0;32m'; C_INFO='\033[0;34m'
C_HIGH='\033[0;36m'; C_RESET='\033[0m'; C_BOLD='\033[1m'

echo -e "${C_INFO}ℹ${C_RESET}  Base: Adwaita vanilla + transparencias sobre fondo oscuro"
echo -e "${C_INFO}ℹ${C_RESET}  Elementos: panel, quick settings, calendario, notificaciones, dock, carpetas"
echo ""

# ── Instalar extensión user-theme ─────────────────────────────────────────────
arch-chroot "$TARGET" /bin/bash << 'EOF'
export DEBIAN_FRONTEND=noninteractive
apt-get install -y gnome-shell-extension-user-theme
echo "✓  gnome-shell-extension-user-theme instalado"
EOF

# ── Crear estructura del tema y CSS ───────────────────────────────────────────
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

install -d -m 0755 /etc/skel/.themes/Adwaita-Transparent/gnome-shell

cat > /etc/skel/.themes/Adwaita-Transparent/gnome-shell/gnome-shell.css << 'CSSEOF'
/* ══════════════════════════════════════════════════════════════════════════════
   Adwaita-Transparent — ubuntu-advanced-install
   Base: Adwaita vanilla + transparencias sobre fondo oscuro
   GNOME 46–50 / Ubuntu 24.04+
   ══════════════════════════════════════════════════════════════════════════════ */

@import url("resource:///org/gnome/shell/theme/gnome-shell.css");

.popup-menu-content {
    background: rgba(36, 36, 36, 0.88) !important;
    border: none !important;
    box-shadow: none !important;
}

/* PANEL */
#panel {
    background-color: transparent !important;
    border: none !important;
    box-shadow: none !important;
}
#panel .panel-button { background-color: transparent; }
.clock-display { background-color: transparent; box-shadow: none; border: none; }

/* QUICK SETTINGS */
.quick-settings-box, .quick-settings {
    background-color: rgba(36, 36, 36, 0.88);
    border-radius: 24px; border: none; box-shadow: none;
}
.quick-settings-system-item { background-color: transparent; box-shadow: none; }
.quick-toggle-menu { background-color: rgba(36, 36, 36, 0.88) !important; box-shadow: none !important; }

/* CALENDARIO */
.calendar {
    background-color: rgba(36, 36, 36, 0.88) !important;
    border-radius: 14px !important; border-color: transparent !important;
    box-shadow: none !important; padding: 3px !important; margin: 0 !important;
}
.calendar-month-header .calendar-month-label { background-color: transparent; color: white; }
.calendar-day, .calendar-month-header .pager-button {
    background-color: transparent; color: white; border-radius: 9px; transition-duration: 100ms;
}
.calendar-day:hover { background-color: rgba(255,255,255,0.08); box-shadow: none; }
.calendar-today, .calendar-today:selected {
    background-color: rgba(255,255,255,0.20); color: white; font-weight: bold; box-shadow: none;
}
.calendar-today:hover { background-color: rgba(255,255,255,0.28); }
.calendar .calendar-nonwork-day { color: rgba(255,255,255,0.60); }
.calendar .calendar-other-month-day { color: rgba(255,255,255,0.28); }
.calendar .calendar-week-number {
    background-color: rgba(255,255,255,0.06); color: rgba(255,255,255,0.45);
    box-shadow: none; border-radius: 7px;
}

/* WIDGETS DE FECHA */
.events-button, .world-clocks-button, .weather-button {
    background-color: rgba(36,36,36,0.88) !important; color: white !important;
    border-radius: 14px !important; border-color: transparent !important; box-shadow: none !important;
}
.events-button:hover, .world-clocks-button:hover, .weather-button:hover {
    background-color: rgba(255,255,255,0.06);
}

/* NOTIFICACIONES */
.message-list { border-color: transparent; padding: 0; }
.message-list-placeholder { color: rgba(255,255,255,0.38); font-weight: 700; }
.message-list .message, .message-view .message {
    background-color: rgba(36,36,36,0.88) !important;
    box-shadow: none !important; border-radius: 13px !important; transition-duration: 100ms;
}
.message-list .message:hover { background-color: rgba(255,255,255,0.06); }
.message .message-body, .message-title { color: white; }
.message-close-button, .message-expand-button, .message-collapse-button {
    color: white; background-color: rgba(255,255,255,0.08); box-shadow: none; border-radius: 99px;
}
.message-close-button:hover, .message-expand-button:hover, .message-collapse-button:hover {
    background-color: rgba(255,255,255,0.14);
}
.notification-banner {
    background-color: rgba(36,36,36,0.88) !important; color: white !important;
    border: none !important; box-shadow: 0 2px 8px rgba(36,36,36,0.63) !important;
    border-radius: 16px !important;
}
.message:second-in-stack { background-color: rgba(36,36,36,0.78); }
.message:lower-in-stack  { background-color: rgba(36,36,36,0.68); }

/* DOCK */
.dash-background { background-color: rgba(37,37,37,0.4); border-radius: 18px; }

/* APP FOLDERS */
.app-folder-popup {
    background-color: rgba(36,36,36,0.88);
    border-radius: 14px; border: none; box-shadow: none;
}
CSSEOF

cp -a --no-clobber /etc/skel/.themes/. "\$USER_HOME/.themes/"
chown -R "$USERNAME":"$USERNAME" "\$USER_HOME/.themes"

echo "✓  Tema CSS: skel → \$USER_HOME/.themes/Adwaita-Transparent/"
CHROOTEOF

echo ""
echo -e "${C_OK}✓${C_RESET}  Tema CSS creado: /home/${USERNAME}/.themes/Adwaita-Transparent/"
echo -e "${C_INFO}ℹ${C_RESET}  Se aplicará en el primer login (via user-theme + gnome-first-login)"
echo ""

exit 0

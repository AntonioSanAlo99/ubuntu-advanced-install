#!/bin/bash
# MÓDULO 91: Generar informe del sistema
# REQUIERE: TARGET, HOSTNAME, USERNAME, UBUNTU_VERSION
# PRODUCE:  Informe en /tmp/

set -e
[ -f "$(dirname "$0")/../partition.info" ] && source "$(dirname "$0")/../partition.info"


# ── Cargar configuración desde config.yaml ────────────────────────────────────
_YAML_FILE="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}/../config.yaml"
_yaml_val() {
    # Lee una clave de config.yaml: _yaml_val "section" "key" "default"
    local section="$1" key="$2" default="${3:-}"
    [ ! -f "$_YAML_FILE" ] && { echo "$default"; return; }
    local in_section=false val=""
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*# || -z "${line// }" ]] && continue
        if [[ "$line" =~ ^([a-z_]+):[[:space:]]*$ ]]; then
            [ "${BASH_REMATCH[1]}" = "$section" ] && in_section=true || in_section=false
            continue
        fi
        if $in_section && [[ "$line" =~ ^[[:space:]]+${key}:[[:space:]]+(.*) ]]; then
            val="${BASH_REMATCH[1]}"
            val="${val%%#*}"; val="${val%"${val##*[![:space:]]}"}";
            val="${val#\"}" ; val="${val%\"}"; val="${val#\'}" ; val="${val%\'}"
            echo "$val"; return
        fi
    done < "$_YAML_FILE"
    echo "$default"
}

[ -z "${UBUNTU_VERSION:-}" ] && UBUNTU_VERSION=$(_yaml_val "system" "ubuntu_version" "noble")
[ -z "${HOSTNAME:-}" ] && HOSTNAME=$(_yaml_val "system" "hostname" "ubuntu")
[ -z "${USERNAME:-}" ] && USERNAME=$(_yaml_val "system" "username" "")


# Verificar que TARGET está montado
if ! mountpoint -q "${TARGET:-/mnt/ubuntu}" 2>/dev/null; then
    echo "ERROR: TARGET=${TARGET:-/mnt/ubuntu} no está montado." >&2
    exit 1
fi


REPORT_FILE="/tmp/ubuntu-install-report.txt"

cat > "$REPORT_FILE" << EOF
═══════════════════════════════════════════════════════════
  INFORME DE INSTALACIÓN UBUNTU
═══════════════════════════════════════════════════════════
Fecha: $(date)

CONFIGURACIÓN BASE:
  • Versión: Ubuntu $UBUNTU_VERSION
  • Hostname: $HOSTNAME
  • Usuario: $USERNAME
  • Firmware: $FIRMWARE
  
HARDWARE:
  • Disco: $TARGET_DISK
  • Tipo: $DISK_TYPE
  • Partición Root: $ROOT_PART
EOF

[ -n "$EFI_PART" ] && echo "  • Partición EFI: $EFI_PART" >> "$REPORT_FILE"
[ "$DUAL_BOOT_MODE" = "true" ] && echo "  • Dual-boot: SÍ (Windows preservado)" >> "$REPORT_FILE"

cat >> "$REPORT_FILE" << EOF

PARTICIONES:
$(lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT "$TARGET_DISK" 2>/dev/null)

PAQUETES INSTALADOS:
$(arch-chroot "$TARGET" dpkg -l | grep "^ii" | wc -l) paquetes

SERVICIOS HABILITADOS:
$(arch-chroot "$TARGET" systemctl list-unit-files | grep enabled | head -20)

═══════════════════════════════════════════════════════════
EOF

cat "$REPORT_FILE"
echo ""
echo "Informe guardado en: $REPORT_FILE"

exit 0

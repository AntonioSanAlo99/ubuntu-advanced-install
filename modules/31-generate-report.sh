#!/bin/bash
# Módulo 31: Generar informe del sistema

set -e  # Exit on error  # Detectar errores en pipelines


# Variables se pasan desde install.sh via environment
# source "$(dirname "$0")/../config.env"
[ -f "$(dirname "$0")/../partition.info" ] && source "$(dirname "$0")/../partition.info"

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

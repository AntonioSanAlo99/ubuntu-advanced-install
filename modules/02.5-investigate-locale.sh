#!/bin/bash
# Módulo 02.5: INVESTIGACIÓN - Estado del sistema después de debootstrap
# TEMPORAL - Para entender el estado real y diseñar configuración correcta
# Este módulo se ejecuta DESPUÉS de 02-debootstrap y ANTES de 03-configure-base

set -e

# Cargar variables
[ -f "$(dirname "$0")/../partition.info" ] && source "$(dirname "$0")/../partition.info"

REPORT_FILE="$(dirname "$0")/../locale-investigation-report.txt"

echo "════════════════════════════════════════════════════════════════"
echo "  MÓDULO INVESTIGACIÓN: Estado después de debootstrap"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Este módulo es TEMPORAL para investigación"
echo "Generando reporte en: $REPORT_FILE"
echo ""

# Limpiar reporte anterior
> "$REPORT_FILE"

# Función helper para reportar
report() {
    echo "$1" | tee -a "$REPORT_FILE"
}

report "════════════════════════════════════════════════════════════════"
report "REPORTE DE INVESTIGACIÓN: Estado de Locales Después de Debootstrap"
report "════════════════════════════════════════════════════════════════"
report "Fecha: $(date)"
report "Target: $TARGET"
report ""

# ============================================================================
# 1. ARCHIVOS DE CONFIGURACIÓN DE LOCALE
# ============================================================================
report "═══ 1. ARCHIVOS DE CONFIGURACIÓN DE LOCALE ═══"
report ""

report "--- /etc/default/locale ---"
if [ -f "$TARGET/etc/default/locale" ]; then
    report "✓ EXISTE"
    cat "$TARGET/etc/default/locale" | tee -a "$REPORT_FILE"
    report ""
else
    report "✗ NO EXISTE"
    report ""
fi

report "--- /etc/locale.gen ---"
if [ -f "$TARGET/etc/locale.gen" ]; then
    report "✓ EXISTE"
    report "Locales NO comentados:"
    grep -v "^#" "$TARGET/etc/locale.gen" | grep -v "^$" | tee -a "$REPORT_FILE" || report "  (todos comentados o vacío)"
    report ""
    report "Total de líneas en archivo: $(wc -l < $TARGET/etc/locale.gen)"
    report ""
else
    report "✗ NO EXISTE"
    report ""
fi

report "--- /etc/environment ---"
if [ -f "$TARGET/etc/environment" ]; then
    report "✓ EXISTE"
    cat "$TARGET/etc/environment" | tee -a "$REPORT_FILE"
    report ""
else
    report "✗ NO EXISTE"
    report ""
fi

# ============================================================================
# 2. LOCALES GENERADOS
# ============================================================================
report "═══ 2. LOCALES GENERADOS EN EL SISTEMA ═══"
report ""

if [ -d "$TARGET/usr/lib/locale" ]; then
    report "Directorio /usr/lib/locale:"
    ls -la "$TARGET/usr/lib/locale/" 2>/dev/null | tee -a "$REPORT_FILE" || report "Error listando"
    report ""
    report "Total de locales generados: $(ls -1 $TARGET/usr/lib/locale/ 2>/dev/null | wc -l)"
    report ""
else
    report "✗ /usr/lib/locale NO EXISTE"
    report ""
fi

if [ -d "$TARGET/usr/share/i18n/locales" ]; then
    report "Locales disponibles en /usr/share/i18n/locales:"
    ls "$TARGET/usr/share/i18n/locales/" | head -20 | tee -a "$REPORT_FILE"
    report "... (mostrando primeros 20)"
    report ""
else
    report "✗ /usr/share/i18n/locales NO EXISTE"
    report ""
fi

# ============================================================================
# 3. PAQUETES INSTALADOS
# ============================================================================
report "═══ 3. PAQUETES RELACIONADOS CON LOCALE ═══"
report ""

report "--- Paquete: locales ---"
arch-chroot "$TARGET" dpkg -l locales 2>&1 | grep -E "^ii|^un|^rc|no packages" | tee -a "$REPORT_FILE"
report ""

report "--- Paquete: console-data ---"
arch-chroot "$TARGET" dpkg -l console-data 2>&1 | grep -E "^ii|^un|^rc|no packages" | tee -a "$REPORT_FILE"
report ""

report "--- Paquete: console-setup ---"
arch-chroot "$TARGET" dpkg -l console-setup 2>&1 | grep -E "^ii|^un|^rc|no packages" | tee -a "$REPORT_FILE"
report ""

report "--- Paquete: keyboard-configuration ---"
arch-chroot "$TARGET" dpkg -l keyboard-configuration 2>&1 | grep -E "^ii|^un|^rc|no packages" | tee -a "$REPORT_FILE"
report ""

report "--- Todos los paquetes con 'locale' o 'language' ---"
arch-chroot "$TARGET" dpkg -l 2>/dev/null | grep -E "locale|language" | tee -a "$REPORT_FILE" || report "Ninguno"
report ""

# ============================================================================
# 4. COMANDO LOCALE DENTRO DEL CHROOT
# ============================================================================
report "═══ 4. SALIDA DEL COMANDO 'locale' EN CHROOT ═══"
report ""

report "Sin variables de entorno configuradas:"
arch-chroot "$TARGET" /bin/bash -c 'locale' 2>&1 | tee -a "$REPORT_FILE" || report "Error ejecutando locale"
report ""

report "Variables LANG y LC_ALL dentro del chroot:"
arch-chroot "$TARGET" /bin/bash -c 'echo "LANG=$LANG"; echo "LC_ALL=$LC_ALL"' 2>&1 | tee -a "$REPORT_FILE"
report ""

# ============================================================================
# 5. CONFIGURACIÓN DE TECLADO
# ============================================================================
report "═══ 5. CONFIGURACIÓN DE TECLADO ═══"
report ""

report "--- /etc/default/keyboard ---"
if [ -f "$TARGET/etc/default/keyboard" ]; then
    report "✓ EXISTE"
    cat "$TARGET/etc/default/keyboard" | tee -a "$REPORT_FILE"
    report ""
else
    report "✗ NO EXISTE"
    report ""
fi

report "--- /etc/vconsole.conf ---"
if [ -f "$TARGET/etc/vconsole.conf" ]; then
    report "✓ EXISTE"
    cat "$TARGET/etc/vconsole.conf" | tee -a "$REPORT_FILE"
    report ""
else
    report "✗ NO EXISTE"
    report ""
fi

# ============================================================================
# 6. DIRECTORIO /var/lib/locales
# ============================================================================
report "═══ 6. DIRECTORIO /var/lib/locales ═══"
report ""

if [ -d "$TARGET/var/lib/locales/supported.d" ]; then
    report "Contenido de /var/lib/locales/supported.d/:"
    ls -la "$TARGET/var/lib/locales/supported.d/" | tee -a "$REPORT_FILE"
    report ""
    
    for f in "$TARGET/var/lib/locales/supported.d/"*; do
        if [ -f "$f" ]; then
            report "--- Archivo: $(basename $f) ---"
            cat "$f" | tee -a "$REPORT_FILE"
            report ""
        fi
    done
else
    report "✗ /var/lib/locales/supported.d NO EXISTE"
    report ""
fi

# ============================================================================
# 7. APT CONFIGURATION
# ============================================================================
report "═══ 7. CONFIGURACIÓN APT RELACIONADA CON LOCALE ═══"
report ""

if [ -d "$TARGET/etc/apt/apt.conf.d" ]; then
    report "Archivos en /etc/apt/apt.conf.d/ con 'locale' o 'lang':"
    grep -l -i "locale\|lang" "$TARGET/etc/apt/apt.conf.d/"* 2>/dev/null | while read f; do
        report "--- $(basename $f) ---"
        cat "$f" | tee -a "$REPORT_FILE"
        report ""
    done || report "Ninguno encontrado"
    report ""
else
    report "✗ /etc/apt/apt.conf.d NO EXISTE"
    report ""
fi

# ============================================================================
# 8. TEST: EJECUTAR APT UPDATE
# ============================================================================
report "═══ 8. TEST: APT UPDATE (capturando warnings) ═══"
report ""

report "Ejecutando 'apt update' para ver si hay warnings de locale..."
arch-chroot "$TARGET" /bin/bash -c 'export DEBIAN_FRONTEND=noninteractive; apt update -qq 2>&1' | grep -i "locale\|perl.*warning" | tee -a "$REPORT_FILE" || report "Sin warnings de locale"
report ""

# ============================================================================
# 9. TEST: EJECUTAR LOCALE-GEN
# ============================================================================
report "═══ 9. TEST: EJECUTAR locale-gen ═══"
report ""

report "Ejecutando 'locale-gen' para ver warnings..."
arch-chroot "$TARGET" locale-gen 2>&1 | tee -a "$REPORT_FILE"
report ""

# ============================================================================
# 10. INFORMACIÓN DEL SISTEMA
# ============================================================================
report "═══ 10. INFORMACIÓN DEL SISTEMA ═══"
report ""

report "Versión de Ubuntu:"
cat "$TARGET/etc/os-release" | grep -E "VERSION|PRETTY_NAME" | tee -a "$REPORT_FILE"
report ""

report "Versión de debootstrap usado:"
debootstrap --version 2>&1 | head -1 | tee -a "$REPORT_FILE"
report ""

# ============================================================================
# RESUMEN Y CONCLUSIONES
# ============================================================================
report "════════════════════════════════════════════════════════════════"
report "RESUMEN PARA ANÁLISIS"
report "════════════════════════════════════════════════════════════════"
report ""

report "VERIFICAR ESTOS PUNTOS CLAVE:"
report "1. ¿Existe /etc/default/locale? ¿Qué contiene?"
report "2. ¿Hay locales generados en /usr/lib/locale/?"
report "3. ¿Qué dice 'locale' dentro del chroot?"
report "4. ¿Hay warnings al ejecutar apt update?"
report "5. ¿Hay warnings al ejecutar locale-gen?"
report "6. ¿console-data/console-setup están instalados?"
report ""

report "DECISIONES A TOMAR:"
report "A. Si NO hay locale configurado → Configurar es_ES.UTF-8 desde cero"
report "B. Si HAY C.UTF-8 o similar → Cambiar a es_ES.UTF-8"
report "C. Si HAY configuración parcial → Complementar sin romper"
report ""

report "════════════════════════════════════════════════════════════════"
report "FIN DEL REPORTE"
report "════════════════════════════════════════════════════════════════"

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓ Investigación completada"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Reporte guardado en: $REPORT_FILE"
echo ""
echo "PRÓXIMOS PASOS:"
echo "1. Revisar el reporte: cat $REPORT_FILE"
echo "2. Analizar el estado real del sistema"
echo "3. Diseñar configuración apropiada en módulo 03"
echo "4. Este módulo 02.5 se eliminará después"
echo ""
echo "Presiona Enter para continuar con la instalación..."
echo "O Ctrl+C para detener y analizar el reporte primero"
read

exit 0

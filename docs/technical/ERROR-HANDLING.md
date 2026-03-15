# Sistema de Manejo de Errores

## Visión General

El instalador ahora incluye un sistema completo de captura y reporte de errores que:

1. ✅ **NO interrumpe el flujo** - Los módulos continúan ejecutándose incluso si hay errores
2. ✅ **Captura todos los errores** - Errores y advertencias se registran automáticamente
3. ✅ **Resumen al final** - Cada módulo muestra un resumen de errores al finalizar
4. ✅ **Resumen global** - Al final de la instalación se muestra un resumen de todos los módulos

## Arquitectura

### Archivos del Sistema

```
lib/error-handler.sh        # Sistema de tracking de errores
lib/module-template.sh      # Template para nuevos módulos
logs/
├── install-YYYYMMDD-HHMMSS.log  # Log completo de la instalación
├── module-summary.log           # Resumen de módulos ejecutados
/tmp/
├── ubuntu-install-errors.log    # Errores capturados
└── ubuntu-install-warnings.log  # Advertencias capturadas
```

### Funciones Disponibles

#### `log_error(module, message, severity)`
Registra un error o advertencia.

```bash
log_error "Firmware" "No se pudo instalar firmware-realtek" "WARNING"
log_error "GNOME" "gdm3 no se instaló" "ERROR"
```

#### `log_success(module, message)`
Registra una operación exitosa.

```bash
log_success "Firmware" "Intel WiFi firmware instalado"
```

#### `safe_run(module, description, command...)`
Ejecuta un comando y captura automáticamente errores.

```bash
safe_run "GNOME" "Instalación de GNOME Shell" \
    apt install -y gnome-shell
```

#### `show_error_summary(module_name)`
Muestra el resumen de errores del módulo (llamar al final).

```bash
show_error_summary "Firmware Detection"
```

## Uso en Módulos

### Template Básico

```bash
#!/bin/bash
# Módulo XX: Nombre del módulo

source "$(dirname "$0")/../config.env"
source "$(dirname "$0")/../lib/error-handler.sh" 2>/dev/null || {
    # Fallback si no existe el error handler
    log_error() { echo "ERROR: $2"; }
    log_success() { echo "✓ $2"; }
    show_error_summary() { :; }
}

MODULE_NAME="Nombre del Módulo"

# Trap para capturar errores no manejados
trap 'log_error "$MODULE_NAME" "Error no capturado en línea $LINENO" "ERROR"' ERR

# Continuar incluso si hay errores
set +e

echo "═══════════════════════════════════════════════════════════"
echo "  MÓDULO: $MODULE_NAME"
echo "═══════════════════════════════════════════════════════════"
echo ""

# ... código del módulo ...

# Al final del módulo
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "✓ MÓDULO COMPLETADO"
echo "═══════════════════════════════════════════════════════════"
echo ""

show_error_summary "$MODULE_NAME"

exit 0
```

### Ejemplo: Instalación con Captura de Errores

```bash
# Ejemplo 1: Validación simple
if ! apt install -y paquete 2>/dev/null; then
    log_error "$MODULE_NAME" "No se pudo instalar paquete" "WARNING"
else
    log_success "$MODULE_NAME" "Paquete instalado"
fi

# Ejemplo 2: Con contador de errores en chroot
arch-chroot "$TARGET" /bin/bash << 'CHROOTEOF'
ERRORS=0

if ! apt install -y paquete1 2>/dev/null; then
    echo "ERROR: paquete1 falló" >&2
    ((ERRORS++))
else
    echo "✓ paquete1 instalado"
fi

if ! apt install -y paquete2 2>/dev/null; then
    echo "ERROR: paquete2 falló" >&2
    ((ERRORS++))
else
    echo "✓ paquete2 instalado"
fi

echo "Total errores: $ERRORS"
exit $ERRORS
CHROOTEOF

if [ $? -ne 0 ]; then
    log_error "$MODULE_NAME" "Errores en instalación de paquetes" "WARNING"
fi

# Ejemplo 3: Loop con captura
for package in paquete1 paquete2 paquete3; do
    if apt install -y $package 2>/dev/null; then
        log_success "$MODULE_NAME" "$package instalado"
    else
        log_error "$MODULE_NAME" "$package no se pudo instalar" "WARNING"
    fi
done
```

## Salida del Sistema

### Durante la Ejecución

```
════════════════════════════════════════════════════════════════
  MÓDULO: Firmware Detection
════════════════════════════════════════════════════════════════

Detectando hardware...
✓ Firmware Detection: Intel WiFi firmware instalado
✓ Firmware Detection: AMD GPU firmware instalado
✗ Error en Firmware Detection: Realtek firmware no disponible

... (resto del módulo) ...

════════════════════════════════════════════════════════════════
  RESUMEN: Firmware Detection
════════════════════════════════════════════════════════════════
Errores encontrados: 0
Advertencias: 1

Detalles de advertencias:
[14:32:15] [Firmware Detection] WARNING: Realtek firmware no disponible

════════════════════════════════════════════════════════════════
```

### Al Final de la Instalación

```
════════════════════════════════════════════════════════════════
           RESUMEN DE MÓDULOS EJECUTADOS
════════════════════════════════════════════════════════════════

Total de módulos ejecutados: 15
Completados exitosamente:    13
Con errores:                 2

Detalles por módulo:
  ✓ [01-prepare-disk] OK
  ✓ [02-debootstrap] OK
  ✓ [03-install-firmware] OK
  ✓ [04-install-bootloader] OK
  ✓ [05-configure-network] OK
  ✓ [10-install-gnome-core] OK
  ✗ [10-optimize-memory] FAILED (code: 1)
  ✓ [12-install-multimedia] OK
  ✓ [13-install-fonts] OK
  ✓ [14-configure-wireless] OK
  ✓ [15-install-development] OK
  ✗ [16-configure-gaming] FAILED (code: 1)
  ✓ [20-minimize-systemd] OK
  ✓ [21-optimize-laptop] OK
  ✓ [21-laptop-advanced] OK

════════════════════════════════════════════════════════════════

⚠️  ATENCIÓN: Algunos módulos tuvieron errores
   Revisa los logs para más detalles

Logs de errores:
  Error general: /tmp/ubuntu-install-errors.log
  Advertencias: /tmp/ubuntu-install-warnings.log
  Log completo: /path/to/install-20260222-143015.log
```

## Comportamiento

### Modo Automático
- Los módulos continúan ejecutándose automáticamente
- Se registran todos los errores
- Se muestra resumen al final
- No se detiene la instalación

### Modo Interactivo
- Si un módulo falla, se pregunta al usuario si continuar
- Se puede revisar el error antes de decidir
- Se puede abortar la instalación si es crítico

## Logs

### Error Log (`/tmp/ubuntu-install-errors.log`)
```
[14:32:15] [Firmware Detection] ERROR: firmware-realtek no disponible
[14:35:42] [GNOME] ERROR: extension-manager falló al instalar
```

### Warning Log (`/tmp/ubuntu-install-warnings.log`)
```
[14:32:15] [Firmware Detection] WARNING: Realtek firmware no encontrado
[14:40:21] [Gaming] WARNING: Steam no se pudo conectar a servidor
```

### Module Summary (`logs/module-summary.log`)
```
[01-prepare-disk] OK
[02-debootstrap] OK
[03-install-firmware] OK
[10-optimize-memory] FAILED (code: 1)
[16-configure-gaming] FAILED (code: 1)
```

## Beneficios

1. **Visibilidad completa** - Sabes exactamente qué falló y dónde
2. **No interrumpe** - La instalación continúa incluso con errores no críticos
3. **Fácil depuración** - Logs detallados con timestamps
4. **Resumen claro** - Vista rápida del estado de la instalación
5. **Modo interactivo** - Control total sobre si continuar o no

## Migración de Módulos Existentes

Para añadir el manejo de errores a un módulo existente:

1. Añadir el header al inicio (ver template)
2. Cambiar comandos críticos para usar `log_error`/`log_success`
3. Añadir contadores en bloques chroot
4. Llamar a `show_error_summary` al final

No es necesario migrar todos los módulos de una vez - el sistema funciona con fallback si el módulo no tiene el error handler.

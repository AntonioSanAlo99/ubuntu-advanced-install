# Sistema de Logging

## Ubicación de Logs

```
logs/
├── install-20241220-143022.log
├── install-20241220-145513.log
└── install-20241220-151234.log
```

**Formato:** `install-YYYYMMDD-HHMMSS.log`

## Qué se Registra

### Eventos Principales

```
[2024-12-20 14:30:22] [INFO] Inicio de instalación Ubuntu
[2024-12-20 14:30:25] [STEP] Ejecutando módulo: 01-prepare-disk
[2024-12-20 14:30:45] [SUCCESS] Módulo completado: 01-prepare-disk
[2024-12-20 14:30:46] [STEP] Ejecutando módulo: 02-debootstrap
[2024-12-20 14:35:12] [SUCCESS] Módulo completado: 02-debootstrap
[2024-12-20 14:35:13] [WARNING] Paquete opcional no disponible
[2024-12-20 14:35:15] [ERROR] Script falló en línea 142
```

### Niveles de Log

- **INFO**: Información general
- **STEP**: Inicio de paso/módulo
- **SUCCESS**: Operación completada
- **WARNING**: Advertencia (no crítico)
- **ERROR**: Error crítico

## Salida

### En Pantalla

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
▶ Ejecutando módulo: 01-prepare-disk
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Particiones creadas
✓ Sistema de archivos formateado
✓ Módulo completado: 01-prepare-disk
```

### En Archivo Log

```
[2024-12-20 14:30:22] [INFO] ═══════════════════════════════════════
[2024-12-20 14:30:22] [INFO] Inicio de instalación Ubuntu
[2024-12-20 14:30:22] [INFO] Log: logs/install-20241220-143022.log
[2024-12-20 14:30:22] [INFO] ═══════════════════════════════════════
[2024-12-20 14:30:25] [STEP] Ejecutando módulo: 01-prepare-disk
[2024-12-20 14:30:45] [SUCCESS] Particiones creadas
[2024-12-20 14:30:45] [SUCCESS] Sistema de archivos formateado
[2024-12-20 14:30:45] [SUCCESS] Módulo completado: 01-prepare-disk
```

## Captura de Errores

El script usa `trap` para capturar errores:

```bash
trap 'error_handler $LINENO' ERR
```

Cuando falla:

```
[2024-12-20 14:35:15] [ERROR] Script falló en línea 142

✗ Error en línea 142
⚠ Ver log completo en: logs/install-20241220-143022.log
```

## Funciones de Logging

```bash
log_step "Ejecutando módulo"       # Paso principal
log_success "Operación completada"  # Éxito
log_error "Falló la operación"      # Error
log_warning "Advertencia"           # Advertencia
log_info "Información"              # Info general
```

## Todo se Captura

```bash
# Redirigir stdout y stderr al log
exec > >(tee -a "$LOG_FILE")
exec 2>&1
```

**Resultado:** TODO lo que sale por pantalla también va al log.

## Ver Logs en Tiempo Real

### Durante Instalación

```bash
# En otra terminal
tail -f logs/install-*.log
```

### Después de Instalación

```bash
# Ver último log
cat logs/install-$(ls -t logs/ | head -1)

# Buscar errores
grep ERROR logs/*.log

# Ver solo módulo específico
grep "01-prepare-disk" logs/*.log
```

## Logs de Módulos

Cada módulo también genera su propia salida que se captura:

```bash
run_module() {
    local module_name="$1"
    log_step "Ejecutando módulo: $module_name"
    bash "$module_path"  # Todo stdout/stderr va al log
    log_success "Módulo completado: $module_name"
}
```

## Ejemplo Completo de Log

```
[2024-12-20 14:30:22] [INFO] ═══════════════════════════════════════
[2024-12-20 14:30:22] [INFO] Inicio de instalación Ubuntu
[2024-12-20 14:30:22] [INFO] Log: logs/install-20241220-143022.log
[2024-12-20 14:30:22] [INFO] ═══════════════════════════════════════

[2024-12-20 14:30:25] [STEP] Ejecutando módulo: 01-prepare-disk

Particionando /dev/sda...
Creando partición EFI...
Creando partición raíz...
Formateando particiones...

[2024-12-20 14:30:45] [SUCCESS] Módulo completado: 01-prepare-disk

[2024-12-20 14:30:46] [STEP] Ejecutando módulo: 02-debootstrap

Descargando paquetes base...
Instalando sistema base...
Configurando paquetes...

[2024-12-20 14:35:12] [SUCCESS] Módulo completado: 02-debootstrap

[2024-12-20 14:35:13] [STEP] Ejecutando módulo: 03-configure-base

Configurando locales...
Configurando timezone...
Creando usuario...

[2024-12-20 14:35:45] [SUCCESS] Módulo completado: 03-configure-base

[2024-12-20 14:35:46] [INFO] Instalación finalizada
[2024-12-20 14:35:46] [INFO] Log completo guardado en: logs/install-20241220-143022.log
```

## Debugging

### Encontrar Cuándo Falló

```bash
grep -A 5 ERROR logs/install-*.log
```

### Ver Último Módulo Ejecutado

```bash
grep STEP logs/install-*.log | tail -1
```

### Estadísticas de Instalación

```bash
# Módulos completados
grep SUCCESS logs/install-*.log | grep "Módulo completado" | wc -l

# Errores totales
grep ERROR logs/install-*.log | wc -l

# Warnings
grep WARNING logs/install-*.log | wc -l
```

## Limpieza

```bash
# Eliminar logs antiguos (>7 días)
find logs/ -name "*.log" -mtime +7 -delete

# Eliminar todos los logs
rm -rf logs/
```

## .gitignore

Los logs no se suben a git:

```
# .gitignore
logs/
*.log
```

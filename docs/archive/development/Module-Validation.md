# Validación de Módulos - Ejemplos de Uso

## Cómo Añadir Validación a un Módulo

### 1. Al inicio del módulo

```bash
#!/bin/bash
source "$(dirname "$0")/../config.env"
source "$(dirname "$0")/../lib/validate-module.sh"

# Tu código del módulo aquí...
```

### 2. Al final del módulo

```bash
# ============================================================================
# VALIDACIÓN POST-EJECUCIÓN
# ============================================================================

validate_start "01-prepare-disk"

# Validar montajes
validate_mount "$TARGET"
validate_mount "$TARGET/boot/efi"

# Validar espacio en disco
validate_disk_space "$TARGET" 5000 "Partición raíz (mínimo 5GB)"

# Reporte final
validate_report
exit $?
```

## Ejemplos por Módulo

### Módulo 01: Preparación de Disco

```bash
validate_start "01-prepare-disk"

# Montajes
validate_mount "$TARGET" "Partición raíz"
validate_mount "$TARGET/boot/efi" "Partición EFI"

# Espacio
validate_disk_space "$TARGET" 10000 "Raíz (10GB mín)"
validate_disk_space "$TARGET/boot/efi" 500 "EFI (500MB mín)"

validate_report
```

### Módulo 02: Debootstrap

```bash
validate_start "02-debootstrap"

# Directorios críticos
validate_directory "$TARGET/bin" "Binarios del sistema"
validate_directory "$TARGET/lib" "Librerías del sistema"
validate_directory "$TARGET/etc" "Configuración"
validate_directory "$TARGET/var" "Datos variables"

# Archivos esenciales
validate_file "$TARGET/etc/passwd" "Base de datos de usuarios"
validate_file "$TARGET/etc/group" "Base de datos de grupos"
validate_file "$TARGET/etc/fstab" "Tabla de montaje"

# Comandos básicos
validate_command "bash" "$TARGET"
validate_command "apt" "$TARGET"
validate_command "systemctl" "$TARGET"

validate_report
```

### Módulo 03: Configuración Base

```bash
validate_start "03-configure-base"

# Locale
validate_file "$TARGET/etc/default/locale" "Configuración locale"
validate_no_duplicate_config "$TARGET/etc/default/locale" "LANG=" "Variable LANG"

# Timezone
validate_file "$TARGET/etc/localtime" "Zona horaria"

# Usuario
validate_user "$USERNAME" "$TARGET"

# Hostname
validate_file "$TARGET/etc/hostname" "Nombre del host"
validate_no_duplicate_config "$TARGET/etc/hosts" "127.0.0.1" "Localhost en hosts"

validate_report
```

### Módulo 10: GNOME Core

```bash
validate_start "10-install-gnome-core"

# Paquetes críticos
validate_package "gnome-shell" "$TARGET"
validate_package "gdm3" "$TARGET"
validate_package "nautilus" "$TARGET"

# Servicios
validate_service "gdm3" "$TARGET"

# Extensión no deseada eliminada
if [ -d "$TARGET/usr/share/gnome-shell/extensions/snapd-prompting@canonical.com" ]; then
    validate_error "Extensión snapd-prompting no eliminada"
else
    validate_ok "Extensión snapd-prompting eliminada correctamente"
fi

validate_report
```

### Módulo 10-user-config

```bash
validate_start "10-user-config"

# Script de configuración
validate_file "/etc/profile.d/10-gnome-user-config.sh" "Script configuración usuario"
validate_permissions "/etc/profile.d/10-gnome-user-config.sh" "755" "Permisos script"

validate_report
```

### Módulo 10-theme

```bash
validate_start "10-theme"

# Paquete
validate_package "gnome-shell-extension-user-theme" "$TARGET"

# Tema
validate_directory "$TARGET/etc/skel/.themes/Adwaita-Transparent" "Tema transparente"
validate_file "$TARGET/etc/skel/.themes/Adwaita-Transparent/gnome-shell/gnome-shell.css" "CSS del tema"

# Script
validate_file "$TARGET/etc/profile.d/11-gnome-theme-apply.sh" "Script activación tema"
validate_permissions "$TARGET/etc/profile.d/11-gnome-theme-apply.sh" "755" "Permisos script"

validate_report
```

### Módulo de Descarga (ejemplo genérico)

```bash
validate_start "download-chrome"

URL="https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
DEST="/tmp/chrome.deb"

# Descargar
wget -O "$DEST" "$URL"

# Validar descarga
validate_download "$URL" "$DEST" "Google Chrome"
validate_file "$DEST" "Chrome .deb"

# Instalar
dpkg -i "$DEST"

# Validar instalación
validate_package "google-chrome-stable" "$TARGET"

validate_report
```

## Uso Avanzado: Función validate_module

```bash
# Todo en una línea
validate_module "01-prepare-disk" \
    --mount "$TARGET" \
    --mount "$TARGET/boot/efi" \
    --space "$TARGET" 10000 "Raíz" \
    --space "$TARGET/boot/efi" 500 "EFI"
```

## Salida de Ejemplo

### Validación Exitosa

```
════════════════════════════════════════════════════════════════
VALIDACIÓN: 02-debootstrap
════════════════════════════════════════════════════════════════
[OK] Directorio OK: Binarios del sistema (/mnt/bin)
[OK] Directorio OK: Librerías del sistema (/mnt/lib)
[OK] Archivo OK: Base de datos de usuarios (/mnt/etc/passwd)
[OK] Comando disponible: bash
────────────────────────────────────────────────────────────────
RESUMEN DE VALIDACIÓN: 02-debootstrap
Errores:      0
Advertencias: 0
────────────────────────────────────────────────────────────────
✓ Módulo 02-debootstrap: Validación completa sin errores
```

### Con Errores

```
════════════════════════════════════════════════════════════════
VALIDACIÓN: 10-install-gnome-core
════════════════════════════════════════════════════════════════
[OK] Paquete instalado: gnome-shell
✗ VALIDACIÓN ERROR: Paquete no instalado en /mnt: gdm3
[WARNING] Servicio no habilitado en /mnt: gdm3
[ERROR] Extensión snapd-prompting no eliminada
────────────────────────────────────────────────────────────────
RESUMEN DE VALIDACIÓN: 10-install-gnome-core
Errores:      2
Advertencias: 1
────────────────────────────────────────────────────────────────
✗ Módulo 10-install-gnome-core: 2 error(es), 1 advertencia(s)
```

## Integración con Logging

Todo va al log principal:

```
[2024-12-20 14:30:45] [STEP] Ejecutando módulo: 02-debootstrap
[... salida del módulo ...]
[2024-12-20 14:35:12] [SUCCESS] Módulo completado: 02-debootstrap

════════════════════════════════════════════════════════════════
VALIDACIÓN: 02-debootstrap
════════════════════════════════════════════════════════════════
[OK] Directorio OK: Binarios del sistema (/mnt/bin)
[OK] Comando disponible: bash
────────────────────────────────────────────────────────────────
RESUMEN DE VALIDACIÓN: 02-debootstrap
Errores:      0
Advertencias: 0
────────────────────────────────────────────────────────────────
```

## Checklist de Validaciones por Tipo de Módulo

### Módulo de Particionado
- [ ] Montajes (`validate_mount`)
- [ ] Espacio en disco (`validate_disk_space`)

### Módulo de Instalación de Paquetes
- [ ] Paquetes instalados (`validate_package`)
- [ ] Comandos disponibles (`validate_command`)

### Módulo de Configuración
- [ ] Archivos creados (`validate_file`)
- [ ] Sin duplicados (`validate_no_duplicate_config`)
- [ ] Permisos correctos (`validate_permissions`)

### Módulo de Servicios
- [ ] Servicios habilitados (`validate_service`)

### Módulo de Usuario
- [ ] Usuario existe (`validate_user`)
- [ ] Directorio home (`validate_directory`)

### Módulo de Descarga
- [ ] URL accesible (`validate_url`)
- [ ] Descarga exitosa (`validate_download`)
- [ ] Archivo no vacío (`validate_file`)

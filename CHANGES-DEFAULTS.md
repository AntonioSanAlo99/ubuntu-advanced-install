# Cambios en Valores Predeterminados

## Cambios aplicados

### 1. Módulo de backports eliminado
- ❌ Eliminado: `06-enable-backports.sh`
- **Razón**: Los backports raramente se necesitan en instalaciones nuevas y pueden causar conflictos de versiones

### 2. Tipo de hardware: Desktop por defecto
```
ANTES:
  1) Laptop [predeterminado]
  2) Desktop/Servidor

AHORA:
  1) Desktop/Servidor [predeterminado]
  2) Laptop
```
**Razón**: La mayoría de instalaciones son desktop/workstation, no laptop

### 3. Hardening de seguridad: NO por defecto
```
ANTES:
¿Aplicar hardening de seguridad? (s/n) [s]

AHORA:
¿Aplicar hardening de seguridad? (s/n) [n]
```
**Razón**: El hardening puede causar problemas de compatibilidad y debe ser una elección consciente del usuario

### 4. Menú principal: Instalación guiada primero
```
ANTES:
  1) Instalación automática completa
  2) Instalación interactiva (paso a paso)

AHORA:
  1) Instalación interactiva guiada (recomendado)
  2) Instalación automática (requiere config.env)
```
**Razón**: La instalación guiada es más amigable para nuevos usuarios y permite personalización

## Impacto en instalaciones

### Instalación típica ahora es:
1. Ejecutar `./install.sh`
2. Seleccionar opción `1` (guiada)
3. Responder preguntas interactivas
4. Desktop es el tipo predeterminado
5. Security hardening NO se aplica por defecto
6. Backports NO se habilitan

### Valores predeterminados finales:
```bash
UBUNTU_VERSION="noble"           # 24.04 LTS
IS_LAPTOP="false"                # Desktop/workstation
INSTALL_GNOME="true"             # Sí
INSTALL_MULTIMEDIA="true"        # Sí
INSTALL_DEVELOPMENT="false"      # No
INSTALL_GAMING="false"           # No
MINIMIZE_SYSTEMD="true"          # Sí
ENABLE_SECURITY="false"          # No ← CAMBIADO
USE_NO_INSTALL_RECOMMENDS="true" # Sí
```

## Migración desde versión anterior

Si tenías scripts que usaban los valores antiguos:

### Backports
```bash
# Si necesitas backports manualmente:
sudo add-apt-repository -y "deb http://archive.ubuntu.com/ubuntu/ $(lsb_release -cs)-backports main restricted universe multiverse"
sudo apt update
```

### Laptop como predeterminado
```bash
# En config.env o al ejecutar, especifica explícitamente:
IS_LAPTOP="true"
```

### Security hardening activado
```bash
# En config.env:
ENABLE_SECURITY="true"

# O ejecuta el módulo manualmente después:
sudo ./modules/24-security-hardening.sh
```

## Justificación de cada cambio

### Backports eliminado
- Solo ~5% de usuarios necesita backports
- Puede causar actualizaciones inesperadas
- Fácil de habilitar manualmente si se necesita

### Desktop predeterminado
- ~80% de instalaciones son desktop/workstation
- Laptops son caso de uso minoritario
- TLP y otras optimizaciones de laptop son opcionales

### Security hardening opcional
- Puede romper compatibilidad con algunos juegos/apps
- Usuarios avanzados que lo necesitan saben habilitarlo
- Desktop típico no necesita hardening agresivo

### Instalación guiada primera
- Mejora experiencia de nuevos usuarios
- Automática requiere conocimiento previo de config.env
- Guiada permite ver y entender opciones

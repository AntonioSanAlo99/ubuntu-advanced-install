# Guía de Instalación

Guía paso a paso para instalar Ubuntu usando Ubuntu Advanced Install.

---

## Preparación

### Requisitos

- **Hardware**
  - CPU: x86_64 (64-bit)
  - RAM: Mínimo 2GB (4GB recomendado para GNOME)
  - Disco: Mínimo 20GB libre
  - Conexión a internet activa

- **Software**
  - Ubuntu Live USB (cualquier versión reciente)
  - O cualquier distribución Linux live con debootstrap disponible

- **Conocimientos**
  - Uso básico de terminal Linux
  - Conceptos de particionado de disco
  - Permisos y usuario root

### Descargar el Instalador

```bash
# Opción 1: Desde GitHub
wget https://github.com/tu-usuario/ubuntu-advanced-install/archive/main.tar.gz
tar xzf main.tar.gz
cd ubuntu-advanced-install

# Opción 2: Clonar repositorio
git clone https://github.com/tu-usuario/ubuntu-advanced-install
cd ubuntu-advanced-install
```

---

## Instalación Interactiva (Recomendado)

### Paso 1: Iniciar el Instalador

```bash
sudo ./install.sh
```

Verás el menú principal:

```
╔════════════════════════════════════════╗
║   UBUNTU ADVANCED INSTALL v1.0         ║
╚════════════════════════════════════════╝

INSTALACIÓN COMPLETA:
  1) Instalación interactiva guiada
  2) Instalación automática
```

Selecciona opción **1** para instalación guiada.

### Paso 2: Configuración del Disco

```
[1/8] Configuración del disco
```

**Opciones:**
- Disco a usar (ej: `/dev/sda`)
- Dual boot (sí/no)
- Tamaño de partición Ubuntu (si dual boot)

**Ejemplo:**
```
Disco disponible: /dev/sda (500GB)
¿Usar todo el disco? (s/n) [s]: s
```

### Paso 3: Información del Sistema

```
[2/8] Información del sistema
```

**Configurar:**
- Hostname (nombre del PC)
- Usuario
- Contraseña usuario
- Contraseña root

**Ejemplo:**
```
Hostname [ubuntu]: mi-laptop
Usuario [user]: juan
Contraseña: ********
```

### Paso 4: Zona Horaria

```
[3/8] Zona horaria
```

**Opciones:**
- Seleccionar de lista
- Usar detección automática
- Entrada manual

**Ejemplo:**
```
Zona horaria detectada: Europe/Madrid
¿Usar esta zona horaria? (s/n) [s]: s
```

### Paso 5: Hardware

```
[4/8] Detección de hardware
```

**Preguntas:**
- ¿Es un laptop? (para TLP)
- ¿Tiene WiFi?
- ¿Tiene Bluetooth?

**Detección automática disponible**

### Paso 6: Componentes

```
[5/8] Componentes a instalar
```

**GNOME:**
```
¿Instalar GNOME? (s/n) [s]: s

Personalización de GNOME:
  ¿Optimizar memoria? (s/n) [n]: s
  ¿Aplicar tema transparente? (s/n) [n]: n
  ¿Activar autologin en GDM? (s/n) [n]: n
```

**Otros componentes:**
```
¿Instalar multimedia? (s/n) [s]: s
¿Instalar herramientas de desarrollo? (s/n) [n]: s
¿Configurar para gaming? (s/n) [n]: n
```

### Paso 7: Optimizaciones

```
[6/8] Optimizaciones del sistema
```

**Opciones:**
- Minimizar systemd (deshabilitar servicios innecesarios)
- Security hardening (AppArmor, firewall)
- --no-install-recommends (instalación mínima)

### Paso 8: Resumen

```
[7/8] Resumen de configuración
```

Revisa toda la configuración antes de continuar.

```
╔══════════════════════════════════════════╗
║      RESUMEN DE CONFIGURACIÓN            ║
╚══════════════════════════════════════════╝

Sistema:
  • Hostname: mi-laptop
  • Usuario: juan
  • Tipo: Laptop

Componentes:
  • GNOME: true
    - Optimizar memoria: true
    - Tema transparente: false
  • Multimedia: true
  • Desarrollo: true

¿Continuar con la instalación? (s/n):
```

### Paso 9: Instalación

La instalación se ejecuta automáticamente:

```
[1/5] ✓ Preparando disco...
[2/5] ✓ Instalando sistema base (debootstrap)...
[3/5] ✓ Configurando sistema...
[4/5] ✓ Instalando bootloader...
[5/5] ✓ Instalando componentes...
```

**Duración:** 15-45 minutos dependiendo de:
- Velocidad de internet
- Componentes seleccionados
- Hardware del sistema

### Paso 10: Finalización

```
╔══════════════════════════════════════════╗
║   ✓ INSTALACIÓN COMPLETADA               ║
╚══════════════════════════════════════════╝

El sistema está listo para usar.
Reinicia para iniciar en tu nuevo sistema Ubuntu.

sudo reboot
```

---

## Instalación Automatizada

Para instalaciones repetibles o desatendidas.

### Paso 1: Configurar

```bash
# Copiar plantilla
cp config.env.example config.env

# Editar configuración
nano config.env
```

**Ejemplo de config.env:**
```bash
# Sistema
HOSTNAME="servidor"
USERNAME="admin"
USER_PASSWORD="password123"
ROOT_PASSWORD="rootpass456"

# Hardware
IS_LAPTOP="false"
HAS_WIFI="false"
HAS_BLUETOOTH="false"

# Componentes
INSTALL_GNOME="true"
GNOME_OPTIMIZE_MEMORY="true"
GNOME_TRANSPARENT_THEME="false"
INSTALL_MULTIMEDIA="false"
INSTALL_DEVELOPMENT="true"

# Optimizaciones
MINIMIZE_SYSTEMD="true"
USE_NO_INSTALL_RECOMMENDS="true"
```

### Paso 2: Ejecutar

```bash
sudo ./install.sh --auto
```

La instalación se ejecuta sin intervención.

---

## Post-Instalación

### Primer Arranque

1. **Iniciar sistema**
   ```bash
   sudo reboot
   ```

2. **Login**
   - Usuario: el que configuraste
   - Contraseña: la que configuraste

3. **GNOME (si instalado)**
   - Primer login: scripts automáticos se ejecutan
   - Extensiones se habilitan
   - Tema se aplica (si configurado)
   - App grid se organiza

### Verificar Instalación

```bash
# Ver módulos instalados
cat /var/log/ubuntu-install/installation-report.txt

# Verificar servicios
systemctl list-unit-files --state=enabled

# Ver locales
locale

# Ver zona horaria
timedatectl
```

### Configuración Adicional

**Si instalaste desarrollo:**
```bash
# Verificar herramientas
git --version
python3 --version
node --version
rustc --version  # si instalaste Rust
```

**Si instalaste GNOME:**
```bash
# Configuración adicional con Tweaks
gnome-tweaks
```

---

## Módulos Individuales

Para ejecutar módulos específicos después de la instalación:

```bash
sudo ./install.sh
# Selecciona opción de módulos individuales
```

**Menú de módulos:**
```
MÓDULOS INDIVIDUALES - BASE:
  10) Preparar disco
  11) Instalar sistema base
  12) Configurar sistema
  13) Instalar bootloader
  14) Configurar red

MÓDULOS - COMPONENTES:
  20) GNOME
  22) Multimedia
  23) Fuentes
  24) WiFi/Bluetooth
  25) Desarrollo
  26) Gaming
```

---

## Resolución de Problemas

### Error en Disco

```
Error: No se puede particionar /dev/sda
```

**Solución:**
- Verifica que el disco no esté montado
- Usa el disco correcto
- Ejecuta `lsblk` para ver discos disponibles

### Error en Debootstrap

```
Error: debootstrap failed
```

**Solución:**
- Verifica conexión a internet
- Comprueba que el mirror está disponible
- Intenta de nuevo (puede ser temporal)

### Error en Chroot

```
Error: arch-chroot: command not found
```

**Solución:**
- Instala `arch-install-scripts`
- O usa desde Ubuntu 22.04+ Live USB

Ver [Troubleshooting](03-Troubleshooting.md) completo para más soluciones.

---

## Siguientes Pasos

- **Personalización:** Lee [Configuración](02-Configuration.md)
- **Componentes:** Explora documentación en [Wiki](README.md)
- **Optimizaciones:** Revisa opciones avanzadas
- **Problemas:** Consulta [Troubleshooting](03-Troubleshooting.md)

---

**¡Disfruta de tu nuevo sistema Ubuntu optimizado!**

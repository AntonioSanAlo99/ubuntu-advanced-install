# Guía de Configuración

Documentación completa de todas las opciones de configuración disponibles.

---

## Variables de Configuración

Todas las variables se configuran en `config.env`.

### Sistema Base

#### UBUNTU_VERSION
**Descripción:** Versión de Ubuntu a instalar

**Valores:**
- `noble` - Ubuntu 24.04 LTS (recomendado)
- `jammy` - Ubuntu 22.04 LTS
- `mantic` - Ubuntu 23.10

**Ejemplo:**
```bash
UBUNTU_VERSION="noble"
```

#### HOSTNAME
**Descripción:** Nombre del equipo en la red

**Formato:** Alfanumérico, guiones permitidos, sin espacios

**Ejemplo:**
```bash
HOSTNAME="mi-laptop"
HOSTNAME="servidor-web"
HOSTNAME="workstation"
```

#### USERNAME
**Descripción:** Nombre del usuario principal

**Restricciones:**
- Minúsculas
- Sin espacios
- No puede empezar con número

**Ejemplo:**
```bash
USERNAME="juan"
USERNAME="admin"
```

#### USER_PASSWORD
**Descripción:** Contraseña del usuario principal

**Seguridad:** Se guarda en texto plano en config.env (eliminar después)

**Ejemplo:**
```bash
USER_PASSWORD="MiContraseña123!"
```

#### ROOT_PASSWORD
**Descripción:** Contraseña del usuario root

**Recomendación:** Usar contraseña diferente a la del usuario

**Ejemplo:**
```bash
ROOT_PASSWORD="RootPass456!"
```

---

### Localización

#### TIMEZONE
**Descripción:** Zona horaria del sistema

**Formato:** Area/Ciudad según tz database

**Ejemplos:**
```bash
TIMEZONE="Europe/Madrid"
TIMEZONE="America/New_York"
TIMEZONE="Asia/Tokyo"
TIMEZONE="America/Mexico_City"
```

**Lista completa:**
```bash
timedatectl list-timezones
```

#### LOCALE
**Descripción:** Locale del sistema (idioma y formatos)

**Formato:** xx_XX.UTF-8

**Ejemplos:**
```bash
LOCALE="es_ES.UTF-8"  # Español de España
LOCALE="en_US.UTF-8"  # Inglés de Estados Unidos
LOCALE="pt_BR.UTF-8"  # Portugués de Brasil
```

#### KEYBOARD_LAYOUT
**Descripción:** Distribución del teclado

**Valores comunes:**
- `es` - Español
- `us` - Inglés (Estados Unidos)
- `latam` - Latinoamericano
- `uk` - Inglés (Reino Unido)
- `de` - Alemán
- `fr` - Francés

**Ejemplo:**
```bash
KEYBOARD_LAYOUT="es"
```

---

### Hardware

#### IS_LAPTOP
**Descripción:** Indica si el sistema es un laptop

**Efecto:** Instala TLP para gestión de energía

**Valores:**
```bash
IS_LAPTOP="true"   # Es laptop
IS_LAPTOP="false"  # Es desktop
```

#### HAS_WIFI
**Descripción:** Sistema tiene WiFi

**Efecto:** Instala firmware y herramientas WiFi

**Valores:**
```bash
HAS_WIFI="true"
HAS_WIFI="false"
```

#### HAS_BLUETOOTH
**Descripción:** Sistema tiene Bluetooth

**Efecto:** Instala bluez y herramientas

**Valores:**
```bash
HAS_BLUETOOTH="true"
HAS_BLUETOOTH="false"
```

---

### Componentes

#### INSTALL_GNOME
**Descripción:** Instalar entorno de escritorio GNOME

**Efecto:** Instala GNOME Shell, GDM, aplicaciones core

**Valores:**
```bash
INSTALL_GNOME="true"   # Instalar GNOME
INSTALL_GNOME="false"  # Sistema sin GUI
```

#### GNOME_OPTIMIZE_MEMORY
**Descripción:** Optimizar uso de memoria en GNOME

**Efecto:** Deshabilita Tracker, Evolution Data Server, etc.

**Ahorro:** ~200-400MB RAM

**Valores:**
```bash
GNOME_OPTIMIZE_MEMORY="true"   # Optimizar
GNOME_OPTIMIZE_MEMORY="false"  # Configuración estándar
```

**Servicios deshabilitados:**
- tracker-miner-fs (indexación de archivos)
- tracker-extract (extracción de metadatos)
- evolution-source-registry (sincronización calendarios)
- evolution-addressbook-factory (libreta direcciones)
- evolution-calendar-factory (calendario)

#### GNOME_TRANSPARENT_THEME
**Descripción:** Aplicar tema transparente (TOTALMENTE OPCIONAL)

**Efecto:** Crea tema Adwaita-Transparent con transparencias sutiles

**Transparencias solo en:**
- Quick Settings (panel superior derecho)
- Calendar (al hacer clic en fecha/hora)
- El resto del sistema permanece igual

**Valores:**
```bash
GNOME_TRANSPARENT_THEME="false"  # Recomendado - Adwaita por defecto
GNOME_TRANSPARENT_THEME="true"   # Aplicar tema transparente
```

**Recomendación:** Dejar en `false`. El tema Adwaita por defecto de GNOME es excelente y bien probado.

**Si lo activas:**
- Requiere extensión User Themes
- Se crea en `/usr/share/themes/Adwaita-Transparent`
- Se aplica automáticamente al usuario

#### GDM_AUTOLOGIN
**Descripción:** Login automático en GDM

**Efecto:** Inicia sesión sin pedir contraseña

**Seguridad:** Solo usar en sistemas personales

**Valores:**
```bash
GDM_AUTOLOGIN="true"   # Autologin activado
GDM_AUTOLOGIN="false"  # Pedir contraseña
```

#### INSTALL_MULTIMEDIA
**Descripción:** Instalar soporte multimedia completo

**Incluye:**
- Códecs (H.264, H.265, AAC, MP3)
- Thumbnailers (video, fuentes, RAW)
- gstreamer plugins

**Valores:**
```bash
INSTALL_MULTIMEDIA="true"
INSTALL_MULTIMEDIA="false"
```

#### INSTALL_DEVELOPMENT
**Descripción:** Instalar herramientas de desarrollo

**Incluye:**
- Git
- build-essential (gcc, g++, make)
- Python 3 + pip
- cmake, autoconf, automake

**Preguntas interactivas:**
- Visual Studio Code
- Node.js (repos Ubuntu o NodeSource)
- Rust (rustup)

**Valores:**
```bash
INSTALL_DEVELOPMENT="true"
INSTALL_DEVELOPMENT="false"
```

#### INSTALL_GAMING
**Descripción:** Configurar sistema para gaming

**Incluye:**
- Steam (flatpak)
- Lutris
- GameMode
- Wine
- Drivers gráficos

**Valores:**
```bash
INSTALL_GAMING="true"
INSTALL_GAMING="false"
```

---

### Optimizaciones

#### MINIMIZE_SYSTEMD
**Descripción:** Deshabilitar servicios systemd innecesarios

**Servicios deshabilitados:**
- ModemManager
- bluetooth (si HAS_BLUETOOTH=false)
- cups (impresión)
- avahi-daemon (mDNS)

**Valores:**
```bash
MINIMIZE_SYSTEMD="true"   # Mínimo de servicios
MINIMIZE_SYSTEMD="false"  # Configuración estándar
```

#### ENABLE_SECURITY
**Descripción:** Activar hardening de seguridad

**Incluye:**
- AppArmor enforced
- ufw (firewall)
- fail2ban
- Reglas restrictivas

**Valores:**
```bash
ENABLE_SECURITY="true"
ENABLE_SECURITY="false"
```

#### USE_NO_INSTALL_RECOMMENDS
**Descripción:** Usar --no-install-recommends en apt

**Efecto:** Solo instala dependencias obligatorias

**Ventaja:** Instalación más ligera

**Desventaja:** Puede faltar funcionalidad opcional

**Valores:**
```bash
USE_NO_INSTALL_RECOMMENDS="true"   # Instalación mínima
USE_NO_INSTALL_RECOMMENDS="false"  # Instalar recomendados
```

---

### Disco

#### TARGET_DISK
**Descripción:** Disco donde instalar

**Formato:** /dev/sdX o /dev/nvmeXnY

**Ejemplos:**
```bash
TARGET_DISK="/dev/sda"
TARGET_DISK="/dev/nvme0n1"
TARGET_DISK="/dev/vda"  # En VM
```

#### DUAL_BOOT
**Descripción:** Instalación dual boot con otro sistema

**Efecto:** No usa todo el disco, crea partición específica

**Valores:**
```bash
DUAL_BOOT="true"   # Preservar otros sistemas
DUAL_BOOT="false"  # Usar todo el disco
```

#### UBUNTU_SIZE_GB
**Descripción:** Tamaño partición Ubuntu en dual boot

**Formato:** Número en GB

**Recomendado:** Mínimo 50GB, 100GB o más ideal

**Ejemplo:**
```bash
UBUNTU_SIZE_GB="100"
```

---

## Ejemplos de Configuración

### Desktop Minimalista

Sistema ligero para uso básico:

```bash
# Sistema
UBUNTU_VERSION="noble"
HOSTNAME="mini-pc"
USERNAME="user"

# Componentes
INSTALL_GNOME="true"
GNOME_OPTIMIZE_MEMORY="true"
GNOME_TRANSPARENT_THEME="false"
GDM_AUTOLOGIN="false"

INSTALL_MULTIMEDIA="false"
INSTALL_DEVELOPMENT="false"
INSTALL_GAMING="false"

# Optimizaciones
MINIMIZE_SYSTEMD="true"
USE_NO_INSTALL_RECOMMENDS="true"
```

**Resultado:** ~1.5GB RAM uso, ~10GB disco

---

### Workstation de Desarrollo

Sistema completo para programación:

```bash
# Sistema
UBUNTU_VERSION="noble"
HOSTNAME="dev-station"
USERNAME="developer"

# Componentes
INSTALL_GNOME="true"
GNOME_OPTIMIZE_MEMORY="false"
GNOME_TRANSPARENT_THEME="false"  # Adwaita por defecto (recomendado)

INSTALL_MULTIMEDIA="true"
INSTALL_DEVELOPMENT="true"
INSTALL_GAMING="false"

# Desarrollo (en módulo)
INSTALL_VSCODE="s"
NODEJS_OPTION="3"  # NodeSource LTS
INSTALL_RUST="s"

# Optimizaciones
MINIMIZE_SYSTEMD="false"
USE_NO_INSTALL_RECOMMENDS="false"
```

---

### Gaming PC

Configuración optimizada para juegos:

```bash
# Sistema
UBUNTU_VERSION="noble"
HOSTNAME="gaming-rig"
USERNAME="gamer"

# Hardware
IS_LAPTOP="false"

# Componentes
INSTALL_GNOME="true"
GNOME_OPTIMIZE_MEMORY="true"
GNOME_TRANSPARENT_THEME="false"  # Tema por defecto

INSTALL_MULTIMEDIA="true"
INSTALL_DEVELOPMENT="false"
INSTALL_GAMING="true"

# Optimizaciones
MINIMIZE_SYSTEMD="true"
USE_NO_INSTALL_RECOMMENDS="false"
```

---

### Laptop Eficiente

Máxima duración de batería:

```bash
# Sistema
UBUNTU_VERSION="noble"
HOSTNAME="laptop"
USERNAME="user"

# Hardware
IS_LAPTOP="true"
HAS_WIFI="true"
HAS_BLUETOOTH="true"

# Componentes
INSTALL_GNOME="true"
GNOME_OPTIMIZE_MEMORY="true"
GNOME_TRANSPARENT_THEME="false"

INSTALL_MULTIMEDIA="true"
INSTALL_DEVELOPMENT="false"
INSTALL_GAMING="false"

# Optimizaciones
MINIMIZE_SYSTEMD="true"
USE_NO_INSTALL_RECOMMENDS="true"
```

**TLP se instala automáticamente (IS_LAPTOP=true)**

---

### Servidor Headless

Sin interfaz gráfica, solo terminal:

```bash
# Sistema
UBUNTU_VERSION="noble"
HOSTNAME="servidor"
USERNAME="admin"

# Hardware
IS_LAPTOP="false"
HAS_WIFI="false"
HAS_BLUETOOTH="false"

# Componentes
INSTALL_GNOME="false"  # Sin GUI
INSTALL_MULTIMEDIA="false"
INSTALL_DEVELOPMENT="true"
INSTALL_GAMING="false"

# Optimizaciones
MINIMIZE_SYSTEMD="true"
ENABLE_SECURITY="true"
USE_NO_INSTALL_RECOMMENDS="true"
```

**Resultado:** ~500MB RAM, ~5GB disco

---

## Configuración Avanzada

### Cambiar Mirror de Ubuntu

Editar en módulo 02:

```bash
# modules/02-debootstrap.sh
MIRROR="http://archive.ubuntu.com/ubuntu"

# Para España:
MIRROR="http://es.archive.ubuntu.com/ubuntu"

# Para Latinoamérica:
MIRROR="http://mx.archive.ubuntu.com/ubuntu"
```

### Particionado Personalizado

Editar módulo 01:

```bash
# modules/01-prepare-disk.sh

# Ejemplo: /boot separado
parted -s "$TARGET_DISK" mklabel gpt
parted -s "$TARGET_DISK" mkpart primary fat32 1MiB 513MiB  # EFI
parted -s "$TARGET_DISK" mkpart primary ext4 513MiB 1537MiB  # /boot
parted -s "$TARGET_DISK" mkpart primary ext4 1537MiB 100%  # /
```

### Paquetes Adicionales

Añadir en módulo apropiado:

```bash
# modules/10-install-gnome-core.sh
apt install -y mi-paquete-extra
```

---

## Validación de Configuración

### Verificar config.env

```bash
# Verificar sintaxis
bash -n config.env

# Ver variables
source config.env
echo $HOSTNAME
echo $INSTALL_GNOME
```

### Dry-run (Simulación)

No disponible actualmente. Recomendación: **usar VM para probar**.

---

## Troubleshooting de Configuración

### Error: Variable no definida

```
Error: USERNAME is not set
```

**Solución:** Definir todas las variables obligatorias en config.env

### Error: Valor inválido

```
Error: Invalid timezone
```

**Solución:** Usar formato correcto (ver ejemplos arriba)

### Contraseña débil

Recomendaciones:
- Mínimo 8 caracteres
- Mezclar mayúsculas, minúsculas, números, símbolos
- No usar palabras del diccionario

---

## Recursos

- **Timezones:** `timedatectl list-timezones`
- **Locales:** Ver [Locales.md](Locales.md)
- **Teclados:** Ver [Keyboard.md](Keyboard.md)
- **Módulos:** Ver [Modules.md](Modules.md)

---

**Siguiente:** [Instalación](01-Installation-Guide.md) | [Troubleshooting](03-Troubleshooting.md)

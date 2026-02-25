# Changelog — ubuntu-advanced-install

## [Sesión 6] — 2026-02-24 — Sistema base actualizado desde el primer arranque

### Añadido

#### `03-configure-base.sh` — `apt-get full-upgrade` tras configurar repositorios

El sistema base instalado por debootstrap puede tener paquetes desactualizados
respecto a los repositorios configurados. Sin un upgrade explícito, el sistema
arrancaba por primera vez con actualizaciones pendientes.

**Posición en el módulo:** después de `apt-get update` y antes de instalar
cualquier paquete adicional. Orden resultante:

```
apt-get update          # sincronizar índices con repositorios
apt-get full-upgrade    # actualizar todos los paquetes base  ← nuevo
apt-get install ...     # instalar teclado, language packs, gettext
```

**`full-upgrade` en lugar de `upgrade`:**
`upgrade` no resuelve cambios de dependencias entre paquetes — si una
actualización requiere instalar un paquete nuevo o eliminar uno obsoleto,
`upgrade` la omite. `full-upgrade` resuelve esos casos correctamente,
equivalente al comportamiento de `apt dist-upgrade`.

**Resultado:** el sistema instalado arranca sin actualizaciones pendientes.
`unattended-upgrades` (módulo 06) gestiona las actualizaciones futuras.

### Pendiente (próximas sesiones)
- B04: Locale y timezone hardcodeados
- B05: Contraseñas en `config.env` (diferido)
- Arquitectura CORE/EXTRA del orquestador `install.sh`

---

# Changelog — ubuntu-advanced-install

## [Sesión 5] — 2026-02-24 — Barra de progreso apt en toda la instalación

### Mejorado

#### Barra de progreso dpkg — activada en live y chroot

**Problema:**
Todos los `apt-get install` del instalador corrían sin indicador visual de progreso.
Durante instalaciones largas (GNOME, multimedia, gaming) el terminal permanecía
sin output durante minutos, dando la impresión de que el proceso había colgado.

**Solución — archivo de configuración `99-installer-progress`:**

```
Dpkg::Progress-Fancy "1";
APT::Color "1";
```

`Dpkg::Progress-Fancy` activa la barra de progreso animada de dpkg que muestra:
porcentaje de paquetes procesados, nombre del paquete en curso, y tiempo estimado.
`APT::Color` activa el color en el output de apt (verde OK, amarillo advertencias).

**Tres puntos de activación:**

1. *`install.sh` — función `setup_apt_progress()`*: crea el archivo en el sistema
   live (`/etc/apt/apt.conf.d/`) para el módulo 00. También lo crea en `$TARGET`
   si el directorio ya existe (cubre el caso de reanudación desde módulo 03+).
   Se llama automáticamente desde `export_config_vars()` antes de correr módulos.

2. *`03-configure-base.sh` — bloque previo al LOCALE_FIRST*: garantía para el chroot.
   debootstrap crea `/etc/apt/apt.conf.d/` pero puede estar vacío.
   Este bloque escribe el archivo antes del primer `apt-get` dentro del chroot,
   asegurando que la barra esté activa desde el primer paquete instalado.

3. *El archivo se mantiene en el sistema instalado*: el usuario verá la barra
   de progreso en sus propias actualizaciones con `apt` tras la instalación.
   Si lo prefiere sin barra puede eliminarlo: `rm /etc/apt/apt.conf.d/99-installer-progress`

### Pendiente (próximas sesiones)
- B04: Locale y timezone hardcodeados en `03-configure-base.sh`
- B05: Contraseñas en `config.env` (diferido — uso en LiveCD)
- Arquitectura CORE/EXTRA del orquestador `install.sh`

---

# Changelog — ubuntu-advanced-install

## [Sesión 4] — 2026-02-24 — Autostart XDG + Pacstall eliminado

### Corregido

#### B09 — `10-user-config.sh` movido de `/etc/profile.d/` a `/etc/xdg/autostart/`

**Problema:**
`/etc/profile.d/` se ejecuta en cualquier contexto de shell: bash interactivo,
scripts del sistema, cron, sudo, SSH. El script de configuración de GNOME
corría en contextos donde D-Bus no estaba disponible, `gsettings` fallaba
silenciosamente, y la guardia `[ "$XDG_CURRENT_DESKTOP" != "GNOME" ]` era
el único freno — frágil y dependiente de que la variable estuviera seteada.

**Solución — dos componentes:**

*Script de configuración* en `/usr/local/lib/ubuntu-advanced-install/gnome-first-login.sh`:
- Contiene toda la lógica de gsettings (extensiones, tema, tipografías, dock, appgrid)
- Doble guardia: marker `~/.config/.gnome-user-configured` + verificación de GNOME
- Se autodestruye eliminando su propio `.desktop` de autostart tras ejecutarse
- Sin rastro en el sistema tras el primer login completado

*Entrada de autostart* en `/etc/xdg/autostart/gnome-first-login.desktop`:
- `OnlyShowIn=GNOME;` — el gestor de sesión ignora este entry fuera de GNOME
- `X-GNOME-Autostart-Delay=3` — espera 3 segundos a que el shell esté listo
- `NoDisplay=true` — no aparece en ningún menú de aplicaciones
- Solo se dispara en sesiones gráficas XDG — nunca en TTY, scripts ni cron

#### B06 — Pacstall eliminado de `16-configure-gaming.sh`

**Problema:**
Pacstall se instalaba ejecutando `bash <(curl -fsSL https://pacstall.dev/q/install)`:
código externo ejecutado directamente sin ninguna verificación de integridad.
Su único uso en el proyecto era instalar ProtonPlus.

**Solución:**
ProtonPlus publica `.deb` directamente en GitHub releases (`Vysp3r/ProtonPlus`).
Pacstall era un intermediario innecesario. Eliminado completamente.
ProtonPlus ahora se instala con el mismo patrón que Heroic, Faugus y Fooyin:
GitHub API → URL del `.deb` → `wget` → `apt-get install` → limpieza de `/tmp`.

### Pendiente (próximas sesiones)
- B04: Locale y timezone hardcodeados en `03-configure-base.sh`
- B05: Contraseñas en `config.env` (diferido — uso en LiveCD sin rastro)
- Arquitectura CORE/EXTRA del orquestador `install.sh`
- Configuración dconf de tamaño exacto de iconos en appgrid

---

# Changelog — ubuntu-advanced-install

## [Sesión 3] — 2026-02-24 — Locale silencioso + console-data + gettext

### Corregido

#### `03-configure-base.sh` — Warnings "Cannot set LC_*" durante la instalación

**Problema:**
El módulo configuraba el locale dentro del mismo bloque chroot donde después
corría `apt-get update` e instalaba paquetes. Los scripts de postinstall de
esos paquetes intentaban usar el locale antes de que `locale-gen` hubiera
terminado, generando mensajes constantes de `Cannot set LC_MESSAGES`,
`Cannot set LC_ALL`, etc. El sistema funcionaba correctamente tras reiniciar
porque entonces el locale ya estaba generado, pero durante la instalación el
log era ruidoso.

**Solución — separación en tres bloques chroot:**

*Bloque 1 — LOCALE_FIRST (nuevo, sin apt previo):*
- Establece `LANG=C.UTF-8` como guardia mínima
- Instala el paquete `locales` (único apt con C.UTF-8, sin warnings)
- Corre `locale-gen es_ES.UTF-8` — a partir de aquí el locale existe
- Configura `/etc/default/locale`, `/etc/environment`, `/etc/locale.conf`
- Activa el locale en el entorno del chroot para bloques posteriores

*Bloque 2 — BASE_CONFIG (timezone, teclado, paquetes):*
- A partir de aquí todo apt corre con `es_ES.UTF-8` activo — cero warnings
- Añadidos `console-data`, `console-setup`, `keyboard-configuration`:
  `console-data` proporciona los mapas de teclado que `setupcon` necesita
  para configurar correctamente el teclado español en TTY
- Añadido `gettext`: herramienta base del sistema de traducción,
  asegura que las aplicaciones puedan usar las traducciones instaladas
- `update-locale` llamado después de instalar language-packs

*Bloque 3 — USEREOF (usuario):*
- Sin cambios funcionales — solo hereda el locale ya configurado

**Resultado:** cero mensajes de locale durante la instalación. El sistema
se comporta igual que antes tras el reinicio, pero la instalación es limpia.

### Pendiente (próximas sesiones)
- B04: Locale y timezone aún hardcodeados — pendiente de decisión de diseño
  sobre si hacerlos interactivos o mantenerlos como uso personal
- B05: Contraseñas en texto plano en `config.env`
- B06: Pacstall instalado con `bash <(curl)` en `16-configure-gaming.sh`
- B09: `10-user-config.sh` en `/etc/profile.d/` — mover a xdg/autostart en fase de diseño

---

# Changelog — ubuntu-advanced-install

## [Sesión 2] — 2026-02-24 — UEFI estable + Appgrid completo + Dock macOS

### Corregido

#### UEFI — `dosfstools` no verificado en dependencias
- **Problema:** `mkfs.fat` (parte de `dosfstools`) se llamaba en `01-prepare-disk.sh`
  sin verificar que el paquete estuviera instalado en el sistema live.
  En LiveCDs que no incluyen `dosfstools` por defecto, la instalación UEFI fallaba
  sin mensaje de error útil.
- **Corrección:** Añadida verificación de `dosfstools` en `00-check-dependencies.sh`.
  Se instala automáticamente si no está presente, junto al resto de dependencias.
- **Archivo:** `modules/00-check-dependencies.sh`

#### UEFI — Sintaxis `mkfs.fat -F32` → `-F 32`
- **Problema:** `mkfs.fat -F32` es rechazado por algunas versiones de `dosfstools`
  que requieren espacio entre el flag y el valor (`-F 32`).
- **Corrección:** `mkfs.fat -F32` → `mkfs.fat -F 32`
- **Archivo:** `modules/01-prepare-disk.sh` línea 127

### Mejorado

#### `10-user-config.sh` — Appgrid completo y Dock estilo macOS/Plank

**App Grid:**
- Orden alfabético: `dconf write /org/gnome/shell/app-picker-layout "[]"`
  (layout vacío = GNOME ordena alfabéticamente)
- Carpetas: Utilidades y Sistema — apps asignadas explícitamente, sin categorías
- Eliminado el método CSS de `~/.local/share/gnome-shell/` (era incompleto
  y no afectaba al comportamiento del grid, solo al fondo visual)

**Dock — comportamiento estilo macOS/Plank:**
- `intellihide: true` con modo `FOCUS_APPLICATION_WINDOWS`: se oculta solo cuando
  la ventana activa lo cubre, no cuando cualquier ventana está cerca
- `click-action: minimize-or-previews`: click en icono de app activa → minimiza
  (comportamiento Plank/macOS) en lugar de no hacer nada
- Animación de aparición/desaparición: `animation-time: 0.2s`, `show-delay: 0s`
  para respuesta inmediata al acercarse
- Transparencia: `FIXED` al `0.35` de opacidad (coherente con el tema)
- `show-windows-preview: true`: muestra miniaturas al hover, como macOS

**Nota técnica — filas del appgrid:**
GNOME no expone un setting directo de "número de filas". Las filas resultantes
dependen de la resolución, el tamaño de iconos y el número de columnas configurado.
Con la configuración actual (layout vacío, sin override de columnas) GNOME calcula
automáticamente 3-4 filas en resoluciones 1080p estándar. Si se necesita forzar
exactamente 3 filas, requiere una extensión (Just Perfection) o un patch de GNOME Shell.
Esta limitación queda documentada para la fase de diseño de extensiones.

### Pendiente (próximas sesiones)
- B04: Locale y timezone hardcodeados en `03-configure-base.sh`
- B05: Contraseñas en texto plano en `config.env`
- B06: Pacstall instalado con `bash <(curl)` en `16-configure-gaming.sh`
- B09: `10-user-config.sh` ejecuta en `/etc/profile.d/` (todos los shells)
  → mover a `/etc/xdg/autostart/` en fase de diseño
- Configuración dconf de tamaño exacto de iconos en appgrid (requiere decisión:
  extensión vs valor por defecto de GNOME)

---

# Changelog — ubuntu-advanced-install

## [Sesión 1] — 2026-02-24 — Estabilización: bugs críticos + tema visual

### Corregido

#### B01 — Heredoc con comillas simples en `10-install-gnome-core.sh`
- **Problema:** `arch-chroot "$TARGET" /bin/bash << 'GNOMECFG'` usaba comillas simples,
  bloqueando la expansión de `$FIX_WORKSPACES` y `$DISABLE_USAGE` desde el host.
  Las preguntas al usuario sobre workspaces y tiempo de pantalla no tenían efecto real.
- **Corrección:** Cambiado a `<< GNOMECFG` (sin comillas) con comentario explicativo
  indicando qué variables se expanden desde el host.
- **Archivo:** `modules/10-install-gnome-core.sh` línea 347

#### B02 — AppManager instalado dos veces en `10-install-gnome-core.sh`
- **Problema:** Dos bloques de instalación de AppManager en el mismo módulo:
  primero con URL hardcodeada en `/opt/appmanager/`, luego via GitHub API en `/opt/AppImages/`.
  Generaba dos entradas `.desktop` potencialmente en conflicto.
- **Corrección:** Eliminado el primer bloque (URL hardcodeada, sin versionado dinámico).
  Mantenido únicamente el segundo bloque (GitHub API, versión siempre actualizada,
  instala en `/opt/AppImages/`, crea symlink en `/usr/local/bin/appmanager`).
- **Archivo:** `modules/10-install-gnome-core.sh` — bloque eliminado: antiguas líneas 163-199

#### B03 — Función `step()` no definida en `20-optimize-performance.sh`
- **Problema:** Dos llamadas a `step()` en el bloque de detección AMD (multi-CCD y single-CCD)
  sin que la función estuviera definida en ningún lugar del módulo.
  El módulo fallaba silenciosamente en hardware AMD con arquitectura multi-CCD.
- **Corrección:** Reemplazadas las llamadas a `step()` por `echo` con el mismo mensaje.
- **Archivo:** `modules/20-optimize-performance.sh` líneas 121 y 131

### Mejorado

#### `10-theme.sh` — Reescritura completa del módulo de tema
- **CSS expandido:** El CSS anterior solo tocaba `.quick-settings` y `.calendar`
  y tenía un bug de sintaxis (bloques sin cierre de llave `}`), lo que hacía
  que el tema no aplicara correctamente.
- **Nuevos elementos con transparencia** (fondo oscuro, texto blanco):
  - `#panel` — Panel superior: `rgba(0,0,0,0.40)`
  - `.quick-settings` — Panel de controles: `rgba(0,0,0,0.55)`
  - `.datemenu-today-button` — Calendario: `rgba(0,0,0,0.50)`
  - `.message-list` — Notificaciones: `rgba(0,0,0,0.50)`
  - `.notification-banner` — Banners: `rgba(0,0,0,0.55)`
  - `.apps-scroll-view` — App Grid: `rgba(0,0,0,0.35)`
  - `.app-folder-popup` — Carpetas: `rgba(0,0,0,0.45)`
- **Criterio de opacidad:** valores calibrados para mantener texto blanco legible
  sobre wallpaper oscuro (requisito confirmado por el promotor).
- **Heredocs documentados:** comentarios inline indicando cuál expande variables
  del host y cuál es literal.
- **Permisos:** corregido `chown` y `chmod` sobre el directorio del tema.
- **Output mejorado:** colores ANSI consistentes con el estilo del proyecto.

### Pendiente (próximas sesiones)
- B04: Locale y timezone hardcodeados en `03-configure-base.sh`
- B05: Contraseñas en texto plano en `config.env`
- B06: Pacstall instalado con `bash <(curl)` en `16-configure-gaming.sh`
- B09: `10-user-config.sh` en `/etc/profile.d/` en lugar de `/etc/xdg/autostart/`
- Configuración dconf completa del appgrid (workspaces ocultos, 3 filas, orden alfabético)
- Comportamiento del dock estilo macOS/Plank

---

# Changelog

Todos los cambios notables en el proyecto Ubuntu Advanced Installer se documentarán en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/es/1.0.0/),
y este proyecto adhiere a [Semantic Versioning](https://semver.org/lang/es/).

---

## [1.0.1] - 2024-02-22

### 🚫 Eliminado
- **Validaciones de hardware que bloqueaban instalación**
  - Eliminada validación de RAM mínima (4GB)
  - Eliminada validación de espacio en disco (50GB)
  - Eliminada validación de espacio libre en partición (20GB)
  - Eliminados warnings de CPU cores insuficientes
  - Eliminado sistema de confirmación por errores de hardware
  - [Ver detalles](docs/old/INDEX.md)

### 🔧 Modificado
- `install.sh` - Detección de hardware solo informativa (no bloquea)
- `modules/01-prepare-disk.sh` - Espacio libre solo informativo (no valida)

### 📝 Documentación
- README actualizado con requisitos como recomendaciones (no validados)
- Creado `docs/old/` para archivos históricos
- Creado `docs/old/INDEX.md` con índice de cambios importantes

### ℹ️ Notas
- El instalador ahora permite instalación en cualquier hardware
- Usuario responsable de verificar requisitos mínimos
- Recomendaciones permanecen en README como guía

---

## [1.0.0] - 2024-02-21

### ✨ Añadido
- **VRR (Variable Refresh Rate) en Gaming**
  - Habilitado automáticamente en GNOME
  - Compatible con FreeSync/G-Sync
  - Funciona con monitores 120Hz+
  
- **HDR (High Dynamic Range) en Gaming**
  - Características experimentales habilitadas
  - Detección automática de GNOME 47+
  - Soporte para monitores HDR10/HDR400+
  - Compatible con NVIDIA RTX, AMD RX 5000+, Intel Arc
  
- **Animaciones opcionales en Gaming**
  - Pregunta al usuario si desactivar animaciones
  - Default: NO (mantiene animaciones)
  - Genera archivo `~/.config/gaming-display-config.txt`
  
- **Workspaces configurables en GNOME**
  - Pregunta al usuario: 1 fijo o dinámicos
  - Default: SÍ (1 workspace fijo)
  - Simplifica interfaz para usuarios nuevos
  
- **Tiempo de pantalla configurable en GNOME**
  - Pregunta al usuario si desactivar tracking
  - Default: SÍ (desactivado)
  - Elimina GNOME Usage
  - Desactiva remember-app-usage y remember-recent-files
  - Genera archivo `~/.config/gnome-custom-config.txt`

### 📁 Documentación
- Creado `docs/ROADMAP.md` - Plan de desarrollo futuro
  - v1.1.0 (Q2 2026): KDE, TUI, Profiles, Auto-update
  - v1.2.0 (Q3 2026): Arch, Backup, Cloud, Hooks
  - v2.0.0 (Q4 2026): Multi-distro, Containers, Web UI
  
### 🔧 Modificado
- `modules/16-configure-gaming.sh` - Añadido VRR/HDR y animaciones opcionales
- `modules/10-install-gnome-core.sh` - Añadido workspaces y tiempo pantalla configurables
- `README.md` - Actualizado con nuevas características

### 🐛 Corregido
- **Versiones de Ubuntu en documentación**
  - Eliminadas versiones inexistentes (24.10, 25.04)
  - Documentadas solo versiones del código: 20.04, 22.04, 24.04, 25.10, 26.04
  
- **Versión de GNOME en documentación**
  - Eliminada versión específica "GNOME 47"
  - Ahora: "GNOME Desktop" (versión depende de Ubuntu instalado)

### 📦 Archivos Antiguos
- `docs/old/README.md.old` - README antes de corrección de versiones
- `docs/old/16-configure-gaming.sh.old` - Gaming module antes de VRR/HDR

---

## [0.9.0] - 2024-02-20

### ✨ Primera Versión Funcional

#### Core System
- ✅ Instalador modular completo (25 módulos)
- ✅ Soporte para 5 versiones de Ubuntu (20.04, 22.04, 24.04, 25.10, 26.04)
- ✅ Detección automática de hardware
- ✅ Configuración interactiva

#### Desktop Environment
- ✅ GNOME Desktop completo
- ✅ GDM3 display manager
- ✅ Extensiones base (AppIndicator, Dash to Dock)
- ✅ Temas profesionales (Yaru, Elementary)
- ✅ Optimizaciones de memoria

#### Gaming
- ✅ Steam + Proton GE
- ✅ GameMode + MangoHud
- ✅ Launchers (Heroic, Faugus, Lutris)
- ✅ Optimizaciones sysctl (vm.max_map_count, fs.file-max)
- ✅ Drivers GPU (NVIDIA, AMD, Intel)

#### Development
- ✅ VS Code + extensiones
- ✅ Git + GitHub CLI
- ✅ NodeJS 24.x LTS (Krypton)
- ✅ Docker + Docker Compose
- ✅ Build tools completos

#### Laptop Support
- ✅ TLP (gestión energía)
- ✅ auto-cpufreq
- ✅ Trackpad gestures (libinput-gestures)
- ✅ Batería optimizada

#### System
- ✅ PipeWire (audio avanzado)
- ✅ Bluetooth
- ✅ Servicios systemd minimizados (opcional)
- ✅ Hardening de seguridad (opcional)

#### Documentation
- ✅ README completo
- ✅ ARCHITECTURE.md
- ✅ MODULE-DEVELOPMENT.md

---

## Tipos de Cambios

- `✨ Añadido` - Nuevas características
- `🔧 Modificado` - Cambios en funcionalidad existente
- `🐛 Corregido` - Corrección de bugs
- `🚫 Eliminado` - Características eliminadas
- `🔒 Seguridad` - Correcciones de seguridad
- `📝 Documentación` - Cambios solo en documentación
- `⚡ Rendimiento` - Mejoras de rendimiento
- `♻️ Refactorización` - Cambios de código sin afectar funcionalidad
- `🧪 Testing` - Añadidos o cambios en tests

---

## Versionado

Este proyecto usa [Semantic Versioning](https://semver.org/lang/es/):

- **MAJOR** (X.0.0): Cambios incompatibles con versiones anteriores
- **MINOR** (0.X.0): Nueva funcionalidad compatible hacia atrás
- **PATCH** (0.0.X): Correcciones de bugs compatibles hacia atrás

Ejemplo:
- `1.0.0` → `1.0.1` = Bug fix (PATCH)
- `1.0.1` → `1.1.0` = Nueva característica (MINOR)
- `1.9.5` → `2.0.0` = Cambio incompatible (MAJOR)

---

## Enlaces

- [Código fuente](https://github.com/usuario/ubuntu-advanced-install)
- [Issues](https://github.com/usuario/ubuntu-advanced-install/issues)
- [Roadmap](ROADMAP.md)
- [Archivos antiguos](old/INDEX.md)

---

**Formato del CHANGELOG**: [Keep a Changelog](https://keepachangelog.com/es/1.0.0/)  
**Versionado**: [Semantic Versioning](https://semver.org/lang/es/)

---

<div align="center">

**Ubuntu Advanced Installer**

Instalación profesional de Ubuntu con optimizaciones y configuración avanzada

[📖 README](../README.md) · [🗺️ Roadmap](ROADMAP.md) · [🏗️ Arquitectura](ARCHITECTURE.md)

</div>

# Changelog — ubuntu-advanced-install

## [5.4.0] — 2026-03-28

### Módulos eliminados
- **06-configure-auto-updates**: eliminado. La configuración de unattended-upgrades causaba problemas en chroot. Las actualizaciones de seguridad de Ubuntu funcionan por defecto sin configuración adicional.
- **07-install-rust**: eliminado como módulo independiente. Rust se instala ahora dentro del módulo 23 (desarrollo) como primera herramienta, solo cuando se elige desarrollo.
- **30-configure-storage**: eliminado. El kernel de Linux ya configura I/O scheduler, fstrim y readahead de forma razonable por defecto.
- **31-configure-audio**: eliminado. PipeWire viene configurado por defecto en Ubuntu 24.04+ sin necesidad de módulo adicional.
- **34-security-hardening**: eliminado. Estaba desactivado por defecto y nunca se ejecutaba.

### Refactorización del sistema de perfiles
- **`_defaults_all_off()`**: documentado y categorizado en dos grupos (variables que activan módulos vs variables que configuran módulos). `KERNEL_PARAMS_LEVEL` añadido (faltaba). Punto único de inicialización.
- **`export_config_vars()`**: defaults sincronizados con `_defaults_all_off()`. Corregidos: `INSTALL_GNOME`, `GNOME_OPTIMIZE_MEMORY`, `GNOME_TRANSPARENT_THEME`, `INSTALL_MULTIMEDIA`, `INSTALL_SPOTIFY` tenían default `true` en export pero `false` en defaults.
- **`_profile_server()`**: simplificado — ya no setea `GNOME_DOCK` (sin GNOME no tiene sentido).
- **Funciones modulares**: `_ask_system_base`, `_ask_gaming_extras`, `_ask_adjustments`, `_ask_extras`, `_show_summary` — cada bloque de preguntas es una función reutilizable.
- **`interactive_config()`**: reducida a 71 líneas (orquestador puro que llama funciones).

### Protección de errores en módulo 10 (GNOME Core)
- `glib-compile-schemas` protegido con fallback + `|| true` (schemas de extensiones pueden tener errores).
- `dconf update` protegido en DCONF_SYSTEM y GRADIA_DCONF con `|| echo`.
- `arch-chroot` de dconf y gradia protegidos contra `set -e` con `|| echo`.
- `python3` regex para filtrar gschema override reemplazado por `awk` (sin dependencia de python3 en HOST).
- `exit 0` antes de CHROOTEOF (heredoc que termina en `fi` devolvía exit 1 si la condición era false).

### Gradia — compilación robusta
- Primero intenta compilar con `blueprint-compiler` del repo de Ubuntu.
- Si `meson setup` falla (versión insuficiente), compila `blueprint-compiler` desde GNOME GitLab y reintenta.
- Añadidos `python3-gobject` y `gobject-introspection` como deps runtime.

### Consistencia YAML
- Secciones y campos de `save_config()` y `config.yaml.example` verificados como idénticos (9 secciones, 43 campos).
- Campo `rust` eliminado de `config.yaml.example` (residuo).
- Variables `AUTO_UPDATE_CHOICE`, `ENABLE_SECURITY`, `PERF_TMPFILES_CLEANUP` eliminadas del flujo completo.
- Cero restos de componentes eliminados en sesiones anteriores.

---

## [5.3.0] — 2026-03-28

### Sistema de perfiles
- Nuevo flujo interactivo basado en perfiles que pre-rellenan la configuración.
- **6 perfiles**: Escritorio, Desarrollo (todo dev ON), Gaming (Steam/Heroic/Faugus/ProtonPlus), Completo (todo ON), Servidor (sin GUI), Personalizado (pregunta a pregunta).
- **Gaming como addon**: los perfiles Escritorio, Desarrollo y Servidor preguntan `¿Añadir gaming?` tras seleccionar el perfil.
- **Ajustes fuera del perfil**: panel (Dock/DtP), autologin, kernel params, auto-updates y nothrottle se preguntan siempre.
- **Extras como checklist**: Spotify, OnlyOffice, qBittorrent, OBS, Obsidian, Gradia y Mullvad se preguntan tras los ajustes.
- **Resumen con nombre del perfil**: muestra perfil seleccionado + componentes + extras + optimizaciones.
- Flujo reducido de ~35 preguntas a ~10 para perfiles predefinidos.

### Componentes eliminados del proyecto
- **TLP**: módulo 32 reescrito solo con power-profiles-daemon (sin pregunta, se instala siempre en laptops).
- **Bun + Deno**: eliminados de módulo 23 y del flujo interactivo.
- **Falcond + OptiScaler**: eliminados de módulo 24. GameMode se instala siempre sin condicional.
- **Webapps (Pake/Tauri)**: eliminados de módulo 25. Carpetas Streaming e IA del app grid eliminadas. Fichero `files/webapps/` borrado.
- **Gestores CLI (kernel-manager + firmware-manager)**: eliminados de módulo 25. Ficheros `files/bin/` borrados.
- **INSTALL_RUST**: variable eliminada del flujo (módulo 07 es CORE, se ejecuta siempre).
- **POWER_MANAGER**: variable eliminada de todo el flujo (map_yaml, export, save_config).

### Steam — 3 métodos de instalación
- **Método 1) GLFS** tarball (estable, necesita i386).
- **Método 2) .deb oficial Valve** (nuevo, recomendado, default) — con preconfiguración QoL completa: registry.vdf, config.vdf, loginusers.vdf, .desktop optimizado, debconf licencia pre-aceptada.
- **Método 3) SteamRT3 Beta** (experimental, containerizado 64-bit).
- Los tres métodos comparten la misma preconfiguración QoL (steamdeps anulado, STEAM_RUNTIME=1, estructura de directorios, .desktop con flags `-silent -nofriendsui -nominidumps -nocrashmonitor`).

### Kernel params — simplificado a 3 niveles
- **1) Estándar**: Clear Linux defaults (base + gaming fusionados, incluye `preempt=full tsc=reliable split_lock_detect=off`).
- **2) Estándar + mitigations=off**: máximo rendimiento.
- **3) Mínimo**: solo `quiet splash`.

### App grid
- Carpetas Streaming e IA eliminadas (webapps ya no existen).
- 7 carpetas: Utilidades, Sistema, Juegos, Multimedia, Desarrollo, Internet, Oficina.
- `org.gnome.Meld.desktop` con M mayúscula (fix .desktop).
- `vim.desktop` oculto con NoDisplay=true.

### QA
- 29 scripts compilan sin errores.
- 0 restos de componentes eliminados.
- 0 variables huérfanas.
- 2 bloques `else` vacíos corregidos (residuos de eliminación de variables).
- Label "TLP" en build_module_list corregido.

---

## [5.2.0] — 2026-03-26

### Rust como módulo CORE independiente
- **Nuevo módulo `07-install-rust.sh`**: Rust (rustup) se instala siempre como módulo CORE, independiente de `INSTALL_DEVELOPMENT`. Antes, si el usuario no elegía desarrollo, Rust no se instalaba y las webapps Pake fallaban.
- Bloque de Rust eliminado de módulo 23. Solo queda un comentario de referencia.

### n8n añadido a desarrollo
- Nueva pregunta `¿n8n (automatización de workflows)?` en ambos modos (servidor y escritorio).
- Instalación via `npm install -g n8n`. Requiere Node.js.
- Campo `n8n` en config.yaml, map_yaml_to_legacy, export_config_vars, save_config.

### AWS CLI — dependencias de runtime
- Añadidos `groff` y `less` como dependencias. AWS CLI los necesita para `aws help` (formatea man pages) y como pager por defecto. Sin ellos: `[Errno 2] No such file or directory`.

### Gradia — reescritura de compilación
- **`set -e`** en el heredoc: cualquier error aborta. Antes los fallos eran silenciosos.
- **Sin redirección de output**: meson y ninja muestran errores en terminal.
- **Eliminado `gcc` y `export CC=gcc`**: Gradia es Python + Blueprint, no C.
- **Eliminado `libsoup-3.0-dev`**: no es dependencia de Gradia.
- **Añadido `appstream`**: necesario para validación de metainfo.
- **`--buildtype=release`** para optimización.
- Verificación post-install: comprueba que `/usr/bin/gradia` existe.

### Carpetas app grid reorganizadas
- **Ghostty** → Sistema (antes Desarrollo)
- **Nautilus** → Sistema (antes no asignado)
- **Google Chrome** → Internet (antes no asignado)
- **Neovim** (`nvim.desktop`) → Desarrollo (antes no asignado)
- **Wireshark** → Internet (antes Sistema)
- Webapps con prefijo `pake-` en vez de `webapp-` (coherente con Pake/Tauri).

### gschema override — fix warnings perpetuos
- **ubuntu-dock**: regex del filtro python3 arreglado. Ahora elimina las 39 líneas completas de la sección `[org.gnome.shell.extensions.ubuntu-dock]` cuando se usa Dash to Panel. Antes solo eliminaba las primeras 8 líneas (header) y el resto generaba warnings en `glib-compile-schemas` cada vez que se instalaba/desinstalaba un paquete.
- **`sort-directories-first`**: se elimina del override dinámicamente en GNOME 48+ (donde la key fue eliminada de Nautilus). Se mantiene en GNOME < 48 (donde sí existe).

### GNOME Keyring / PAM — fix `gkr-pam: couldn't unlock`
- **Ya no se crea fichero `default`** en `~/.local/share/keyrings/`. gnome-keyring-daemon lo crea él mismo. Un fichero `default` huérfano (apuntando a un `login.keyring` inexistente) era la causa del error.
- **PAM `gdm-autologin`**: añadidas líneas explícitas `auth optional pam_gnome_keyring.so` y `session optional pam_gnome_keyring.so auto_start`.
- **Autostart `unlock-keyring.desktop`**: mejorado con `X-GNOME-Autostart-Phase=PreDisplayServer` y `exit 0` para no fallar silenciosamente.

### Migración config.env → config.yaml completa
- `config.env.example` eliminado del proyecto.
- `tools/validate-installer.sh` migrado a verificar `config.yaml`.
- `modules/92-backup-config.sh` hace backup de `config.yaml`.
- Documentación (wiki + docs) actualizada: cero referencias funcionales a `config.env`.

### Variables booleanas unificadas
- Todos los defaults `"n"` en módulos 23, 24, 25 corregidos a `"false"` (8 variables en módulo 23, 1 en módulo 24, 6 en módulo 25).

### Webapps — diagnóstico mejorado
- Echo de diagnóstico al inicio del script para confirmar ejecución y USERNAME.
- Node.js se auto-instala dentro del script si no está disponible.
- Resumen actualizado de "Chrome standalone" a "Pake/Tauri".

### Steam — arranque directo
- **steamdeps anulado** (`ln -sf /usr/bin/true /usr/bin/steamdeps`) en ambos métodos (GLFS y SteamRT3).
- **`STEAM_RUNTIME=1`** en `/etc/environment.d/50-steam.conf`: steam.sh usa runtime bundled sin verificar deps.
- **Bootstrap pre-copiado** (solo GLFS): primer arranque instantáneo sin descargar ~400MB.

---

## [5.1.0] — 2026-03-25

### Arquitectura — comunicación orquestador → módulos
- **`export_config_vars()`**: 61 variables exportadas al entorno para subprocesos. Antes, los módulos no recibían ninguna variable de configuración (bug bloqueante).
- **`validate_config()`**: validación de USERNAME, UBUNTU_VERSION, HOSTNAME, GNOME_DOCK, KERNEL_PARAMS_LEVEL antes de ejecutar módulos.
- **Parser `_yaml_val()` inline en 17 módulos**: cada módulo lee `config.yaml` directamente con su propia función. Sin librerías compartidas. Precedencia: entorno exportado > config.yaml > default hardcoded.
- **Unificación `s/n` → `true/false`**: todas las variables booleanas usan `true`/`false`. Eliminada la convención `s/n` de todo el proyecto (install.sh, módulos, config.yaml).
- **Helper `_yn()`**: convierte respuestas interactivas del usuario ("s"/"n") a `true`/`false`.

### Campos nuevos en config.yaml
- `gaming.steam_method`: 1 (GLFS) o 2 (SteamRT3 64-bit).
- `extras.gradia`: screenshot tool (true/false).
- `extras.sys_managers`: kernel-manager + firmware-manager (true/false).
- `laptop.nothrottle`: fix Intel thermal throttling (true/false).

### Correcciones de bugs
- **BUG-03 Gradia condicional**: keybindings de Gradia y desactivación de atajos nativos de screenshot solo se aplican si `INSTALL_GRADIA=true`. Sin Gradia, los atajos nativos de GNOME quedan intactos.
- **BUG-08 exit_code race condition**: `sync` antes de leer fichero de exit code, validación numérica, y si no se captura → asume fallo (no enmascara errores silenciosamente).
- **BUG-09 error_handler visible**: ahora muestra warning amarillo en terminal además de loguear en fichero.
- **BUG-10 repos APT duplicados**: módulo 03 ya no reescribe `/etc/apt/sources.list.d/ubuntu.sources` (creado por módulo 02).

### Rendimiento
- **`apt-get update` consolidados**: módulo 23 pasa de 3 updates a 1 (repos NodeSource + VSCode + eza se añaden primero, un solo update después).
- **Build deps compartidas ProtonPlus + MangoJuice**: un solo ciclo install → compilar ambos → purge. Antes eran 2 ciclos independientes (~2-3 min ahorrados).
- **`glib-compile-schemas`**: 2 compilaciones globales → 1 en módulo 10.
- **`fc-cache` sin `-f`**: solo actualiza fuentes nuevas (antes reconstruía toda la caché).
- **97 `dconf write` → 1 `dconf load`**: configuración de V-Shell en módulo 11 cargada con un solo fichero INI.
- **Descargas en paralelo**: fuentes Microsoft (~50 archivos) y Nerd Fonts (6 zips) en módulo 21. Heroic + udev rules + Discord en módulo 24.

### Pantalla principal
- `./install.sh` sin argumentos muestra directamente el banner ASCII + 2 opciones (interactiva / automática). Sin logs previos, sin preguntas previas.
- Los flags CLI (`--auto`, `--module`, `--help`, etc.) despachan directo sin pantalla principal.

### `--dry-run`
- Nuevo flag `--dry-run` / `-n`: muestra configuración completa + lista de módulos CORE/EXTRA + variables, sin ejecutar nada. Funciona con config.yaml o interactivamente.

### Cabeceras REQUIERE/PRODUCE
- 25 módulos documentados con `# REQUIERE:` y `# PRODUCE:` en su cabecera.

### Tests post-instalación
- Nuevo `tools/post-install-test.sh`: 61 checks en 8 secciones (sistema, boot, red, gnome, software, optimizaciones, audio). Para ejecutar dentro del sistema instalado.

### Rust como instalación base
- Rust (rustup) se instala siempre como dependencia del sistema, no como opción de desarrollo.
- Necesario para compilar webapps con Pake (Tauri) y como toolchain de desarrollo.
- Pregunta interactiva de Rust eliminada de install.sh.

### Webapps reescritas con Pake (Tauri/Rust)
- **Eliminado**: Chrome `--app=URL` (shortcuts de navegador sin aislamiento).
- **Nuevo**: cada webapp se compila como binario nativo (~5MB) usando WebKitGTK del sistema via Pake (Tauri/Rust). Sin Electron, sin Chromium embebido.
- 11 webapps: Netflix, HBO Max, Prime Video, Disney+, Filmin, DAZN, Movistar+, YouTube, YouTube Music, ChatGPT, Claude.
- Dependencias Tauri: `libwebkit2gtk-4.1-dev`, `libxdo-dev`, `libssl-dev`, `libayatana-appindicator3-dev`, `librsvg2-dev`.
- `pake-cli` instalado via npm. Cada webapp se compila como usuario con acceso a `~/.cargo/bin`.
- Primera compilación ~2-3 min (descarga caché Tauri), siguientes ~30-60s cada una.
- Chrome policy de extensiones de privacidad se mantiene para la navegación en Chrome.

---

## [5.0.0] — 2026-03-22

### Eliminaciones
- **zram y swapfile eliminados** — Sin swap. El sistema usa RAM directamente.
- **No Screenshot Box** — Extensión eliminada (instalación y lista de extensiones activas).
- **Unigine Heaven benchmark** — Eliminado completamente.
- **Falcond GUI compilación separada** — Integrada en el bloque principal de falcond.

### Preguntas duplicadas corregidas (definitivo)
- Módulos 23, 24 y 25 ya no tienen `read -p`. Usan `${VAR:-n}` como default.
- Las preguntas interactivas existen SOLO en install.sh.
- Export reparado: `PERF_OOMD_AGGRESSIVE`, `PERF_TMPFILES_CLEANUP`, `PERF_DNS_OVER_TLS` añadidos.

### GNOME Keyring — reescritura completa (módulo 10)
- Eliminado script Python que generaba `login.keyring` binario (causaba "failed to allocate 41GB").
- PAM: solo `pam-auth-update --enable gnome-keyring` (método oficial Ubuntu).
- Sin autologin: PAM crea el keyring automáticamente al primer login.
- Con autologin: autostart `.desktop` que ejecuta `gnome-keyring-daemon --unlock` con contraseña vacía.

### Gradia movido a extras (módulo 25)
- Ya no se compila en GNOME core (módulo 10).
- Pregunta propia `¿Gradia (screenshot tool)?` con variable `INSTALL_GRADIA`.
- `gcc` añadido a dependencias + `export CC=gcc` para evitar error meson (pgcc/icc/icx).
- Los keybindings (Print Screen → Gradia) se mantienen en dconf (inocuos si no instalado).

### Falcond — reescritura completa (módulo 24)
- Actualizado según wiki Nobara y README upstream.
- Zig 0.15.1+ (última release via GitHub API) + `libc6-dev` como build dep.
- Estructura correcta: `repo/falcond/build.zig` (doble cd).
- Daemon + config + service + perfiles de juegos (PikaOS-Linux/falcond-profiles).
- Grupo `falcond` creado + usuario añadido (requerido para editar perfiles).
- GUI (Rust+GTK4) se intenta desde `git.pika-os.com` — falla silenciosamente si no accesible.
- Zig se limpia después de la compilación.

### PsyCachy kernel — fix descarga (módulo 24)
- Patrón de grep corregido: prefijos exactos en vez de regex (`linux-image-psycachy`, etc.).
- Mensaje de error por cada .deb no encontrado.

### Logging — filtro de falsos positivos mejorado (install.sh)
- D-Bus/NM/chroot/gschema warnings filtrados del conteo y de "Errores relevantes".
- Módulos como 05-configure-network reportan 0 errores en vez de 5.

### Nautilus `sort-directories-first` (gschema.override)
- Reordenada al final con comentario de compatibilidad GNOME 48+.

### Dash to Panel — Activities button (módulo 10)
- Movido a zona derecha (`stackedBR`) justo antes del calendario.

### Blur my Shell — aplicación en user dconf (módulo 11)
- Configuración via `dconf write` en primer login (las extensiones no leen system-db).

### App grid — 9 carpetas con IA separada de Streaming (módulo 11)
- ChatGPT y Claude en carpeta "IA", no en "Streaming".

---

## [4.8.3] — 2026-03-22

### App grid — carpetas completas y coherentes (módulo 11)
- **Utilidades**: añadidos Déjà Dup (backups) y Gradia (screenshot).
- **Sistema**: añadido GNOME Boxes (VMs).
- **Juegos**: añadido Falcond GUI.
- **Multimedia**: añadido OBS Studio.
- **Desarrollo**: añadidos Meld (diff) y Postman (API).
- **Oficina** (NUEVA): OnlyOffice + Obsidian.
- **Streaming** (NUEVA): todas las webapps (Netflix, HBO, Disney+, Prime, Filmin, DAZN, Movistar+, YouTube, YouTube Music, ChatGPT, Claude).
- 8 carpetas totales (antes 6). Todas las apps instaladas tienen carpeta asignada.
- GNOME las ignora si el .desktop no existe — sin errores si una app opcional no se instaló.

---

## [4.8.2] — 2026-03-22

### aMule eliminado del proyecto
- Todas las referencias eliminadas: módulos 11, 25, install.sh, config.yaml.

### qBittorrent movido a extras con pregunta (módulo 25)
- Ya no se instala como parte de GNOME core (módulo 10).
- Pregunta `¿qBittorrent (cliente torrent)? (s/n) [n]` en extras.
- Variable `INSTALL_QBITTORRENT` en install.sh y config.yaml.

---

## [4.8.1] — 2026-03-22

### NVIDIA — método directo ubuntu-drivers autoinstall (módulo 24)
- Reescrito install_nvidia: solo `ubuntu-drivers autoinstall` + fallback `nvidia-driver` metapaquete.
- Eliminado: PPA System76 (innecesario, añadía complejidad y un apt-get update extra).
- Eliminado: nvidia-driver-560/550 hardcodeados (ahora autodetección).
- Eliminado: `libva-x11-2` de todos los bloques GPU (obsoleto en Wayland 100%).
- Wayland: modprobe.d, initramfs early-load, suspend/resume, EGL, environment.d, GDM.
- El driver correcto se selecciona automáticamente según la generación de GPU.

---

## [4.8.0] — 2026-03-22

### Logging estructurado y legibilidad del flujo

#### run_module — cabecera y pie de log por módulo
- Cada módulo ahora escribe cabecera estructurada en su log: nombre, label, paso N/total, timestamp, hostname.
- Pie de log con conteo automático de errores y warnings del log del módulo.
- Errores relevantes extraídos automáticamente (grep de error/fail/unable/cannot) — últimos 10 del módulo.
- Filtro inteligente: excluye falsos positivos (install -f, PIPESTATUS, Install-Recommends, etc.).

#### module-summary.log mejorado
- Formato tabular: timestamp, módulo, estado, duración, count de errores y warnings.
- Permite ver de un vistazo qué módulos tuvieron problemas y cuánto tardó cada uno.

#### Sumario final con diagnóstico
- Tras completar todos los módulos, el sumario muestra:
  - Total de errores y warnings de toda la instalación.
  - Lista de módulos que tuvieron errores (con conteo).
  - Comando para investigar un módulo concreto.

---

## [4.7.1] — 2026-03-22

### Optimización de velocidad de instalación

#### APT Pipeline (módulo 02)
- `Pipeline-Depth 5`: descarga 5 paquetes simultáneos por conexión HTTP.
- `Acquire::Languages "none"`: no descarga traducciones (~30% menos en apt-get update).
- `Acquire::Queue-Mode "host"`: optimiza cola de descargas por servidor.
- `APT::Acquire::Retries 3`: reintenta descargas fallidas automáticamente.

#### Reducción de llamadas redundantes
- 1 `apt-get update` eliminado (sin repo nuevo en else de i386).
- pip+venv+fzf consolidados en 1 sola llamada apt-get (antes 3 separadas).
- Descargas de zoxide y yazi en paralelo (background jobs).

#### Eliminaciones que ahorran I/O
- `/etc/X11/xorg.conf.d` ya no se crea (localectl nativo).
- `gnome-power-manager` no se descarga/instala (deprecated).
- Spotify ya no se parchea con sed post-instalación.

---

## [4.7.0] — 2026-03-22

### Reducción de deuda técnica — preparación Wayland 100% / Ubuntu 26.04

#### /etc/environment → systemd environment.d
- Variables de sesión migradas de `/etc/environment` (legacy) a `/etc/environment.d/*.conf`.
- NVIDIA: `/etc/environment.d/50-nvidia-wayland.conf` (GBM, GLX, VA-API).
- General: `/etc/environment.d/50-wayland-session.conf` (GST_VAAPI, SDL).
- `man environment.d(5)` — método nativo de systemd para variables de sesión.

#### Workarounds X11 eliminados
- `--ozone-platform=x11` de Spotify eliminado (Wayland nativo por defecto).
- `/etc/X11/xorg.conf.d/00-keyboard.conf` eliminado — reemplazado por `localectl set-x11-keymap` (systemd/Wayland nativo).
- `QT_QPA_PLATFORM=wayland;xcb` eliminado — Qt6 detecta Wayland automáticamente desde Qt 6.5.

#### Variables de entorno obsoletas eliminadas
- `GSK_RENDERER=ngl` — resuelto en GTK 4.16+ (GNOME 47+).
- `MOZ_ENABLE_WAYLAND=1` — default en Firefox 121+ (Ubuntu 24.04+).
- `ELECTRON_OZONE_PLATFORM_HINT=auto` — default en Electron 28+.

#### Paquetes deprecated eliminados
- `gnome-power-manager` eliminado — GNOME Settings muestra detalles de batería nativamente via upower.

#### config.yaml — formato de configuración moderno
- Nuevo `config.yaml.example` con estructura declarativa YAML por secciones.
- Parser YAML minimalista integrado en install.sh (sin dependencias externas).
- config.yaml tiene prioridad sobre config.env (legacy sigue soportado).
- Mapeo automático YAML → variables legacy que los módulos esperan.
- Variables obsoletas eliminadas de config.env.example: `HAS_WIFI`, `HAS_BLUETOOTH`, `INSTALL_STORAGE_OPT`, `STORAGE_DISK_TYPE`.

### Scheduler BORE/EEVDF (módulo 24)
- Pregunta de scheduler restaurada: BORE (gaming) o EEVDF (allround).
- Aplicado via `sysctl kernel.sched_bore` en `/etc/sysctl.d/90-scheduler.conf`.
- Sin recompilación — PsyCachy viene con CONFIG_SCHED_BORE=y, se desactiva en runtime.

---

## [4.6.0] — 2026-03-22

### Kernel CachyOS → PsyCachy (módulo 24)
- Reemplazada compilación desde fuente por `.deb` precompilados de `psygreg/linux-psycachy`.
- Descarga automática de GitHub releases: linux-image, linux-headers, linux-libc-dev.
- BORE scheduler incluido por defecto. Sin pregunta de scheduler (PsyCachy viene preconfigurado).
- Eliminadas 178 líneas de compilación huérfana y todas las referencias a `CACHYOS_SCHEDULER`.

### Gradia — fix compilación (módulo 10)
- `gir1.2-xdpgtk4-1.0` se instala por separado con fallback (no existe en Ubuntu 24.04 base).
- `meson setup` y `ninja` ya no usan pipe que tragaba el exit code.
- Añadidos post-instalación: `glib-compile-schemas`, `update-desktop-database`, `gtk-update-icon-cache`.
- Logs de error en `/tmp/gradia-meson.log` y `/tmp/gradia-ninja.log`.
- Añadida dependencia `desktop-file-utils`.

### Blur-my-shell — fix transparencia invertida (módulo 10)
- Los valores de `overview` y `appfolder` estaban intercambiados.
- Overview ahora tiene `customize=true`, `sigma=0`, `brightness=1.0`, `blur=false`, `style-dialogs=1`.
- Appfolder ahora tiene solo `blur=false`.

### Dash to Panel — workspace indicator estilo Zorin OS (módulo 10)
- Configuración dconf de `org/gnome/shell/extensions/dash-to-panel` añadida.
- Activities button visible a la izquierda (abre overview/workspace view).
- Panel inferior, 48px, 100% ancho, elementos ordenados como en captura Zorin OS.
- Transparencia 35%, previews de ventanas, click-action cycle-minimize.
- `panel-element-positions-monitors-sync=true` para multi-monitor.

---

## [4.5.0] — 2026-03-21

### Nautilus — preferencias sensatas (gschema override)
- Carpetas antes que archivos (`sort-directories-first=true`) en Nautilus y diálogos GTK3/GTK4.
- Vista de lista por defecto con columnas: nombre, tamaño, tipo, fecha.
- Ruta editable siempre visible (`always-use-location-entry=true`).
- Zoom compacto (small) para ver más archivos.
- Crear enlace simbólico disponible en menú contextual.

### Archivos comprimidos — abrir por defecto (no extraer)
- MIME types de .zip, .tar.gz, .tar.xz, .tar.zst, .7z, .rar, .iso, .deb, .rpm configurados para abrir con File Roller.
- Doble clic en archivo comprimido → explorar contenido (no extraer automáticamente).
- Configurado en `/etc/skel/`, `/usr/share/applications/`, y usuario principal.

### GNOME Sushi — previsualización rápida (módulo 10)
- `gnome-sushi` instalado: pulsar Espacio en Nautilus → preview instantáneo.
- Soporta imágenes, PDFs, vídeos, audio, texto con syntax highlighting, SVG.

### Thumbnails de vídeo (módulo 10)
- `ffmpegthumbnailer` instalado: Nautilus genera previews de .mp4, .mkv, .avi automáticamente.

### GNOME Boxes (módulo 23)
- Opción `¿GNOME Boxes (máquinas virtuales)?` en desarrollo (escritorio).

### CLI modernas — siempre con desarrollo (módulo 23)
- **eza**: ls moderno con colores, iconos, Git (repo APT oficial deb.gierens.de).
- **fzf**: fuzzy finder.
- **zoxide**: cd inteligente que aprende directorios frecuentes (.deb GitHub).
- **yazi**: file manager terminal Rust con async I/O y previews (binario GitHub).
- Aliases en skel: `ls→eza`, `ll→eza -l --icons`, `la→eza -la`, `tree→eza --tree`.
- `eval "$(zoxide init bash)"` en skel .bashrc.

### pip + venv — siempre con desarrollo (módulo 23)
- `python3-pip` + `python3-venv` instalados siempre.

### Runtimes JS opcionales (módulo 23)
- **Bun**: runtime JS/TS ultrarrápido (binario GitHub releases).
- **Deno**: runtime JS/TS seguro con TypeScript nativo (binario GitHub releases).

### Docker tools opcionales (módulo 23)
- **unregistry**: registry ligero que sirve imágenes desde el Docker daemon local.
- **docker-pussh**: push de imágenes Docker a servidores remotos via SSH sin registry.
- **uncloud**: deploy de contenedores multi-host con WireGuard mesh + Caddy HTTPS.

### Meld — diff/merge visual (módulo 23, solo escritorio)
- Instalado via `apt-get`. Configurado como `diff.tool` y `merge.tool` de Git.

### Postman — API testing (módulo 23, solo escritorio)
- Instalado desde tarball oficial pstmn.io con desktop entry.

### PRIME hybrid GPU — reescritura completa (módulo 24)
- `switcheroo-control` por defecto en todos los escenarios dual GPU.
- `NVreg_DynamicPowerManagement=0x02` (Fine-Grained): GPU dedicada se apaga sola.
- `PrefersNonDefaultGPU=true` en .desktop de Steam, Heroic, Faugus.
- GNOME ofrece "Ejecutar con tarjeta gráfica dedicada" en clic derecho.

---

## [4.4.0] — 2026-03-21

### NVIDIA Wayland — configuración profesional completa (módulo 24)
- 8 ajustes integrados para la mejor experiencia Wayland con NVIDIA:
  - DRM KMS: `modeset=1`, `fbdev=1` via `/etc/modprobe.d/nvidia.conf`
  - `NVreg_PreserveVideoMemoryAllocations=1`: preserva VRAM en suspend
  - `NVreg_UsePageAttributeTable=1`: mejor rendimiento de memoria
  - Early-load en initramfs: nvidia, nvidia_modeset, nvidia_uvm, nvidia_drm
  - Suspend/resume/hibernate services habilitados
  - EGL Wayland libs: `libnvidia-egl-wayland1`, `libnvidia-egl-gbm1`
  - Variables de entorno: `GBM_BACKEND=nvidia-drm`, `__GLX_VENDOR_LIBRARY_NAME=nvidia`, `LIBVA_DRIVER_NAME=nvidia`, `GSK_RENDERER=ngl`, `MOZ_ENABLE_WAYLAND=1`, `ELECTRON_OZONE_PLATFORM_HINT=auto`
  - GDM: anulación de `61-gdm.rules` + `WaylandEnable=true` forzado

### Gradia — screenshot tool nativo (módulo 10)
- Compilado desde fuente (meson + ninja) desde `github.com/AlexanderVanhee/Gradia`.
- GTK4/libadwaita, usa `org.freedesktop.portal.Screenshot` directamente (sin gnome-screenshot).
- Keybindings estilo Windows 10 Recortes:
  - `Print Screen` → Gradia
  - `Super+Shift+S` → Gradia (equivalente Win+Shift+S)
  - `Alt+Print Screen` → Gradia
- Todos los atajos nativos de GNOME Shell para screenshots desactivados.

### Déjà Dup — backups integrados (módulo 10)
- Instalado siempre con escritorio GNOME.
- Integración nativa en GNOME Settings como "Copias de seguridad".
- Soporta local, remoto, Google Drive. Encriptación GPG. Incrementales automáticos.

### Monitor de batería para portátiles (módulo 10)
- `gnome-power-manager` instalado solo si `IS_LAPTOP=true`.
- Detalles avanzados: ciclos, salud, tasa de descarga, historial.

### Modo servidor / headless (install.sh)
- `¿Escritorio GNOME? (s/n)` — si dice no, desactiva automáticamente todo lo GUI.
- Multimedia, gaming, webapps, Spotify, OBS, Obsidian, dock, autologin, tema: desactivados.
- Solo pregunta: desarrollo (sin VSCode), Node, Rust, topgrade, Mullvad, gestores CLI.

### Preguntas eliminadas (install.sh)
- `¿WiFi?` y `¿Bluetooth?` eliminadas — autodetección en módulo 22.
- WiFi/BT se configura automáticamente si se detecta hardware.

### Wireless simplificado (módulo 22)
- Eliminados: `wireless-tools` (obsoleto), `wpasupplicant` (dep de NM), `crda` (deprecado kernel 4.15+), `bluez-tools` (innecesario en GNOME).
- WiFi: solo `iw` + `rfkill` + `wireless-regdb`.
- Bluetooth: no instala nada (bluez ya viene con gnome-shell), solo habilita servicio + `AutoEnable=true`.

### blur-my-shell (módulo 10)
- `sigma=0`, `brightness=1.0` en todas las secciones (transparencia pura sin blur).
- App folders: `blur=false`, `sigma=0`.

### CSS overview limpio (módulo 13)
- Workspace thumbnails ocultos (`.workspace-thumbnails` → `opacity:0`, `width:0`).
- Indicadores de página ocultos.
- Overview muestra solo ventanas abiertas sobre wallpaper limpio.

### GNOME Keyring fix (módulo 10)
- `login.keyring` vacío creado siempre (no solo en autologin).
- Resuelve: `gkr-pam: couldn't unlock`, `failed to allocate 105GB`, `gnome-keyring-daemon.service failed`.

### Audio (módulo 31)
- `alsa-utils` eliminado — PipeWire no lo necesita y tiene udev rule rota en Ubuntu 25.04.

### OBS Studio y Obsidian (módulo 25)
- OBS: PPA `obsproject/obs-studio` con fallback a repo Ubuntu.
- Obsidian: `.deb` desde GitHub releases API.

---

## [4.3.0] — 2026-03-21

### Calidad profesional — ajustes inspirados en archinstall/CachyOS

#### bash-completion (módulo 03)
- Instalado `bash-completion` en sistema base.
- `.bashrc` en `/etc/skel/` con `complete -cf sudo` y aliases útiles (`ll`, `la`, `grep --color`, `df -h`, `free -h`, `ip -color`).
- Todos los usuarios nuevos heredan la configuración.

#### WiFi Regulatory Domain (módulo 22)
- Instalado `wireless-regdb` + `crda`.
- Código de país derivado automáticamente del locale (`es_ES.UTF-8` → `ES`).
- Configurado en `/etc/default/crda` y aplicado con `iw reg set`.
- Desbloquea canales 5GHz/6GHz legales del país.

#### NVIDIA Power Management (módulo 24)
- Habilitados `nvidia-suspend.service`, `nvidia-resume.service`, `nvidia-hibernate.service`.
- `/etc/modprobe.d/nvidia-power.conf`: `modeset=1`, `fbdev=1`, `NVreg_PreserveVideoMemoryAllocations=1`.
- Módulos NVIDIA añadidos a initramfs para early-load (`nvidia`, `nvidia_modeset`, `nvidia_uvm`, `nvidia_drm`).
- `update-initramfs -u` ejecutado automáticamente.

#### Realtime privileges para audio gaming (módulo 24)
- Grupo `realtime` creado, usuario añadido.
- `/etc/security/limits.d/99-realtime-audio.conf`: `rtprio 98`, `memlock unlimited`, `nice -20`.
- Reduce latencia de audio bajo carga (gaming, producción).

#### UFW Firewall (módulo 34)
- Instalado y habilitado `ufw` con política `deny incoming` / `allow outgoing`.
- Protección básica en WiFi pública.

#### Secure Boot UEFI (módulo 34)
- Detecta sistema UEFI automáticamente.
- Instala `shim-signed` + `grub-efi-amd64-signed` (kernels Ubuntu firmados por Canonical).
- Kernels custom (CachyOS) requieren MOK enrollment manual (documentado).

#### OBS Studio (módulo 25)
- PPA `obsproject/obs-studio` con fallback a repo Ubuntu.

#### Obsidian (módulo 25)
- `.deb` desde GitHub releases API (`obsidianmd/obsidian-releases`).
- Instalado con `dpkg -i` + resolución de dependencias.

### QA fixes incluidos
- `apt` → `apt-get` en módulos 00, 22, 34 (5 usos corregidos).
- Tools con sintaxis rota eliminados (`TEST-gnome.sh`, `TEST-template.sh`).
- Módulo `90-verify-system` añadido a ambos flujos de instalación.
- Módulo 30 (almacenamiento) simplificado: solo ajustes seguros (scheduler I/O, readahead, fstrim), sin modificar fstab ni sysctl.

---

## [4.2.0] — 2026-03-21

### Kernel CachyOS — reescritura completa
- Eliminado uso del repo `linux-cachyos` (PKGBUILD de Arch) que fallaba al parsear variables `${_major}.${_minor}`.
- Ahora descarga el kernel mainline estable directamente de kernel.org (API JSON con fallback HTML).
- Parches CachyOS clonados desde `github.com/CachyOS/kernel-patches` — aplica parches base, scheduler (BORE) y comunes según la versión del kernel.
- Configuración del scheduler 100% via `sed` sobre `.config` (sin `scripts/config`).
- 4 opciones de scheduler documentadas:
  - **1) BORE** — Burst-Oriented Response Enhancer sobre EEVDF. Prioriza ráfagas cortas de CPU. Ideal gaming.
  - **2) BORE + sched-ext** — BORE + framework BPF para schedulers en userspace (scx_bpfland, scx_rusty). Cambio en caliente.
  - **3) EEVDF** — Earliest Eligible Virtual Deadline First (stock CachyOS). Equilibrio fairness/rendimiento.
  - **4) CFS compat** — Sin BORE ni sched-ext, PREEMPT_VOLUNTARY. Máxima estabilidad y compatibilidad.

### Steam — reorganización i386
- `STEAM_METHOD=2` (SteamRT3 64-bit) ahora muestra aviso EXPERIMENTAL antes de continuar.
- Pregunta interactiva de i386 se hace FUERA del heredoc chroot (antes era inviable por stdin).
- Variable `USE_I386` condiciona todos los paquetes `:i386` del módulo: Mesa base, drivers AMD, dependencias Steam.
- GLFS (método 1) sigue siendo 100% i386 como siempre.
- SteamRT3 (método 2) permite un sistema 100% 64-bit si el usuario rechaza i386.

### Ghostty
- Eliminados PPA y .deb como métodos de instalación.
- Único método: script de mkasberg (`curl -fsSL https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh | bash`), que compila desde fuente y genera el .deb automáticamente.

### Zig (para Falcond)
- Instalación via método lindevs.com: última release estable de GitHub API (`api.github.com/repos/ziglang/zig/releases/latest`).
- Fallback a versiones fijas (0.14.1, 0.14.0, 0.13.0) con ambos formatos de nombre de archivo.

### Mullvad VPN
- Cambiado de `deb ... stable $CODENAME main` a `deb ... stable stable main` como indica la documentación oficial.

### Fixes de prueba de instalación (Ubuntu 25.04 Questing)
- **FFmpeg**: eliminados nombres de paquetes con versión hardcodeada (`libavcodec60`, `libavformat60`, etc.). Reemplazados por `ffmpeg libavcodec-extra`.
- **gschema**: eliminada key inexistente `latency-compensation-enabled` de `org.gnome.mutter` (no existe en GNOME 48+).
- **Ghostty PPA**: silenciado stdout+stderr de `add-apt-repository` para evitar error ruidoso.
- **Módulo 25 (extras)**: añadido `apt-get install -y wget` en chroot antes de ejecutar script de webapps (fix code 127).

---

## [4.1.0] — 2026-03-20

### Kernel CachyOS (primera implementación)
- Módulo 24: compilación desde fuente con `make deb-pkg`.
- Pregunta BORE o EEVDF en install.sh.
- CONFIG_CACHY, HZ=1000, preempt=full, BBR3, THP=always, sched-ext.

### Falcond + GUI
- Zig 0.14.0 binario estático desde ziglang.org.
- Compilación de falcond desde `github.com/PikaOS-Linux/falcond`.
- Perfiles de `falcond-profiles`. Grupo falcond.
- GUI desde `git.pika-os.com` (Rust+GTK4).
- Si falcond activo → GameMode (Feral) NO se instala (conflicto documentado).

### OptiScaler
- Módulo 24: clona `0ptiscaler4linux` en `/opt/optiscaler`, wrapper en `/usr/local/bin/optiscaler`.

### Parámetros del kernel (4 niveles)
- Variable `KERNEL_PARAMS_LEVEL` con 4 niveles documentados:
  - 1) base: quiet splash intel_pstate page_alloc nowatchdog
  - 2) gaming: base + preempt=full tsc=reliable split_lock_detect=off
  - 3) inseguro: gaming + mitigations=off
  - 4) mínimo: quiet splash
- Bloque GRUB gaming anterior eliminado (integrado en niveles).

### Gestores CLI opcionales
- `kernel-manager`: list, available, install, remove, set-default, cleanup, cachyos, params (muestra/modifica parámetros GRUB).
- `firmware-manager`: wrapper fwupd (status, check, update, history, security, downgrade).
- Variable `INSTALL_SYS_MANAGERS`. fwupd instalado como dependencia.

### Webapps streaming
- 7 servicios streaming: Netflix, HBO Max, Prime Video, Disney+, Filmin, DAZN, Movistar+.
- YouTube + YouTube Music con perfil Chrome dedicado y extensiones forzadas (uBlock Origin Lite, SponsorBlock, Return YouTube Dislike, DeArrow).
- ChatGPT + Claude como webapps con drag & drop nativo.
- Variable `INSTALL_STREAMING_WEBAPPS`.

### Steam SteamRT3 Beta
- Opción 2 en gaming: `.deb` oficial Valve desde CDN Akamai.
- Variable `STEAM_METHOD` (1=GLFS, 2=SteamRT3).

### Fix GSK NVIDIA
- `GSK_RENDERER=ngl` en `/etc/environment` solo cuando se instalan drivers NVIDIA.

### Estética blur-my-shell
- sigma=4, brightness=0.85, noise=0. Overview: blur=false (transparencia pura). App folders: sigma=8.

### Mejoras de calidad
- 26 silencios `2>/dev/null` dañinos eliminados de apt-get install/update/dpkg.
- 21 usos de `apt` cambiados a `apt-get` (5 módulos).
- 7 usos de `chmod +x` cambiados a `chmod 755`.
- Resumen final reescrito con secciones: módulos ok/fallidos/omitidos, sistema, GNOME, software, extras, warnings, tiempo.

### README.md
- Documentación completa: qué hace, uso, requisitos, estructura, tablas de opciones, arquitectura GNOME, reconocimientos a 40+ proyectos.

---

## [4.0-BETA2] — 2026-03-17

### Base limpia
- Revertido a BETA2 como base tras bugs #1-#24.
- Estructura modular renumerada.
- Guards, cabeceras, contraseñas, PAM, barra de progreso.
- Módulos gaming/extras/desarrollo completos.

### GNOME (3 capas sin conflictos)
- gschema.override: temas, fuentes, dock, workspaces, privacidad, power, favorites.
- dconf 00-*: welcome-dialog, experimental-features, blur-my-shell, app-picker-layout, workspaces (para locks).
- dconf 01-*: enabled-extensions (dock+DING condicionales).
- dconf locks: workspaces (3 keys).
- Script primer login: wallpaper, user-theme, carpetas app grid, apps ocultas.

### Extensiones GNOME
- Alphabetical App Grid, Caffeine, No Overview, No Screenshot Box.
- Preactivación via dconf.
- No-overview: descarga desde API extensions.gnome.org (zip oficial para versión exacta de GNOME).

---

## [Sesiones 1-15b] — 2026-02 a 2026-03

Historial detallado de correcciones CSS de tema Adwaita-Transparent, fixes de workspaces, NoDisplay, ProtonUp-Qt, Heroic config, extension-manager, contraseñas seguras, y limpieza de módulos archivados.

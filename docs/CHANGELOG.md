# Changelog — ubuntu-advanced-install

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

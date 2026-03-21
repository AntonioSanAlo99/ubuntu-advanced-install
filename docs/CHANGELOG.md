# Changelog — ubuntu-advanced-install

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

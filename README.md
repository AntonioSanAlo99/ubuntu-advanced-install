# ubuntu-advanced-install

Instalador modular de Ubuntu con debootstrap. Construye un sistema Ubuntu desde cero con GNOME, gaming, multimedia, desarrollo y webapps preconfiguradas, en una sola ejecución.

## Qué hace

Partiendo de un USB live o un entorno mínimo, este instalador:

1. Particiona el disco (GPT + EFI + ext4, con soporte dual boot)
2. Instala Ubuntu base via debootstrap (sin snap, sin paquetes innecesarios)
3. Configura GNOME con dock, extensiones, tema oscuro, transparencia y wallpaper
4. Instala software multimedia, desarrollo, gaming y extras según elección del usuario
5. Aplica optimizaciones de rendimiento configurables (zram, oomd, DNS-over-TLS, tmpfiles.d)
6. Genera webapps de streaming y de IA como aplicaciones standalone
7. Verifica la instalación y genera un informe

Todo es interactivo con preguntas claras, o automático via `config.yaml` / `config.env`.

## Uso

```bash
# Interactivo (recomendado)
sudo ./install.sh

# Automático (requiere config.yaml o config.env)
sudo ./install.sh --auto

# Ver opciones
sudo ./install.sh --help
```

## Requisitos

- USB live de Ubuntu 24.04+ o entorno con acceso root
- Conexión a internet
- Disco objetivo (se formatea completamente o se reutiliza partición EFI en dual boot)
- Mínimo 20 GB de espacio en disco

## Estructura

```
install.sh                    Orquestador principal
config.yaml.example           Configuración YAML declarativa (prioridad)
config.env.example             Configuración legacy bash (fallback)
docs/
  CHANGELOG.md                Historial de cambios
  ROADMAP.md                  Features futuras planificadas
modules/
  00-check-dependencies.sh    Verificar herramientas necesarias
  01-prepare-disk.sh          Particionar y formatear
  02-debootstrap.sh           Instalar sistema base (APT pipeline optimizado)
  03-configure-base.sh        Locales, timezone, usuarios, fstab
  04-install-bootloader.sh    GRUB + parámetros del kernel
  05-configure-network.sh     NetworkManager + systemd-resolved (DNS-over-TLS opcional)
  06-configure-auto-updates.sh  Actualizaciones automáticas
  10-install-gnome-core.sh    GNOME Shell + extensiones + dconf + systemd-oomd
  11-configure-gnome-user.sh  Primer login, wallpaper, carpetas app grid (9 carpetas)
  12-optimize-gnome.sh        Optimización de memoria GNOME
  13-configure-gnome-theme.sh Tema transparente CSS
  20-install-multimedia.sh    VLC, Fooyin, Spotify, codecs
  21-install-fonts.sh         Nerd Fonts, Microsoft, Google
  22-configure-wireless.sh    WiFi + Bluetooth
  23-install-development.sh   Dev tools + herramientas de red/cloud opcionales
  24-configure-gaming.sh      Steam, Heroic, drivers GPU, MangoHud, kernel PsyCachy
  25-install-extras.sh        OnlyOffice, qBittorrent, webapps, gestores CLI
  30-configure-storage.sh     zram/swapfile + tmpfiles.d + I/O schedulers + fstrim
  31-configure-audio.sh       PipeWire optimizado
  32-optimize-laptop.sh       TLP / power-profiles-daemon
  33-minimize-systemd.sh      Deshabilitar servicios innecesarios
  34-security-hardening.sh    UFW + sysctl + Secure Boot + kernel lockdown
  90-verify-system.sh         Verificación post-instalación
  91-generate-report.sh       Informe del sistema
  92-backup-config.sh         Backup de configuración
files/
  99-ubuntu-advanced-install.gschema.override   Configuración GNOME
  bin/kernel-manager          Gestor CLI de kernels y parámetros GRUB
  bin/firmware-manager        Gestor CLI de firmware (fwupd)
  webapps/                    Generador de webapps Chrome standalone
```

## Opciones de instalación

### Software

| Categoría | Incluye |
|-----------|---------|
| **Multimedia** | VLC, Fooyin, Spotify, codecs completos, PipeWire |
| **Desarrollo** | Git, Ghostty, NodeJS, VSCode, Rust, Topgrade, pip+venv, eza, fzf, zoxide, yazi |
| **Desarrollo (opcional)** | Lazy TUI (lazygit+lazydocker+LazyVim), Bun, Deno, Docker tools, Meld, Postman, GNOME Boxes |
| **Red y cloud (opcional)** | Wireshark, nmap, AWS CLI v2, httpie, jq |
| **Gaming** | Steam (GLFS), Heroic, Faugus, MangoHud, MangoJuice, drivers GPU (ubuntu-drivers autoinstall) |
| **Extras (opcional)** | OnlyOffice, qBittorrent, Mullvad VPN, OBS Studio, Obsidian |

### Gaming avanzado (opcional)

| Opción | Descripción |
|--------|-------------|
| **Kernel PsyCachy** | .deb precompilados con scheduler BORE o EEVDF |
| **Falcond** | Daemon de auto-optimización gaming (PikaOS) + GUI |
| **OptiScaler** | FSR4/DLSS/XeSS para todos los juegos |
| **ProtonPlus** | Gestor de versiones Proton/Wine-GE |
| **PRIME hybrid** | switcheroo-control para GPU dual (NVIDIA+iGPU) |

### Optimizaciones de rendimiento (todas opcionales)

Cada optimización puede activarse por separado para medir su impacto individual. Diseñado para testeo A/B: instalar con una feature, medir, comparar.

| Variable | Default | Descripción |
|----------|---------|-------------|
| `PERF_ZRAM` | `true` | Swap en RAM comprimida (zstd ~3:1) vs swapfile tradicional |
| `PERF_ZRAM_SWAPPINESS` | `180` | Swappiness para zram (180) o disco (10). Configurable |
| `PERF_OOMD_AGGRESSIVE` | `true` | systemd-oomd agresivo (CachyOS) vs defaults systemd |
| `PERF_TMPFILES_CLEANUP` | `true` | Limpieza automática /tmp, cachés, journal vs desactivada |
| `PERF_DNS_OVER_TLS` | `true` | DNS cifrado (Cloudflare+Quad9) vs DNS del DHCP/router |
| `ENABLE_SECURITY` | `false` | Kernel lockdown=integrity (puede romper NVIDIA DKMS) |

En `config.yaml`:

```yaml
performance:
  zram: true
  zram_swappiness: 180
  oomd_aggressive: true
  tmpfiles_cleanup: true
  dns_over_tls: true
```

### Parámetros del kernel

| Nivel | Parámetros |
|-------|------------|
| **1 — Base** | `quiet splash intel_pstate=active no_timer_check page_alloc.shuffle=1 rcupdate.rcu_expedited=1 nowatchdog nmi_watchdog=0` |
| **2 — Gaming** | Base + `preempt=full tsc=reliable split_lock_detect=off` |
| **3 — Inseguro** | Gaming + `mitigations=off` (desactiva Spectre/Meltdown) |
| **4 — Mínimo** | Solo `quiet splash` |

### Webapps (Chrome standalone)

Ventanas aisladas con soporte DRM (Widevine), drag & drop y SSO:

- **Streaming:** Netflix, HBO Max, Prime Video, Disney+, Filmin, DAZN, Movistar+
- **YouTube:** YouTube + YouTube Music con perfil dedicado y extensiones de privacidad (uBlock Origin Lite, SponsorBlock, Return YouTube Dislike, DeArrow)
- **IA:** ChatGPT, Claude

### Herramientas CLI (opcionales)

- **`kernel-manager`** — Listar, instalar, eliminar kernels. Compilar PsyCachy. Gestionar parámetros GRUB (restaurar base, aplicar gaming, añadir/quitar custom).
- **`firmware-manager`** — Comprobar y aplicar actualizaciones de firmware via fwupd/LVFS.

## Configuración GNOME

Tres capas sin conflictos:

| Capa | Archivo | Qué configura |
|------|---------|---------------|
| gschema.override | `99-ubuntu-advanced-install` | Temas, fuentes, dock, workspaces, privacidad, Nautilus |
| dconf system-db | `00-ubuntu-advanced-install` | welcome-dialog, experimental-features, blur-my-shell, Gradia keybindings, Dash to Panel |
| Script primer login | `gnome-first-login.sh` | Wallpaper, user-theme, 9 carpetas app grid (requiere D-Bus) |

Carpetas del app grid: Utilidades, Sistema, Juegos, Multimedia, Desarrollo, Internet, Oficina, Streaming, IA.

Extensiones preinstaladas: Blur my Shell, Alphabetical App Grid, Caffeine, No Overview, No Screenshot Box, Dash to Panel.

Nautilus configurado con carpetas primero, vista de lista, ruta editable, archivos comprimidos se abren (no extraen), GNOME Sushi (Espacio = preview), thumbnails de vídeo.

Gradia como screenshot tool por defecto: Print Screen, Super+Shift+S, Alt+Print Screen → Gradia (compilado desde fuente, usa portal XDG nativo).

Los workspaces están protegidos con dconf locks para que Ubuntu no los sobreescriba.

## GPU y drivers

- **NVIDIA**: `ubuntu-drivers autoinstall` + Wayland completo (modeset, fbdev, EGL, GBM, suspend/resume, initramfs, environment.d, GDM).
- **PRIME hybrid**: switcheroo-control, DynamicPowerManagement=0x02, PrefersNonDefaultGPU en Steam/Heroic/Faugus.
- **AMD/Intel**: Sin configuración extra — los drivers mesa están en el kernel.

## Almacenamiento

- **zram** (default): swap en RAM comprimida con zstd. 3 métodos de fallback (systemd-zram-generator → zram-tools → udev manual).
- **swapfile** (alternativa): dd + fstab si PERF_ZRAM=false.
- **I/O schedulers**: udev rules (nvme→none, ssd→mq-deadline, hdd→bfq).
- **Readahead**: nvme/ssd→256K, emmc→512K, hdd→4096K.
- **fstrim**: semanal via systemd timer.
- **tmpfiles.d** (opcional): limpieza automática /tmp 7d, /var/tmp 30d, thumbnails 30d, apt cache 14d, journal max 500M.

## Red

- **systemd-resolved**: DNS-over-TLS con Cloudflare (1.1.1.1) + Quad9 (9.9.9.9), fallback Google. Modo opportunistic (compatible con cualquier red). Configurable.
- **NetworkManager**: gestión unificada de todas las interfaces.
- **APT optimizado**: Pipeline-Depth 5, sin traducciones, Queue-Mode host.

## Logging

Cada módulo tiene cabecera y pie de log estructurado con conteo automático de errores/warnings. `module-summary.log` con formato tabular. Sumario final con diagnóstico.

## Licencia

Este proyecto es software libre. Cada componente instalado mantiene su propia licencia.

---

## Reconocimientos

Este instalador no existiría sin el trabajo de estos proyectos y comunidades:

### Distribuciones y métodos de instalación

- **[Arch Linux](https://archlinux.org)** y **[archinstall](https://github.com/archlinux/archinstall)** — Filosofía de construir el sistema pieza a pieza y la idea de un instalador modular
- **[Alpine Linux](https://alpinelinux.org)** y **[setup-alpine](https://wiki.alpinelinux.org/wiki/Installation)** — Referencia de instalador minimalista en shell puro
- **[Bazzite](https://bazzite.gg)** — Patrón de configuración GNOME con gschema overrides + dconf system-db + script de primer login
- **[CachyOS](https://cachyos.org)** — Kernel optimizado con BORE/EEVDF, patchset de rendimiento, systemd-oomd tuning y zram defaults
- **[Clear Linux](https://clearlinux.org)** — Parámetros de kernel para escritorio optimizado
- **[PikaOS](https://pika-os.com)** — Falcond (auto-optimización gaming), inspiración para integración gaming en Linux
- **[Zorin OS](https://zorin.com)** — Referencia de overrides de GSettings para escritorio pulido
- **[Calamares](https://calamares.io)** — Referencia de UX para instaladores de escritorio
- **[Subiquity](https://github.com/canonical/subiquity)** — Instalador oficial de Ubuntu Server
- **[GLFS](https://glfs-book.github.io/glfs/)** — Método de instalación de Steam desde tarball
- **[Fedora](https://fedoraproject.org)** — Referencia para zram como swap por defecto y systemd-zram-generator

### Software

- **[Valve / Steam](https://store.steampowered.com)** — Plataforma de gaming y Proton
- **[Heroic Games Launcher](https://heroicgameslauncher.com)** — Launcher para Epic/GOG/Amazon
- **[Faugus Launcher](https://github.com/Faugus/faugus-launcher)** — Launcher ligero para Proton
- **[MangoHud](https://github.com/flightlessmango/MangoHud)** — Overlay de rendimiento
- **[MangoJuice](https://github.com/radiolamp/mangojuice)** — GUI para MangoHud
- **[ProtonPlus](https://github.com/Vysp3r/ProtonPlus)** — Gestor de versiones Proton/Wine-GE
- **[GameMode](https://github.com/FeralInteractive/gamemode)** — Optimización de rendimiento por juego (Feral Interactive)
- **[Falcond](https://github.com/PikaOS-Linux/falcond)** — Daemon de auto-optimización gaming (PikaOS / ferreo)
- **[OptiScaler](https://github.com/optiscaler/OptiScaler)** — Bridge de upscaling/frame generation cross-GPU
- **[0ptiscaler4linux](https://github.com/ind4skylivey/0ptiscaler4linux)** — Instalador de OptiScaler para Linux
- **[Ghostty](https://ghostty.org)** — Terminal GPU-accelerated (Mitchell Hashimoto)
- **[ghostty-ubuntu](https://github.com/mkasberg/ghostty-ubuntu)** — PPA de Ghostty para Ubuntu (Mike Kasberg)
- **[Fooyin](https://github.com/fooyin/fooyin)** — Reproductor de música Qt6
- **[Topgrade](https://github.com/topgrade-rs/topgrade)** — Actualizador universal
- **[Nerd Fonts](https://github.com/ryanoasis/nerd-fonts)** — Fuentes parcheadas con iconos
- **[AM / AppImage Manager](https://github.com/ivan-hc/AM)** — Gestión de AppImages (ivan-hc)
- **[Gradia](https://github.com/AlexanderVanhee/Gradia)** — Screenshot tool GTK4/libadwaita con anotaciones (Alexander Vanhee)
- **[Déjà Dup](https://apps.gnome.org/DejaDup/)** — Backups integrados en GNOME
- **[GNOME Sushi](https://gitlab.gnome.org/GNOME/sushi)** — Previsualización rápida de archivos (Espacio en Nautilus)
- **[eza](https://eza.rocks)** — Reemplazo moderno de ls con colores, iconos y Git (eza-community)
- **[fzf](https://github.com/junegunn/fzf)** — Fuzzy finder para terminal (Junegunn Choi)
- **[zoxide](https://github.com/ajeetdsouza/zoxide)** — cd inteligente que aprende directorios (Ajeet D'Souza)
- **[yazi](https://yazi-rs.github.io)** — File manager terminal en Rust con async I/O (sxyazi)
- **[lazygit](https://github.com/jesseduffield/lazygit)** — TUI para Git (Jesse Duffield)
- **[lazydocker](https://github.com/jesseduffield/lazydocker)** — TUI para Docker (Jesse Duffield)
- **[LazyVim](https://www.lazyvim.org)** — Distribución de Neovim preconfigurada (Folke Lemaitre)
- **[Bun](https://bun.sh)** — Runtime JS/TS ultrarrápido (Jarred Sumner / Oven)
- **[Deno](https://deno.com)** — Runtime JS/TS seguro con TypeScript nativo (Ryan Dahl)
- **[Unregistry](https://github.com/psviderski/unregistry)** — Push Docker images sin registry (Pasha Sviderski)
- **[Uncloud](https://github.com/psviderski/uncloud)** — Deploy multi-host Docker simplificado (Pasha Sviderski)
- **[Meld](https://meldmerge.org)** — Diff/merge visual para archivos y directorios
- **[Postman](https://www.postman.com)** — Plataforma de API testing
- **[Wireshark](https://www.wireshark.org)** — Análisis de tráfico de red
- **[nmap](https://nmap.org)** — Scanner de red y puertos
- **[AWS CLI](https://aws.amazon.com/cli/)** — CLI oficial de Amazon Web Services
- **[HTTPie](https://httpie.io)** — HTTP client para terminal
- **[jq](https://jqlang.github.io/jq/)** — Procesador JSON en línea de comandos

### Extensiones GNOME

- **[Blur my Shell](https://github.com/aunetx/blur-my-shell)** — Transparencia y blur en GNOME (aunetx)
- **[Alphabetical App Grid](https://github.com/stuarthayhurst/alphabetical-grid-extension)** — Orden alfabético en el grid (Stuart Hayhurst)
- **[Caffeine](https://github.com/eonpatapon/gnome-shell-extension-caffeine)** — Evitar suspensión (eonpatapon)
- **[No Overview](https://github.com/fthx/no-overview)** — Sin overview al iniciar sesión (fthx)
- **[No Screenshot Box](https://github.com/abdallah-alkanani/no-screenshot-box)** — Sin rectángulo de captura (Abdallah Al-Kanani)
- **[Dash to Panel](https://github.com/home-sweet-gnome/dash-to-panel)** — Panel inferior estilo Windows

### Extensiones Chrome (privacidad YouTube)

- **[uBlock Origin Lite](https://github.com/nicedoc/nicedoc/blob/master/docs/nicedoc.md)** — Bloqueo de anuncios MV3 (Raymond Hill)
- **[SponsorBlock](https://sponsor.ajay.app)** — Skip de sponsors en YouTube (Ajay Ramachandran)
- **[Return YouTube Dislike](https://returnyoutubedislike.com)** — Restaurar contador de dislikes
- **[DeArrow](https://dearrow.ajay.app)** — Títulos y thumbnails sin clickbait (Ajay Ramachandran)

### Kernel y rendimiento

- **[BORE Scheduler](https://github.com/firelzrd/bore-scheduler)** — Burst-Oriented Response Enhancer (firelzrd)
- **[linux-psycachy](https://github.com/psygreg/linux-psycachy)** — Kernel precompilado con patches CachyOS (psygreg)
- **[sched-ext](https://github.com/sched-ext)** — Framework de schedulers en userspace
- **[fwupd](https://fwupd.org)** — Actualización de firmware en Linux (Richard Hughes)

### Herramientas de sistema

- **[debootstrap](https://wiki.debian.org/Debootstrap)** — Bootstrap de sistemas Debian/Ubuntu
- **[PipeWire](https://pipewire.org)** — Servidor de audio/video moderno
- **[NetworkManager](https://networkmanager.dev)** — Gestión de red
- **[systemd-resolved](https://www.freedesktop.org/software/systemd/man/systemd-resolved.service.html)** — DNS resolver con DNS-over-TLS
- **[systemd-oomd](https://www.freedesktop.org/software/systemd/man/systemd-oomd.service.html)** — OOM killer proactivo
- **[systemd-zram-generator](https://github.com/systemd/zram-generator)** — Configuración automática de zram

---

*Construido con bash, debootstrap y muchas horas leyendo wikis.*

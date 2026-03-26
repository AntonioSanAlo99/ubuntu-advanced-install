# ubuntu-advanced-install

Instalador modular de Ubuntu con debootstrap. Construye un sistema Ubuntu desde cero con GNOME, gaming, multimedia, desarrollo y webapps nativas, en una sola ejecución.

## Qué hace

Partiendo de un USB live o un entorno mínimo, este instalador:

1. Particiona el disco (GPT + EFI + ext4, con soporte dual boot)
2. Instala Ubuntu base via debootstrap (sin snap, sin paquetes innecesarios)
3. Configura GNOME con dock, extensiones, tema oscuro, transparencia y wallpaper
4. Instala Rust (rustup) como toolchain base del sistema
5. Instala software multimedia, desarrollo, gaming y extras según elección del usuario
6. Compila webapps nativas con Pake (Tauri/Rust, ~5MB cada una, sin Electron)
7. Aplica optimizaciones de rendimiento configurables (oomd, DNS-over-TLS, tmpfiles.d)
8. Verifica la instalación y genera un informe

Todo es interactivo con preguntas claras, o automático via `config.yaml`.

## Uso

```bash
# Pantalla principal (recomendado)
sudo ./install.sh

# Automático (requiere config.yaml)
sudo ./install.sh --auto

# Ver plan sin ejecutar nada
sudo ./install.sh --dry-run

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
install.sh                    Orquestador principal (banner + 2 opciones)
config.yaml.example           Configuración YAML declarativa
modules/
  00-check-dependencies.sh    Verificar herramientas necesarias
  01-prepare-disk.sh          Particionar y formatear
  02-debootstrap.sh           Instalar sistema base (APT pipeline optimizado)
  03-configure-base.sh        Locales, timezone, usuarios
  04-install-bootloader.sh    GRUB + parámetros del kernel (4 niveles)
  05-configure-network.sh     NetworkManager + systemd-resolved (DNS-over-TLS)
  06-configure-auto-updates.sh  Actualizaciones automáticas
  07-install-rust.sh            Rust (rustup) — base del sistema
  10-install-gnome-core.sh    GNOME Shell + extensiones + dconf + GDM
  11-configure-gnome-user.sh  Primer login, wallpaper, V-Shell, carpetas app grid
  12-optimize-gnome.sh        Optimización de memoria GNOME
  13-configure-gnome-theme.sh Tema transparente Adwaita-Transparent
  20-install-multimedia.sh    VLC, Fooyin, Spotify, códecs
  21-install-fonts.sh         Nerd Fonts, Microsoft, sistema (descargas paralelas)
  22-configure-wireless.sh    WiFi + Bluetooth (autodetección)
  23-install-development.sh   Dev tools opcionales (n8n, Docker tools, etc.)
  24-configure-gaming.sh      Steam, Heroic, drivers GPU, MangoHud, kernel PsyCachy
  25-install-extras.sh        OnlyOffice, webapps Pake, gestores CLI
  30-configure-storage.sh     I/O schedulers + fstrim + readahead
  31-configure-audio.sh       PipeWire + WirePlumber
  32-optimize-laptop.sh       TLP / power-profiles-daemon
  33-minimize-systemd.sh      Deshabilitar servicios innecesarios
  34-security-hardening.sh    UFW + sysctl + Secure Boot
  90-verify-system.sh         Verificación post-instalación
  91-generate-report.sh       Informe del sistema
  92-backup-config.sh         Backup de configuración
files/
  99-ubuntu-advanced-install.gschema.override   Defaults GNOME
  bin/kernel-manager          Gestor CLI de kernels
  bin/firmware-manager        Gestor CLI de firmware (fwupd)
  webapps/                    Generador de webapps nativas con Pake
tools/
  post-install-test.sh        Tests post-instalación (61 checks, 8 secciones)
  validate-installer.sh       Validador de estructura del proyecto
```

### Arquitectura de configuración

Cada módulo es un script independiente ejecutado como subproceso. Recibe variables por dos vías (sin librerías compartidas):

```
install.sh
├── export_config_vars()  → 61 variables exportadas al entorno
├── config.yaml           → cada módulo tiene su propio parser _yaml_val()
├── partition.info        → 7 variables de disco (generadas por módulo 01)
└── modules/XX.sh         → precedencia: entorno > config.yaml > default
```

## Opciones de instalación

### Software

| Categoría | Incluye |
|-----------|---------|
| **Base** | Rust (rustup), bash-completion, chrony (NTP) |
| **Multimedia** | VLC, Fooyin, Spotify, códecs completos, PipeWire |
| **Desarrollo** | Git, Ghostty, NodeJS, VSCode, Topgrade, pip+venv, eza, fzf, zoxide, yazi |
| **Desarrollo (opcional)** | n8n, Lazy TUI (lazygit+lazydocker+LazyVim), Bun, Deno, Docker tools, Meld, Postman, GNOME Boxes |
| **Red y cloud (opcional)** | Wireshark, nmap, AWS CLI v2, httpie, jq |
| **Gaming** | Steam (GLFS/SteamRT3), Heroic, Faugus, MangoHud, MangoJuice, drivers GPU |
| **Extras (opcional)** | OnlyOffice, qBittorrent, Mullvad VPN, OBS Studio, Obsidian, Gradia |

### Gaming avanzado (opcional)

| Opción | Descripción |
|--------|-------------|
| **Kernel PsyCachy** | .deb precompilados con scheduler BORE o EEVDF |
| **Falcond** | Daemon de auto-optimización gaming (PikaOS) |
| **OptiScaler** | FSR4/DLSS/XeSS para todos los juegos |
| **ProtonPlus** | Gestor de versiones Proton/Wine-GE (compilado desde fuente) |
| **PRIME hybrid** | switcheroo-control para GPU dual (NVIDIA+iGPU) |

### Webapps nativas (Pake / Tauri / Rust)

Cada webapp se compila como binario nativo (~5MB) usando WebKitGTK del sistema. Sin Electron, sin Chromium embebido.

- **Streaming:** Netflix, HBO Max, Prime Video, Disney+, Filmin, DAZN, Movistar+
- **Media:** YouTube, YouTube Music
- **IA:** ChatGPT, Claude

Chrome mantiene extensiones de privacidad forzadas (uBlock Origin Lite, SponsorBlock, Return YouTube Dislike, DeArrow) para la navegación normal.

### Parámetros del kernel

| Nivel | Parámetros |
|-------|------------|
| **1 — Base** | `quiet splash intel_pstate=active no_timer_check page_alloc.shuffle=1 nowatchdog` |
| **2 — Gaming** | Base + `preempt=full tsc=reliable split_lock_detect=off` |
| **3 — Inseguro** | Gaming + `mitigations=off` (desactiva Spectre/Meltdown) |
| **4 — Mínimo** | Solo `quiet splash` |

## Configuración GNOME

Tres capas sin conflictos:

| Capa | Archivo | Qué configura |
|------|---------|---------------|
| gschema.override | `99-ubuntu-advanced-install` | Temas, fuentes, dock, workspaces, privacidad, Nautilus |
| dconf system-db | `00-ubuntu-advanced-install` | welcome-dialog, V-Shell defaults, Dash to Panel, Gradia (condicional) |
| Script primer login | `gnome-first-login.sh` | Wallpaper, V-Shell (97 keys via dconf load), carpetas app grid |

Extensiones: V-Shell (vertical-workspaces), Caffeine, Dash to Panel o Ubuntu Dock + Arc Menu, AppIndicator, user-theme.

Carpetas del app grid: Utilidades, Sistema, Juegos, Multimedia, Desarrollo, Internet, Oficina, Streaming, IA.

## GPU y drivers

- **NVIDIA**: `ubuntu-drivers autoinstall` + Wayland completo (modeset, fbdev, EGL, GBM, suspend/resume, initramfs).
- **PRIME hybrid**: switcheroo-control, DynamicPowerManagement, PrefersNonDefaultGPU.
- **AMD/Intel**: Drivers mesa en el kernel, sin configuración extra.

## Tests post-instalación

```bash
# Dentro del sistema instalado
sudo bash tools/post-install-test.sh

# Solo sección GNOME
sudo bash tools/post-install-test.sh --section gnome
```

61 checks en 8 secciones: sistema, boot, red, gnome, software, optimizaciones, audio. Salida con ✓/✗/⚠.

## Licencia

Este proyecto es software libre. Cada componente instalado mantiene su propia licencia.

---

## Reconocimientos

Este instalador no existiría sin el trabajo de estos proyectos:

### Distribuciones e instaladores
[Arch Linux](https://archlinux.org) · [archinstall](https://github.com/archlinux/archinstall) · [Alpine Linux](https://alpinelinux.org) · [Bazzite](https://bazzite.gg) · [CachyOS](https://cachyos.org) · [Clear Linux](https://clearlinux.org) · [PikaOS](https://pika-os.com) · [Zorin OS](https://zorin.com) · [Calamares](https://calamares.io) · [GLFS](https://glfs-book.github.io/glfs/) · [Fedora](https://fedoraproject.org)

### Software
[Steam](https://store.steampowered.com) · [Heroic](https://heroicgameslauncher.com) · [Faugus](https://github.com/Faugus/faugus-launcher) · [MangoHud](https://github.com/flightlessmango/MangoHud) · [MangoJuice](https://github.com/radiolamp/mangojuice) · [ProtonPlus](https://github.com/Vysp3r/ProtonPlus) · [GameMode](https://github.com/FeralInteractive/gamemode) · [Falcond](https://github.com/PikaOS-Linux/falcond) · [OptiScaler](https://github.com/optiscaler/OptiScaler) · [Ghostty](https://ghostty.org) · [Fooyin](https://github.com/fooyin/fooyin) · [Topgrade](https://github.com/topgrade-rs/topgrade) · [Gradia](https://github.com/AlexanderVanhee/Gradia) · [Pake](https://github.com/tw93/Pake) · [n8n](https://n8n.io) · [Déjà Dup](https://apps.gnome.org/DejaDup/) · [eza](https://eza.rocks) · [fzf](https://github.com/junegunn/fzf) · [zoxide](https://github.com/ajeetdsouza/zoxide) · [yazi](https://yazi-rs.github.io) · [lazygit](https://github.com/jesseduffield/lazygit) · [LazyVim](https://www.lazyvim.org) · [Bun](https://bun.sh) · [Deno](https://deno.com)

### Extensiones GNOME
[V-Shell](https://github.com/G-dH/vertical-workspaces) · [Caffeine](https://github.com/eonpatapon/gnome-shell-extension-caffeine) · [Dash to Panel](https://github.com/home-sweet-gnome/dash-to-panel) · [Arc Menu](https://gitlab.com/arcmenu/ArcMenu)

### Kernel y rendimiento
[BORE Scheduler](https://github.com/firelzrd/bore-scheduler) · [linux-psycachy](https://github.com/psygreg/linux-psycachy) · [PipeWire](https://pipewire.org) · [fwupd](https://fwupd.org) · [Nerd Fonts](https://github.com/ryanoasis/nerd-fonts)

---

*Construido con bash, debootstrap, Rust y muchas horas leyendo wikis.*

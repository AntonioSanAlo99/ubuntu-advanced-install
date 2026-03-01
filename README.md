# Ubuntu Advanced Installer

Instalador de Ubuntu 24.04 LTS desde un live de Debian 13. Una sola ejecución produce un sistema completamente configurado — sin warnings, sin pasos manuales, listo para usar desde el primer arranque.

---

## Uso

```bash
sudo su -
apt update && apt install -y git
git clone https://github.com/usuario/ubuntu-advanced-install.git
cd ubuntu-advanced-install
chmod +x install.sh
./install.sh
```

Las dependencias necesarias (`debootstrap`, `arch-install-scripts`, `parted`, `dosfstools`, `ubuntu-keyring`) se instalan automáticamente si no están presentes.

---

## Lo que resuelve este instalador

La instalación estándar de Ubuntu deja muchas cosas a medias que los usuarios terminan resolviendo uno a uno, buscando en foros, o simplemente viviendo con ellas. Este instalador los resuelve todos en silencio.

### Parámetros de kernel de Clear Linux

Intel desarrolló una lista de parámetros de arranque que mejoran el rendimiento en hardware de consumo. Ubuntu no los activa por defecto. El instalador los añade a GRUB:

- **`intel_pstate=active`** — fuerza el governor de frecuencia nativo de Intel en lugar del genérico del kernel, con mejor respuesta en cargas variables
- **`page_alloc.shuffle=1`** — aleatoriza la asignación de páginas de memoria, mejora el rendimiento en benchmarks de memoria y reduce la fragmentación
- **`rcupdate.rcu_expedited=1`** — acelera las actualizaciones RCU del kernel, reduce latencia en operaciones del sistema
- **`tsc=reliable`** — evita que el kernel verifique repetidamente el contador de ciclos de la CPU, elimina overhead innecesario en hardware moderno
- **`nowatchdog` + `nmi_watchdog=0`** — desactiva el watchdog de hardware, reduce interrupciones periódicas que afectan la latencia
- **`cryptomgr.notests`** — omite los tests de autocomprobación del gestor criptográfico en el arranque, sin impacto en seguridad
- **`intel_iommu=igfx_off`** — desactiva IOMMU para la gráfica integrada Intel, evita overhead de traducción de direcciones en la GPU integrada
- **`no_timer_check`** — omite la verificación del temporizador durante el arranque, reduce el tiempo de boot

Además se documenta en `/etc/default/grub` la opción `mitigations=off` (comentada) para quien quiera el máximo rendimiento desactivando las mitigaciones de Spectre/Meltdown (+10-20% CPU en cargas intensivas).

### Locale sin warnings

En una instalación limpia de Ubuntu, los primeros `apt install` generan `perl: warning: Setting locale failed`, `Cannot set LC_*` y `bash: warning: setlocale`. El instalador configura `es_ES.UTF-8` antes de cualquier llamada a apt — locale generado y activo desde el principio — de forma que esos warnings no aparecen nunca, ni durante la instalación ni después.

### Un workspace, sin workspaces dinámicos

GNOME por defecto crea workspaces nuevos automáticamente y muestra indicadores de paginación en el app grid. Para usuarios que no usan workspaces múltiples (la mayoría), esto genera confusión y clutter visual. El instalador configura un workspace único y fijo en dos capas: dconf de sistema durante la instalación y gsettings de usuario en el primer login, más CSS para suprimir los indicadores del grid.

### GNOME configurado de verdad, no a medias

El problema técnico de fondo es que `gsettings` necesita D-Bus y no funciona dentro del chroot, así que los instaladores o lo omiten o ejecutan comandos que fallan silenciosamente. Este instalador usa dconf de sistema (`/etc/dconf/db/local.d/`) para lo que se aplica durante la instalación, y un script autodestructivo en `/etc/xdg/autostart/` para lo que necesita sesión gráfica. Al arrancar el sistema por primera vez, GNOME ya está completamente configurado:

- **App grid siempre alfabético.** GNOME sobreescribe el orden cada vez que el usuario interactúa con el grid. Se resuelve con un dconf lock de sistema: la escritura falla en silencio y el orden alfabético se mantiene de forma permanente.
- **Extensiones activas desde el primer login**, no solo instaladas y apagadas.
- **Tema oscuro, iconos Elementary, fuentes Ubuntu + JetBrains Mono Nerd Font** configurados antes de que el usuario vea la pantalla.
- **Dock con autohide inteligente:** se oculta únicamente cuando una ventana lo tapa (`FOCUS_APPLICATION_WINDOWS`), no con cualquier movimiento del ratón. Transparencia 35%, botón de apps arriba, click minimiza o muestra previsualizaciones.
- **Extensión snapd-prompting eliminada.** Ubuntu la instala por defecto y no aporta nada para la mayoría de usuarios.
- **Apps de sistema agrupadas en carpetas** (Utilidades, Sistema) para que el grid no sea una lista plana de 40 iconos.
- **Workspaces ocultos del app grid** con CSS. GNOME los muestra como páginas paginadas; se suprimen para que el grid sea solo aplicaciones.
- **Wallpaper correcto de la versión** detectado automáticamente desde `/usr/share/backgrounds/`.

### Screen Time completamente desactivado

Ubuntu activa por defecto el registro del uso de aplicaciones y archivos recientes. Se desactivan en tres capas: dconf default de sistema, gsettings de usuario y el schema `org.gnome.desktop.screen-time-limits`. No aparece en ningún panel ni genera datos en segundo plano.

### Repositorios en formato DEB822

Los repositorios APT se configuran en formato DEB822 (`.sources`), el estándar de APT 3.0 que Ubuntu 24.04 usa internamente. El `sources.list` legacy queda vacío con un comentario explicativo. Esto evita advertencias de deprecación y es compatible con cualquier herramienta moderna de gestión de paquetes.

### Optimización de memoria GNOME (opcional, interactivo)

GNOME en idle consume entre 1.2 y 1.5 GB de RAM con su configuración estándar. El instalador ofrece reducirlo a 600-800 MB con opciones explicadas y sus trade-offs:

- **gnome-software deshabilitado** (~80-150 MB) — reemplazado por update-manager. No hay pérdida funcional para actualizaciones del sistema.
- **Tracker deshabilitado** (~100-200 MB) — el indexador de archivos. Efecto: búsquedas en Nautilus más lentas. Recomendado si no se buscan archivos por contenido.
- **Evolution Data Server deshabilitado** (~50-100 MB) — sincronización de calendario y contactos. Recomendado si no se usa GNOME Calendar ni Contacts.
- **Animaciones deshabilitadas** (~30-50 MB + CPU) — para hardware muy limitado.

Cada opción se pregunta por separado con el valor recomendado por defecto.

### Fuentes que funcionan en todo

La instalación base de Ubuntu tiene fuentes que dan problemas en webs, documentos y terminales. El instalador añade:

- **Microsoft Core Fonts** (Arial, Times New Roman, Courier New, Verdana, etc.) — la mayoría de documentos Word y webs que no se ven bien en Linux es por esto.
- **Noto + DejaVu + Liberation** — cobertura Unicode completa, sin cuadros vacíos en webs con caracteres especiales o asiáticos.
- **Noto Color Emoji** — emojis en color en el navegador y el terminal.
- **FiraCode, JetBrains Mono, Hack, Meslo** como Nerd Fonts — iconos en terminales y editores de código.

### Miniaturas para todos los formatos

Nautilus solo genera miniaturas de imágenes básicas en una instalación estándar. El instalador añade:

- **Vídeo** (MP4, MKV, AVI, MOV…) — primer fotograma del archivo
- **Audio** (MP3, FLAC, OGG, M4A…) — carátula del álbum vía Totem, que se instala exclusivamente para este propósito
- **PDF** — primera página del documento
- **ePub** — portada del libro
- **WebP y HEIF/HEIC** — fotos de iPhone y formato web moderno
- **AppImages** — icono de la aplicación extraído del bundle

### Gaming sin configuración manual

Steam, Lutris, Heroic y Faugus Launcher se instalan. Lo que no es obvio:

- **`vm.max_map_count=2147483642`** — el límite por defecto (65530) causa crashes o rendimiento degradado en juegos como Star Citizen, Elden Ring o cualquier título con muchos recursos cargados simultáneamente.
- **VRR (Variable Refresh Rate) activado** si GNOME ≥ 46. Detecta la versión de GNOME en tiempo de instalación y configura `experimental-features` con un autostart autodestructivo que se ejecuta en el primer login y desaparece.
- **HDR activado** si GNOME ≥ 48.
- **Detección de GPU en tiempo de instalación:** identifica automáticamente NVIDIA, AMD o Intel y registra el resultado en el resumen de instalación.
- **Detección de mandos conectados:** identifica DualShock 4/DualSense, Xbox, Switch Pro, Logitech Gaming y muestra cuántos se detectaron antes de instalar las reglas.
- **Reglas udev para mandos** (game-devices-udev): DualShock 4, DualSense, Xbox, Switch Pro, 8BitDo, Logitech, Razer, HORI y más. Sin estas reglas, muchos mandos no se reconocen o necesitan permisos root.
- **ProtonUp-Qt** vía Pacstall para gestionar versiones de Proton y Proton-CachyOS.
- **GameMode + MangoHud + GOverlay** — optimización de recursos durante el juego y overlay de métricas.
- **TCP BBR + fq** — mejora en juegos online con pérdida de paquetes.

### Laptop: detección de hardware inalámbrico y control de CPU avanzado

El módulo de WiFi/Bluetooth detecta automáticamente el chipset presente (Intel, Realtek, Broadcom, Atheros, MediaTek — tanto PCI como USB) e instala el firmware específico. No instala nada que no haga falta.

Además de TLP o power-profiles-daemon, el instalador incluye `cpu-power-manager`: herramienta de terminal equivalente a ThrottleStop en Windows. Permite ajustar undervolt (hasta -250 mV con validación de límites de seguridad), TDP (PL1/PL2, 5-125W), offset PROCHOT y frecuencias máximas y mínimas. Nada de esto es accesible desde la interfaz gráfica de Ubuntu.

### Herramientas de desarrollo

Además de git, build-essential y Python 3, el instalador configura todos los repositorios en formato DEB822 antes de instalar:

- **VSCode** desde el repositorio oficial de Microsoft (DEB822)
- **Node.js 24 LTS** desde NodeSource (DEB822), no el paquete anticuado de los repos de Ubuntu
- **Rust** vía rustup instalado como el usuario del sistema, no como root

### Boot sin esperas innecesarias

`NetworkManager-wait-online` y `systemd-networkd-wait-online` retrasan el arranque esperando una conexión de red que las aplicaciones de escritorio no necesitan. Se deshabilitan. También `systemd-hostnamed`, `systemd-localed`, `systemd-timedated` y `ModemManager` en sistemas sin módem.

### systemd-oomd activo

El OOM killer del kernel mata procesos de forma abrupta cuando la memoria se agota. systemd-oomd actúa antes, terminando procesos de forma ordenada. Viene en Ubuntu pero no se habilita en la instalación estándar.

### Hardening de red sin fricción

Aplica parámetros sysctl estándar: rp_filter, bloqueo de ICMP redirects, SYN cookies contra SYN flood, ASLR máximo (`kernel.randomize_va_space=2`), `kernel.kptr_restrict=2` y `kernel.dmesg_restrict=1`. Ninguno afecta al uso normal.

---

## Requisitos

- Live de Debian 13 arrancado desde USB (o cualquier sistema con APT)
- Conexión a internet
- Disco con mínimo 25 GB

---

## Modo automático

Para instalación sin preguntas, configurar `config.env` antes de ejecutar:

```bash
cp config.env.example config.env
nano config.env
./install.sh   # seleccionar opción 2
```

Las contraseñas se pasan vía `printf | chpasswd` (nunca como variables de entorno) para evitar exposición en `ps aux`. Al finalizar, el instalador ofrece sobrescribir `config.env` con datos aleatorios antes de borrarlo.

---

## Componentes opcionales

| Componente | Por defecto | Variable en `config.env` |
|---|---|---|
| GNOME | ✅ activado | `INSTALL_GNOME=true` |
| Tema Adwaita con transparencias | ❌ desactivado | `GNOME_TRANSPARENT_THEME=true` |
| Optimización de memoria GNOME | ❌ desactivado | `GNOME_OPTIMIZE_MEMORY=true` |
| Multimedia (códecs, VLC, Fooyin) | ✅ activado | `INSTALL_MULTIMEDIA=true` |
| Desarrollo (VSCode, Node.js, Rust) | ❌ desactivado | `INSTALL_DEVELOPMENT=true` |
| Gaming completo | ❌ desactivado | `INSTALL_GAMING=true` |
| Optimizaciones laptop | ❌ desactivado | `IS_LAPTOP=true` |
| Minimizar servicios systemd | ❌ desactivado | `MINIMIZE_SYSTEMD=true` |
| Hardening de seguridad | ❌ desactivado | `ENABLE_SECURITY=true` |

---

## Documentación

- [Guía de instalación](wiki/user-guides/01-Installation-Guide.md)
- [Opciones de configuración](wiki/user-guides/02-Configuration.md)
- [Resolución de problemas](wiki/user-guides/03-Troubleshooting.md)
- [Arquitectura de configuración GNOME](docs/technical/GNOME-CONFIG-ARCHITECTURE.md)
- [Changelog](docs/CHANGELOG.md)
- [Roadmap](docs/ROADMAP.md)

---

## Licencia

GPL-3.0-only

# Ubuntu Advanced Installer

Instalador modular de Ubuntu 24.04 LTS desde un live de Debian 13. Una ejecución, sistema listo — sin warnings, sin pasos manuales, sin configuración posterior.

```bash
sudo su -
apt update && apt install -y git
git clone https://github.com/usuario/ubuntu-advanced-install.git
cd ubuntu-advanced-install && chmod +x install.sh && ./install.sh
```

> Las dependencias del live (`debootstrap`, `arch-install-scripts`, `parted`…) se instalan automáticamente si no están presentes.

---

## Qué resuelve

Ubuntu estándar llega con muchas cosas a medias. Este instalador las resuelve todas antes del primer arranque:

### Sistema base
- **Locale sin warnings** — `run_module` exporta `LC_ALL=C.UTF-8` al entorno del host antes de cada módulo; `arch-chroot` lo hereda y `apt` siempre encuentra un locale válido. El locale se configura con el método estándar Debian: `debconf-set-selections` + `dpkg-reconfigure locales`, que internamente ejecuta `locale-gen`, `update-locale` y `setupcon` para configurar también la fuente y charset del TTY.
- **Parámetros de kernel de Clear Linux** — `page_alloc.shuffle`, `rcupdate.rcu_expedited`, `tsc=reliable`, `intel_pstate=active` y más. Menor latencia, boot más rápido, sin tocar nada manualmente.
- **Repositorios en formato DEB822** — el estándar de APT 3.0 desde el primer momento, incluyendo repos de terceros (VSCode, NodeSource, Chrome).
- **systemd-oomd activo** — Ubuntu lo incluye pero no lo habilita. Termina procesos de forma ordenada antes de que el kernel mate todo a lo bruto.
- **Boot sin esperas de red** — `NetworkManager-wait-online` y `systemd-networkd-wait-online` deshabilitados. En desktop no sirven para nada.

### GNOME
- **Configuración real desde el chroot** — `gsettings` necesita D-Bus y no funciona en chroot. Este instalador usa dconf de sistema para la instalación y un script autodestructivo en el primer login para el resto. Extensiones activas, tema oscuro, dock y fuentes configurados desde el primer arranque.
- **App grid alfabético permanente** — GNOME sobreescribe el orden cada vez que el usuario toca el grid. Resuelto con dconf lock: el orden nunca cambia.
- **Un workspace limpio** — sin workspaces dinámicos, sin indicadores de paginación, sin confusión.
- **Screen Time desactivado** en tres capas. Ubuntu lo activa por defecto.
- **Miniaturas completas** — vídeo, audio con carátula (MP3/FLAC/OGG), PDF, ePub, WebP, HEIC, AppImages. Nautilus estándar solo miniaturiza imágenes básicas.
- **Fuentes** — Microsoft Core Fonts, Noto, DejaVu, Noto Color Emoji y Nerd Fonts (JetBrains Mono, FiraCode, Hack, Meslo). La mayoría de webs y documentos Word que "no se ven bien en Linux" son un problema de fuentes.
- **Memoria optimizable** — idle estándar: 1.2–1.5 GB. Con las opciones activadas: 600–800 MB. gnome-software, Tracker y Evolution Data Server se pueden deshabilitar individualmente con sus trade-offs explicados.

### Gaming *(opcional)*
Detecta GPU y mandos conectados antes de instalar nada.

- `vm.max_map_count` ajustado — sin esto, Star Citizen, Elden Ring y muchos otros crashean o rinden mal
- VRR si GNOME ≥ 46 · HDR si GNOME ≥ 48 — detectado y configurado en tiempo de instalación
- Reglas udev para mandos (DualShock 4/5, Xbox, Switch Pro, 8BitDo, Razer…) — sin ellas muchos mandos necesitan permisos de root
- TCP BBR como algoritmo de congestión para juego online
- Steam · Lutris · Heroic · Faugus · ProtonUp-Qt · Proton-CachyOS · GameMode · MangoHud

### Laptop *(opcional)*
- Detección automática del chipset WiFi/Bluetooth (Intel, Realtek, Broadcom, Atheros, MediaTek — PCI y USB) para instalar solo el firmware necesario
- `cpu-power-manager` incluido: equivalente a ThrottleStop en Windows. Undervolt, TDP (PL1/PL2), PROCHOT, frecuencias por core — nada de esto existe en la interfaz gráfica de Ubuntu

### Desarrollo *(opcional)*
VSCode, Node.js 24 LTS desde NodeSource (no el paquete anticuado de Ubuntu) y Rust vía rustup — todo desde repositorios oficiales en formato DEB822, instalado con el usuario correcto.

---

## Modo automático

```bash
cp config.env.example config.env
nano config.env        # disco, usuario, contraseñas, componentes
./install.sh           # opción 2
```

Las contraseñas se pasan vía `printf | chpasswd`, nunca como variables de entorno. Al finalizar, `config.env` se sobreescribe con datos aleatorios antes de borrarse.

---

## Componentes opcionales

| Componente | Variable |
|---|---|
| Tema Adwaita transparente | `GNOME_TRANSPARENT_THEME=true` |
| Optimización de memoria GNOME | `GNOME_OPTIMIZE_MEMORY=true` |
| Gaming completo | `INSTALL_GAMING=true` |
| Herramientas de desarrollo | `INSTALL_DEVELOPMENT=true` |
| Optimizaciones laptop | `IS_LAPTOP=true` |
| Minimizar servicios systemd | `MINIMIZE_SYSTEMD=true` |
| Hardening de red y kernel | `ENABLE_SECURITY=true` |

GNOME y multimedia activos por defecto.

---

GPL-3.0-only · [Changelog](docs/CHANGELOG.md) · [Roadmap](docs/ROADMAP.md) · [Wiki](wiki/)

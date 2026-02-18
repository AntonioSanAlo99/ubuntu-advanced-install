# 🚀 Ubuntu Advanced Install

Sistema de instalación Ubuntu **completamente modular** basado en debootstrap. Control total sobre cada componente, sin metapaquetes innecesarios y con optimizaciones de rendimiento extraídas directamente de **Intel Clear Linux**.

---

## ⚡ Instalación rápida

```bash
sudo su -
apt install git
git clone https://github.com/AntonioSanAlo99/ubuntu-advanced-install
cd ubuntu-advanced-install
chmod +x install.sh
./install.sh
```

En la primera ejecución se lanza el asistente de configuración interactivo. Al terminar, el sistema queda listo para instalar.

---

## 📋 ¿Qué incluye?

### 🧱 Sistema base
- ✅ Instalación mínima con debootstrap (sin bloatware)
- ✅ Ubuntu 24.04 LTS (noble), 25.04 (plucky) y 25.10 (questing)
- ✅ Detección automática BIOS/UEFI
- ✅ Dual-boot con Windows (detección automática)
- ✅ Repositorios completos: main, restricted, universe, multiverse
- ✅ `--no-install-recommends` por defecto → sistema más ligero

### 🎯 Instalación inteligente
- ✅ Asistente interactivo guiado (8 pasos)
- ✅ Instalación automática desatendida
- ✅ Instalación paso a paso con confirmación
- ✅ 20 módulos independientes y reutilizables
- ✅ Ejecuta solo lo que necesitas

### 🏎️ Optimizaciones modulares para testing

**Sistema de optimizaciones con activación selectiva.** Todas las optimizaciones están comentadas por defecto para que puedas activarlas una a una y medir su impacto real en tu hardware.

#### Parámetros de boot activos (Clear Linux base)

```
intel_pstate=active      → Hardware gestiona frecuencias (<1ms latencia)
cryptomgr.notests        → Boot más rápido (sin tests de crypto)
intel_iommu=igfx_off     → iGPU sin IOMMU (mejor rendimiento gráfico)
no_timer_check           → Elimina check de timer al arrancar
page_alloc.shuffle=1     → Aleatoriza páginas (seguridad + rendimiento)
rcupdate.rcu_expedited=1 → RCU expedited (menor latencia)
tsc=reliable             → TSC como fuente de tiempo fiable
nowatchdog               → Sin watchdog (menos overhead)
nmi_watchdog=0           → Sin NMI watchdog (menos interrupciones)
```

#### Parámetros opcionales para testing

Documentados en `/etc/default/grub` tras la instalación:
- `mitigations=off` → +10-20% CPU (desactiva Spectre/Meltdown)
- `split_lock_detect=off` → Sin verificaciones (10ª gen Intel+)

#### Categorías runtime (sysctl)

Archivo: `/etc/sysctl.d/99-performance-modular.conf`

- **MEMORIA** — swappiness=1, page-cluster=0
- **FS_CACHE** — vfs_cache_pressure=50
- **SCHEDULER** — migration_cost=5ms, nr_migrate=256
- **RED** — BBR, tcp_fastopen

**Herramienta de testing:** `tools/benchmark-optimizer.sh`

```bash
sudo benchmark-optimizer.sh enable MEMORIA
sudo benchmark-optimizer.sh status
sudo benchmark-optimizer.sh disable ALL
```

Ver [TESTING-GUIDE.md](TESTING-GUIDE.md) para workflow completo.

### 🎯 Filosofía de optimización

El sistema implementa optimizaciones **modulares y medibles**. Nada se activa por defecto — tú decides qué optimizaciones aplicar según los benchmarks en tu hardware específico.

Ver **[TESTING-GUIDE.md](TESTING-GUIDE.md)** para el workflow completo de testing y benchmarks esperados.

### 🎨 Componentes opcionales
- ✅ **GNOME** por componentes (sin `ubuntu-desktop`)
- ✅ **NetworkManager** con fix "unmanaged" incluido
- ✅ **Multimedia:** Códecs completos, VLC, Fooyin
- ✅ **Fuentes Microsoft:** Core, ClearType, Tahoma, Segoe UI
- ✅ **Gaming:** Vulkan, gamemode, reglas udev para 17+ marcas de periféricos
- ✅ **WiFi/Bluetooth** soporte completo
- ✅ **Desarrollo:** Git, build-essential, Python
- ✅ **Google Chrome** instalado directamente desde Google

### 🔒 Seguridad
- ✅ Protección contra IP spoofing y SYN flood
- ✅ ASLR habilitado
- ✅ dmesg restringido
- ✅ Actualizaciones automáticas de seguridad

---

## 🗂️ Estructura

```
ubuntu-advanced-install/
├── install.sh                       # Script principal
├── config.env                       # Configuración (generado por el asistente)
├── partition.info                   # Info de particiones (generado)
└── modules/
    ├── 00-check-dependencies.sh     # Verificar dependencias del host
    ├── 01-prepare-disk.sh           # Detección de discos y particionado
    ├── 02-debootstrap.sh            # Sistema base mínimo
    ├── 03-configure-base.sh         # Hostname, locale español, usuario
    ├── 04-install-bootloader.sh     # Kernel + GRUB + parámetros Clear Linux
    ├── 05-configure-network.sh      # NetworkManager (base)
    ├── 06-enable-backports.sh       # Repositorios backports (opcional)
    ├── 10-install-gnome.sh          # GNOME por componentes + Chrome
    ├── 12-install-multimedia.sh     # Códecs, VLC, Fooyin
    ├── 13-install-fonts.sh          # Fuentes Microsoft y del sistema
    ├── 14-configure-wireless.sh     # WiFi y Bluetooth
    ├── 15-install-development.sh    # Herramientas de desarrollo
    ├── 16-configure-gaming.sh       # Vulkan, gamemode, udev periféricos
    ├── 21-optimize-laptop.sh        # TLP + thermald
    ├── 23-minimize-systemd.sh       # Desactivar servicios innecesarios
    ├── 24-security-hardening.sh     # Hardening del kernel
    ├── 30-verify-system.sh          # Verificar instalación
    ├── 31-generate-report.sh        # Generar informe del sistema
    └── 32-backup-config.sh          # Backup de configuración
```

---

## 🎯 Modos de uso

```bash
./install.sh                          # Menú interactivo completo
./install.sh --auto                   # Instalación automática desatendida
./install.sh --interactive            # Paso a paso con confirmación
./install.sh --config                 # Solo generar config.env
./install.sh --module <nombre>        # Ejecutar un módulo concreto
./install.sh --list                   # Listar módulos disponibles
```

---

## 💡 Casos de uso

### Laptop personal con GNOME
```bash
INSTALL_GNOME="true"
INSTALL_MULTIMEDIA="true"
IS_LAPTOP="true"
```
Resultado: GNOME completo, TLP, códecs + VLC + Fooyin, Chrome — ~4-5 GB instalado

### Servidor mínimo sin GUI
```bash
INSTALL_GNOME="false"
INSTALL_MULTIMEDIA="false"
MINIMIZE_SYSTEMD="true"
ENABLE_SECURITY="true"
```
Resultado: Solo CLI, systemd minimizado, hardening — ~1.5-2 GB instalado

### Workstation de desarrollo
```bash
INSTALL_GNOME="true"
INSTALL_DEVELOPMENT="true"
INSTALL_MULTIMEDIA="false"
```
Resultado: GNOME + Git, build-essential, Python — ~3-4 GB instalado

### Gaming desktop
```bash
INSTALL_GNOME="true"
INSTALL_MULTIMEDIA="true"
INSTALL_GAMING="true"
```
Resultado: GNOME + Vulkan + gamemode + reglas udev para ratones/teclados/mandos — ~5-6 GB instalado

---

## 🪟 Dual-boot con Windows

El instalador detecta automáticamente particiones Windows y ofrece tres opciones: dual-boot conservando Windows, formateo completo, o particionado manual. En modo dual-boot instala `os-prober` y configura GRUB con timeout de 10 segundos.

---

## ⚠️ Antes de instalar

- Haz backup de tus datos
- Verifica que el disco sea el correcto
- Ten conexión a internet disponible
- Necesitas al menos 20 GB libres
- Debootstrap tarda 5-15 minutos según la conexión

---

## 🆘 Troubleshooting

**Red no disponible tras el primer arranque:**
```bash
sudo tee /etc/NetworkManager/conf.d/10-globally-managed-devices.conf << EOF
[keyfile]
unmanaged-devices=none
EOF
sudo systemctl restart NetworkManager
```

**GRUB no detecta Windows:**
```bash
sudo apt install os-prober
echo "GRUB_DISABLE_OS_PROBER=false" | sudo tee -a /etc/default/grub
sudo os-prober && sudo update-grub
```

**Reinstalar un componente:**
```bash
./install.sh --module <nombre-del-módulo>
```

**Después de instalar — eliminar contraseñas:**
```bash
rm ~/ubuntu-advanced-install/config.env
```

---

## 📚 Recursos

- [Ubuntu Debootstrap](https://wiki.ubuntu.com/DebootstrapChroot)
- [Intel Clear Linux optimizations](https://github.com/clearlinux-pkgs/linux)
- [Fooyin](https://github.com/fooyin/fooyin)
- [TLP](https://linrunner.de/tlp/)

---

**Ubuntu Advanced Install** — Instalación modular, optimizada y sin bloatware 🚀

**Versión:** 2.0 · **Módulos:** 20 · **Ubuntu soportado:** 24.04 / 25.04 / 25.10

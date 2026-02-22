# Solución de Problemas

Guía completa para resolver errores comunes durante y después de la instalación.

---

## Problemas Durante la Instalación

### Error: debootstrap no encontrado

**Síntoma:**
```
bash: debootstrap: command not found
```

**Causa:** El sistema Live no tiene debootstrap instalado

**Solución:**
```bash
# En Debian/Ubuntu Live
sudo apt update
sudo apt install debootstrap

# Reintentar instalación
sudo ./install.sh
```

---

### Error: arch-chroot no encontrado

**Síntoma:**
```
bash: arch-chroot: command not found
```

**Causa:** arch-install-scripts no instalado

**Solución:**
```bash
# Opción 1: Instalar arch-install-scripts
sudo apt install arch-install-scripts

# Opción 2: Usar Ubuntu 22.04+ Live que lo incluye
# Opción 3: El instalador usa fallback con chroot normal
```

**Nota:** Desde Ubuntu 22.04, arch-chroot está disponible por defecto.

---

### Error: No se puede particionar el disco

**Síntoma:**
```
Error: Could not create partition
Device or resource busy
```

**Causa:** Disco montado o en uso

**Solución:**
```bash
# 1. Ver qué está montado
lsblk
mount | grep sda

# 2. Desmontar todo
sudo umount /dev/sda1
sudo umount /dev/sda2
# ... todas las particiones

# 3. Verificar procesos usando el disco
sudo fuser -mv /dev/sda

# 4. Matar procesos si necesario
sudo fuser -km /dev/sda

# 5. Reintentar
sudo ./install.sh
```

---

### Error: debootstrap falla

**Síntoma:**
```
E: Failed getting release file
W: Failure trying to run: chroot /mnt dpkg --configure -a
```

**Causas posibles:**

#### 1. Sin internet
```bash
# Verificar conectividad
ping -c 3 google.com

# Si falla, configurar red
sudo dhclient
```

#### 2. Mirror no disponible
```bash
# Editar modules/02-debootstrap.sh
# Cambiar mirror:
MIRROR="http://archive.ubuntu.com/ubuntu"

# Por uno local (España):
MIRROR="http://es.archive.ubuntu.com/ubuntu"
```

#### 3. Versión incorrecta
```bash
# Verificar que la versión existe
# En config.env:
UBUNTU_VERSION="noble"  # 24.04 LTS (correcto)
UBUNTU_VERSION="oracular"  # 24.10 (puede no estar en repos aún)
```

---

### Error: Disco lleno durante instalación

**Síntoma:**
```
No space left on device
```

**Causa:** Partición muy pequeña

**Solución:**
```bash
# Verificar espacio
df -h /mnt

# Mínimo recomendado:
# - Sistema base: 10GB
# - Con GNOME: 15GB
# - Con desarrollo: 20GB
# - Con gaming: 30GB

# Si es muy pequeño, reparticionar
sudo umount -R /mnt
sudo ./install.sh  # Especificar tamaño mayor
```

---

## Problemas en Chroot

### Warning: Perl locale

**Síntoma:**
```
perl: warning: Setting locale failed.
perl: warning: Please check that your locale settings:
```

**Es normal:** Aparece UNA vez durante `locale-gen`

**Es problema:** Si aparece en cada comando `apt`

**Solución si persiste:**
```bash
# En chroot
export LC_ALL=C
apt update
```

Ver [Locales.md](Locales.md) para más detalles.

---

### Error: systemctl en chroot

**Síntoma:**
```
System has not been booted with systemd as init system
Failed to connect to bus
```

**Es normal:** systemd no funciona en chroot

**Solución:** El instalador usa symlinks manuales

Ver [Chroot-Limitations.md](Chroot-Limitations.md)

---

### Error: dbus en chroot

**Síntoma:**
```
Failed to connect to D-Bus
```

**Es normal:** D-Bus no corre en chroot

**Solución:** Configuración se aplica en primer login

---

## Problemas Post-Instalación

### Sistema no arranca - Error GRUB

**Síntoma:**
```
error: no such device
grub rescue>
```

**Causa:** GRUB mal instalado o UUID incorrecto

**Solución desde Live USB:**
```bash
# 1. Montar sistema
sudo mount /dev/sda2 /mnt  # Tu partición raíz
sudo mount /dev/sda1 /mnt/boot/efi  # Partición EFI

# 2. Chroot
sudo arch-chroot /mnt

# 3. Reinstalar GRUB
grub-install /dev/sda
update-grub

# 4. Salir y reiniciar
exit
sudo reboot
```

---

### Sistema no arranca - Kernel panic

**Síntoma:**
```
Kernel panic - not syncing
VFS: Unable to mount root fs
```

**Causa:** initramfs no regenerado o fstab incorrecto

**Solución:**
```bash
# 1. Boot en Live USB
# 2. Montar sistema
sudo mount /dev/sda2 /mnt
sudo mount /dev/sda1 /mnt/boot/efi

# 3. Chroot
sudo arch-chroot /mnt

# 4. Regenerar initramfs
update-initramfs -u -k all

# 5. Verificar fstab
cat /etc/fstab
# UUIDs deben coincidir con:
blkid

# 6. Salir y reiniciar
exit
sudo reboot
```

---

### GDM no inicia - Pantalla negra

**Síntoma:** Después de login, pantalla negra

**Causas posibles:**

#### 1. GDM no habilitado
```bash
# Verificar
systemctl status gdm3

# Habilitar
sudo systemctl enable gdm3
sudo systemctl start gdm3
```

#### 2. Drivers gráficos
```bash
# Ver errores
journalctl -xeb

# Para NVIDIA, instalar drivers propietarios
sudo ubuntu-drivers autoinstall
```

#### 3. Wayland en hardware antiguo
```bash
# Forzar X11
sudo nano /etc/gdm3/custom.conf

# Descomentar:
WaylandEnable=false

# Reiniciar GDM
sudo systemctl restart gdm3
```

---

### Teclado incorrecto

**Síntoma:** Teclas no coinciden con layout físico

**Solución:**
```bash
# Temporal (hasta reinicio)
setxkbmap es

# Permanente
sudo dpkg-reconfigure keyboard-configuration

# O editar directamente
sudo nano /etc/default/keyboard
# XKBLAYOUT="es"

# Aplicar
sudo setupcon -k
```

Ver [Keyboard.md](Keyboard.md)

---

### Locale incorrecto

**Síntoma:** Fechas, moneda en idioma incorrecto

**Solución:**
```bash
# Ver locale actual
locale

# Cambiar
sudo update-locale LANG=es_ES.UTF-8

# Cerrar sesión y volver a entrar
```

Ver [Locales.md](Locales.md)

---

### WiFi no funciona

**Síntoma:** No detecta redes WiFi

**Solución:**
```bash
# 1. Verificar hardware
lspci | grep -i network
lsusb | grep -i wireless

# 2. Ver si el driver está cargado
lsmod | grep iwl  # Intel
lsmod | grep ath  # Atheros
lsmod | grep rtw  # Realtek

# 3. Instalar firmware si falta
sudo apt install linux-firmware

# 4. Para Intel específicamente
sudo apt install firmware-iwlwifi

# 5. Reiniciar NetworkManager
sudo systemctl restart NetworkManager
```

---

### Bluetooth no funciona

**Síntoma:** Bluetooth no disponible

**Solución:**
```bash
# 1. Verificar servicio
systemctl status bluetooth

# 2. Iniciar si está detenido
sudo systemctl start bluetooth
sudo systemctl enable bluetooth

# 3. Desbloquear si está bloqueado
rfkill list
rfkill unblock bluetooth

# 4. Reiniciar servicio
sudo systemctl restart bluetooth
```

---

### Audio no funciona

**Síntoma:** Sin sonido

**Solución:**
```bash
# 1. Verificar que no esté muteado
alsamixer
# Presionar M para unmute

# 2. Ver dispositivos de audio
aplay -l

# 3. Reiniciar PulseAudio/PipeWire
systemctl --user restart pipewire
systemctl --user restart wireplumber

# 4. Verificar en GNOME Settings
gnome-control-center sound
```

---

### Extensiones GNOME no funcionan

**Síntoma:** Extensiones instaladas pero no activas

**Solución:**
```bash
# 1. Habilitar manualmente
gnome-extensions enable ubuntu-dock@ubuntu.com

# 2. Ver errores
journalctl -f

# 3. Reiniciar GNOME Shell
# En X11:
killall -SIGQUIT gnome-shell

# En Wayland:
# Cerrar sesión y volver a entrar
```

---

### Tema transparente no se aplica

**Síntoma:** Tema creado pero no activo

**Solución:**
```bash
# 1. Verificar que existe
ls -la ~/.themes/Adwaita-Transparent/

# 2. Habilitar extensión user-theme
gnome-extensions enable user-theme@gnome-shell-extensions.gcampax.github.com

# 3. Aplicar tema
gsettings set org.gnome.shell.extensions.user-theme name 'Adwaita-Transparent'

# 4. Reiniciar GNOME Shell (X11)
killall -SIGQUIT gnome-shell
```

---

### Steam/Gaming no funciona

**Síntoma:** Juegos no inician o errores de drivers

**Solución:**
```bash
# 1. Instalar drivers propietarios NVIDIA
sudo ubuntu-drivers autoinstall
sudo reboot

# 2. Verificar Vulkan
vulkaninfo | grep "deviceName"

# 3. Habilitar arquitectura 32-bit
sudo dpkg --add-architecture i386
sudo apt update

# 4. Instalar dependencias 32-bit
sudo apt install libgl1-mesa-dri:i386

# 5. Ver logs de Steam
~/.local/share/Steam/logs/
```

---

### VS Code no abre

**Síntoma:** Error al iniciar VS Code

**Solución:**
```bash
# 1. Ejecutar desde terminal para ver error
code

# 2. Si falla por GPU, deshabilitar aceleración
code --disable-gpu

# 3. Reinstalar
sudo apt remove code
sudo apt install code

# 4. Permisos
sudo chown -R $USER ~/.config/Code
```

---

## Problemas de Rendimiento

### Sistema lento - Alta uso RAM

**Diagnóstico:**
```bash
# Ver uso de memoria
free -h
htop

# Ver servicios pesados
systemctl list-units --type=service --state=running
```

**Solución:**
```bash
# 1. Optimizar GNOME
# Ejecutar módulo de optimización:
sudo modules/10-optimize.sh

# 2. Deshabilitar Tracker
systemctl --user mask tracker-miner-fs
systemctl --user mask tracker-extract

# 3. Minimizar systemd
sudo modules/23-minimize-systemd.sh
```

Ver [GNOME-Memory.md](GNOME-Memory.md)

---

### Sistema lento - Alta uso CPU

**Diagnóstico:**
```bash
# Ver procesos
top
htop

# Ver servicios
systemctl list-units --state=running
```

**Solución:**
```bash
# Deshabilitar servicios innecesarios
sudo systemctl disable cups  # Si no usas impresora
sudo systemctl disable bluetooth  # Si no usas Bluetooth
sudo systemctl disable ModemManager  # Si no usas módem
```

---

### Laptop - Batería se agota rápido

**Solución:**
```bash
# 1. Instalar TLP
sudo apt install tlp
sudo systemctl enable tlp
sudo systemctl start tlp

# 2. Ver estadísticas de energía
sudo tlp-stat -b

# 3. Configuración agresiva
sudo nano /etc/tlp.conf
# TLP_DEFAULT_MODE=BAT
# TLP_PERSISTENT_DEFAULT=1
```

---

## Herramientas de Diagnóstico

### Logs del Sistema

```bash
# Logs generales
journalctl -xeb

# Boot anterior
journalctl -b -1

# Servicio específico
journalctl -u gdm3

# Errores del kernel
dmesg | grep -i error

# Logs de instalación (nuestro instalador)
cat /var/log/ubuntu-install/installation.log
```

### Verificar Hardware

```bash
# CPU
lscpu

# Memoria
free -h
sudo dmidecode -t memory

# Disco
lsblk
sudo fdisk -l

# PCI (GPU, Red, etc.)
lspci

# USB
lsusb

# Red
ip a
iwconfig
```

### Verificar Servicios

```bash
# Estado de servicio
systemctl status gdm3

# Servicios fallidos
systemctl --failed

# Servicios habilitados
systemctl list-unit-files --state=enabled

# Servicios corriendo
systemctl list-units --type=service --state=running
```

---

## Recuperación de Sistema

### Modo de Recuperación

```bash
# 1. Al arrancar, presionar Shift
# 2. Seleccionar "Advanced options for Ubuntu"
# 3. Seleccionar kernel con "(recovery mode)"
# 4. Elegir opción:
#    - root: Shell con permisos root
#    - fsck: Verificar sistema de archivos
#    - network: Habilitar red
```

### Desde Live USB

```bash
# 1. Boot Live USB
# 2. Montar sistema
sudo mount /dev/sda2 /mnt
sudo mount /dev/sda1 /mnt/boot/efi

# 3. Chroot
sudo arch-chroot /mnt

# 4. Reparar lo necesario
# 5. Salir
exit
sudo umount -R /mnt
sudo reboot
```

---

## Obtener Ayuda

### Información del Sistema

```bash
# Generar reporte completo
sudo modules/31-generate-report.sh

# El reporte está en:
cat /var/log/ubuntu-install/installation-report.txt
```

### Reportar Bug

Incluir:
1. Versión de Ubuntu
2. Hardware (CPU, RAM, GPU)
3. Pasos para reproducir
4. Logs relevantes
5. Archivo config.env (sin contraseñas)

### Recursos

- **GitHub Issues:** Para bugs
- **GitHub Discussions:** Para preguntas
- **Wiki:** Documentación completa
- **Logs:** `/var/log/ubuntu-install/`

---

## Prevención de Problemas

### Antes de Instalar

✅ Verificar requisitos de hardware
✅ Hacer backup de datos importantes
✅ Probar en VM primero
✅ Leer documentación
✅ Tener Live USB de respaldo

### Durante Instalación

✅ Mantener conexión a internet estable
✅ No interrumpir el proceso
✅ Verificar configuración antes de confirmar
✅ Anotar errores que aparezcan

### Después de Instalar

✅ Verificar que todo funciona
✅ Hacer snapshot/backup del sistema
✅ Guardar config.env (sin contraseñas)
✅ Documentar cambios personalizados

---

**Siguiente:** [Configuración](02-Configuration.md) | [Instalación](01-Installation-Guide.md)

# Wiki - Ubuntu Advanced Install

Documentación completa del instalador avanzado de Ubuntu 25.10.

---

## 📚 Documentación

### Guías Principales

- **[Installation Guide](01-Installation-Guide.md)** - Instalación paso a paso
- **[Configuration](02-Configuration.md)** - Opciones de configuración
- **[Troubleshooting](03-Troubleshooting.md)** - Solución de problemas

### Componentes

#### Sistema Base
- **[Locales](Locales.md)** - Configuración de idioma (es_ES.UTF-8)
- **[Keyboard](Keyboard.md)** - Configuración de teclado español

#### Desktop
- **[GNOME](GNOME.md)** - Desktop environment
- **[GNOME Extensions](GNOME-Extensions.md)** - Extensiones instaladas
- **[GNOME Memory](GNOME-Memory.md)** - Optimizaciones de memoria
- **[GNOME Transparency](GNOME-Transparency.md)** - Tema transparente

#### Multimedia
- **[Fonts](Fonts.md)** - Fuentes instaladas
- **[Thumbnailers](Thumbnailers.md)** - Miniaturas de archivos

#### Gaming
- **[Gaming](Gaming.md)** - Configuración gaming completa
- **[Gaming Launchers](Gaming-Launchers.md)** - Steam, Lutris, Heroic, Faugus

#### Desarrollo
- **[Rust Development](Rust-Development.md)** - Configuración Rust

#### Hardware
- **[Laptop](Laptop.md)** - Optimizaciones para portátiles

---

## 🎯 Inicio Rápido

### Instalación Básica

```bash
# Descargar
wget https://github.com/.../ubuntu-advanced-install.tar.gz
tar xzf ubuntu-advanced-install.tar.gz
cd ubuntu-advanced-install

# Instalar
sudo bash install.sh
```

Ver: [Installation Guide](01-Installation-Guide.md)

### Post-Instalación

#### Gaming

```bash
# MangoHud (configurar overlay)
goverlay

# GameMode (ya funciona automáticamente)
gamemoderun ./juego
```

Ver: [Gaming Guide](Gaming.md)

#### Locales

```bash
# Cambiar idioma
sudo dpkg-reconfigure locales
```

Ver: [Locales Guide](Locales.md)

---

## 📊 Versión Actual

**v3.8.0** - Instalación Gaming Limpia

### Cambios Recientes

- ✅ Instalación limpia gaming (sin variables automáticas)
- ✅ dpkg-reconfigure para locales (método oficial)
- ✅ Auto-detección paquetes (libtag, libebur128, fonts)
- ✅ Formato consistente de echo
- ✅ Google Chrome restaurado

### Historial

Ver archivos en `_archive/` para versiones anteriores.

---

## 🎯 Filosofía del Proyecto

### Instalación Limpia

```
✓ Instalar software y herramientas
✓ Optimizar sistema (kernel params, udev)
✗ NO imponer configuraciones de usuario
✗ NO asumir preferencias
```

### Ejemplos

**Gaming**:
- Instala: gamemode, mangohud, launchers
- NO configura: Variables de entorno, MangoHud automático
- Usuario: Configura según necesidad

**Locales**:
- Configura: es_ES.UTF-8 (método oficial dpkg-reconfigure)
- Usuario: Puede cambiar fácilmente

---

## 🐛 Problemas Comunes

### Locale Warnings

```bash
sudo dpkg-reconfigure locales
```

### GameMode ld.so Errors

```bash
# Versión antigua configuró LD_PRELOAD incorrectamente
grep -r "LD_PRELOAD.*gamemode" /etc/profile.d/ ~/.bashrc
# Eliminar esas líneas
```

### Fuentes No Instaladas

```bash
sudo bash modules/13-install-fonts.sh
```

Ver: [Troubleshooting Guide](03-Troubleshooting.md)

---

## 📋 Módulos

### Base (Siempre)
- 00-check-dependencies
- 01-prepare-disk
- 02-debootstrap
- 03-configure-base
- 04-install-bootloader
- 05-configure-network

### Desktop (Opcional)
- 10-install-gnome-core
- 10-user-config

### Multimedia (Opcional)
- 12-install-multimedia
- 13-install-fonts

### Gaming (Opcional)
- 16-configure-gaming

### Desarrollo (Opcional)
- 15-install-development

---

## 🔧 Testing

Ver [Testing Guide](Testing-Guide.md) para:
- Crear máquinas virtuales
- Probar módulos individuales
- Validar instalación

---

## 📖 Contribuir

### Documentación

Para añadir/actualizar docs:

1. Crear/editar archivo `.md` en `wiki/`
2. Seguir formato existente
3. Añadir enlace en este README
4. Mover versión antigua a `_archive/`

### Estructura

```
wiki/
├── README.md (este archivo)
├── 01-Installation-Guide.md
├── 02-Configuration.md
├── 03-Troubleshooting.md
├── [Componente].md
└── _archive/ (versiones antiguas)
```

---

## 📞 Soporte

- **Issues**: GitHub Issues
- **Docs**: Esta wiki
- **Logs**: `/var/log/ubuntu-install/*.log`

---

**Documentación actualizada**: v3.8.0

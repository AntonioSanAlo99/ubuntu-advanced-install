# Ubuntu Advanced Installer

Instalador avanzado de Ubuntu con configuración profesional de GNOME, optimizaciones de rendimiento y herramientas de desarrollo.

## 🎯 Filosofía del Proyecto

**Configuración perfecta desde el inicio** - Sin warnings, sin errores, sin configuración manual después de instalar.

### Principios

1. **Configuración automática completa** - Todo configurado en la instalación
2. **Sin dependencias innecesarias** - Solo lo esencial y útil
3. **Rendimiento optimizado** - Memoria, systemd, energía
4. **Privacidad respetada** - Configuración consciente de privacidad
5. **Profesional y limpio** - Como una instalación enterprise

## 🚀 Inicio Rápido

```bash
# Descargar
wget https://tu-url/ubuntu-advanced-install.tar.gz
tar xzf ubuntu-advanced-install.tar.gz
cd ubuntu-advanced-install

# Ejecutar
sudo ./install.sh
```

## 📚 Documentación

### Para Usuarios

- **[Guía de Instalación](wiki/user-guides/01-Installation-Guide.md)** - Cómo usar el instalador
- **[Configuración](wiki/user-guides/02-Configuration.md)** - Opciones disponibles
- **[Troubleshooting](wiki/user-guides/03-Troubleshooting.md)** - Solución de problemas

### Guías de Características

- **[GNOME](wiki/GNOME.md)** - Configuración de GNOME
- **[Gaming](wiki/Gaming.md)** - Optimizaciones para gaming
- **[Laptop](wiki/Laptop.md)** - Optimizaciones para portátiles
- **[Fonts](wiki/Fonts.md)** - Fuentes instaladas
- **[Locales](wiki/Locales.md)** - Configuración de idioma

### Para Desarrolladores

- **[Documentación Técnica](docs/technical/)** - Detalles de implementación
- **[Organización](docs/ORGANIZATION.md)** - Estructura del proyecto
- **[Changelog](docs/CHANGELOG.md)** - Registro de cambios
- **[Roadmap](docs/ROADMAP.md)** - Plan de desarrollo

## ✨ Características

### Sistema Base

- ✅ Locale español perfecto desde inicio (sin warnings)
- ✅ Teclado español configurado (consola + X11)
- ✅ Workspaces dinámicos
- ✅ Timezone automático (Europe/Madrid)
- ✅ Actualizaciones automáticas configurables

### GNOME

- ✅ GNOME Shell + extensiones esenciales activas
- ✅ Tema oscuro por defecto
- ✅ Dock transparente (30%)
- ✅ Chrome + Nautilus anclados
- ✅ App folders sin duplicados
- ✅ Workspaces ocultos en app grid
- ✅ Screen Time deshabilitado (privacidad)

### Optimizaciones

- ✅ Memoria optimizada (zswap, transparent hugepages)
- ✅ Systemd minimizado (servicios innecesarios deshabilitados)
- ✅ systemd-oomd activo (protección OOM)
- ✅ Laptop optimizado (TLP, termald)

### Multimedia

- ✅ Códecs completos (ffmpeg, gstreamer)
- ✅ Thumbnailers (video, pdf, epub, imágenes)
- ✅ Fooyin (reproductor de audio moderno)
- ✅ Spotify opcional (repositorio oficial)

### Gaming

- ✅ Steam, Lutris, Heroic, Faugus
- ✅ ProtonPlus (vía Pacstall)
- ✅ GameMode + MangoHud + GOverlay
- ✅ Drivers Mesa + Vulkan
- ✅ VRR habilitado (GNOME 46+)
- ✅ HDR habilitado (GNOME 48+)
- ✅ Optimizaciones sysctl

### Desarrollo

- ✅ VSCode (oficial)
- ✅ Git + build-essential
- ✅ Node.js LTS
- ✅ Python 3 + pip
- ✅ Docker + Docker Compose
- ✅ Rust opcional

## 🎨 Resultado Final

Sistema Ubuntu con:
- GNOME configurado profesionalmente
- Extensiones activas desde inicio
- Sin warnings en ningún comando
- Optimizado para rendimiento
- Listo para producción

## 📋 Requisitos

- Ubuntu 24.04 LTS ISO (o posterior)
- Conexión a internet
- Disco con al menos 25GB
- Arranque desde USB live

## 🤝 Contribuir

Ver [docs/PROJECT-INFO.md](docs/PROJECT-INFO.md) para detalles de desarrollo.

## 📄 Licencia

GPL-3.0-only

---

**Ubuntu Advanced Installer** - Configuración perfecta desde el inicio.

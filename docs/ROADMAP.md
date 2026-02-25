# Ubuntu Advanced Installer - Roadmap

## 🗺️ Plan de Desarrollo

Este documento describe las características planificadas para futuras versiones del instalador.

---

## v1.1.0 - Interfaz y Usabilidad

### TUI (Text User Interface)
- [ ] **Interfaz TUI con dialog/whiptail**
  - Navegación con teclado
  - Mejor experiencia visual que menú de texto
  - Selección múltiple de módulos
  - Configuración interactiva mejorada

### ISO Personalizada
- [ ] **Crear ISO de Ubuntu con instalador preinstalado**
  - ISO booteable con el instalador incluido
  - No requiere clonar repositorio
  - Distribución más fácil
  - Basada en Ubuntu Live

### Gaming: Drivers Gráficos
- [ ] **Instalación opcional de drivers en módulo gaming**
  - NVIDIA drivers propietarios (detección automática)
  - AMD AMDGPU-PRO (opcional)
  - Intel graphics drivers actualizados
  - Opción de drivers beta/experimentales

### Gaming: Emuladores
- [ ] **Selector de emuladores y EmulationStation**
  - EmulationStation DE
  - RetroArch + cores básicos
  - Dolphin (GameCube/Wii)
  - PCSX2 (PS2)
  - RPCS3 (PS3)
  - Yuzu/Ryujinx (Switch)
  - PPSSPP (PSP)

---

## v1.2.0 - Mejoras GNOME y Gestión de Aplicaciones

### GNOME: Apariencia Mejorada
- [ ] **Temas y personalización avanzada**
  - Temas adicionales (Catppuccin, Nord, Dracula)
  - Configuración de blur en GNOME
  - Iconos personalizados avanzados
  - Configuración de fuentes mejorada
  - Tweaks adicionales de apariencia

### AppImages: Tienda y Gestor
- [ ] **Integración de AppImageHub/Store**
  - Navegador de AppImages disponibles
  - Instalación con un click
  - Categorización de apps

- [ ] **AM (AppImage Manager)**
  - Gestión centralizada de AppImages
  - Actualización automática
  - Integración en menú de aplicaciones
  - Thumbnails y metadatos

### Desarrollo: Topgrade
- [ ] **Topgrade para actualizaciones**
  - Actualización de todo el sistema
  - Soporte para múltiples package managers
  - Flatpak, Snap, cargo, npm, etc.
  - Configuración automática

---

## v1.3.0 - Aplicaciones Extras

### Suite Ofimática
- [ ] **OnlyOffice**
  - Instalación desde repositorio oficial
  - Alternativa a LibreOffice
  - Mejor compatibilidad MS Office

### Comunicación
- [ ] **Teams for Linux**
  - Cliente no oficial de Microsoft Teams
  - Soporte para videollamadas
  
- [ ] **Telegram Desktop**
  - Desde repositorio oficial
  - Versión nativa

### Productividad
- [ ] **Obsidian**
  - AppImage o .deb
  - Notas y knowledge base
  
- [ ] **Ghostty**
  - Terminal moderna y rápida
  - Alternativa a GNOME Terminal

### Multimedia
- [ ] **Spotify**
  - Cliente oficial
  - Repositorio o Flatpak

### VPN y Remoto
- [ ] **Mullvad VPN**
  - Cliente oficial
  - WireGuard integrado
  
- [ ] **AnyDesk**
  - Escritorio remoto
  - Alternativa a TeamViewer

### Virtualización
- [ ] **QEMU/KVM + Virtual Machine Manager**
  - Virt-manager (GUI)
  - QEMU/KVM optimizado
  - Libvirt configurado
  - Network bridges
  - GPU passthrough (opcional)

---

## v1.4.0 - Depuración y Estabilidad

### Depuración del Instalador
- [ ] **Testing automatizado**
  - Tests unitarios de módulos
  - Tests de integración
  - CI/CD con GitHub Actions
  
- [ ] **Manejo de errores mejorado**
  - Mejor recuperación de fallos
  - Rollback automático en errores críticos
  - Logs más detallados
  
- [ ] **Validación de hardware**
  - Verificación de compatibilidad antes de instalar
  - Advertencias tempranas
  - Sugerencias de módulos según hardware

---

## v2.0.0 - Expansión Futura (Planificación Temprana)

### Multi-Desktop
- [ ] **Soporte para KDE Plasma**
  - Alternativa a GNOME
  - Configuraciones optimizadas
  
- [ ] **Soporte para Xfce/LXQt**
  - Para hardware más antiguo
  - Menor uso de recursos

### Profiles Guardados
- [ ] **Sistema de perfiles**
  - Guardar configuraciones
  - Reutilizar en múltiples instalaciones
  - Importar/exportar perfiles
  - Profiles comunitarios

### Backup Automático
- [ ] **Módulos de backup**
  - Backup pre-instalación
  - Snapshots del sistema
  - Integración con Timeshift

---

## Módulos en Desarrollo Activo

### Prioritarios para v1.1.0:
1. TUI con dialog/whiptail
2. Drivers gráficos en gaming
3. ISO personalizada

### Prioritarios para v1.2.0:
1. AM (AppImage Manager)
2. Topgrade
3. Mejoras de apariencia GNOME

### Prioritarios para v1.3.0:
1. Suite de aplicaciones extras
2. QEMU/KVM + virt-manager

---

## Contribuciones

¿Quieres ayudar con alguna de estas características?

1. **Abre un issue** etiquetado con `enhancement`
2. **Comenta en Discussions** sobre la característica
3. **Crea un PR** con tu implementación

Ver [MODULE-DEVELOPMENT.md](MODULE-DEVELOPMENT.md) para guías de desarrollo.

---

## Notas de Implementación

### TUI
- Usar `dialog` o `whiptail` (pre-instalado en Ubuntu)
- Mantener compatibilidad con modo texto actual
- Modo fallback si TUI no disponible

### ISO Personalizada
- Basar en Ubuntu ISO
- Inyectar instalador en /usr/local
- Modificar live environment
- Usar `cubic` o `remastersys`

### AppImage Manager
- Integrar AM desde repositorio oficial
- Configurar actualización automática
- Desktop entries automáticos

### QEMU/KVM
- Detectar soporte de virtualización (VT-x/AMD-V)
- Configurar grupos de usuarios (libvirt, kvm)
- Bridge networking opcional
- GPU passthrough solo para hardware compatible

---

## Timeline Estimado

```
v1.1.0 - Q2 2026
  - TUI
  - ISO personalizada
  - Drivers gaming
  - Emuladores

v1.2.0 - Q3 2026
  - AppImage Manager (AM)
  - Topgrade
  - Mejoras GNOME

v1.3.0 - Q4 2026
  - Aplicaciones extras
  - QEMU/KVM

v1.4.0 - Q1 2027
  - Depuración y estabilidad
  - Testing automatizado

v2.0.0 - Q2 2027+
  - Multi-desktop
  - Profiles
  - Features avanzadas
```

*Los tiempos son estimados y pueden cambiar según disponibilidad.*

---

## Priorización

Las características se priorizan por:

1. **Demanda de usuarios** (issues, votos)
2. **Complejidad vs valor**
3. **Dependencias técnicas**
4. **Recursos disponibles**

---

**Última actualización**: 22 Feb 2026  
**Versión del documento**: 2.0

---

<div align="center">

[⬆ Volver al README](../README.md) · [📖 Documentación](./) · [🐛 Issues](https://github.com/usuario/ubuntu-advanced-install/issues)

</div>

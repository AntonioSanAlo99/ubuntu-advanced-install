# Ubuntu Advanced Install - Wiki

Documentación completa del instalador avanzado de Ubuntu.

## 📚 Índice de Contenidos

### 🚀 Inicio Rápido
- [README Principal](README.md) - Visión general del proyecto
- [Guía de Testing](TESTING-GUIDE.md) - Cómo probar el instalador

### 🔧 Configuración del Sistema

#### Internacionalización
- [Configuración de Locales](Locales.md) - Sistema en español
- [Configuración de Teclado](Keyboard.md) - Teclado español

#### Optimizaciones
- [Optimizaciones Clear Linux](Clear-Linux-Optimizations.md) - Parámetros del kernel
- [Optimización de Memoria en GNOME](GNOME-Memory.md) - Reducir consumo de RAM

### 🎨 Personalización

#### GNOME
- [Extensiones de GNOME](GNOME-Extensions.md) - Extensiones instaladas
- [Transparencias en GNOME](GNOME-Transparency.md) - Tema Adwaita-Transparent

#### Multimedia
- [Thumbnailers](Thumbnailers.md) - Miniaturas de archivos

### 📖 Módulos

#### Información General
- [Módulos Standalone](Standalone-Modules.md) - Uso independiente de módulos
- [Cambios de Numeración](Module-Reorder.md) - Reorganización de módulos
- [Cambios en Valores Predeterminados](Defaults.md) - Configuración por defecto

### 🛠️ Referencia Técnica

#### Para Desarrolladores
- [Notas sobre Locales en Chroot](Locales-Chroot.md) - Filosofía Arch en Ubuntu

---

## 📑 Estructura de Archivos

```
wiki/
├── INDEX.md                          # Este archivo
├── README.md                         # Visión general
├── TESTING-GUIDE.md                  # Guía de testing
│
├── Locales.md                        # Configuración de idioma
├── Locales-Chroot.md                 # Técnica: locales en chroot
├── Keyboard.md                       # Configuración de teclado
│
├── Clear-Linux-Optimizations.md      # Optimizaciones del kernel
├── GNOME-Memory.md                   # Optimización de memoria
│
├── GNOME-Extensions.md               # Extensiones de GNOME
├── GNOME-Transparency.md             # Transparencias
├── Thumbnailers.md                   # Miniaturas
│
├── Standalone-Modules.md             # Uso standalone
├── Module-Reorder.md                 # Cambios de numeración
└── Defaults.md                       # Valores predeterminados
```

## 🔍 Búsqueda Rápida

### Por Tema

**Idioma y Teclado:**
- [Locales](Locales.md) | [Teclado](Keyboard.md) | [Chroot](Locales-Chroot.md)

**Rendimiento:**
- [Clear Linux](Clear-Linux-Optimizations.md) | [Memoria GNOME](GNOME-Memory.md)

**Personalización:**
- [Extensiones](GNOME-Extensions.md) | [Transparencias](GNOME-Transparency.md) | [Thumbnailers](Thumbnailers.md)

**Módulos:**
- [Standalone](Standalone-Modules.md) | [Reordenación](Module-Reorder.md) | [Defaults](Defaults.md)

### Por Caso de Uso

**"Quiero instalar Ubuntu optimizado"**
→ [README](README.md) → [Testing](TESTING-GUIDE.md)

**"El sistema está en inglés"**
→ [Locales](Locales.md) → [Teclado](Keyboard.md)

**"GNOME consume mucha RAM"**
→ [Memoria GNOME](GNOME-Memory.md)

**"Quiero transparencias"**
→ [Transparencias](GNOME-Transparency.md)

**"Las extensiones no funcionan"**
→ [Extensiones](GNOME-Extensions.md)

**"No hay miniaturas de archivos"**
→ [Thumbnailers](Thumbnailers.md)

**"Errores de locale en chroot"**
→ [Locales Chroot](Locales-Chroot.md)

---

## 📝 Contribuir

Si encuentras errores o quieres mejorar la documentación:
1. Los archivos están en formato Markdown
2. Sigue la estructura existente
3. Añade ejemplos prácticos cuando sea posible

## 📄 Licencia

Documentación bajo la misma licencia que el proyecto principal.

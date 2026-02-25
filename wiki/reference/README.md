# Referencias Técnicas

Información de referencia para usuarios avanzados.

## 📚 Contenido

- **[Chroot Limitations](Chroot-Limitations.md)** - Limitaciones de chroot
- **[Keyboard](Keyboard.md)** - Configuración de teclado
- **[Testing Guide](Testing-Guide.md)** - Testing del sistema

## 🔍 Chroot

El instalador usa `arch-chroot` para configurar el sistema.

**Limitaciones**:
- No hay sesión gráfica activa
- DBus no funciona completamente
- systemctl limitado

Ver [Chroot-Limitations.md](Chroot-Limitations.md) para detalles.

## ⌨️ Teclado

Configuración de teclado español en consola y X11.

Ver [Keyboard.md](Keyboard.md).

## 🧪 Testing

Cómo probar el instalador y módulos individuales.

Ver [Testing-Guide.md](Testing-Guide.md).

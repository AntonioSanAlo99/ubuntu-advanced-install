# Módulos Standalone - Guía de Uso

Los módulos de componentes (10-16) y optimización (20-24) pueden ejecutarse de dos formas:

## 1. Durante la instalación (modo automático)

```bash
./install.sh
```

Los módulos detectan automáticamente que `config.env` existe y usan `arch-chroot`.

## 2. En un sistema ya instalado (modo standalone)

```bash
cd ubuntu-advanced-install/modules
sudo ./10-install-gnome.sh
sudo ./12-install-multimedia.sh
sudo ./20-optimize-performance.sh
```

Los módulos detectan que NO existe `config.env` y ejecutan directamente sin chroot.

## Modificaciones aplicadas

Cada módulo standalone ahora:

1. **Source el header común**: `source "$(dirname "$0")/_standalone-header.sh"`
2. **No requiere config.env**: Usa defaults si no existe
3. **Detecta el modo automáticamente**:
   - Con config.env → Modo instalación (usa arch-chroot)
   - Sin config.env → Modo standalone (ejecución directa)
4. **Variables autodetectadas en standalone**:
   - `USERNAME`: Del usuario que ejecutó sudo
   - `TARGET`: "/" (raíz del sistema)
   - `USE_NO_INSTALL_RECOMMENDS`: false por defecto

## Ejemplo de conversión

### Antes (solo instalación):
```bash
#!/bin/bash
source "$(dirname "$0")/../config.env"

arch-chroot "$TARGET" /bin/bash << CHROOTEOF
apt install -y package
CHROOTEOF
```

### Después (standalone + instalación):
```bash
#!/bin/bash
source "$(dirname "$0")/_standalone-header.sh"

if [ "$STANDALONE_MODE" = true ]; then
    # Modo standalone
    apt install -y $APT_FLAGS package
else
    # Modo instalación
    arch-chroot "$TARGET" /bin/bash << CHROOTEOF
    apt install -y \$APT_FLAGS package
CHROOTEOF
fi
```

## Módulos convertidos

- [x] _standalone-header.sh (header común)
- [ ] 10-install-gnome.sh
- [ ] 11-configure-network.sh
- [ ] 12-install-multimedia.sh
- [ ] 13-install-fonts.sh
- [ ] 14-configure-wireless.sh
- [ ] 15-install-development.sh
- [ ] 16-configure-gaming.sh
- [ ] 20-optimize-performance.sh
- [ ] 21-optimize-laptop.sh
- [ ] 23-minimize-systemd.sh
- [ ] 24-security-hardening.sh

## Testing

```bash
# Test en sistema real
cd modules
sudo ./_standalone-header.sh  # Ver variables detectadas
sudo ./10-install-gnome.sh     # Instalar GNOME en sistema actual

# Test durante instalación
./install.sh  # Los módulos siguen funcionando normalmente
```

#!/bin/bash
# Módulo 05: Habilitar backports (opcional)

source "$(dirname "$0")/../config.env"

echo "═══════════════════════════════════════════════════════════"
echo "  HABILITAR BACKPORTS"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Los backports proporcionan versiones más recientes de software"
echo "manteniendo la estabilidad del sistema base."
echo ""
echo "Útil para:"
echo "  • Kernels más recientes"
echo "  • Drivers actualizados"
echo "  • Software de desarrollo moderno"
echo ""
read -p "¿Habilitar backports? (s/n) [n]: " enable_backports

if [[ ! $enable_backports =~ ^[SsYy]$ ]]; then
    echo "Backports no habilitados"
    exit 0
fi

arch-chroot "$TARGET" /bin/bash << 'CHROOTEOF'


# Descomentar línea de backports en sources.list
sed -i "s/^# deb.*backports/deb http:\/\/archive.ubuntu.com\/ubuntu\/ $(lsb_release -cs)-backports main restricted universe multiverse/" /etc/apt/sources.list

# Si no existe, agregarla
if ! grep -q "backports" /etc/apt/sources.list; then
    echo "deb http://archive.ubuntu.com/ubuntu/ $(lsb_release -cs)-backports main restricted universe multiverse" >> /etc/apt/sources.list
fi

# Configurar prioridad de backports (lower priority, solo manual)
cat > /etc/apt/preferences.d/backports << 'EOF'
# Backports con prioridad baja (solo instalación manual)
Package: *
Pin: release a=$(lsb_release -cs)-backports
Pin-Priority: 100
EOF

# Actualizar índice
apt update

echo "✓ Backports habilitados"
echo ""
echo "Uso:"
echo "  apt install -t $(lsb_release -cs)-backports <paquete>"
echo ""
echo "Ejemplo:"
echo "  apt install -t $(lsb_release -cs)-backports linux-image-generic"

CHROOTEOF

echo ""
echo "✓✓✓ Backports configurados ✓✓✓"
echo ""
echo "Los backports están disponibles pero NO se instalan automáticamente"
echo "Para instalar desde backports:"
echo "  sudo apt install -t $UBUNTU_VERSION-backports <paquete>"

#!/bin/bash
# Módulo 20: Optimizaciones de rendimiento modulares

set -eo pipefail  # Detectar errores en pipelines

# Variables se pasan desde install.sh via environment
# source "$(dirname "$0")/../config.env"

echo "Configurando optimizaciones de rendimiento modulares..."

# Detectar CPU
CPU_VENDOR=$(grep "vendor_id" /proc/cpuinfo | head -1 | awk '{print $3}')
CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -1)

echo "CPU detectado: $CPU_VENDOR"

arch-chroot "$TARGET" /bin/bash << 'CHROOTEOF'

# ============================================================================
# CONFIGURACIÓN MODULAR DE RENDIMIENTO
# ============================================================================

cat > /etc/sysctl.d/99-performance-modular.conf << 'SYSCTLEOF'
# ============================================================================
# CONFIGURACIÓN DE RENDIMIENTO MODULAR
# ============================================================================
# Cada sección puede activarse/desactivarse independientemente para testing
# Descomenta las líneas que quieras probar
# Aplica cambios con: sudo sysctl -p /etc/sysctl.d/99-performance-modular.conf
# ============================================================================

# === MEMORIA ===
# Efecto: Sistema más ágil, todo permanece en RAM el máximo tiempo posible
# Con swappiness=1 el kernel usa swap solo en situaciones de necesidad real
# Descomenta para testing:
#vm.swappiness = 1

# Efecto: En NVMe lee del swap exactamente lo necesario (no 8 páginas)
# Descomenta para testing:
#vm.page-cluster = 0

# === FILESYSTEM CACHE ===
# Efecto: Segunda apertura de apps/archivos más rápida
# Retiene estructuras de filesystem en caché más tiempo
# Descomenta para testing:
#vm.vfs_cache_pressure = 50

# === CPU SCHEDULER ===
# Efecto: Tareas permanecen en su core más tiempo = mejor caché
# Ubuntu default: 500000 (0.5ms), este valor: 5000000 (5ms)
# Descomenta para testing:
#kernel.sched_migration_cost_ns = 5000000

# Efecto: Scheduler mueve más tareas por ciclo de balanceo
# Ubuntu default: 32, este valor: 256 (8x)
# Descomenta para testing:
#kernel.sched_nr_migrate = 256

# Efecto: Agrupa procesos de sesión de usuario (compilaciones en background
# no compiten directamente con GNOME por CPU)
# Ubuntu default: 1 (activado), mantener activado
kernel.sched_autogroup_enabled = 1

# === RED (BBR - Google) ===
# Efecto: Menor latencia de red, mejor throughput en todo tipo de conexiones
# Descomenta para testing:
#net.core.default_qdisc = fq
#net.ipv4.tcp_congestion_control = bbr
#net.ipv4.tcp_fastopen = 3
#net.ipv4.tcp_slow_start_after_idle = 0

# === FILESYSTEM WATCHES ===
# Efecto: GNOME/apps no usan polling de CPU para detectar cambios de archivos
# Recomendado activar siempre (Ubuntu default: 8192, muy bajo para desktop moderno)
fs.inotify.max_user_watches = 524288

SYSCTLEOF

echo "✓ Archivo de configuración modular creado"

# Detectar arquitectura y crear configuración específica
CPU_VENDOR=$(grep "vendor_id" /proc/cpuinfo | head -1 | awk '{print $3}')

if [ "$CPU_VENDOR" = "GenuineIntel" ]; then
    cat > /etc/sysctl.d/99-performance-arch.conf << 'INTELEOF'
# ============================================================================
# OPTIMIZACIONES ESPECÍFICAS DE INTEL
# ============================================================================

# Intel Turbo Boost Max Technology scheduling
# Crítico para 12ª-14ª generación (P-cores + E-cores)
# Garantiza que tareas críticas vayan a los cores más rápidos
kernel.sched_itmt_enabled = 1

# Sistemas Intel mono-socket: desactivar balanceo NUMA innecesario
kernel.numa_balancing = 0
INTELEOF
    echo "✓ Optimizaciones Intel configuradas"

elif [ "$CPU_VENDOR" = "AuthenticAMD" ]; then
    # Detectar número de CCDs en AMD
    NUM_L3_CACHES=$(lscpu | grep "L3 cache" | wc -l)
    
    if [ "$NUM_L3_CACHES" -gt 1 ]; then
        cat > /etc/sysctl.d/99-performance-arch.conf << 'AMDMULTIEOF'
# ============================================================================
# OPTIMIZACIONES ESPECÍFICAS DE AMD (MULTI-CCD)
# ============================================================================

# AMD Ryzen con múltiples CCDs: activar balanceo NUMA
# Los CCDs tienen latencias de memoria distintas
kernel.numa_balancing = 1

# Permitir migraciones más frecuentes entre CCDs
kernel.sched_migration_cost_ns = 3000000
AMDMULTIEOF
        echo "✓ Optimizaciones AMD multi-CCD configuradas"
    else
        cat > /etc/sysctl.d/99-performance-arch.conf << 'AMDSINGLEEOF'
# ============================================================================
# OPTIMIZACIONES ESPECÍFICAS DE AMD (SINGLE-CCD)
# ============================================================================

# AMD Ryzen con un solo CCD: desactivar balanceo NUMA innecesario
kernel.numa_balancing = 0
AMDSINGLEEOF
        echo "✓ Optimizaciones AMD single-CCD configuradas"
    fi
fi

CHROOTEOF

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  OPTIMIZACIONES CONFIGURADAS EN MODO MODULAR"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Los parámetros están COMENTADOS por defecto para que puedas"
echo "activarlos selectivamente y medir su impacto real."
echo ""
echo "Archivo de configuración:"
echo "  /etc/sysctl.d/99-performance-modular.conf"
echo ""
echo "Para activar una categoría:"
echo "  1. Edita el archivo y descomenta las líneas deseadas"
echo "  2. Aplica cambios: sudo sysctl -p /etc/sysctl.d/99-performance-modular.conf"
echo ""
echo "Para herramientas de testing automático, instala:"
echo "  tools/benchmark-optimizer.sh (después de la instalación)"
echo ""
echo "════════════════════════════════════════════════════════════════"


exit 0

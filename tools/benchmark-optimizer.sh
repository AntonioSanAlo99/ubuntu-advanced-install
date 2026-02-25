#!/bin/bash
# Herramienta de testing de optimizaciones modulares

SYSCTL_FILE="/etc/sysctl.d/99-performance-modular.conf"

show_help() {
    cat << 'EOF'
╔════════════════════════════════════════════════════════════════╗
║         HERRAMIENTA DE TESTING DE OPTIMIZACIONES              ║
╚════════════════════════════════════════════════════════════════╝

CATEGORÍAS DISPONIBLES:
  MEMORIA      - swappiness=1, page-cluster=0
  FS_CACHE     - vfs_cache_pressure=50
  SCHEDULER    - migration_cost=5ms, nr_migrate=256
  RED          - BBR, tcp_fastopen, slow_start
  ALL          - Activar todas las categorías
  NONE         - Desactivar todas (volver a defaults Ubuntu)

COMANDOS:
  sudo ./benchmark-optimizer.sh enable MEMORIA
  sudo ./benchmark-optimizer.sh enable SCHEDULER
  sudo ./benchmark-optimizer.sh enable ALL
  sudo ./benchmark-optimizer.sh disable MEMORIA
  sudo ./benchmark-optimizer.sh disable ALL
  sudo ./benchmark-optimizer.sh status

WORKFLOW RECOMENDADO DE TESTING:
  1. Benchmark baseline sin optimizaciones
     $ sudo ./benchmark-optimizer.sh disable ALL
     $ <ejecutar tu benchmark>
  
  2. Activar una categoría y medir
     $ sudo ./benchmark-optimizer.sh enable MEMORIA
     $ <ejecutar tu benchmark>
     $ <comparar resultados>
  
  3. Repetir con cada categoría para aislar el efecto
  
  4. Activar combinaciones
     $ sudo ./benchmark-optimizer.sh enable MEMORIA
     $ sudo ./benchmark-optimizer.sh enable RED
     $ <ejecutar benchmark>

NOTA: Los cambios son inmediatos, no requieren reinicio

EJEMPLOS DE BENCHMARKS:
  - Compilación:  time make -j$(nproc)
  - I/O:          fio --name=test --rw=randread --size=1G
  - Red:          iperf3 -c <server>
  - Boot:         systemd-analyze
  - Memoria:      sysbench memory run

EOF
}

enable_memoria() {
    sed -i 's/^#vm.swappiness = 1/vm.swappiness = 1/' "$SYSCTL_FILE"
    sed -i 's/^#vm.page-cluster = 0/vm.page-cluster = 0/' "$SYSCTL_FILE"
    sysctl -p "$SYSCTL_FILE" 2>&1 | grep -E "swappiness|page-cluster"
    echo "✓ MEMORIA activada"
}

disable_memoria() {
    sed -i 's/^vm.swappiness = 1/#vm.swappiness = 1/' "$SYSCTL_FILE"
    sed -i 's/^vm.page-cluster = 0/#vm.page-cluster = 0/' "$SYSCTL_FILE"
    sysctl -w vm.swappiness=60 > /dev/null
    sysctl -w vm.page-cluster=3 > /dev/null
    echo "✓ MEMORIA desactivada (defaults Ubuntu: swappiness=60, page-cluster=3)"
}

enable_fs_cache() {
    sed -i 's/^#vm.vfs_cache_pressure = 50/vm.vfs_cache_pressure = 50/' "$SYSCTL_FILE"
    sysctl -p "$SYSCTL_FILE" 2>&1 | grep "vfs_cache_pressure"
    echo "✓ FS_CACHE activada"
}

disable_fs_cache() {
    sed -i 's/^vm.vfs_cache_pressure = 50/#vm.vfs_cache_pressure = 50/' "$SYSCTL_FILE"
    sysctl -w vm.vfs_cache_pressure=100 > /dev/null
    echo "✓ FS_CACHE desactivada (default Ubuntu: 100)"
}

enable_scheduler() {
    sed -i 's/^#kernel.sched_migration_cost_ns = 5000000/kernel.sched_migration_cost_ns = 5000000/' "$SYSCTL_FILE"
    sed -i 's/^#kernel.sched_nr_migrate = 256/kernel.sched_nr_migrate = 256/' "$SYSCTL_FILE"
    sysctl -p "$SYSCTL_FILE" 2>&1 | grep -E "sched_migration|sched_nr_migrate"
    echo "✓ SCHEDULER activado"
}

disable_scheduler() {
    sed -i 's/^kernel.sched_migration_cost_ns = 5000000/#kernel.sched_migration_cost_ns = 5000000/' "$SYSCTL_FILE"
    sed -i 's/^kernel.sched_nr_migrate = 256/#kernel.sched_nr_migrate = 256/' "$SYSCTL_FILE"
    sysctl -w kernel.sched_migration_cost_ns=500000 > /dev/null
    sysctl -w kernel.sched_nr_migrate=32 > /dev/null
    echo "✓ SCHEDULER desactivado (defaults Ubuntu: migration=500000, nr_migrate=32)"
}

enable_red() {
    sed -i 's/^#net.core.default_qdisc = fq/net.core.default_qdisc = fq/' "$SYSCTL_FILE"
    sed -i 's/^#net.ipv4.tcp_congestion_control = bbr/net.ipv4.tcp_congestion_control = bbr/' "$SYSCTL_FILE"
    sed -i 's/^#net.ipv4.tcp_fastopen = 3/net.ipv4.tcp_fastopen = 3/' "$SYSCTL_FILE"
    sed -i 's/^#net.ipv4.tcp_slow_start_after_idle = 0/net.ipv4.tcp_slow_start_after_idle = 0/' "$SYSCTL_FILE"
    sysctl -p "$SYSCTL_FILE" 2>&1 | grep -E "qdisc|congestion|fastopen|slow_start"
    echo "✓ RED (BBR) activada"
}

disable_red() {
    sed -i 's/^net.core.default_qdisc = fq/#net.core.default_qdisc = fq/' "$SYSCTL_FILE"
    sed -i 's/^net.ipv4.tcp_congestion_control = bbr/#net.ipv4.tcp_congestion_control = bbr/' "$SYSCTL_FILE"
    sed -i 's/^net.ipv4.tcp_fastopen = 3/#net.ipv4.tcp_fastopen = 3/' "$SYSCTL_FILE"
    sed -i 's/^net.ipv4.tcp_slow_start_after_idle = 0/#net.ipv4.tcp_slow_start_after_idle = 0/' "$SYSCTL_FILE"
    sysctl -w net.core.default_qdisc=fq_codel > /dev/null
    sysctl -w net.ipv4.tcp_congestion_control=cubic > /dev/null
    sysctl -w net.ipv4.tcp_fastopen=1 > /dev/null
    sysctl -w net.ipv4.tcp_slow_start_after_idle=1 > /dev/null
    echo "✓ RED desactivada (defaults Ubuntu: cubic, fq_codel)"
}

show_status() {
    echo "════════════════════════════════════════════════════════════════"
    echo "  ESTADO ACTUAL DE OPTIMIZACIONES"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    echo "MEMORIA:"
    echo "  swappiness:      $(sysctl -n vm.swappiness) (Ubuntu default: 60)"
    echo "  page-cluster:    $(sysctl -n vm.page-cluster) (Ubuntu default: 3)"
    echo ""
    echo "FS_CACHE:"
    echo "  vfs_cache_pressure: $(sysctl -n vm.vfs_cache_pressure) (Ubuntu default: 100)"
    echo ""
    echo "SCHEDULER:"
    echo "  migration_cost:  $(sysctl -n kernel.sched_migration_cost_ns) (Ubuntu default: 500000)"
    echo "  nr_migrate:      $(sysctl -n kernel.sched_nr_migrate) (Ubuntu default: 32)"
    echo "  autogroup:       $(sysctl -n kernel.sched_autogroup_enabled) (siempre activo)"
    echo ""
    echo "RED:"
    echo "  qdisc:           $(sysctl -n net.core.default_qdisc) (Ubuntu default: fq_codel)"
    echo "  congestion:      $(sysctl -n net.ipv4.tcp_congestion_control) (Ubuntu default: cubic)"
    echo "  fastopen:        $(sysctl -n net.ipv4.tcp_fastopen) (Ubuntu default: 1)"
    echo ""
    echo "ARQUITECTURA:"
    if [ -f /etc/sysctl.d/99-performance-arch.conf ]; then
        grep -v "^#" /etc/sysctl.d/99-performance-arch.conf | grep -v "^$"
    else
        echo "  (no detectada)"
    fi
    echo ""
    echo "════════════════════════════════════════════════════════════════"
}

# Main
if [ "$EUID" -ne 0 ]; then 
    echo "Error: Este script debe ejecutarse como root (sudo)"
    exit 1
fi

if [ ! -f "$SYSCTL_FILE" ]; then
    echo "Error: Archivo $SYSCTL_FILE no encontrado"
    echo "Ejecuta primero el módulo 20 del instalador"
    exit 1
fi

ACTION=$1
CATEGORY=$2

case "$ACTION" in
    enable)
        case "$CATEGORY" in
            MEMORIA)     enable_memoria ;;
            FS_CACHE)    enable_fs_cache ;;
            SCHEDULER)   enable_scheduler ;;
            RED)         enable_red ;;
            ALL)
                enable_memoria
                enable_fs_cache
                enable_scheduler
                enable_red
                echo ""
                echo "✓ Todas las optimizaciones activadas"
                ;;
            *)
                echo "Categoría desconocida: $CATEGORY"
                show_help
                exit 1
                ;;
        esac
        ;;
    disable)
        case "$CATEGORY" in
            MEMORIA)     disable_memoria ;;
            FS_CACHE)    disable_fs_cache ;;
            SCHEDULER)   disable_scheduler ;;
            RED)         disable_red ;;
            ALL)
                disable_memoria
                disable_fs_cache
                disable_scheduler
                disable_red
                echo ""
                echo "✓ Todas las optimizaciones desactivadas (defaults Ubuntu)"
                ;;
            *)
                echo "Categoría desconocida: $CATEGORY"
                show_help
                exit 1
                ;;
        esac
        ;;
    status)
        show_status
        ;;
    *)
        show_help
        exit 1
        ;;
esac


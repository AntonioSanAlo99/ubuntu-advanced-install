#!/bin/bash
# Módulo 21-laptop-advanced: Gestión avanzada multi-vendor (OPCIONAL)

set -e  # Exit on error


# Variables se pasan desde install.sh via environment
# source "$(dirname "$0")/../config.env"

echo "════════════════════════════════════════════════════════════════"
echo "  GESTIÓN AVANZADA DE LAPTOP (OPCIONAL)"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Este módulo instala herramientas avanzadas de gestión:"
echo "  • Undervolt para CPU Intel (si disponible)"
echo "  • Control de ventiladores (multi-vendor)"
echo "  • Monitoreo de temperaturas"
echo ""
warn "️  ADVERTENCIA:"
echo "  Undervolt puede causar inestabilidad si se configura mal."
echo "  Solo para usuarios con conocimiento de su hardware."
echo ""

read -p "¿Instalar herramientas avanzadas? (s/n) [n]: " INSTALL_ADVANCED
INSTALL_ADVANCED=${INSTALL_ADVANCED:-n}

if [ "$INSTALL_ADVANCED" != "s" ] && [ "$INSTALL_ADVANCED" != "S" ]; then
    step " Gestión avanzada omitida"
    exit 0
fi

# ============================================================================
# DETECCIÓN DE HARDWARE
# ============================================================================

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  DETECCIÓN DE HARDWARE"
echo "════════════════════════════════════════════════════════════════"
echo ""

# CPU Vendor
CPU_VENDOR=""
if grep -q "Intel" /proc/cpuinfo; then
    CPU_VENDOR="Intel"
    CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
    step " CPU Intel detectada: $CPU_MODEL"
elif grep -q "AMD" /proc/cpuinfo; then
    CPU_VENDOR="AMD"
    CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
    step " CPU AMD detectada: $CPU_MODEL"
else
    warn " CPU no reconocida"
    CPU_VENDOR="Unknown"
fi

# Laptop Vendor
LAPTOP_VENDOR="Generic"
LAPTOP_MODEL=""

if command -v dmidecode >/dev/null 2>&1; then
    LAPTOP_VENDOR=$(dmidecode -s system-manufacturer 2>/dev/null | head -1 | tr '[:upper:]' '[:lower:]')
    LAPTOP_MODEL=$(dmidecode -s system-product-name 2>/dev/null | head -1)
    
    step " Laptop: $LAPTOP_VENDOR $LAPTOP_MODEL"
    
    # Detectar marcas específicas
    if echo "$LAPTOP_VENDOR" | grep -qi "lenovo"; then
        LAPTOP_VENDOR="lenovo"
    elif echo "$LAPTOP_VENDOR" | grep -qi "dell"; then
        LAPTOP_VENDOR="dell"
    elif echo "$LAPTOP_VENDOR" | grep -qi "hp\|hewlett"; then
        LAPTOP_VENDOR="hp"
    elif echo "$LAPTOP_VENDOR" | grep -qi "asus"; then
        LAPTOP_VENDOR="asus"
    elif echo "$LAPTOP_VENDOR" | grep -qi "acer"; then
        LAPTOP_VENDOR="acer"
    else
        LAPTOP_VENDOR="generic"
    fi
fi

# Detectar ThinkPad específicamente
IS_THINKPAD=false
if echo "$LAPTOP_MODEL" | grep -qi "thinkpad"; then
    IS_THINKPAD=true
    echo "  → ThinkPad detectado (soporte específico disponible)"
fi

echo ""

# ============================================================================
# PARTE 1: INTEL UNDERVOLT (solo Intel)
# ============================================================================

if [ "$CPU_VENDOR" = "Intel" ]; then
    echo "════════════════════════════════════════════════════════════════"
    echo "  INTEL UNDERVOLT"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    echo "El undervolt reduce el voltaje de la CPU para:"
    echo "  • Reducir temperaturas (5-15°C típico)"
    echo "  • Mejorar rendimiento sostenido"
    echo "  • Reducir consumo de batería"
    echo ""
    warn "️  IMPORTANTE:"
    echo "  • Valores muy agresivos causan inestabilidad/crashes"
    echo "  • Se ofrecen valores CONSERVADORES por defecto"
    echo "  • Usuarios avanzados pueden personalizar"
    echo ""
    
    read -p "¿Configurar Intel Undervolt? (s/n) [n]: " SETUP_UNDERVOLT
    SETUP_UNDERVOLT=${SETUP_UNDERVOLT:-n}
    
    if [ "$SETUP_UNDERVOLT" = "s" ] || [ "$SETUP_UNDERVOLT" = "S" ]; then
        
        # Preguntar nivel de experiencia
        echo ""
        echo "Nivel de experiencia:"
        echo "  1) Principiante - Valores CONSERVADORES (MÁS SEGURO)"
        echo "  2) Intermedio  - Valores MODERADOS"
        echo "  3) Avanzado    - Personalizar valores"
        echo ""
        read -p "Selecciona nivel (1/2/3) [1]: " UV_LEVEL
        UV_LEVEL=${UV_LEVEL:-1}
        
        # Valores según nivel
        case $UV_LEVEL in
            1)  # CONSERVADOR - MUY SEGURO
                UV_CPU=-50
                UV_GPU=-40
                UV_CACHE=-50
                UV_SA=-30
                UV_IO=-30
                echo ""
                step " Nivel CONSERVADOR seleccionado:"
                echo "  CPU: ${UV_CPU}mV (muy seguro)"
                echo "  GPU: ${UV_GPU}mV (muy seguro)"
                echo "  Cache: ${UV_CACHE}mV (muy seguro)"
                ;;
            2)  # MODERADO - SEGURO
                UV_CPU=-70
                UV_GPU=-55
                UV_CACHE=-70
                UV_SA=-40
                UV_IO=-40
                echo ""
                step " Nivel MODERADO seleccionado:"
                echo "  CPU: ${UV_CPU}mV (seguro para mayoría)"
                echo "  GPU: ${UV_GPU}mV (seguro para mayoría)"
                echo "  Cache: ${UV_CACHE}mV (seguro para mayoría)"
                ;;
            3)  # AVANZADO - PERSONALIZADO
                echo ""
                echo "════════════════════════════════════════════════════════════════"
                echo "  CONFIGURACIÓN PERSONALIZADA"
                echo "════════════════════════════════════════════════════════════════"
                echo ""
                echo "Rangos recomendados:"
                echo "  • Conservador: -30 a -60mV"
                echo "  • Moderado:    -60 a -90mV"
                echo "  • Agresivo:    -90 a -120mV"
                echo "  • Límite:      -150mV (riesgo inestabilidad)"
                echo ""
                warn "️  Validación activa: Se rechazarán valores peligrosos (>-150mV)"
                echo ""
                
                # CPU
                while true; do
                    read -p "Undervolt CPU (mV negativo) [-80]: " UV_CPU
                    UV_CPU=${UV_CPU:--80}
                    
                    # Validar rango
                    if [ "$UV_CPU" -gt 0 ]; then
                        warn "️  Error: Debe ser negativo"
                        continue
                    fi
                    if [ "$UV_CPU" -lt -150 ]; then
                        warn "️  Error: Demasiado agresivo (máximo -150mV)"
                        echo "    Valores tan altos causan crashes casi garantizados"
                        continue
                    fi
                    break
                done
                
                # GPU
                while true; do
                    read -p "Undervolt GPU (mV negativo) [-60]: " UV_GPU
                    UV_GPU=${UV_GPU:--60}
                    if [ "$UV_GPU" -gt 0 ] || [ "$UV_GPU" -lt -150 ]; then
                        warn "️  Error: Rango válido: 0 a -150mV"
                        continue
                    fi
                    break
                done
                
                # Cache
                while true; do
                    read -p "Undervolt Cache (mV negativo) [-80]: " UV_CACHE
                    UV_CACHE=${UV_CACHE:--80}
                    if [ "$UV_CACHE" -gt 0 ] || [ "$UV_CACHE" -lt -150 ]; then
                        warn "️  Error: Rango válido: 0 a -150mV"
                        continue
                    fi
                    break
                done
                
                # SA/IO (automáticos, menos críticos)
                UV_SA=$((UV_CPU / 2))
                UV_IO=$((UV_CPU / 2))
                
                echo ""
                step " Valores personalizados:"
                echo "  CPU: ${UV_CPU}mV"
                echo "  GPU: ${UV_GPU}mV"
                echo "  Cache: ${UV_CACHE}mV"
                echo "  SA/IO: ${UV_SA}mV (automático)"
                ;;
            *)
                warn "️  Opción inválida, usando valores conservadores"
                UV_CPU=-50
                UV_GPU=-40
                UV_CACHE=-50
                UV_SA=-30
                UV_IO=-30
                ;;
        esac
        
        echo ""
        echo "Instalando intel-undervolt..."
        
        arch-chroot "$TARGET" /bin/bash << UVEOF
export DEBIAN_FRONTEND=noninteractive

# Instalar intel-undervolt
apt install -y intel-undervolt

# Configurar /etc/intel-undervolt.conf
cat > /etc/intel-undervolt.conf << 'EOF'
# Intel Undervolt Configuration
# Generado por Ubuntu Advanced Installer
# Valores seguros validados

# Undervolt values (mV)
undervolt 0 'CPU' $UV_CPU
undervolt 1 'GPU' $UV_GPU
undervolt 2 'CPU Cache' $UV_CACHE
undervolt 3 'System Agent' $UV_SA
undervolt 4 'Analog I/O' $UV_IO

# Enable on boot
enable-on-boot yes
EOF

# Aplicar undervolt
intel-undervolt apply || true

# Habilitar servicio
systemctl enable intel-undervolt.service

step " Intel Undervolt configurado"

UVEOF
        
        echo ""
        echo "════════════════════════════════════════════════════════════════"
        echo "  INTEL UNDERVOLT CONFIGURADO"
        echo "════════════════════════════════════════════════════════════════"
        echo ""
        echo "Valores aplicados:"
        echo "  CPU:   ${UV_CPU}mV"
        echo "  GPU:   ${UV_GPU}mV"
        echo "  Cache: ${UV_CACHE}mV"
        echo ""
        warn "️  IMPORTANTE - PRÓXIMOS PASOS:"
        echo ""
        echo "1. Después del primer arranque, PRUEBA ESTABILIDAD:"
        echo "   stress-ng --cpu 0 --timeout 10m"
        echo ""
        echo "2. Si hay crashes/freezes:"
        echo "   - Reduce valores en 10-20mV"
        echo "   - Edita: /etc/intel-undervolt.conf"
        echo "   - Aplica: sudo intel-undervolt apply"
        echo ""
        echo "3. Monitoreo de temperaturas:"
        echo "   watch -n1 sensors"
        echo ""
        echo "════════════════════════════════════════════════════════════════"
        echo ""
        
    else
        step " Intel Undervolt omitido"
    fi
else
    echo "════════════════════════════════════════════════════════════════"
    echo "  INTEL UNDERVOLT NO DISPONIBLE"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    echo "CPU $CPU_VENDOR detectada - Undervolt solo soportado en Intel"
    echo ""
fi

# ============================================================================
# PARTE 2: CONTROL DE VENTILADORES (Multi-vendor)
# ============================================================================

echo "════════════════════════════════════════════════════════════════"
echo "  CONTROL DE VENTILADORES"
echo "════════════════════════════════════════════════════════════════"
echo ""

read -p "¿Configurar control de ventiladores? (s/n) [n]: " SETUP_FANS
SETUP_FANS=${SETUP_FANS:-n}

if [ "$SETUP_FANS" = "s" ] || [ "$SETUP_FANS" = "S" ]; then
    
    echo ""
    echo "Detectando soporte de ventiladores..."
    echo ""
    
    FAN_METHOD="none"
    
    # Opción 1: ThinkPad (thinkfan)
    if [ "$IS_THINKPAD" = true ]; then
        step " ThinkPad detectado - Usando ThinkFan"
        FAN_METHOD="thinkfan"
        
    # Opción 2: Dell (i8kutils)
    elif [ "$LAPTOP_VENDOR" = "dell" ]; then
        step " Dell detectado - Usando i8kutils"
        FAN_METHOD="i8k"
        
    # Opción 3: HP (Verificar soporte)
    elif [ "$LAPTOP_VENDOR" = "hp" ]; then
        if [ -d /sys/devices/platform/hp-wmi ]; then
            step " HP con soporte WMI - Usando lm-sensors"
            FAN_METHOD="lm-sensors"
        else
            warn "️  HP detectado pero sin soporte específico"
            FAN_METHOD="lm-sensors"
        fi
        
    # Opción 4: ASUS (asus-nb-ctrl o lm-sensors)
    elif [ "$LAPTOP_VENDOR" = "asus" ]; then
        step " ASUS detectado - Usando lm-sensors + fancontrol"
        FAN_METHOD="lm-sensors"
        
    # Opción 5: Generic (lm-sensors)
    else
        step " Laptop genérico - Intentando lm-sensors"
        FAN_METHOD="lm-sensors"
    fi
    
    echo "  Método seleccionado: $FAN_METHOD"
    echo ""
    
    # Instalar según método
    case $FAN_METHOD in
        thinkfan)
            echo "Instalando ThinkFan (ThinkPad)..."
            arch-chroot "$TARGET" /bin/bash << 'THINKEOF'
export DEBIAN_FRONTEND=noninteractive

apt install -y thinkfan

# Habilitar módulo del kernel
echo "options thinkpad_acpi fan_control=1" > /etc/modprobe.d/thinkfan.conf

# Configuración básica
cat > /etc/thinkfan.conf << 'EOF'
# ThinkFan Configuration
# Generado por Ubuntu Advanced Installer

sensors:
  - hwmon: /sys/class/hwmon
    name: coretemp
    indices: [1, 2, 3, 4]

fans:
  - tpacpi: /proc/acpi/ibm/fan

levels:
  - [0, 0, 50]      # Fan off hasta 50°C
  - [1, 48, 55]     # Nivel 1
  - [2, 52, 60]     # Nivel 2
  - [3, 56, 65]     # Nivel 3
  - [4, 60, 70]     # Nivel 4
  - [5, 65, 75]     # Nivel 5
  - [7, 70, 85]     # Nivel 7 (alto)
  - ["level full-speed", 80, 32767]  # Máximo >80°C
EOF

# Habilitar servicio
systemctl enable thinkfan.service

step " ThinkFan configurado"
THINKEOF
            ;;
            
        i8k)
            echo "Instalando i8kutils (Dell)..."
            arch-chroot "$TARGET" /bin/bash << 'DELLEOF'
export DEBIAN_FRONTEND=noninteractive

apt install -y i8kutils

# Cargar módulo
echo "dell_smm_hwmon" > /etc/modules-load.d/dell-fan.conf

# Configuración básica
cat > /etc/i8kmon.conf << 'EOF'
# i8kmon configuration for Dell laptops

set config(daemon) 1
set config(auto) 1

# Temperature thresholds (adjust for your model)
set config(0) {{0 0} -1 55 -1 55}
set config(1) {{1 1} 50 60 50 60}
set config(2) {{2 2} 55 70 55 70}
set config(3) {{2 2} 65 128 65 128}
EOF

systemctl enable i8kmon.service

step " i8kutils configurado"
DELLEOF
            ;;
            
        lm-sensors)
            echo "Instalando lm-sensors + fancontrol..."
            arch-chroot "$TARGET" /bin/bash << 'SENSEOF'
export DEBIAN_FRONTEND=noninteractive

apt install -y lm-sensors fancontrol

step " lm-sensors instalado"
echo ""
warn "️  CONFIGURACIÓN MANUAL REQUERIDA:"
echo "    Después del primer arranque ejecuta:"
echo "    sudo sensors-detect"
echo "    sudo pwmconfig"
SENSEOF
            ;;
            
        *)
            warn "️  No se pudo determinar método de control de ventiladores"
            echo "    El sistema usará control automático por BIOS"
            ;;
    esac
    
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "  CONTROL DE VENTILADORES CONFIGURADO"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    echo "Método: $FAN_METHOD"
    echo "Vendor: $LAPTOP_VENDOR"
    
    if [ "$FAN_METHOD" = "thinkfan" ]; then
        echo ""
        echo "Configuración ThinkFan:"
        echo "  • Archivo: /etc/thinkfan.conf"
        echo "  • Servicio: thinkfan.service"
        echo "  • Logs: journalctl -u thinkfan"
    elif [ "$FAN_METHOD" = "i8k" ]; then
        echo ""
        echo "Configuración Dell i8k:"
        echo "  • Archivo: /etc/i8kmon.conf"
        echo "  • Servicio: i8kmon.service"
    elif [ "$FAN_METHOD" = "lm-sensors" ]; then
        echo ""
        warn "️  Requiere configuración manual:"
        echo "  1. sudo sensors-detect (detectar sensores)"
        echo "  2. sudo pwmconfig (configurar ventiladores)"
    fi
    
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    
else
    step " Control de ventiladores omitido"
fi

# ============================================================================
# PARTE 3: THERMALD (Intel genérico)
# ============================================================================

if [ "$CPU_VENDOR" = "Intel" ]; then
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "  THERMALD (Intel Thermal Daemon)"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    echo "Thermald gestiona la temperatura automáticamente en CPUs Intel"
    echo ""
    
    read -p "¿Instalar thermald? (s/n) [s]: " INSTALL_THERMALD
    INSTALL_THERMALD=${INSTALL_THERMALD:-s}
    
    if [ "$INSTALL_THERMALD" = "s" ] || [ "$INSTALL_THERMALD" = "S" ]; then
        arch-chroot "$TARGET" /bin/bash << 'THERMALEOF'
export DEBIAN_FRONTEND=noninteractive

apt install -y thermald

systemctl enable thermald.service

step " Thermald instalado y habilitado"
THERMALEOF
        step " Thermald configurado"
    else
        step " Thermald omitido"
    fi
fi

# ============================================================================
# RESUMEN FINAL
# ============================================================================

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  GESTIÓN AVANZADA DE LAPTOP COMPLETADA"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Hardware detectado:"
echo "  • CPU: $CPU_VENDOR"
echo "  • Laptop: $LAPTOP_VENDOR"
[ "$IS_THINKPAD" = true ] && echo "  • ThinkPad: Sí"
echo ""

if [ "$SETUP_UNDERVOLT" = "s" ] || [ "$SETUP_UNDERVOLT" = "S" ]; then
    step " Intel Undervolt configurado"
fi

if [ "$SETUP_FANS" = "s" ] || [ "$SETUP_FANS" = "S" ]; then
    step " Control ventiladores: $FAN_METHOD"
fi

if [ "$INSTALL_THERMALD" = "s" ] || [ "$INSTALL_THERMALD" = "S" ]; then
    step " Thermald habilitado"
fi

echo ""
echo "════════════════════════════════════════════════════════════════"
echo ""

exit 0

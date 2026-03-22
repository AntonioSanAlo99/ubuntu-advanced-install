#!/bin/bash
# Script de validación y corrección del instalador
# Verifica que todo esté correcto antes de ejecutar

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "════════════════════════════════════════════════════════════════"
echo "  VALIDACIÓN DEL INSTALADOR UBUNTU"
echo "════════════════════════════════════════════════════════════════"
echo ""

ERRORS=0
WARNINGS=0

# ============================================================================
# 1. VERIFICAR ESTRUCTURA DE DIRECTORIOS
# ============================================================================

echo "[1/8] Verificando estructura de directorios..."

required_dirs=(
    "modules"
    "docs"
    "files"
    "tools"
    "logs"
)

for dir in "${required_dirs[@]}"; do
    if [ ! -d "$dir" ]; then
        echo "  ✗ Falta directorio: $dir"
        mkdir -p "$dir"
        echo "    → Creado"
    else
        echo "  ✓ $dir"
    fi
done

echo ""

# ============================================================================
# 2. VERIFICAR ARCHIVOS PRINCIPALES
# ============================================================================

echo "[2/8] Verificando archivos principales..."

if [ ! -f "install.sh" ]; then
    echo "  ✗ CRÍTICO: Falta install.sh"
    ((ERRORS++))
else
    echo "  ✓ install.sh"
    # Verificar que sea ejecutable
    if [ ! -x "install.sh" ]; then
        chmod +x install.sh
        echo "    → Permisos de ejecución añadidos"
    fi
fi

if [ ! -f "config.env" ]; then
    if [ -f "config.env.example" ]; then
        cp config.env.example config.env
        echo "  ✓ config.env creado desde example"
    else
        echo "  ✗ ADVERTENCIA: Falta config.env"
        ((WARNINGS++))
    fi
else
    echo "  ✓ config.env"
fi

if [ ! -f "README.md" ]; then
    echo "  ✗ ADVERTENCIA: Falta README.md"
    ((WARNINGS++))
else
    echo "  ✓ README.md"
fi

echo ""

# ============================================================================
# 3. VERIFICAR MÓDULOS CRÍTICOS
# ============================================================================

echo "[3/8] Verificando módulos críticos..."

critical_modules=(
    "00-check-dependencies"
    "01-prepare-disk"
    "02-debootstrap"
    "03-configure-base"
    "04-install-bootloader"
    "05-configure-network"
)

for mod in "${critical_modules[@]}"; do
    if [ ! -f "modules/$mod.sh" ]; then
        echo "  ✗ CRÍTICO: Falta módulo $mod.sh"
        ((ERRORS++))
    else
        echo "  ✓ $mod.sh"
        # Verificar permisos
        if [ ! -x "modules/$mod.sh" ]; then
            chmod +x "modules/$mod.sh"
            echo "    → Permisos añadidos"
        fi
    fi
done

echo ""

# ============================================================================
# 4. VERIFICAR MÓDULOS OPCIONALES
# ============================================================================

echo "[4/8] Verificando módulos opcionales..."

optional_modules=(
    "10-install-gnome-core"
    "15-install-development"
    "16-configure-gaming"
    "21-optimize-laptop"
    "23-minimize-systemd"
    "24-security-hardening"
)

for mod in "${optional_modules[@]}"; do
    if [ -f "modules/$mod.sh" ]; then
        echo "  ✓ $mod.sh"
        # Verificar permisos
        if [ ! -x "modules/$mod.sh" ]; then
            chmod +x "modules/$mod.sh"
        fi
    else
        echo "  ⚠ Opcional no encontrado: $mod.sh"
    fi
done

echo ""

# ============================================================================
# 5. VERIFICAR SINTAXIS DE BASH EN MÓDULOS
# ============================================================================

echo "[5/8] Verificando sintaxis de módulos..."

syntax_errors=0
for module in modules/*.sh; do
    if [ -f "$module" ]; then
        if bash -n "$module" 2>/dev/null; then
            echo "  ✓ $(basename $module)"
        else
            echo "  ✗ Error de sintaxis: $(basename $module)"
            ((syntax_errors++))
            ((ERRORS++))
        fi
    fi
done

if [ $syntax_errors -eq 0 ]; then
    echo "  → Todos los módulos tienen sintaxis correcta"
fi

echo ""

# ============================================================================
# 6. VERIFICAR config.env
# ============================================================================

echo "[6/8] Verificando config.env..."

if [ -f "config.env" ]; then
    # Verificar variables requeridas
    required_vars=(
        "UBUNTU_VERSION"
        "HOSTNAME"
        "USERNAME"
        "TARGET"
    )
    
    source config.env
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            echo "  ✗ Variable no definida: $var"
            ((WARNINGS++))
        else
            echo "  ✓ $var=${!var}"
        fi
    done
else
    echo "  ✗ config.env no existe"
    ((ERRORS++))
fi

echo ""

# ============================================================================
# 7. VERIFICAR FUNCIONES EN install.sh
# ============================================================================

echo "[7/8] Verificando funciones en install.sh..."

if [ -f "install.sh" ]; then
    required_functions=(
        "log_step"
        "log_success"
        "log_error"
        "log_warning"
        "log_info"
        "check_root"
        "run_module"
        "show_menu"
        "load_or_create_config"
        "full_automatic_install"
        "full_interactive_install"
    )
    
    for func in "${required_functions[@]}"; do
        if grep -q "^$func()" install.sh; then
            echo "  ✓ Función: $func"
        else
            echo "  ✗ Función no encontrada: $func"
            ((ERRORS++))
        fi
    done
fi

echo ""

# ============================================================================
# 8. VERIFICAR DOCUMENTACIÓN
# ============================================================================

echo "[8/8] Verificando documentación..."

docs_files=(
    "docs/README.md"
    "docs/CHANGELOG.md"
    "docs/ROADMAP.md"
    "docs/ARCHITECTURE.md"
)

for doc in "${docs_files[@]}"; do
    if [ -f "$doc" ]; then
        echo "  ✓ $(basename $doc)"
    else
        echo "  ⚠ Falta: $(basename $doc)"
        ((WARNINGS++))
    fi
done

echo ""

# ============================================================================
# RESUMEN FINAL
# ============================================================================

echo "════════════════════════════════════════════════════════════════"
echo "  RESUMEN DE VALIDACIÓN"
echo "════════════════════════════════════════════════════════════════"
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo "✓ PERFECTO: Sistema listo para instalación"
    echo ""
    echo "Puedes ejecutar:"
    echo "  sudo bash install.sh              # Menú interactivo"
    echo "  sudo bash install.sh --auto       # Instalación automática"
    echo "  sudo bash install.sh --help       # Ver todas las opciones"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo "⚠ ADVERTENCIAS: $WARNINGS"
    echo "  El sistema puede funcionar pero revisa las advertencias"
    exit 0
else
    echo "✗ ERRORES CRÍTICOS: $ERRORS"
    echo "⚠ ADVERTENCIAS: $WARNINGS"
    echo ""
    echo "Corrige los errores antes de ejecutar la instalación"
    exit 1
fi

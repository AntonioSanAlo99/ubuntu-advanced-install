#!/bin/bash
# validate-module.sh - Sistema de validación post-ejecución de módulos

# Este script se sourcea al final de cada módulo para validar:
# - Errores silenciosos
# - Configuraciones duplicadas
# - Código no ejecutado
# - Directorios faltantes
# - Archivos no descargados

# ============================================================================
# VARIABLES GLOBALES DE VALIDACIÓN
# ============================================================================

VALIDATION_LOG="${LOG_FILE:-/tmp/module-validation.log}"
MODULE_NAME="${MODULE_NAME:-unknown}"
VALIDATION_ERRORS=0
VALIDATION_WARNINGS=0

# ============================================================================
# FUNCIONES DE VALIDACIÓN
# ============================================================================

validate_start() {
    local module="$1"
    MODULE_NAME="$module"
    echo "" >> "$VALIDATION_LOG"
    echo "════════════════════════════════════════════════════════════════" >> "$VALIDATION_LOG"
    echo "VALIDACIÓN: $MODULE_NAME" >> "$VALIDATION_LOG"
    echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')" >> "$VALIDATION_LOG"
    echo "════════════════════════════════════════════════════════════════" >> "$VALIDATION_LOG"
}

validate_error() {
    local message="$1"
    VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
    echo "[ERROR] $message" >> "$VALIDATION_LOG"
    echo -e "${RED}✗ VALIDACIÓN ERROR: $message${NC}" >&2
}

validate_warning() {
    local message="$1"
    VALIDATION_WARNINGS=$((VALIDATION_WARNINGS + 1))
    echo "[WARNING] $message" >> "$VALIDATION_LOG"
    echo -e "${YELLOW}⚠ VALIDACIÓN WARNING: $message${NC}" >&2
}

validate_ok() {
    local message="$1"
    echo "[OK] $message" >> "$VALIDATION_LOG"
}

# ============================================================================
# VALIDACIONES ESPECÍFICAS
# ============================================================================

# Verificar que directorio existe y no está vacío
validate_directory() {
    local dir="$1"
    local description="${2:-$dir}"
    
    if [ ! -d "$dir" ]; then
        validate_error "Directorio no existe: $description ($dir)"
        return 1
    fi
    
    if [ -z "$(ls -A "$dir" 2>/dev/null)" ]; then
        validate_warning "Directorio existe pero está vacío: $description ($dir)"
        return 1
    fi
    
    validate_ok "Directorio OK: $description ($dir)"
    return 0
}

# Verificar que archivo existe y tiene contenido
validate_file() {
    local file="$1"
    local description="${2:-$file}"
    
    if [ ! -f "$file" ]; then
        validate_error "Archivo no existe: $description ($file)"
        return 1
    fi
    
    if [ ! -s "$file" ]; then
        validate_warning "Archivo existe pero está vacío: $description ($file)"
        return 1
    fi
    
    validate_ok "Archivo OK: $description ($file)"
    return 0
}

# Verificar que paquete está instalado
validate_package() {
    local package="$1"
    local target="${2:-/}"
    
    if [ "$target" = "/" ]; then
        if ! dpkg -l "$package" 2>/dev/null | grep -q "^ii"; then
            validate_error "Paquete no instalado: $package"
            return 1
        fi
    else
        if ! arch-chroot "$target" dpkg -l "$package" 2>/dev/null | grep -q "^ii"; then
            validate_error "Paquete no instalado en $target: $package"
            return 1
        fi
    fi
    
    validate_ok "Paquete instalado: $package"
    return 0
}

# Verificar que servicio está habilitado
validate_service() {
    local service="$1"
    local target="${2:-/}"
    
    if [ "$target" = "/" ]; then
        if ! systemctl is-enabled "$service" &>/dev/null; then
            validate_error "Servicio no habilitado: $service"
            return 1
        fi
    else
        if ! arch-chroot "$target" systemctl is-enabled "$service" &>/dev/null; then
            validate_error "Servicio no habilitado en $target: $service"
            return 1
        fi
    fi
    
    validate_ok "Servicio habilitado: $service"
    return 0
}

# Verificar que dispositivo está montado
validate_mount() {
    local mountpoint="$1"
    
    if ! mountpoint -q "$mountpoint" 2>/dev/null; then
        validate_error "No montado: $mountpoint"
        return 1
    fi
    
    validate_ok "Montado: $mountpoint"
    return 0
}

# Buscar configuraciones duplicadas
validate_no_duplicate_config() {
    local file="$1"
    local key="$2"
    local description="${3:-$key en $file}"
    
    if [ ! -f "$file" ]; then
        return 0  # Archivo no existe, no hay duplicados
    fi
    
    local count=$(grep -c "^${key}" "$file" 2>/dev/null || echo "0")
    
    if [ "$count" -gt 1 ]; then
        validate_warning "Configuración duplicada: $description ($count veces)"
        return 1
    fi
    
    validate_ok "Sin duplicados: $description"
    return 0
}

# Verificar que comando existe y es ejecutable
validate_command() {
    local cmd="$1"
    local target="${2:-/}"
    
    if [ "$target" = "/" ]; then
        if ! command -v "$cmd" &>/dev/null; then
            validate_error "Comando no encontrado: $cmd"
            return 1
        fi
    else
        if ! arch-chroot "$target" command -v "$cmd" &>/dev/null; then
            validate_error "Comando no encontrado en $target: $cmd"
            return 1
        fi
    fi
    
    validate_ok "Comando disponible: $cmd"
    return 0
}

# Verificar que URL es accesible
validate_url() {
    local url="$1"
    local description="${2:-$url}"
    
    if ! curl -sfL -I "$url" -o /dev/null --connect-timeout 5; then
        validate_error "URL no accesible: $description ($url)"
        return 1
    fi
    
    validate_ok "URL accesible: $description"
    return 0
}

# Verificar descarga exitosa
validate_download() {
    local url="$1"
    local dest="$2"
    local description="${3:-$(basename "$dest")}"
    
    if [ ! -f "$dest" ]; then
        validate_error "Descarga falló: $description ($url -> $dest)"
        return 1
    fi
    
    if [ ! -s "$dest" ]; then
        validate_error "Descarga vacía: $description ($dest)"
        return 1
    fi
    
    validate_ok "Descarga exitosa: $description"
    return 0
}

# Verificar que usuario existe
validate_user() {
    local user="$1"
    local target="${2:-/}"
    
    if [ "$target" = "/" ]; then
        if ! id "$user" &>/dev/null; then
            validate_error "Usuario no existe: $user"
            return 1
        fi
    else
        if ! arch-chroot "$target" id "$user" &>/dev/null; then
            validate_error "Usuario no existe en $target: $user"
            return 1
        fi
    fi
    
    validate_ok "Usuario existe: $user"
    return 0
}

# Verificar permisos de archivo
validate_permissions() {
    local file="$1"
    local expected_perms="$2"
    local description="${3:-$file}"
    
    if [ ! -e "$file" ]; then
        validate_error "Archivo no existe para verificar permisos: $description"
        return 1
    fi
    
    local actual_perms=$(stat -c "%a" "$file" 2>/dev/null)
    
    if [ "$actual_perms" != "$expected_perms" ]; then
        validate_warning "Permisos incorrectos: $description (esperado: $expected_perms, actual: $actual_perms)"
        return 1
    fi
    
    validate_ok "Permisos correctos: $description ($expected_perms)"
    return 0
}

# Verificar espacio en disco
validate_disk_space() {
    local mountpoint="$1"
    local min_mb="$2"
    local description="${3:-$mountpoint}"
    
    local available_mb=$(df -m "$mountpoint" | awk 'NR==2 {print $4}')
    
    if [ "$available_mb" -lt "$min_mb" ]; then
        validate_warning "Espacio insuficiente: $description (disponible: ${available_mb}MB, mínimo: ${min_mb}MB)"
        return 1
    fi
    
    validate_ok "Espacio suficiente: $description (${available_mb}MB disponible)"
    return 0
}

# ============================================================================
# REPORTE FINAL
# ============================================================================

validate_report() {
    echo "" >> "$VALIDATION_LOG"
    echo "────────────────────────────────────────────────────────────────" >> "$VALIDATION_LOG"
    echo "RESUMEN DE VALIDACIÓN: $MODULE_NAME" >> "$VALIDATION_LOG"
    echo "Errores:      $VALIDATION_ERRORS" >> "$VALIDATION_LOG"
    echo "Advertencias: $VALIDATION_WARNINGS" >> "$VALIDATION_LOG"
    echo "────────────────────────────────────────────────────────────────" >> "$VALIDATION_LOG"
    
    if [ "$VALIDATION_ERRORS" -gt 0 ]; then
        echo -e "${RED}✗ Módulo $MODULE_NAME: $VALIDATION_ERRORS error(es), $VALIDATION_WARNINGS advertencia(s)${NC}"
        return 1
    elif [ "$VALIDATION_WARNINGS" -gt 0 ]; then
        echo -e "${YELLOW}⚠ Módulo $MODULE_NAME: $VALIDATION_WARNINGS advertencia(s)${NC}"
        return 0
    else
        echo -e "${GREEN}✓ Módulo $MODULE_NAME: Validación completa sin errores${NC}"
        return 0
    fi
}

# ============================================================================
# FUNCIÓN PRINCIPAL DE VALIDACIÓN
# ============================================================================

validate_module() {
    local module="$1"
    shift
    
    validate_start "$module"
    
    # Ejecutar todas las validaciones pasadas como argumentos
    while [ $# -gt 0 ]; do
        case "$1" in
            --dir)
                validate_directory "$2" "$3"
                shift 3 || shift $#
                ;;
            --file)
                validate_file "$2" "$3"
                shift 3 || shift $#
                ;;
            --package)
                validate_package "$2" "${3:-/}"
                shift 3 || shift $#
                ;;
            --service)
                validate_service "$2" "${3:-/}"
                shift 3 || shift $#
                ;;
            --mount)
                validate_mount "$2"
                shift 2 || shift $#
                ;;
            --no-dup)
                validate_no_duplicate_config "$2" "$3" "$4"
                shift 4 || shift $#
                ;;
            --command)
                validate_command "$2" "${3:-/}"
                shift 3 || shift $#
                ;;
            --url)
                validate_url "$2" "$3"
                shift 3 || shift $#
                ;;
            --download)
                validate_download "$2" "$3" "$4"
                shift 4 || shift $#
                ;;
            --user)
                validate_user "$2" "${3:-/}"
                shift 3 || shift $#
                ;;
            --perms)
                validate_permissions "$2" "$3" "$4"
                shift 4 || shift $#
                ;;
            --space)
                validate_disk_space "$2" "$3" "$4"
                shift 4 || shift $#
                ;;
            *)
                validate_warning "Argumento de validación desconocido: $1"
                shift
                ;;
        esac
    done
    
    validate_report
}

# Exportar funciones para uso en módulos
export -f validate_start
export -f validate_error
export -f validate_warning
export -f validate_ok
export -f validate_directory
export -f validate_file
export -f validate_package
export -f validate_service
export -f validate_mount
export -f validate_no_duplicate_config
export -f validate_command
export -f validate_url
export -f validate_download
export -f validate_user
export -f validate_permissions
export -f validate_disk_space
export -f validate_report
export -f validate_module

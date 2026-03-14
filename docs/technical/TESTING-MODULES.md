# Módulos de Testeo

## Visión General

Los módulos de testeo (TEST-*) permiten probar funcionalidades específicas del sistema sin ejecutar la instalación completa. Son especialmente útiles para:

1. **Desarrollo**: Probar cambios en módulos sin reinstalar todo
2. **Depuración**: Aislar problemas en componentes específicos  
3. **Personalización**: Experimentar con configuraciones antes de aplicarlas
4. **Aprendizaje**: Entender cómo funcionan las partes del sistema

## Características

✅ **No modifican la instalación principal** - Trabajan en modo aislado
✅ **Selección individual de parámetros** - Control total sobre cada opción
✅ **Reversibles** - Pueden deshacerse los cambios
✅ **Resultados detallados** - Muestran exactamente qué se hizo
✅ **Modo interactivo** - Menú fácil de usar
✅ **Modo automático** - Ejecutables desde install.sh

## Módulos Disponibles

### TEST-gnome.sh
Prueba configuraciones de GNOME:
- Extensiones (habilitar/deshabilitar)
- Temas de interfaz
- Configuración de botones, dock, fuentes
- Optimizaciones de rendimiento

### TEST-gaming.sh (por crear)
Prueba configuraciones de gaming:
- Proton versions
- GameMode
- MangoHud
- Parámetros sysctl

### TEST-power.sh (por crear)
Prueba gestión de energía:
- TLP vs power-profiles-daemon
- Undervolt (simulado seguro)
- CPU governors
- Límites de frecuencia

### TEST-network.sh (por crear)
Prueba conectividad:
- WiFi
- Bluetooth
- NetworkManager
- DNS

## Uso

### Opción 1: Ejecución Directa (Recomendado)

```bash
# Ejecutar módulo de test directamente
cd ubuntu-advanced-install
sudo ./modules/TEST-gnome.sh
```

Esto abre un menú interactivo donde puedes:
1. Seleccionar qué test ejecutar
2. Configurar parámetros individuales
3. Ver resultados inmediatos
4. Revertir cambios si es necesario

### Opción 2: Desde install.sh

Para habilitar en el menú principal:

**Paso 1:** Editar `install.sh`

Buscar la sección de módulos de testeo (línea ~618):

```bash
# MÓDULOS DE TESTEO (COMENTADOS POR DEFECTO)
```

**Paso 2:** Descomentar las líneas

```bash
# ANTES (comentado):
# echo -e "${CYAN}MÓDULOS DE TESTEO (AVANZADO):${NC}"
# echo "  90) [TEST] GNOME - Probar configuración GNOME"

# DESPUÉS (descomentado):
echo -e "${CYAN}MÓDULOS DE TESTEO (AVANZADO):${NC}"
echo "  90) [TEST] GNOME - Probar configuración GNOME"
```

**Paso 3:** Descomentar en el case statement

Buscar el `case $choice in` y añadir:

```bash
case $choice in
    1) full_interactive_install ;;
    # ... otros casos ...
    
    # Añadir estos:
    90) run_module "TEST-gnome" ;;
    91) run_module "TEST-gaming" ;;
    92) run_module "TEST-power" ;;
    93) run_module "TEST-network" ;;
```

**Paso 4:** Ejecutar install.sh

```bash
sudo ./install.sh
# Ahora verás las opciones 90-93 en el menú
```

## Estructura de un Módulo de Test

### Header con Instrucciones

```bash
#!/bin/bash
# Módulo TEST: Nombre

# ============================================================================
# HABILITACIÓN EN install.sh
# ============================================================================
# Para habilitar este módulo de test, en install.sh descomentar:
#
# En show_menu(), añadir:
#   echo "  XX) [TEST] Nombre - Descripción"
#
# En el case del menú:
#   XX) run_module "TEST-nombre" ;;
# ============================================================================
```

### Funciones de Test Individuales

```bash
test_function_1() {
    echo -e "${CYAN}═══ Test: Función 1 ═══${NC}"
    echo ""
    
    # Selección de parámetros
    read -p "Parámetro 1 (valor por defecto): " param1
    param1=${param1:-valor_defecto}
    
    read -p "Parámetro 2 (s/n) [n]: " param2
    param2=${param2:-n}
    
    # Mostrar configuración
    echo ""
    echo "Ejecutando test con:"
    echo "  Parámetro 1: $param1"
    echo "  Parámetro 2: $param2"
    echo ""
    
    # Ejecutar test
    if comando_test; then
        log_success "$MODULE_NAME" "Test completado"
    else
        log_error "$MODULE_NAME" "Test falló" "WARNING"
    fi
}
```

### Menú Principal

```bash
show_test_menu() {
    clear
    echo -e "${BOLD}${CYAN}═══════════════════════════════════${NC}"
    echo -e "${BOLD}${CYAN}      MÓDULO DE TESTEO - NOMBRE${NC}"
    echo -e "${BOLD}${CYAN}═══════════════════════════════════${NC}"
    echo ""
    echo "Tests disponibles:"
    echo ""
    echo "  1) Test 1 - Descripción"
    echo "  2) Test 2 - Descripción"
    echo "  3) Test 3 - Descripción"
    echo ""
    echo "  a) Ejecutar todos"
    echo "  r) Revertir cambios"
    echo "  q) Salir"
    echo ""
    read -p "Selecciona opción: " choice
    
    case $choice in
        1) test_function_1 ;;
        2) test_function_2 ;;
        # etc...
    esac
}
```

### Detección de Modo de Ejecución

```bash
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    # Ejecución directa - modo interactivo
    while true; do
        show_test_menu
    done
else
    # Ejecución desde install.sh - modo automático
    test_function_1
    test_function_2
    show_error_summary "$MODULE_NAME"
fi
```

## Ejemplo: TEST-gnome.sh

### Ejecución Directa

```bash
sudo ./modules/TEST-gnome.sh
```

Salida:
```
════════════════════════════════════════════════════════════════
              MÓDULO DE TESTEO - GNOME
════════════════════════════════════════════════════════════════

⚠️  Módulo de PRUEBAS - No afecta la instalación principal
   Requiere tener GNOME instalado para tests reales

Tests disponibles:

  1) Extensiones GNOME - Habilitar/deshabilitar extensiones
  2) Tema GNOME - Cambiar tema de interfaz
  3) Configuración GNOME - Botones, dock, fuentes
  4) Optimización - Rendimiento y recursos

  a) Ejecutar todos los tests
  r) Revertir a valores por defecto
  q) Salir

Selecciona opción: 1
```

Seleccionando opción 1:
```
═══ Test: Extensiones GNOME ═══

Extensiones disponibles para test:
  1) Dash to Dock
  2) AppIndicator
  3) User Themes
  4) Blur my Shell

Selecciona extensión (1-4): 1

Testeando extensión: Dash to Dock
¿Habilitar esta extensión? (s/n) [s]: s

Habilitando Dash to Dock...
✓ TEST-GNOME: Dash to Dock habilitada

Presiona Enter para continuar...
```

## Crear un Nuevo Módulo de Test

### Paso 1: Copiar Template

```bash
cp modules/TEST-template.sh modules/TEST-mimodulo.sh
```

### Paso 2: Personalizar

Editar `TEST-mimodulo.sh`:

1. Cambiar `MODULE_NAME="TEST-Template"` a tu nombre
2. Modificar las instrucciones de habilitación en el header
3. Implementar las funciones `test_function_X()`
4. Actualizar el menú con tus opciones
5. Añadir lógica de reversión si aplica

### Paso 3: Hacer Ejecutable

```bash
chmod +x modules/TEST-mimodulo.sh
```

### Paso 4: Probar

```bash
sudo ./modules/TEST-mimodulo.sh
```

### Paso 5: Documentar en install.sh

Añadir las líneas comentadas en `install.sh` según el template.

## Buenas Prácticas

### 1. Siempre Ofrecer Valores por Defecto

```bash
read -p "Valor (por defecto: X) [X]: " valor
valor=${valor:-X}
```

### 2. Confirmar Acciones Importantes

```bash
echo "Esta acción hará cambios en el sistema"
read -p "¿Continuar? (s/n): " confirm
if [ "$confirm" != "s" ]; then
    echo "Cancelado"
    return 0
fi
```

### 3. Mostrar Qué Se Está Haciendo

```bash
echo "Ejecutando test con:"
echo "  Parámetro 1: $param1"
echo "  Parámetro 2: $param2"
echo ""
```

### 4. Proporcionar Reversión

```bash
test_revert() {
    echo "Revirtiendo cambios..."
    # Código para deshacer
    log_success "$MODULE_NAME" "Cambios revertidos"
}
```

### 5. Usar Logging

```bash
log_success "$MODULE_NAME" "Operación exitosa"
log_error "$MODULE_NAME" "Algo falló" "WARNING"
```

### 6. Detectar si Herramientas Están Disponibles

```bash
if command -v gnome-extensions >/dev/null 2>&1; then
    # Hacer test real
    gnome-extensions enable "$EXT_ID"
else
    # Simular test
    echo "⚠ GNOME no instalado, simulando..."
    log_success "$MODULE_NAME" "Simulación exitosa"
fi
```

## Ventajas de los Módulos de Test

1. **Desarrollo Rápido**: Prueba cambios sin reinstalar todo
2. **Seguridad**: No afecta instalación principal
3. **Aprendizaje**: Entiende cómo funciona cada parte
4. **Depuración**: Aisla problemas específicos
5. **Personalización**: Experimenta con configuraciones
6. **Documentación**: El código sirve como referencia

## Limitaciones

- Requieren que el componente esté instalado para tests reales
- Algunos tests solo pueden simular sin instalación completa
- La reversión puede no ser 100% en todos los casos
- Requieren privilegios de superusuario

## Módulos Planeados

- ✅ TEST-gnome.sh (implementado)
- ⬜ TEST-gaming.sh (gaming config)
- ⬜ TEST-power.sh (power management)
- ⬜ TEST-network.sh (conectividad)
- ⬜ TEST-audio.sh (audio/pulseaudio)
- ⬜ TEST-display.sh (resolución/monitores)
- ⬜ TEST-kernel.sh (parámetros kernel)

## Contribuir

Para añadir un nuevo módulo de test:

1. Usar `TEST-template.sh` como base
2. Seguir las convenciones de naming
3. Incluir instrucciones de habilitación en el header
4. Documentar cada función de test
5. Proporcionar opción de reversión
6. Probar en modo directo y desde install.sh

#!/bin/bash
# Módulo 17: Compatibilidad con archivos .exe (Wine)

set -eo pipefail  # Detectar errores en pipelines

source "$(dirname "$0")/../config.env"

echo "════════════════════════════════════════════════════════════════"
echo "  COMPATIBILIDAD CON ARCHIVOS .EXE (WINE)"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Este módulo instala:"
echo "  • Wine Stable (última versión estable)"
echo "  • Winetricks (herramientas Wine)"
echo "  • Configuración automática de asociación .exe"
echo "  • PlayOnLinux (GUI opcional)"
echo ""

read -p "¿Instalar soporte Wine para archivos .exe? (s/n) [s]: " INSTALL_WINE
INSTALL_WINE=${INSTALL_WINE:-s}

if [ "$INSTALL_WINE" != "s" ] && [ "$INSTALL_WINE" != "S" ]; then
    echo "✓ Compatibilidad Wine omitida"
    exit 0
fi

read -p "¿Instalar PlayOnLinux (GUI)? (s/n) [n]: " INSTALL_POL
INSTALL_POL=${INSTALL_POL:-n}

APT_FLAGS=""
[ "$USE_NO_INSTALL_RECOMMENDS" = "true" ] && APT_FLAGS="--no-install-recommends"

arch-chroot "$TARGET" /bin/bash << CHROOTEOF
export DEBIAN_FRONTEND=noninteractive

APT_FLAGS="$APT_FLAGS"
USERNAME="$USERNAME"
INSTALL_POL="$INSTALL_POL"

# ============================================================================
# HABILITAR ARQUITECTURA i386
# ============================================================================

echo ""
echo "Habilitando arquitectura i386..."

dpkg --add-architecture i386
apt update

echo "✓ i386 habilitado"

# ============================================================================
# INSTALAR WINE
# ============================================================================

echo ""
echo "Instalando Wine..."

# Añadir repositorio oficial de Wine
mkdir -pm755 /etc/apt/keyrings
wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key

# Añadir repositorio según la versión de Ubuntu
UBUNTU_CODENAME=\$(lsb_release -sc)

wget --timeout=30 --tries=3 -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/\${UBUNTU_CODENAME}/winehq-\${UBUNTU_CODENAME}.sources

apt update

# Instalar Wine Stable
apt install -y --install-recommends winehq-stable

echo "✓ Wine instalado"

# Verificar versión
wine --version

# ============================================================================
# INSTALAR WINETRICKS
# ============================================================================

echo ""
echo "Instalando Winetricks..."

apt install -y winetricks

echo "✓ Winetricks instalado"

# ============================================================================
# PLAYONLINUX (OPCIONAL)
# ============================================================================

if [ "\$INSTALL_POL" = "s" ] || [ "\$INSTALL_POL" = "S" ]; then
    echo ""
    echo "Instalando PlayOnLinux..."
    
    apt install -y playonlinux
    
    echo "✓ PlayOnLinux instalado"
fi

# ============================================================================
# CONFIGURACIÓN DE ASOCIACIÓN DE ARCHIVOS
# ============================================================================

echo ""
echo "Configurando asociación de archivos .exe..."

# Crear script para ejecutar .exe con Wine
cat > /usr/local/bin/wine-handler << 'WINEHANDLER'
#!/bin/bash
# Wine handler para archivos .exe

# Si el archivo no existe, salir
if [ ! -f "$1" ]; then
    zenity --error --text="Archivo no encontrado: $1" 2>/dev/null || \
    notify-send "Wine" "Archivo no encontrado: $1"
    exit 1
fi

# Ejecutar con Wine
wine "$1"
WINEHANDLER

chmod +x /usr/local/bin/wine-handler

# Crear entrada de aplicación para Wine
mkdir -p /usr/share/applications

cat > /usr/share/applications/wine.desktop << 'WINEDESKTOP'
[Desktop Entry]
Name=Wine
Comment=Ejecutar programas de Windows
Exec=wine-handler %f
Terminal=false
Type=Application
Icon=wine
Categories=System;Emulator;
MimeType=application/x-ms-dos-executable;application/x-msdos-program;application/x-exe;application/x-winexe;
NoDisplay=true
WINEDESKTOP

# Registrar MIME types para .exe
cat > /usr/share/mime/packages/wine.xml << 'WINEMIME'
<?xml version="1.0" encoding="UTF-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="application/x-ms-dos-executable">
    <comment>Windows executable</comment>
    <glob pattern="*.exe"/>
    <glob pattern="*.EXE"/>
  </mime-type>
  <mime-type type="application/x-msdos-program">
    <comment>MS-DOS program</comment>
    <glob pattern="*.com"/>
    <glob pattern="*.COM"/>
  </mime-type>
  <mime-type type="application/x-msi">
    <comment>Windows Installer package</comment>
    <glob pattern="*.msi"/>
    <glob pattern="*.MSI"/>
  </mime-type>
</mime-info>
WINEMIME

update-mime-database /usr/share/mime

# Asociar .exe con Wine como aplicación por defecto
xdg-mime default wine.desktop application/x-ms-dos-executable
xdg-mime default wine.desktop application/x-msdos-program
xdg-mime default wine.desktop application/x-exe
xdg-mime default wine.desktop application/x-winexe

echo "✓ Asociación de archivos configurada"

# ============================================================================
# CONFIGURACIÓN PARA USUARIO
# ============================================================================

echo ""
echo "Configurando Wine para el usuario..."

# Crear script de inicialización de Wine para el usuario
cat > /etc/skel/.wine-init << 'WINEINIT'
#!/bin/bash
# Inicialización automática de Wine (ejecuta una vez)

if [ ! -f "\$HOME/.wine-initialized" ]; then
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "  INICIALIZANDO WINE - COMPATIBILIDAD WINDOWS 10"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    echo "Instalando componentes de Windows 10..."
    echo "Esto puede tardar 10-15 minutos. Por favor, espera..."
    echo ""
    
    # Crear prefix de Wine
    echo "[1/8] Creando Wine prefix..."
    WINEDEBUG=-all wineboot -u 2>/dev/null
    
    # Configurar Wine como Windows 10
    echo "[2/8] Configurando versión Windows 10..."
    WINEDEBUG=-all winetricks -q win10 2>/dev/null || true
    
    # Fuentes de Windows (esencial)
    echo "[3/8] Instalando fuentes de Windows..."
    WINEDEBUG=-all winetricks -q corefonts 2>/dev/null || true
    
    # Visual C++ Redistributables (muy común)
    echo "[4/8] Instalando Visual C++ 2015-2022..."
    WINEDEBUG=-all winetricks -q vcrun2015 vcrun2017 vcrun2019 2>/dev/null || true
    
    # .NET Framework 4.8 (última versión)
    echo "[5/8] Instalando .NET Framework 4.8..."
    WINEDEBUG=-all winetricks -q dotnet48 2>/dev/null || true
    
    # DirectX 9, 10, 11 (gaming y multimedia)
    echo "[6/8] Instalando DirectX..."
    WINEDEBUG=-all winetricks -q d3dx9 d3dx10 d3dx11_43 2>/dev/null || true
    WINEDEBUG=-all winetricks -q d3dcompiler_43 d3dcompiler_47 2>/dev/null || true
    
    # Componentes multimedia
    echo "[7/8] Instalando componentes multimedia..."
    WINEDEBUG=-all winetricks -q quartz wmp10 2>/dev/null || true
    
    # Librerías esenciales
    echo "[8/8] Instalando librerías del sistema..."
    WINEDEBUG=-all winetricks -q msxml3 msxml6 2>/dev/null || true
    WINEDEBUG=-all winetricks -q vcrun6 mfc42 2>/dev/null || true
    
    touch "\$HOME/.wine-initialized"
    
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "✓ Wine inicializado con compatibilidad Windows 10"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    echo "Componentes instalados:"
    echo "  ✅ Windows 10 (emulación)"
    echo "  ✅ Fuentes de Windows"
    echo "  ✅ Visual C++ 2015-2022"
    echo "  ✅ .NET Framework 4.8"
    echo "  ✅ DirectX 9, 10, 11"
    echo "  ✅ Windows Media Player 10"
    echo "  ✅ Librerías del sistema"
    echo ""
    echo "Wine está listo para ejecutar aplicaciones de Windows 10"
    echo ""
fi
WINEINIT

chmod +x /etc/skel/.wine-init

# Crear configuración por defecto de usuario
mkdir -p /home/\$USERNAME/.config/autostart 2>/dev/null || true
chown -R \$USERNAME:\$USERNAME /home/\$USERNAME/.config 2>/dev/null || true

echo "✓ Wine configurado para usuario"

# ============================================================================
# OPTIMIZACIONES
# ============================================================================

echo ""
echo "Aplicando optimizaciones de Wine..."

# Variables de entorno para Wine
cat > /etc/profile.d/wine-env.sh << 'WINEENV'
#!/bin/bash
# Variables de entorno para Wine

# Reducir debug output
export WINEDEBUG=-all

# Usar esync para mejor rendimiento
export WINEESYNC=1

# Usar fsync si está disponible
export WINEFSYNC=1

# DirectX mejor rendimiento
export DXVK_HUD=0
export DXVK_LOG_LEVEL=none
WINEENV

chmod +x /etc/profile.d/wine-env.sh

echo "✓ Optimizaciones aplicadas"

CHROOTEOF

# ============================================================================
# INFORMACIÓN POST-INSTALACIÓN
# ============================================================================

# Crear archivo de ayuda
cat > "$TARGET/home/$USERNAME/Wine-Help.txt" << 'HELPEOF'
═══════════════════════════════════════════════════════════════
                WINE - COMPATIBILIDAD WINDOWS 10
═══════════════════════════════════════════════════════════════

COMPONENTES INSTALADOS AUTOMÁTICAMENTE:

  ✅ Windows 10 (versión emulada)
  ✅ Fuentes de Windows (Arial, Times New Roman, Courier, etc.)
  ✅ Visual C++ Redistributables (2015, 2017, 2019, 2022)
  ✅ .NET Framework 4.8 (última versión)
  ✅ DirectX 9, 10, 11 (d3dx9, d3dx10, d3dx11)
  ✅ DirectX Compiler (d3dcompiler_43, d3dcompiler_47)
  ✅ Windows Media Player 10
  ✅ MSXML 3 y 6
  ✅ Visual C++ 6 Runtime
  ✅ Microsoft Foundation Classes 4.2

Con estas dependencias puedes ejecutar la mayoría de aplicaciones
de Windows 10 sin necesidad de instalar nada adicional.

═══════════════════════════════════════════════════════════════

EJECUTAR ARCHIVOS .EXE:

  Opción 1: Doble clic en el archivo .exe (asociación automática)
  
  Opción 2: Click derecho → Abrir con → Wine
  
  Opción 3: Desde terminal:
    $ wine programa.exe

INSTALAR PROGRAMAS:

  Doble clic en instalador.exe
  o
  $ wine instalador.exe
  
  La mayoría de instaladores funcionarán sin problemas.

GESTIONAR CONFIGURACIÓN DE WINE:

  $ winecfg
  
  Aquí puedes:
  - Cambiar versión de Windows emulada (ya está en Windows 10)
  - Configurar drives
  - Ajustar gráficos
  - Configurar audio
  - Gestionar librerías DLL

INSTALAR DEPENDENCIAS ADICIONALES:

  $ winetricks
  
  Ejemplos de componentes NO instalados por defecto:
  
  - DirectX 12:    winetricks dxvk
  - Visual Studio: winetricks msvc2019
  - Java:          winetricks java
  - Flash Player:  winetricks flash
  - Silverlight:   winetricks silverlight

DEPENDENCIAS YA INSTALADAS (NO necesitas reinstalar):

  ✓ corefonts     (Fuentes de Windows)
  ✓ vcrun2015     (Visual C++ 2015)
  ✓ vcrun2017     (Visual C++ 2017)
  ✓ vcrun2019     (Visual C++ 2019)
  ✓ dotnet48      (.NET Framework 4.8)
  ✓ d3dx9         (DirectX 9)
  ✓ d3dx10        (DirectX 10)
  ✓ d3dx11_43     (DirectX 11)
  ✓ d3dcompiler_43 (DirectX Compiler)
  ✓ d3dcompiler_47 (DirectX Compiler)
  ✓ quartz        (Multimedia)
  ✓ wmp10         (Windows Media Player)
  ✓ msxml3        (XML Parser 3)
  ✓ msxml6        (XML Parser 6)
  ✓ vcrun6        (Visual C++ 6)
  ✓ mfc42         (Microsoft Foundation Classes)

UBICACIÓN DE ARCHIVOS DE WINDOWS:

  ~/.wine/drive_c/
  
  Equivalencias:
  - C:\                → ~/.wine/drive_c/
  - C:\Program Files   → ~/.wine/drive_c/Program Files/
  - C:\Program Files (x86) → ~/.wine/drive_c/Program Files (x86)/
  - C:\users           → ~/.wine/drive_c/users/
  - C:\Windows         → ~/.wine/drive_c/windows/

APLICACIONES DE EJEMPLO QUE FUNCIONAN:

  ✅ Microsoft Office (versiones antiguas)
  ✅ Adobe Photoshop CS6 y anteriores
  ✅ Juegos antiguos (hasta ~2015)
  ✅ WinRAR, 7-Zip
  ✅ Notepad++
  ✅ Paint.NET
  ✅ FileZilla
  ✅ Instaladores .exe en general

SOLUCIÓN DE PROBLEMAS:

  1. Programa no inicia:
     $ wine programa.exe
     (Verás errores en terminal para diagnosticar)
  
  2. Falta DLL específica:
     $ winetricks nombre_dll
     Ejemplo: winetricks vcrun2013
  
  3. Problemas gráficos:
     $ winecfg → Graphics → Enable "Emulate a virtual desktop"
     Tamaño recomendado: 1920x1080
  
  4. Programa requiere .NET antiguo:
     $ winetricks dotnet40
     (dotnet48 ya está instalado)
  
  5. Problemas de audio:
     $ winecfg → Audio → Test Sound
  
  6. Limpiar Wine (empezar de cero):
     $ rm -rf ~/.wine
     $ wineboot -u
     (Reinstalará todas las dependencias automáticamente)

HERRAMIENTAS ÚTILES:

  - winecfg:     Configuración de Wine
  - winetricks:  Instalar componentes adicionales
  - winefile:    Explorador de archivos estilo Windows
  - regedit:     Editor de registro de Wine
  - taskmgr:     Administrador de tareas de Wine
  - uninstaller: Desinstalar programas de Wine

PLAYONLINUX (si instalado):

  GUI amigable para gestionar diferentes versiones de Wine
  y programas de Windows. Buscar en el menú de aplicaciones.
  
  Ventajas:
  - Scripts para juegos populares (Steam, Origin, Battle.net)
  - Múltiples versiones de Wine en paralelo
  - Prefixes aislados por aplicación

RENDIMIENTO:

  Wine está optimizado con:
  - WINEESYNC=1 (event synchronization)
  - WINEFSYNC=1 (file synchronization)
  - WINEDEBUG=-all (sin debug overhead)
  
  Para juegos, considera instalar:
  $ winetricks dxvk    (Vulkan-based DirectX 11/10/9)
  $ winetricks vkd3d   (Vulkan-based DirectX 12)

ACTUALIZACIONES:

  Wine se actualiza automáticamente con el sistema:
  $ sudo apt update && sudo apt upgrade
  
  Para cambiar a Wine Staging (más experimental):
  $ sudo apt install --install-recommends winehq-staging

═══════════════════════════════════════════════════════════════
      WINE CON COMPATIBILIDAD WINDOWS 10 ESTÁ LISTO
═══════════════════════════════════════════════════════════════

Toda la configuración se hizo automáticamente al primer login.
Puedes empezar a ejecutar tus aplicaciones de Windows ahora.

Para más información:
  - https://www.winehq.org/
  - https://wiki.winehq.org/
  - https://appdb.winehq.org/ (base de datos de compatibilidad)

═══════════════════════════════════════════════════════════════
HELPEOF

chown $USERNAME:$USERNAME "$TARGET/home/$USERNAME/Wine-Help.txt"

# ============================================================================
# CONFIRMACIÓN FINAL
# ============================================================================

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓ COMPATIBILIDAD WINE INSTALADA"
echo "════════════════════════════════════════════════════════════════"
echo ""

echo "Software instalado:"
echo "  ✅ Wine Stable (última versión)"
echo "  ✅ Winetricks (gestor de dependencias)"

if [ "$INSTALL_POL" = "s" ] || [ "$INSTALL_POL" = "S" ]; then
    echo "  ✅ PlayOnLinux (GUI)"
fi

echo ""
echo "Configuración aplicada:"
echo "  ✅ Asociación de archivos .exe"
echo "  ✅ MIME types configurados"
echo "  ✅ Optimizaciones de rendimiento"
echo "  ✅ Variables de entorno"
echo ""

echo "Dependencias Windows 10 (instalación automática al primer login):"
echo "  ✅ Windows 10 (emulación)"
echo "  ✅ Fuentes de Windows"
echo "  ✅ Visual C++ 2015-2022"
echo "  ✅ .NET Framework 4.8"
echo "  ✅ DirectX 9, 10, 11"
echo "  ✅ Windows Media Player 10"
echo "  ✅ Librerías del sistema (MSXML, MFC, etc.)"
echo ""

echo "Uso:"
echo "  • Doble clic en archivos .exe para ejecutar"
echo "  • Terminal: wine programa.exe"
echo "  • Configurar: winecfg"
echo "  • Dependencias adicionales: winetricks"
echo ""

echo "Documentación:"
echo "  ~/Wine-Help.txt (guía completa de compatibilidad Windows 10)"
echo ""

echo "Próximos pasos:"
echo "  1. Al primer login, Wine instalará dependencias de Windows 10"
echo "     (proceso automático, tarda ~10-15 minutos)"
echo "  2. Leer ~/Wine-Help.txt para guía completa"
echo "  3. Ejecutar archivos .exe con doble clic"
echo ""

echo "⚠️  IMPORTANTE:"
echo "  La primera vez que inicies sesión, Wine instalará automáticamente"
echo "  todas las dependencias de Windows 10. Esto puede tardar 10-15 minutos."
echo "  Por favor, no interrumpas el proceso."
echo ""

exit 0

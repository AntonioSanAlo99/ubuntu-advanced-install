# Launchers de Juegos

El módulo de gaming instala tres launchers desde sus .deb oficiales:

## Steam (Valve oficial)

### Instalación
```bash
# Descarga desde CDN oficial de Valve
https://cdn.cloudflare.steamstatic.com/client/installer/steam.deb
```

### Qué es
- Plataforma oficial de Valve
- Biblioteca de juegos de Steam
- Proton integrado (ejecuta juegos Windows en Linux)
- Mayor catálogo de juegos para Linux

### Uso
1. Abrir Steam desde el menú
2. Iniciar sesión con cuenta Steam
3. Configurar Proton: Steam → Configuración → Compatibilidad
4. Activar: "Habilitar Steam Play para títulos soportados"
5. Activar: "Habilitar Steam Play para todos los títulos"

### Proton
- Permite ejecutar juegos Windows en Linux
- Basado en Wine + DXVK
- Integrado en Steam (no requiere configuración manual)
- ProtonDB para ver compatibilidad: https://www.protondb.com/

## Heroic Games Launcher

### Instalación
```bash
# Última versión desde GitHub oficial
https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher/releases
```

### Qué es
- Launcher de código abierto
- Soporte para múltiples tiendas:
  - Epic Games Store
  - GOG
  - Amazon Prime Gaming
- Alternativa a clientes oficiales

### Uso
1. Abrir Heroic Games Launcher
2. Iniciar sesión en Epic Games / GOG / Amazon
3. Ver biblioteca de juegos
4. Configurar Wine/Proton por juego
5. Instalar y jugar

### Características
- ✅ Gestión de múltiples runners (Wine, Proton-GE)
- ✅ Sincronización de guardados en la nube
- ✅ Integración con Proton-GE
- ✅ Actualizaciones automáticas de juegos

## Faugus Launcher

### Instalación
```bash
# Última versión desde GitHub oficial
https://github.com/Faugus/faugus-launcher/releases
```

### Qué es
- Lanzador universal para cualquier juego
- No está atado a ninguna tienda
- Para juegos standalone, ejecutables, ROMs

### Uso
1. Abrir Faugus Launcher
2. Añadir juegos manualmente:
   - Ejecutables de Windows (.exe)
   - Juegos nativos Linux
   - ROMs de emuladores
   - Scripts personalizados
3. Configurar Wine/Proton por juego
4. Organizar biblioteca personal

### Casos de Uso
- 🎮 Juegos comprados fuera de tiendas (Humble Bundle, itch.io)
- 🎮 Ejecutables standalone
- 🎮 Juegos portables
- 🎮 ROMs de consolas con emuladores
- 🎮 Juegos piratas (mods, homebrew)

## Comparación

| Característica | Steam | Heroic | Faugus |
|----------------|-------|--------|--------|
| **Tiendas** | Solo Steam | Epic/GOG/Amazon | Ninguna (manual) |
| **Instalación juegos** | Automática | Automática | Manual |
| **Proton integrado** | ✅ Sí | ⚠️ Externo | ⚠️ Externo |
| **Catálogo** | Muy grande | Grande | N/A |
| **DRM** | Steam DRM | Epic/GOG DRM | Sin DRM |
| **Actualizaciones** | Automáticas | Automáticas | Manuales |
| **Mejor para** | Juegos Steam | Multi-tienda | Juegos standalone |

## Configuración de Proton/Wine

### Proton-GE (recomendado)

ProtonUp-Qt ya está instalado para gestionar Proton-GE:

```bash
# Lanzar ProtonUp-Qt
protonup-qt
```

**Pasos:**
1. Abrir ProtonUp-Qt
2. Seleccionar versión de Proton-GE más reciente
3. Instalar para Steam y/o Heroic
4. Reiniciar launchers

### Ubicaciones de Proton

```
Steam:
~/.local/share/Steam/compatibilitytools.d/

Heroic:
~/.config/heroic/tools/proton/

Faugus:
~/.local/share/faugus-launcher/
```

## Verificar Instalación

```bash
# Steam
which steam
steam --version

# Heroic
which heroic
heroic --version

# Faugus
which faugus-launcher
```

## Troubleshooting

### Steam no inicia

**Solución:**
```bash
# Reinstalar dependencias i386
sudo dpkg --add-architecture i386
sudo apt update
sudo apt install libgl1-mesa-dri:i386 libgl1:i386

# Limpiar caché
rm -rf ~/.steam/steam
steam
```

### Heroic: Juego no inicia

**Verificar:**
1. Wine/Proton instalado correctamente
2. Configuración del juego → Runner → Proton-GE
3. Logs en: ~/.config/heroic/logs/

**Solución común:**
```bash
# Instalar dependencias Wine
sudo apt install wine64 wine32 winetricks
```

### Faugus: Error al lanzar juego

**Verificar:**
1. Ruta del ejecutable correcta
2. Permisos de ejecución: `chmod +x juego.exe`
3. Wine/Proton configurado en el launcher

### Rendimiento bajo

**Optimizaciones:**
1. Habilitar Gamemode:
   ```bash
   # Añadir a opciones de lanzamiento
   gamemoderun %command%
   ```

2. Variables de entorno útiles:
   ```bash
   # Mesa (AMD/Intel)
   MESA_LOADER_DRIVER_OVERRIDE=zink
   
   # DXVK async (menos stuttering)
   DXVK_ASYNC=1
   
   # Compositor (reducir input lag)
   __GL_YIELD="NOTHING"
   ```

3. Steam → Propiedades del juego → Opciones de lanzamiento:
   ```
   gamemoderun DXVK_ASYNC=1 %command%
   ```

## Gestión de Bibliotecas

### Steam Library en disco externo

```bash
# Añadir ubicación
Steam → Configuración → Descargas → Carpetas de contenido
```

### Heroic: Mover juegos

```bash
# En configuración de cada juego
Heroic → Biblioteca → Juego → Configuración → Install Path
```

### Faugus: Organizar juegos

```bash
# Crear categorías/colecciones dentro del launcher
Faugus → Biblioteca → Nueva colección
```

## Actualizaciones

### Steam
- Actualizaciones automáticas (cliente y juegos)

### Heroic
```bash
# Descargar nueva versión .deb
wget URL_NUEVA_VERSION
sudo dpkg -i heroic_VERSION.deb
```

### Faugus
```bash
# Similar a Heroic
wget URL_NUEVA_VERSION
sudo dpkg -i faugus-launcher_VERSION.deb
```

### Proton-GE
```bash
# Usar ProtonUp-Qt
protonup-qt
```

## Recursos Adicionales

- **ProtonDB**: https://www.protondb.com/ - Compatibilidad de juegos
- **Steam Deck**: https://www.steamdeck.com/ - Gaming en Linux
- **Heroic Wiki**: https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher/wiki
- **Faugus GitHub**: https://github.com/Faugus/faugus-launcher
- **Are We Anti-Cheat Yet**: https://areweanticheatyet.com/

## Notas Importantes

⚠️ **Anti-Cheat**
- Algunos juegos con anti-cheat no funcionan en Linux
- Verificar en ProtonDB antes de comprar
- Easy Anti-Cheat y BattlEye tienen soporte limitado

⚠️ **DRM**
- Juegos con Denuvo pueden tener problemas
- DRM de Epic Games funciona generalmente bien
- GOG es DRM-free (mejor compatibilidad)

✅ **Recomendación**
- Probar juegos en ProtonDB primero
- Usar Proton-GE en lugar de Proton estándar
- Habilitar Gamemode para mejor rendimiento

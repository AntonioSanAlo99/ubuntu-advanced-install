# Thumbnailers en GNOME - Información

## ¿Qué son los thumbnailers?

Los thumbnailers son programas que generan miniaturas (previews) de archivos para mostrar en Nautilus y otros gestores de archivos.

## Thumbnailers instalados

### Video
- **ffmpegthumbnailer** → Miniaturas de archivos de video (MP4, MKV, AVI, etc.)

### Audio
- **Totem** → Miniaturas de archivos de audio (MP3, FLAC, OGG, etc.)
  - NOTA: Totem se instala temporalmente para esta funcionalidad
  - GNOME planea crear un paquete dedicado de thumbnailers en 2026
  - Mientras tanto, Totem es la única forma de tener miniaturas de audio

### Imágenes
- **libgdk-pixbuf2.0-bin** → PNG, JPG, GIF, BMP
- **webp-pixbuf-loader** → WebP
- **libheif-gdk-pixbuf** → HEIF/HEIC (fotos de iPhone)

### Documentos
- **poppler-utils** → PDF
- **gnome-epub-thumbnailer** → EPUB (libros electrónicos)
- **ghostscript** → PostScript, EPS

## ¿Por qué instalar Totem solo para thumbnailers?

**Situación actual (2025-2026):**
- Los thumbnailers de audio están integrados en Totem
- No existe un paquete standalone `gnome-audio-thumbnailer`
- Opciones:
  1. Instalar Totem completo (reproduce videos, pero no lo necesitas)
  2. No tener miniaturas de archivos de audio

**Solución temporal:**
Instalamos Totem y opcionalmente lo ocultamos del menú de aplicaciones.

## Cómo ocultar Totem del menú (opcional)

Si solo quieres los thumbnailers de audio y no quieres ver Totem en el menú:

```bash
sudo nano /usr/share/applications/org.gnome.Totem.desktop
```

Añade esta línea:
```
NoDisplay=true
```

O ejecuta:
```bash
echo "NoDisplay=true" | sudo tee -a /usr/share/applications/org.gnome.Totem.desktop
```

Totem seguirá funcionando para generar miniaturas, pero no aparecerá en el menú de aplicaciones.

## Ubicación del cache de thumbnails

```
~/.cache/thumbnails/
├── normal/     # 128x128 px
├── large/      # 256x256 px
└── fail/       # Archivos que fallaron
```

## Regenerar thumbnails

Si las miniaturas no se muestran correctamente:

```bash
# Limpiar cache
rm -rf ~/.cache/thumbnails/*

# Nautilus regenerará las miniaturas automáticamente
nautilus -q
nautilus
```

## Formatos soportados por thumbnailer

| Formato | Thumbnailer | Paquete |
|---------|-------------|---------|
| MP4, MKV, AVI, MOV | ffmpegthumbnailer | ffmpegthumbnailer |
| MP3, FLAC, OGG, M4A | Totem | totem |
| PNG, JPG, GIF | gdk-pixbuf | libgdk-pixbuf2.0-bin |
| WebP | webp-pixbuf-loader | webp-pixbuf-loader |
| HEIF, HEIC | libheif | libheif-gdk-pixbuf |
| PDF | Poppler | poppler-utils |
| EPUB | gnome-epub-thumbnailer | gnome-epub-thumbnailer |

## Futuro (2026+)

GNOME está trabajando en un paquete dedicado de thumbnailers que NO requerirá Totem:
- `gnome-thumbnailers` (nombre provisional)
- Incluirá thumbnailers para audio, video, documentos
- Cuando esté disponible, Totem podrá desinstalarse si solo se usaba para thumbnailers

## Troubleshooting

**Las miniaturas no se generan:**
```bash
# Verificar que los thumbnailers están instalados
dpkg -l | grep -E "ffmpegthumbnailer|totem|poppler"

# Verificar permisos
ls -la ~/.cache/thumbnails/

# Forzar regeneración
rm -rf ~/.cache/thumbnails/* && nautilus -q
```

**Totem no genera miniaturas de audio:**
```bash
# Verificar que totem-plugins está instalado
dpkg -l | grep totem-plugins

# Reinstalar si es necesario
sudo apt-get install --reinstall totem totem-plugins
```

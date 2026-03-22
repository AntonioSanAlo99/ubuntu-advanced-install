# ROADMAP — ubuntu-advanced-install

## Próximas mejoras (sin overhead)

### systemd-boot en vez de GRUB
- Más rápido, más simple, integración nativa con systemd.
- Soporta Secure Boot, no necesita `update-grub`.
- Ubuntu 26.04 va en esa dirección.
- Requiere reescribir módulo 04 (bootloader) completamente.

### Unified Kernel Images (UKI)
- Kernel + initramfs + cmdline + firma en un solo fichero EFI.
- systemd-boot los detecta automáticamente.
- Estándar emergente: Fedora, Arch, Ubuntu lo están adoptando.
- Complementa systemd-boot (no tiene sentido sin él).
- Requiere: `ukify`, `systemd-stub`, reorganización de `/boot`.

### Plymouth con tema de arranque
- Splash limpio en vez de texto del kernel.
- Requiere: tema compatible con systemd-boot (si se migra).

### Impresoras (CUPS + drivers)
- `cups`, `cups-filters`, `system-config-printer`.
- Ubuntu Desktop lo instala por defecto, debootstrap no.

### Flatpak + Flathub (opcional, con pregunta)
- Acceso al ecosistema de apps modernas (Discord, Bottles, etc.).
- GNOME Software como frontend.
- Solo si el usuario lo elige explícitamente.

### Soporte multi-layout de teclado
- Permitir elegir múltiples layouts (ej: español + inglés).
- `localectl set-x11-keymap es,us` con toggle.

### Microsoft Core Fonts (corefonts)
- Compatibilidad con documentos Office.
- `ttf-mscorefonts-installer` requiere aceptar EULA.

### appimage-thumbnailer — usar GitHub API
- Actualmente v4.0.0 hardcodeada (módulo 20, L83).
- Migrar a descarga dinámica via API de GitHub releases.

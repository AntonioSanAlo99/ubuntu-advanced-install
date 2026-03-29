# Sistema de Perfiles — Diseño v1

## Flujo

```
[1] SISTEMA BASE (siempre)
    → Versión Ubuntu, hostname, usuario, contraseña, desktop/laptop

[2] PERFIL
    1) Escritorio     — GNOME + multimedia
    2) Desarrollo     — Escritorio + todo dev ON
    3) Gaming         — Escritorio + Steam/Heroic/Faugus/ProtonPlus/drivers
    4) Completo       — Todo ON
    5) Servidor       — Sin GUI
    6) Personalizado  — Preguntas una a una (flujo actual)

[3] ¿AÑADIR GAMING? (solo si perfil 1, 2 o 5)

[4] AJUSTES (siempre, fuera del perfil)
    → Panel: Ubuntu Dock / Dash to Panel
    → Autologin GDM (s/n)
    → Parámetros kernel (base / gaming / mitigations=off / mínimo)
    → Auto-updates (seguridad / todas / ninguna)
    → nothrottle (solo laptop Intel)

[5] EXTRAS (checklist — el perfil NO decide estos)
    → Spotify
    → OnlyOffice
    → qBittorrent
    → OBS Studio
    → Obsidian
    → Gradia (screenshot tool)
    → Mullvad VPN

[6] GAMING EXTRAS (solo si gaming activo — perfil 3, 4, o addon)
    → Discord (s/n)
    → Kernel CachyOS (s/n) + scheduler
    → GPU manual (auto/amd/intel/nvidia/...)
    → Steam method (GLFS / SteamRT3)

[7] RESUMEN → confirmar o volver a ajustar
```

## Tabla de Variables por Perfil

### Leyenda
- **✓** = true (activado por el perfil)
- **✗** = false (desactivado por el perfil)
- **ASK** = se pregunta fuera del perfil (ajustes/extras)
- **—** = no aplica (valor heredado o no relevante)

### Variables del sistema base (siempre se preguntan)

| Variable           | Descripción                    | Siempre |
|--------------------|--------------------------------|---------|
| UBUNTU_VERSION     | noble / jammy / focal / etc.   | ASK     |
| HOSTNAME           | Nombre del equipo              | ASK     |
| USERNAME           | Nombre de usuario              | ASK     |
| USER_PASSWORD      | Contraseña del usuario         | ASK     |
| ROOT_PASSWORD      | Contraseña de root             | ASK     |
| IS_LAPTOP          | Desktop / Laptop               | ASK     |
| TARGET_DISK        | Disco destino                  | auto    |
| TARGET             | Punto de montaje               | auto    |
| DUAL_BOOT          | Dual boot                      | false   |
| UBUNTU_SIZE_GB     | Tamaño partición dual boot     | 50      |
| HAS_WIFI           | WiFi detectado                 | true    |
| HAS_BLUETOOTH      | Bluetooth detectado            | true    |

### Variables pre-rellenadas por el perfil

| Variable              | Escritorio | Desarrollo | Gaming | Completo | Servidor |
|-----------------------|:----------:|:----------:|:------:|:--------:|:--------:|
| **GNOME**             |            |            |        |          |          |
| INSTALL_GNOME         | ✓          | ✓          | ✓      | ✓        | ✗        |
| GNOME_OPTIMIZE_MEMORY | ✓          | ✓          | ✓      | ✓        | ✗        |
| GNOME_TRANSPARENT_THEME| ✓         | ✓          | ✓      | ✓        | ✗        |
| **MULTIMEDIA**        |            |            |        |          |          |
| INSTALL_MULTIMEDIA    | ✓          | ✓          | ✓      | ✓        | ✗        |
| **DESARROLLO**        |            |            |        |          |          |
| INSTALL_DEVELOPMENT   | ✗          | ✓          | ✗      | ✓        | ✗        |
| INSTALL_VSCODE        | ✗          | ✓          | ✗      | ✓        | ✗        |
| NODEJS_OPTION         | —          | 2 (LTS)    | —      | 2 (LTS)  | —        |
| INSTALL_TOPGRADE      | ✗          | ✓          | ✗      | ✓        | ✗        |
| INSTALL_BOXES         | ✗          | ✓          | ✗      | ✓        | ✗        |
| INSTALL_LAZY_TOOLS    | ✗          | ✓          | ✗      | ✓        | ✗        |
| INSTALL_DOCKER_TOOLS  | ✗          | ✓          | ✗      | ✓        | ✗        |
| INSTALL_N8N           | ✗          | ✓          | ✗      | ✓        | ✗        |
| INSTALL_MELD          | ✗          | ✓          | ✗      | ✓        | ✗        |
| INSTALL_POSTMAN       | ✗          | ✓          | ✗      | ✓        | ✗        |
| INSTALL_NETTOOLS      | ✗          | ✓          | ✗      | ✓        | ✗        |
| **GAMING (core)**     |            |            |        |          |          |
| INSTALL_GAMING        | ✗          | ✗          | ✓      | ✓        | ✗        |
| INSTALL_PROTONPLUS    | ✗          | ✗          | ✓      | ✓        | ✗        |
| STEAM_METHOD          | —          | —          | 1      | 1        | —        |
| **GAMING (extras)**   | si addon → ASK | si addon → ASK | ASK | ✓ | ✗   |
| INSTALL_DISCORD       | ✗          | ✗          | ASK    | ✓        | ✗        |
| INSTALL_CACHYOS_KERNEL| ✗          | ✗          | ASK    | ✓        | ✗        |
| PSYCACHY_SCHEDULER    | —          | —          | ASK    | bore     | —        |
| GPU_MANUAL            | —          | —          | ASK    | ASK      | —        |

### Variables de AJUSTES (siempre se preguntan, fuera del perfil)

| Variable            | Descripción                         | Default   |
|---------------------|-------------------------------------|-----------|
| GNOME_DOCK          | ubuntu-dock / dash-to-panel         | ASK       |
| GDM_AUTOLOGIN       | Autologin GDM                       | ASK [s]   |
| KERNEL_PARAMS_LEVEL | 1=base 2=gaming 3=mitigations 4=min | ASK [1]   |
| AUTO_UPDATE_CHOICE  | 1=seguridad 2=todas 3=ninguna       | ASK [1]   |
| INSTALL_NOTHROTTLE  | nothrottle (solo laptop Intel)      | ASK [n]   |

### Variables de EXTRAS (checklist, fuera del perfil)

| Variable                 | Descripción                     | Default |
|--------------------------|---------------------------------|---------|
| INSTALL_SPOTIFY          | Spotify (snap)                  | ASK [s] |
| INSTALL_ONLYOFFICE       | OnlyOffice Desktop              | ASK [n] |
| INSTALL_QBITTORRENT      | qBittorrent                     | ASK [n] |
| INSTALL_OBS              | OBS Studio                      | ASK [n] |
| INSTALL_OBSIDIAN         | Obsidian                        | ASK [n] |
| INSTALL_GRADIA           | Gradia (screenshot tool)        | ASK [n] |
| INSTALL_MULLVAD          | Mullvad VPN                     | ASK [n] |

### Variables fijas (no se preguntan, siempre mismo valor)

| Variable              | Valor | Motivo                              |
|-----------------------|-------|-------------------------------------|
| INSTALL_RUST          | true  | Base del sistema (módulo 07 CORE)   |
| MINIMIZE_SYSTEMD      | true  | Siempre se minimiza                 |
| ENABLE_SECURITY       | false | Hardening desactivado por defecto   |
| PERF_OOMD_AGGRESSIVE  | true  | Performance siempre activa          |
| PERF_TMPFILES_CLEANUP | true  | Performance siempre activa          |
| PERF_DNS_OVER_TLS     | true  | Performance siempre activa          |

## Ejemplo de flujo: Perfil "Desarrollo"

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[1/7] Sistema base
  Ubuntu 24.04 LTS · hostname: ubuntu · usuario: antonio · Desktop

[2/7] Perfil
  > 2) Desarrollo
  ✓ GNOME + Multimedia + Dev completo (VSCode, Node LTS, topgrade,
    Wireshark/AWS)

[3/7] ¿Añadir gaming?
  > sí
  ✓ Steam + Heroic + Faugus + ProtonPlus + drivers

[4/7] Ajustes
  Panel: [Dash to Panel] · Autologin: [s] · Kernel: [base]
  Updates: [seguridad] · Energía: [ppd]

[5/7] Extras
  ¿Spotify? [s]  ¿OnlyOffice? [n]  ¿qBittorrent? [n]
  ¿OBS? [n]  ¿Obsidian? [n]  ¿Gradia? [s]  ¿Webapps? [s]

[6/7] Resumen
  ┌──────────────────────────────────────────────────────┐
  │ Ubuntu noble · antonio@ubuntu · Desktop              │
  │ GNOME (Dash to Panel) · Autologin · Multimedia       │
  │ Desarrollo: TODO · Gaming: core                      │
  │ Extras: Spotify, Gradia, Webapps                     │
  │ Kernel: base · Updates: seguridad · systemd: min     │
  └──────────────────────────────────────────────────────┘
  ¿Continuar? [s]

[7/7] ¿Guardar config.yaml? [s]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

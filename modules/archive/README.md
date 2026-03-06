# modules/archive/

Módulos retirados del flujo principal de instalación. Se conservan por referencia histórica o para posible recuperación de lógica.

| Archivo | Razón |
|---------|-------|
| `00-check-dependencies-OLD.sh` | Versión anterior de módulo 00 |
| `01-prepare-disk-OLD-COMPLEX.sh` | Versión anterior más compleja de módulo 01 |
| `03-configure-base-OLD-COMPLEX.sh` | Versión anterior de módulo 03 |
| `03-configure-base-OLD-GUESS.sh` | Versión experimental de módulo 03 |
| `02.5-investigate-locale.sh` | Script de diagnóstico de locales, no forma parte del flujo de instalación |
| `03-install-firmware.sh` | Módulo de firmware no invocado en ningún flujo actual |
| `17-install-wine.sh` | Wine no está integrado en el flujo principal (Gaming usa Proton directamente) |
| `20-optimize-performance.sh` | Duplicado/supersedido por módulos 21-23 |
| `21-laptop-advanced.sh` | Supersedido por `21-optimize-laptop.sh` |

> Para recuperar alguno: `mv modules/archive/<nombre>.sh modules/`

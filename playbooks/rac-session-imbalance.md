# Playbook: Desbalance de sesiones en RAC

Playbook representativo para el escenario típico "una instancia del cluster está más cargada que las demás".

## Cuándo usar

Target confirmado por discovery como `instance_mode = rac`, y el DBA reporta (o `/diagnose` clasifica) un síntoma de tipo desbalance/saturación de una instancia.

## Pasos

1. `oracle-discovery-analyst` confirma topología (si no hay cache).
2. `oracle-rac-analyst` → `rac/session-distribution` (`Q-RAC-SESSION-DIST-001`) y `rac/service-placement` (`Q-RAC-SERVICE-PLACEMENT-001`).
3. Si el desbalance es significativo (ver umbral en `policies/`): activar `os-platform-analyst` para confirmar si la instancia sobrecargada también satura CPU/memoria del nodo.
4. Si la causa apunta a `CLB_GOAL`/`RLB_GOAL` mal configurado o ausencia de balanceo del lado del connection pool de aplicación → `oracle-rac-analyst` produce `PROBABLE_CAUSE` y una recomendación.
5. Si el desbalance coincide con un patrón de wait `gc *` relevante → correlacionar con `oracle-performance-analyst` (`performance/wait-events`).
6. `change-advisor` estructura la recomendación (ej. ajustar `CLB_GOAL` del servicio) como `CHG-*` para ejecución manual — nunca se relocaliza ninguna sesión automáticamente.
7. `technical-documentation-manager` cierra el análisis.

## Salida esperada

`findings.md` con la tabla de distribución por servicio/instancia y la causa probable; `proposed-changes.md` si hay una corrección de configuración identificada.

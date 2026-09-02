# Playbook: Health check — Standalone, Filesystem, NON-CDB

Playbook representativo (sección 23, materialización de ejemplos, no una lista exhaustiva). Sigue `workflows/healthcheck.md` para el ambiente más simple soportado.

## Cuándo usar

Target confirmado por discovery como: `instance_mode = single`, `storage_mode = filesystem`, `container_mode = non_cdb`.

## Pasos

1. `oracle-discovery-analyst` confirma identidad (si no hay cache).
2. `oracle-dba-analyst`: `oracle/database-state`, `oracle/tablespaces`, `oracle/temp`, `oracle/undo`, `oracle/sessions`, `oracle/invalid-objects`.
3. `os-platform-analyst` (skill de la plataforma detectada): `os/*/cpu`, `os/*/memory`, `os/*/filesystems`.
4. Si el DBA pidió performance explícitamente: `oracle-performance-analyst` con ventana por defecto de 1h (última hora hábil).
5. `technical-documentation-manager` cierra `analysis/ANA-YYYYMMDD-NNN/`.

## Agentes NO activados en este playbook

`oracle-rac-analyst`, `oracle-asm-storage-analyst`, `oracle-multitenant-analyst`, `oracle-dataguard-analyst` — no aplican a esta topología (activación mínima).

## Salida esperada

`findings.md` con estado de tablespaces/TEMP/UNDO/sesiones/objetos inválidos y recursos del host; `recommendations.md` sólo si hay hallazgo `MEDIUM`/`HIGH`.

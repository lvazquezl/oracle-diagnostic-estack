---
name: container-state
id: multitenant/container-state
version: 1.0.0
domain: multitenant
status: active
---

# Purpose

Determinar el estado de cada PDB de un CDB (OPEN/MOUNTED/READ ONLY/RESTRICTED) y señalar estados inesperados que puedan indicar un problema operativo o de disponibilidad de servicio.

# Supported Oracle versions

12c–23ai (multitenant no existe en 10g/11g).

# Supported OS/platforms

Todas las soportadas por el stack.

# Supported architectures

Standalone y RAC. CDB/PDB exclusivamente. ASM y Filesystem. Primary y Physical Standby (con las limitaciones de vistas en standby, declaradas explícitamente).

# Prerequisites

Requiere `core/context-discovery` confirmando `container_mode = cdb` y la lista de PDBs visibles.

# Required evidence

- query_id: `Q-CDB-PDB-STATE-001` (`DBA_PDBS`, `V$PDBS`)

# Optional evidence

- query_id: `Q-CDB-CONTAINERS-001` (`V$CONTAINERS`, metadata adicional de contenedor)

# Read-only operations

Lectura de `DBA_PDBS`, `V$PDBS`, `V$CONTAINERS`.

# Forbidden operations

No ejecuta `ALTER PLUGGABLE DATABASE OPEN/CLOSE/UNPLUG`, no crea/elimina PDBs.

# Decision logic

1. Para cada PDB, leer `OPEN_MODE` y `RESTRICTED`.
2. Si `OPEN_MODE = MOUNTED` fuera de una ventana de mantenimiento conocida (no declarada en `constraints` del Task Package) → severidad `HIGH` (PDB no disponible para aplicación).
3. Si `RESTRICTED = YES` fuera de contexto de mantenimiento → `MEDIUM`, señalando que sólo usuarios con privilegio `RESTRICTED SESSION` pueden conectar.
4. Si `OPEN_MODE = READ ONLY` y no se esperaba (el DBA no lo declaró como PDB de sólo lectura intencional) → `MEDIUM`.

# Confidence model

`FACT` para el estado leído directamente. `PROBABLE_CAUSE` sólo si el estado inesperado coincide con un evento reportado por el DBA (ej. "la aplicación X no puede conectar desde hace una hora").

# Output schema

```yaml
findings:
  - pdb: string
    open_mode: string
    restricted: bool
    severity: LOW|MEDIUM|HIGH
    confidence: FACT|PROBABLE_CAUSE
    evidence_refs: [EVD-...]
```

# Related skills

`multitenant/pdb`, `multitenant/services`, `multitenant/troubleshooting`.

# Escalation

Un PDB `MOUNTED`/`RESTRICTED` inesperado en producción escala inmediatamente a `incident-root-cause-analyst`.

# Data sensitivity

Baja: nombres de PDB pueden enmascararse según política si revelan nombres de cliente/aplicación.

# Context budget

Bajo: escala linealmente con el número de PDBs, acotable vía `constraints.pdb_scope` del Task Package.

# Tests

`tests/test_cdb_pdb_detection.sh`, `tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `findings.md` desglosado por PDB.

# Evolution via `/change`

Cambios de umbral/severidad vía `/change policy`; nuevas queries vía `/change query`.

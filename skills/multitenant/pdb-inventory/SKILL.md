---
name: pdb-inventory
id: multitenant/pdb-inventory
version: 1.0.0
domain: multitenant
status: active
---

# Purpose

Inventariar todas las PDBs de un CDB — `CON_ID`/`NAME`/`OPEN_MODE`/`RESTRICTED`/`OPEN_TIME`/`TOTAL_SIZE`/`RECOVERY_STATUS` — base para el resto de skills de PDB (`# 10` del prompt de Fase 6).

# Supported Oracle versions

12c–23ai. `OPEN_TIME`/`TOTAL_SIZE`/`RECOVERY_STATUS` disponibles en todo el rango 12.1+ (no requieren guardia adicional).

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`multitenant/cdb-discovery` confirmó `multitenant_mode == cdb`.

# Required evidence

- `Q-CDB-PDB-STATE-001` (`V$PDBS`)

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno para el inventario básico. Multi-PDB más allá del límite de edición es `LICENSE_DEPENDENT` — señalado como finding separado, no bloquea el inventario.

# Query IDs

`Q-CDB-PDB-STATE-001`.

# Collector IDs

Ninguno propio.

# Read-only operations

Lectura de `V$PDBS`.

# Forbidden operations

No crea/elimina/abre/cierra PDBs.

# Decision logic

1. Para CDBs con muchas PDBs, nunca enviar el inventario completo por defecto — resumir (`pdb_count`, `open_state_summary`) y aplicar `top_n` (`# 49`, `# 50` del prompt).
2. No asumir disponibilidad universal de todas las columnas — usar las variantes (12.1 vs. 12.2+) ya certificadas en `Q-CDB-PDB-STATE-001`.
3. Publicar el inventario tokenizado (`pdb_token`) para consumo del resto de skills.

# Normal state

Todas las PDBs esperadas presentes en el inventario, con `total_size`/`recovery_status` determinables.

# Abnormal patterns

Una PDB esperada por el DBA ausente del inventario (posible unplug no comunicado) — se reporta como `HYPOTHESIS`, nunca `FACT`, hasta correlación adicional.

# False positives

Ninguno propio — el inventario en sí es una lectura directa; la evaluación de estado la hace `multitenant/pdb-state`.

# Correlation rules

Alimenta `multitenant/pdb-state`, `multitenant/pdb-open-mode`, `multitenant/application-containers`, `multitenant/proxy-pdb` — todos consumen el mismo inventario, nunca vuelven a consultar `V$PDBS` por separado.

# Confidence model

`FACT` para todo campo leído directamente.

# Severity

N/A — el inventario no asigna severidad, eso lo hace `multitenant/pdb-state`.

# Output schema

```yaml
pdb_inventory:
  - con_id: int
    pdb_token: string
    total_size_bytes: int|null
    recovery_status: string|null
    evidence_refs: [EVD-...]
```

# Related skills

`multitenant/pdb-state`, `multitenant/pdb-open-mode`.

# Escalation

N/A — ver `multitenant/pdb-state` para escalación por estado anómalo.

# Manual remediation guidance

Ninguna.

# Security

`pdb_token` tokenizado consistentemente (`PDB_001`, `PDB_002`, ...) en toda la sesión de análisis.

# Tests

`tests/test_pdb_inventory.sh`, `tests/test_no_write_operations.sh`, `tests/test_multitenant_container_scope.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/pdb-inventory.md`.

# Change history

v1.0.0 — Fase 6, creación inicial.

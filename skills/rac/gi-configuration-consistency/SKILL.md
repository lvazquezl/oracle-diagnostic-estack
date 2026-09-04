---
name: gi-configuration-consistency
id: rac/gi-configuration-consistency
version: 1.0.0
domain: rac
status: active
---

# Purpose

Responder "¿existe inconsistencia entre GI y la base de datos?" (`# 1` del prompt de Fase 4) — ej. `srvctl config database` (registro en GI) vs. `cluster_database`/instancias reales reportadas por la base. Distinto de `rac/configuration-drift`, que compara instancias entre sí, no GI vs. base.

# Supported Oracle versions

11gR2–23ai.

# Supported OS/platforms

Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server.

# Supported architectures

RAC y RAC One Node.

# Prerequisites

`rac/topology` y `rac/gi-version` resueltos.

# Required evidence

- `Q-ORA-PARAMETERS-RAC-DIFF-001` (`cluster_database` y parámetros relacionados)
- collector `get_cluster_resources` extendido con `srvctl config database` para comparar

# Optional evidence

- `rac/gi-version` para version mismatch GI vs. Oracle Home de la base.

# Read-only operations

Lectura de `V$PARAMETER`/`GV$PARAMETER` y salida estructurada de `srvctl config database`.

# Forbidden operations

No corrige el registro en GI (`srvctl modify database` prohibido).

# Decision logic

1. Comparar el número de instancias registradas en GI (`srvctl config database`) contra `cluster_database`/instancias visibles en `GV$INSTANCE`.
2. Comparar la versión de Oracle Home registrada en GI contra la versión reportada por la instancia.
3. Cualquier discrepancia se reporta como observación de configuración — nunca se corrige automáticamente.

# Confidence model

`FACT` para ambas fuentes leídas directamente. `OBSERVATION` para la discrepancia detectada.

# Output schema

```yaml
findings:
  - dimension: INSTANCE_COUNT|ORACLE_HOME_VERSION
    gi_value: string
    database_value: string
    consistent: bool
    evidence_refs: [EVD-...]
```

# Related skills

`rac/configuration-drift`, `rac/gi-version`.

# Escalation

Inconsistencia relevante (ej. instancia activa no registrada en GI) → `change-advisor` para propuesta de alineación manual.

# Data sensitivity

Media.

# Context budget

Media.

# Tests

`tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `rac-topology.md`.

# Evolution via `/change`

Nuevas dimensiones de consistencia vía `/change query`.

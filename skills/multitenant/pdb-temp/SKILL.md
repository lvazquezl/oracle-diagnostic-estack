---
name: pdb-temp
id: multitenant/pdb-temp
version: 1.0.0
domain: multitenant
status: active
---

# Purpose

Análisis de presión de TEMP scoped por PDB cuando la versión lo permite, correlacionando con Performance si hay waits TEMP (`# 18` del prompt de Fase 6).

# Supported Oracle versions

12c–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`multitenant/pdb-tablespaces` resuelto.

# Required evidence

- `Q-CDB-TEMP-001` (`CDB_TEMP_FILES`/`GV$TEMP_SPACE_HEADER`)

# Optional evidence

Ninguna propia — waits TEMP se obtienen vía delegación a `oracle-performance-analyst`.

# Licensing requirements

Ninguno.

# Query IDs

`Q-CDB-TEMP-001`.

# Collector IDs

Ninguno propio.

# Read-only operations

Lectura de `CDB_TEMP_FILES`/`GV$TEMP_SPACE_HEADER`.

# Forbidden operations

No resize/agrega tempfile automáticamente (`# 18`).

# Decision logic

1. Calcular presión (`LOW|MEDIUM|HIGH|UNKNOWN`) a partir de `bytes_used`/`bytes_free` por PDB.
2. Si hay presión `HIGH`, delegar a `oracle-performance-analyst` para confirmar correlación con waits TEMP reales (`direct path read/write temp`) — nunca afirmar la causa sin esa evidencia.

# Normal state

Uso de TEMP por debajo de umbrales de presión, con margen suficiente.

# Abnormal patterns

Presión `HIGH` sostenida, especialmente si coincide con operaciones de ordenamiento/hash grandes reportadas por el DBA.

# False positives

Un pico temporal de TEMP durante una carga batch conocida no es un problema por sí solo.

# Correlation rules

Delega a `oracle-performance-analyst` para el lado waits — este skill sólo aporta el lado de capacidad.

# Confidence model

`OBSERVATION` para la presión calculada; nunca `PROBABLE_CAUSE` sin correlación de waits confirmada por Performance.

# Severity

Presión `HIGH` sostenida → `MEDIUM`/`HIGH` según impacto reportado.

# Output schema

```yaml
pdb_temp:
  - pdb_token: string
    used_bytes: int|null
    allocated_bytes: int|null
    pressure: LOW|MEDIUM|HIGH|UNKNOWN
    evidence_refs: [EVD-...]
```

# Related skills

`multitenant/pdb-tablespaces`, `multitenant/pdb-undo`.

# Escalation

Presión `HIGH` con impacto en producción → `oracle-performance-analyst`, luego `incident-root-cause-analyst` si no se resuelve.

# Manual remediation guidance

Resize/agregar tempfile se entrega vía Manual Action Contract, `execution_status: NOT_EXECUTED`.

# Security

`pdb_token` tokenizado.

# Tests

`tests/test_pdb_temp.sh`, `tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/pdb-findings.md`.

# Change history

v1.0.0 — Fase 6, creación inicial.

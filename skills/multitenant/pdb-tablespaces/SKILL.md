---
name: pdb-tablespaces
id: multitenant/pdb-tablespaces
version: 1.0.0
domain: multitenant
status: active
---

# Purpose

Uso de tablespaces por PDB — reutiliza el modelo de Oracle Core, extendido con `con_id` — used/free/autoextend/status/contents, nunca capacidad física ASM subyacente (`# 16`, `# 17` del prompt de Fase 6).

# Supported Oracle versions

12c–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC. ASM y Filesystem.

# Prerequisites

`multitenant/pdb-inventory` resuelto.

# Required evidence

- `Q-CDB-TABLESPACES-001` (`CDB_TABLESPACE_USAGE_METRICS`/`CDB_TABLESPACES`/`CDB_DATA_FILES`)

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno.

# Query IDs

`Q-CDB-TABLESPACES-001`.

# Collector IDs

Ninguno propio.

# Read-only operations

Lectura de `CDB_TABLESPACE_USAGE_METRICS`/`CDB_TABLESPACES`/`CDB_DATA_FILES`.

# Forbidden operations

No agrega datafiles, no modifica autoextend (`# 17`: no agregar datafiles).

# Decision logic

1. Reportar `used_percent`/`used_space`/`tablespace_size` por PDB/tablespace.
2. Distinguir `contents` (`PERMANENT`/`TEMPORARY`/`UNDO`) — TEMP y UNDO se cubren con más detalle en `multitenant/pdb-temp`/`pdb-undo`, este skill da la vista general.
3. Nunca mezclar capacidad lógica de PDB con capacidad física ASM — una presión de tablespace con sospecha de origen ASM se delega a `oracle-asm-storage-analyst`, nunca se infiere directamente (`# 16`, `# 35`).

# Normal state

`used_percent` dentro de umbrales normales, `autoextend` habilitado donde se espera.

# Abnormal patterns

Tablespace cerca de `MAXSIZE` sin `autoextend`, o `autoextend` habilitado sin límite en un filesystem con poco espacio libre (correlacionar con `oracle-asm-storage-analyst`/`os-platform-analyst`).

# False positives

Un tablespace `READ ONLY` intencional (histórico) con `used_percent` alto no es un problema.

# Correlation rules

Delega a `oracle-asm-storage-analyst` cuando hay evidencia de presión de diskgroup detrás de la capacidad lógica (`# 35`).

# Confidence model

`FACT` para el uso leído directamente.

# Severity

`used_percent > 90%` sin autoextend → `HIGH`.

# Output schema

```yaml
pdb_storage:
  - pdb_token: string
    tablespace: string
    used_bytes: int|null
    free_bytes: int|null
    autoextend: bool|null
    status: string
    contents: PERMANENT|TEMPORARY|UNDO
    evidence_refs: [EVD-...]
```

# Related skills

`multitenant/pdb-temp`, `multitenant/pdb-undo`.

# Escalation

Tablespace crítico sin espacio y sin autoextend → `incident-root-cause-analyst`.

# Manual remediation guidance

Resize/agregar datafile se entrega vía Manual Action Contract, `execution_status: NOT_EXECUTED`.

# Security

`tablespace`/`pdb_token` → KEEP/tokenizado según política.

# Tests

`tests/test_pdb_tablespaces.sh`, `tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/pdb-findings.md`.

# Change history

v1.0.0 — Fase 6, creación inicial.

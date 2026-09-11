---
name: backup-inventory
id: rman/backup-inventory
version: 1.0.0
domain: rman
status: active
---

# Purpose

Inventario normalizado de backups (tipo, nivel, device type, tiempos, tamaño, tag, controlfile/SPFILE incluido) desde backup sets y piezas físicas — base de todo el resto del dominio (`# 9` del prompt de Fase 7).

# Supported Oracle versions

10g–23ai. `CON_ID` (multitenant-aware) sólo 12.1+ vía `Q-RMAN-BACKUP-SET-001-V2`.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`rman/configuration` resuelto (contexto de device type default).

# Required evidence

- `Q-RMAN-BACKUP-SET-001`
- `Q-RMAN-BACKUP-PIECE-001`

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno.

# Query IDs

`Q-RMAN-BACKUP-SET-001`, `Q-RMAN-BACKUP-PIECE-001`.

# Collector IDs

`get_backup_inventory`.

# Read-only operations

Lectura de `V$BACKUP_SET`/`V$BACKUP_PIECE`.

# Forbidden operations

Nunca ejecuta `BACKUP`/`DELETE`/`CROSSCHECK`/`CHANGE`.

# Decision logic

1. Normalizar `BACKUP_TYPE`+`INCREMENTAL_LEVEL` a `FULL|INCREMENTAL_LEVEL_0|LEVEL_1_DIFFERENTIAL|LEVEL_1_CUMULATIVE|ARCHIVELOG|CONTROLFILE|SPFILE|IMAGE_COPY` — nunca por heurística de `TAG` (`# 9`).
2. Unir con `V$BACKUP_PIECE` (`SET_STAMP`) para conteo de piezas disponibles vs. declaradas.
3. Piezas con `STATUS` distinto de `A` (Available) → marcar el backup set como parcialmente inutilizable, nunca asumir completo.

# Normal state

Backup sets con todas sus piezas en `STATUS = A`.

# Abnormal patterns

Backup set con `PIECES` declarado mayor al número de piezas `A` disponibles — evidencia de pieza perdida/inaccesible.

# False positives

Piezas `STATUS = D` (Deleted) intencionalmente tras rotación de retención no son un problema — reflejan limpieza ya ejecutada por el DBA.

# Correlation rules

Alimenta `rman/backup-freshness`, `rman/full-backup`, `rman/incremental-backup`, `rman/restore-readiness`.

# Confidence model

`FACT` para inventario leído directamente.

# Severity

Pieza declarada pero no disponible en un backup reciente → `MEDIUM`/`HIGH` según antigüedad del gap.

# Output schema

```yaml
backup_inventory:
  - key: string
    type: FULL|INCREMENTAL_LEVEL_0|LEVEL_1_DIFFERENTIAL|LEVEL_1_CUMULATIVE|ARCHIVELOG|CONTROLFILE|SPFILE|IMAGE_COPY
    device_type: DISK|SBT_TAPE|UNKNOWN
    start_time: string|null
    completion_time: string|null
    pieces: int|null
    tag_token: string|null
    controlfile_included: bool|null
    con_id: int|null
    evidence_refs: [EVD-...]
```

# Related skills

`rman/backup-status`, `rman/backup-freshness`, `rman/full-backup`, `rman/incremental-backup`, `rman/restore-readiness`.

# Escalation

Piezas perdidas en el backup más reciente de producción → `incident-root-cause-analyst`.

# Manual remediation guidance

Backup faltante se entrega como recomendación de `BACKUP` manual vía Manual Action Contract — nunca ejecutado.

# Security

`tag_token`/`handle` siempre tokenizados.

# Tests

`tests/test_backup_inventory_query.sh`, `tests/test_backup_piece_query.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/backup-inventory.md`.

# Change history

v1.0.0 — Fase 7, creación inicial.

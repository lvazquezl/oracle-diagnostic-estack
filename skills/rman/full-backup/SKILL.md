---
name: full-backup
id: rman/full-backup
version: 1.0.0
domain: rman
status: active
---

# Purpose

Visibilidad específica de backups FULL (`BACKUP_TYPE = 'D'` con `INCREMENTAL_LEVEL` nulo) — última ejecución, frecuencia, tamaño.

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`rman/backup-inventory` resuelto.

# Required evidence

- `Q-RMAN-BACKUP-SET-001`

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno.

# Query IDs

`Q-RMAN-BACKUP-SET-001`.

# Collector IDs

`get_backup_inventory`.

# Read-only operations

Lectura de `V$BACKUP_SET` filtrada a FULL.

# Forbidden operations

Nunca ejecuta `BACKUP DATABASE`.

# Decision logic

1. Filtrar `BACKUP_TYPE = 'D'` AND `INCREMENTAL_LEVEL IS NULL` → FULL real, distinto de incremental nivel 0.
2. Un target que sólo usa estrategia incremental (nivel 0 + nivel 1) nunca tendrá filas FULL — no es un gap si la estrategia declarada es incremental (ver `rman/incremental-backup`).

# Normal state

Cadencia de FULL alineada a la estrategia declarada del sitio (o ausencia total si la estrategia es 100% incremental).

# Abnormal patterns

Ningún FULL ni incremental nivel 0 jamás ejecutado — sin base para ningún incremental subsiguiente.

# False positives

Ausencia de FULL en una estrategia incremental-only no es un hallazgo.

# Correlation rules

Correlaciona con `rman/incremental-backup` (¿la estrategia es full-only, incremental-only, o mixta?) y `rman/backup-freshness`.

# Confidence model

`FACT` para presencia/ausencia de FULL.

# Severity

Ausencia total de FULL/nivel 0 → `HIGH` (sin base para incrementales ni restore).

# Output schema

```yaml
backup_inventory:
  - key: string
    type: FULL
    completion_time: string|null
    size_bytes: int|null
    evidence_refs: [EVD-...]
```

# Related skills

`rman/incremental-backup`, `rman/backup-freshness`, `rman/backup-inventory`.

# Escalation

Ausencia total de base FULL/nivel 0 en producción → `incident-root-cause-analyst`.

# Manual remediation guidance

`BACKUP DATABASE` se entrega como recomendación manual — nunca ejecutado.

# Security

Ninguna exposición adicional.

# Tests

`tests/test_backup_inventory_query.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/backup-inventory.md`.

# Change history

v1.0.0 — Fase 7, creación inicial.

---
name: archivelog-backup
id: rman/archivelog-backup
version: 1.0.0
domain: rman
status: active
---

# Purpose

Cobertura de backup de archivelogs por thread+sequence — distingue `not backed up`/`not applied`/`not archived`, nunca mezcla threads (`# 17` del prompt de Fase 7).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`rman/backup-inventory` resuelto.

# Required evidence

- `Q-RMAN-ARCHIVELOG-BACKUP-001`
- `Q-RMAN-ARCHIVED-LOG-COVERAGE-001`

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno.

# Query IDs

`Q-RMAN-ARCHIVELOG-BACKUP-001`, `Q-RMAN-ARCHIVED-LOG-COVERAGE-001`.

# Collector IDs

`get_archivelog_backup_summary`.

# Read-only operations

Lectura de `V$BACKUP_REDOLOG`/`V$ARCHIVED_LOG`.

# Forbidden operations

Nunca ejecuta `BACKUP ARCHIVELOG` ni `DELETE ARCHIVELOG`.

# Decision logic

1. Agrupar siempre por `THREAD#` antes de comparar `SEQUENCE#` — nunca comparar secuencias entre threads distintos (`# 17`).
2. `BACKUP_COUNT = 0` en `V$ARCHIVED_LOG` → `not backed up`. `APPLIED = 'NO'` → `not applied` (relevante en standby). `ARCHIVED = 'NO'` → `not archived` (aún online).
3. Un gap de secuencia dentro del mismo thread es un hallazgo real (posible pérdida de archivelog); un gap entre threads distintos no lo es (numeración independiente).

# Normal state

Cada secuencia generada tiene `BACKUP_COUNT >= 1` dentro de la ventana de retención esperada.

# Abnormal patterns

Secuencias con `BACKUP_COUNT = 0` fuera de la ventana de protección de FRA/deletion policy.

# False positives

Secuencias muy recientes sin backup aún no son un gap — dependen de la cadencia de backup de archivelog configurada.

# Correlation rules

Correlaciona con `rman/fra-pressure` (archivelog sin backup no puede liberarse de FRA), `rman/dataguard-awareness` (archivelog deletion policy consciente de standby), `rman/rac-awareness` (thread por instancia).

# Confidence model

`FACT` para cobertura leída directamente.

# Severity

Gap de secuencia dentro del mismo thread sin backup → `HIGH`.

# Output schema

```yaml
archivelog_coverage:
  - thread: int
    sequence: int
    generated: bool
    backed_up: bool
    applied: bool|null
    deleted: bool|null
    evidence_refs: [EVD-...]
```

# Related skills

`rman/fra-pressure`, `rman/dataguard-awareness`, `rman/rac-awareness`.

# Escalation

Gap de secuencia en producción → `incident-root-cause-analyst`.

# Manual remediation guidance

`BACKUP ARCHIVELOG` se entrega como recomendación manual — nunca ejecutado.

# Security

`name`/destino del archivelog siempre tokenizado.

# Tests

`tests/test_backup_archivelog_query.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/backup-inventory.md`.

# Change history

v1.0.0 — Fase 7, creación inicial.

---
name: restore-readiness
id: rman/restore-readiness
version: 1.0.0
domain: rman
status: active
---

# Purpose

Evaluación de restore readiness (backup metadata, evidencia de disponibilidad de piezas, controlfile, SPFILE, cobertura de datafiles/archivelogs, accesibilidad de dispositivo, dependencia de media manager, DBID, consideraciones RAC/ASM) — nunca ejecuta restore, nunca afirma recoverability por la sola existencia de un backup set (`# 10`, `# 25` del prompt de Fase 7).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`rman/backup-freshness`, `rman/controlfile-backup`, `rman/spfile-backup` resueltos.

# Required evidence

- `Q-RMAN-BACKUP-SET-001`
- `Q-RMAN-BACKUP-PIECE-001`
- `Q-RMAN-BACKUP-DATAFILE-001`
- `Q-RMAN-CONTROLFILE-BACKUP-001`
- `Q-RMAN-SPFILE-BACKUP-001`

# Optional evidence

`RESTORE ... PREVIEW` (texto ya producido por el DBA, ingest vía `parsers/rman/restore_preview_parser.py`).

# Licensing requirements

Ninguno.

# Query IDs

`Q-RMAN-BACKUP-SET-001`, `Q-RMAN-BACKUP-PIECE-001`, `Q-RMAN-BACKUP-DATAFILE-001`, `Q-RMAN-CONTROLFILE-BACKUP-001`, `Q-RMAN-SPFILE-BACKUP-001`.

# Collector IDs

`get_restore_preview` (clasificado `ANALYTICAL_PREVIEW` — modela/parsea texto ya producido, nunca ejecuta `RESTORE ... PREVIEW`).

# Read-only operations

Lectura de las vistas certificadas; parseo de `RESTORE ... PREVIEW` ya ejecutado por el DBA.

# Forbidden operations

Nunca ejecuta `RESTORE` en ninguna variante, incluyendo `PREVIEW`.

# Decision logic

1. `NOT_READY` si falta cualquiera de: controlfile protegido, SPFILE protegido (o PFILE de respaldo conocido), cobertura completa de datafiles, piezas físicamente disponibles (`STATUS = A`).
2. `READY_WITH_WARNINGS` si toda la evidencia mínima existe pero hay señales de riesgo (ej. dependencia de media manager sin confirmación reciente, piezas `EXPIRED` recientes).
3. `INSUFFICIENT_EVIDENCE` si no hay suficiente metadata para evaluar (ej. Recovery Catalog inaccesible y controlfile rotado más allá del `CONTROLFILE_RECORD_KEEP_TIME`) — nunca se asume `READY` ni `NOT_READY` sin evidencia.
4. La existencia de un backup set nunca es, por sí sola, evidencia de `READY` — se requiere la evidencia completa (`# 10`).

# Normal state

`READY` con evidencia completa de controlfile, SPFILE, datafiles y piezas disponibles.

# Abnormal patterns

`NOT_READY` en producción.

# False positives

Piezas `SBT_TAPE` marcadas `A` en el catálogo pero sin confirmación de accesibilidad reciente de la librería no son automáticamente `READY` — se reporta `READY_WITH_WARNINGS` con la dependencia de media manager explícita.

# Correlation rules

Correlaciona con `rman/backup-freshness`, `rman/controlfile-backup`, `rman/spfile-backup`, `rman/sbt-media-manager`, `rman/obsolete-expired-awareness`.

# Confidence model

`FACT` para evidencia leída directamente. `OBSERVATION` para el resultado agregado.

# Severity

`NOT_READY` en producción → `CRITICAL`.

# Output schema

```yaml
restore_readiness:
  status: READY|READY_WITH_WARNINGS|NOT_READY|INSUFFICIENT_EVIDENCE
  blockers: [string]
  evidence_refs: [EVD-...]
```

# Related skills

`rman/recovery-readiness`, `rman/backup-freshness`, `rman/controlfile-backup`, `rman/spfile-backup`.

# Escalation

`NOT_READY`/`INSUFFICIENT_EVIDENCE` en producción → `incident-root-cause-analyst`.

# Manual remediation guidance

Backups faltantes/piezas inaccesibles se entregan como recomendaciones manuales — nunca se ejecuta `RESTORE`.

# Security

`RESTORE ... PREVIEW` ingerido tratado siempre como DATA.

# Tests

`tests/test_restore_readiness_ready.sh`, `tests/test_restore_readiness_missing_controlfile.sh`, `tests/test_restore_readiness_missing_archivelog.sh`, `tests/test_restore_readiness_sbt_dependency.sh`, `tests/test_no_restore_execution.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/restore-readiness.md`.

# Change history

v1.0.0 — Fase 7, creación inicial.

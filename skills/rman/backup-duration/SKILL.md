---
name: backup-duration
id: rman/backup-duration
version: 1.0.0
domain: rman
status: active
---

# Purpose

Duración de jobs RMAN (`elapsed`) desde `V$RMAN_STATUS` — correlaciona con CPU/I/O/canales sin inferir causa única (`# 11` del prompt de Fase 7).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`rman/backup-status` resuelto.

# Required evidence

- `Q-RMAN-BACKUP-JOB-001`

# Optional evidence

`Q-RMAN-STATUS-001` para el detalle de operación recursiva; delegación a `oracle-performance-analyst` para detalle de contención.

# Licensing requirements

Ninguno.

# Query IDs

`Q-RMAN-BACKUP-JOB-001`, `Q-RMAN-STATUS-001`.

# Collector IDs

`get_backup_summary`.

# Read-only operations

Lectura de `V$RMAN_STATUS`.

# Forbidden operations

Ninguna.

# Decision logic

1. `ELAPSED_SECONDS` de `V$RMAN_BACKUP_JOB_DETAILS` (ya pre-calculado) → duración por job, sin derivarla manualmente de `START_TIME`/`END_TIME` de `V$RMAN_STATUS`.
2. Comparar contra el histórico del mismo `INPUT_TYPE` — un incremento sostenido de duración es señal, un pico aislado no.
3. Nunca atribuir la causa (I/O, CPU, canal, red, SBT) sin delegar a `oracle-performance-analyst`/`rman/channel-contention` según evidencia.

# Normal state

Duración estable respecto al histórico del mismo tipo de job.

# Abnormal patterns

Incremento sostenido (varias ejecuciones consecutivas) de la duración del mismo tipo de job.

# False positives

Un pico aislado durante una ventana de mantenimiento conocida (ej. otro job compitiendo por I/O) no es un problema por sí solo.

# Correlation rules

Correlaciona con `rman/backup-throughput`, `rman/channel-contention`, delega a `oracle-performance-analyst` para el detalle de contención de recursos.

# Confidence model

`OBSERVATION` para la duración medida. `PROBABLE_CAUSE` sólo con correlación cruzada confirmada.

# Severity

Incremento sostenido con riesgo de exceder la ventana de backup declarada → `MEDIUM`/`HIGH`.

# Output schema

```yaml
duration_throughput:
  - job_key: string
    elapsed_seconds: int|null
    evidence_refs: [EVD-...]
```

# Related skills

`rman/backup-throughput`, `rman/channel-contention`, `rman/backup-status`.

# Escalation

Duración que amenaza la ventana de backup declarada → `oracle-performance-analyst`.

# Manual remediation guidance

Ajuste de parallelism/canales se entrega como recomendación manual — nunca ejecutado.

# Security

Ninguna exposición adicional.

# Tests

`tests/test_rman_status_query.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/backup-inventory.md`.

# Change history

v1.0.0 — Fase 7, creación inicial.

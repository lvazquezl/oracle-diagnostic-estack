---
name: backup-throughput
id: rman/backup-throughput
version: 1.0.0
domain: rman
status: active
---

# Purpose

Throughput agregado/por canal/de media manager (`input_bytes`, `output_bytes`, MB/s) desde `V$RMAN_STATUS` — correlaciona con compresión/canales sin inferir causa única (`# 11` del prompt de Fase 7).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`rman/backup-duration` resuelto.

# Required evidence

- `Q-RMAN-BACKUP-JOB-001`

# Optional evidence

Delegación a `oracle-performance-analyst`.

# Licensing requirements

Ninguno.

# Query IDs

`Q-RMAN-BACKUP-JOB-001`.

# Collector IDs

`get_backup_summary`.

# Read-only operations

Lectura de `V$RMAN_STATUS`.

# Forbidden operations

Ninguna.

# Decision logic

1. `OUTPUT_BYTES_PER_SEC`/`INPUT_BYTES_PER_SEC` de `V$RMAN_BACKUP_JOB_DETAILS` (ya pre-calculados) — distinto de throughput por canal (requiere `V$RMAN_STATUS` a nivel `ROW_TYPE = 'COMMAND'`/canal individual cuando disponible).
2. `COMPRESSION_RATIO` bajo no es un problema, es evidencia de compresión activa; correlacionar con `rman/configuration#compression_algorithm` antes de reportar.
3. Throughput degradado sostenido → delegar a `oracle-performance-analyst`, nunca inferir I/O/CPU/red como causa sin ese agente.

# Normal state

Throughput estable respecto al histórico del mismo tipo de job/device type.

# Abnormal patterns

Caída sostenida de MB/s en el mismo device type sin cambio de configuración conocido.

# False positives

Menor throughput hacia SBT que hacia DISK no es anómalo por sí solo — perfil esperado de media manager.

# Correlation rules

Correlaciona con `rman/backup-duration`, `rman/channels`, `rman/sbt-media-manager`.

# Confidence model

`OBSERVATION` para el throughput medido.

# Severity

Degradación sostenida con riesgo de ventana de backup → `MEDIUM`.

# Output schema

```yaml
duration_throughput:
  - job_key: string
    input_bytes: int|null
    output_bytes: int|null
    aggregate_mb_per_sec: number|null
    device_type: DISK|SBT_TAPE|UNKNOWN
    evidence_refs: [EVD-...]
```

# Related skills

`rman/backup-duration`, `rman/channels`, `rman/sbt-media-manager`.

# Escalation

Degradación sostenida → `oracle-performance-analyst`.

# Manual remediation guidance

Ajuste de compresión/parallelism se entrega como recomendación manual — nunca ejecutado.

# Security

Ninguna exposición adicional.

# Tests

`tests/test_rman_status_query.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/backup-inventory.md`.

# Change history

v1.0.0 — Fase 7, creación inicial.

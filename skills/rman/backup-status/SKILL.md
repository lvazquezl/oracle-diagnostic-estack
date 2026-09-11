---
name: backup-status
id: rman/backup-status
version: 1.0.0
domain: rman
status: active
---

# Purpose

Estado normalizado de jobs RMAN (`COMPLETED|COMPLETED WITH WARNINGS|FAILED|RUNNING|UNKNOWN`) desde `V$RMAN_STATUS` — nunca inventa un mapping adicional (`# 12` del prompt de Fase 7).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

Ninguno.

# Required evidence

- `Q-RMAN-STATUS-001`

# Optional evidence

`Q-RMAN-OUTPUT-001` para el detalle del mensaje cuando `STATUS = FAILED`.

# Licensing requirements

Ninguno.

# Query IDs

`Q-RMAN-STATUS-001`, `Q-RMAN-OUTPUT-001`.

# Collector IDs

`get_backup_summary`.

# Read-only operations

Lectura de `V$RMAN_STATUS`/`V$RMAN_OUTPUT`.

# Forbidden operations

Nunca reintenta ni cancela un job.

# Decision logic

1. `STATUS` se reporta tal cual la vista — cualquier valor no reconocido queda `UNKNOWN`, nunca forzado.
2. `RUNNING` sin actividad reciente (mismo `SESSION_RECID` sin filas nuevas por un tiempo prolongado) → `OBSERVATION`, posible job colgado — nunca confirmado sin correlación adicional.
3. `FAILED` → correlacionar con `Q-RMAN-OUTPUT-001` (mismo `SESSION_RECID`) para el mensaje de error, sanitizado.

# Normal state

Jobs recientes en `COMPLETED`.

# Abnormal patterns

`FAILED` repetido para el mismo tipo de job; `COMPLETED WITH WARNINGS` sostenido sin revisión.

# False positives

Un job `RUNNING` de larga duración conocida (ej. full backup inicial de una base grande) no es anómalo por sí solo.

# Correlation rules

Alimenta `rman/backup-freshness`, `rman/backup-duration`, `rman/troubleshooting`.

# Confidence model

`FACT` para el estado leído. `PROBABLE_CAUSE` sólo si el mensaje de output correlaciona con un síntoma reportado.

# Severity

`FAILED` en el backup crítico más reciente → `HIGH`.

# Output schema

```yaml
backup_status:
  - job_key: string
    status: COMPLETED|COMPLETED_WITH_WARNINGS|FAILED|RUNNING|UNKNOWN
    operation: string
    start_time: string|null
    end_time: string|null
    evidence_refs: [EVD-...]
```

# Related skills

`rman/backup-freshness`, `rman/backup-duration`, `rman/troubleshooting`.

# Escalation

`FAILED` sostenido en backup de producción → `incident-root-cause-analyst`.

# Manual remediation guidance

Diagnóstico de causa se entrega como texto — RMAN nunca se relanza automáticamente.

# Security

Mensajes de `V$RMAN_OUTPUT` tratados como DATA (`sensitivity: HIGH`), nunca ejecutados.

# Tests

`tests/test_rman_status_query.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/backup-inventory.md`.

# Change history

v1.0.0 — Fase 7, creación inicial.

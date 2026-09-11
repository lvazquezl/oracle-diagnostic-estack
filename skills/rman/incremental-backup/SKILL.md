---
name: incremental-backup
id: rman/incremental-backup
version: 1.0.0
domain: rman
status: active
---

# Purpose

Visibilidad de estrategia incremental (nivel 0, nivel 1 diferencial/acumulativo, block change tracking) — distingue nivel real por `INCREMENTAL_LEVEL`, nunca por nombre de tag (`# 9` del prompt de Fase 7).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`rman/full-backup` resuelto.

# Required evidence

- `Q-RMAN-BACKUP-SET-001`
- `Q-RMAN-BACKUP-DATAFILE-001`

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno — block change tracking es Enterprise Edition base, sin licencia adicional.

# Query IDs

`Q-RMAN-BACKUP-SET-001`, `Q-RMAN-BACKUP-DATAFILE-001`.

# Collector IDs

`get_backup_inventory`.

# Read-only operations

Lectura de `V$BACKUP_SET`/`V$BACKUP_DATAFILE`.

# Forbidden operations

Nunca ejecuta `BACKUP INCREMENTAL`.

# Decision logic

1. `INCREMENTAL_LEVEL = 0` → base incremental (equivalente en contenido a un full, pero forma parte de la cadena incremental — distinto conceptualmente de `BACKUP_TYPE = 'D'` sin nivel).
2. `INCREMENTAL_LEVEL = 1` con `V$BACKUP_DATAFILE.USED_CHANGE_TRACKING = 'YES'` → diferencial eficiente vía block change tracking.
3. Nivel 1 sin nivel 0 previo en la cadena → gap real, correlacionar con `rman/restore-readiness` (rollforward incompleto).
4. Diferencial vs. acumulativo no se distingue directamente en `V$BACKUP_SET` — se infiere por el patrón de encadenamiento de niveles 1 consecutivos vs. siempre-desde-nivel-0, nunca por el nombre del tag.

# Normal state

Cadena nivel 0 → nivel(es) 1 consistente, sin gaps.

# Abnormal patterns

Nivel 1 sin nivel 0 base en la cadena visible.

# False positives

Ausencia de incrementales en una estrategia full-only no es un gap.

# Correlation rules

Correlaciona con `rman/full-backup`, `rman/backup-freshness`, `rman/restore-readiness`.

# Confidence model

`FACT` para niveles leídos. `OBSERVATION` para la clasificación diferencial/acumulativo inferida.

# Severity

Cadena rota (nivel 1 sin base) → `HIGH` — rollforward no garantizado.

# Output schema

```yaml
backup_inventory:
  - key: string
    type: INCREMENTAL_LEVEL_0|LEVEL_1_DIFFERENTIAL|LEVEL_1_CUMULATIVE
    completion_time: string|null
    evidence_refs: [EVD-...]
```

# Related skills

`rman/full-backup`, `rman/backup-freshness`, `rman/restore-readiness`.

# Escalation

Cadena rota en producción → `incident-root-cause-analyst`.

# Manual remediation guidance

`BACKUP INCREMENTAL LEVEL 0` se entrega como recomendación manual — nunca ejecutado.

# Security

Ninguna exposición adicional.

# Tests

`tests/test_backup_inventory_query.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/backup-inventory.md`.

# Change history

v1.0.0 — Fase 7, creación inicial.

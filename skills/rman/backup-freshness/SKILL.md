---
name: backup-freshness
id: rman/backup-freshness
version: 1.0.0
domain: rman
status: active
---

# Purpose

Frescura/completeness de backups (`COMPLETE|PARTIAL|STALE|UNKNOWN|INSUFFICIENT_EVIDENCE`) — nunca afirma recoverability por la sola existencia de un backup set (`# 10` del prompt de Fase 7).

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
- `Q-RMAN-CONTROLFILE-BACKUP-001`
- `Q-RMAN-SPFILE-BACKUP-001`

# Optional evidence

`Q-RMAN-ARCHIVELOG-BACKUP-001` (frescura de backup de archivelog).

# Licensing requirements

Ninguno.

# Query IDs

`Q-RMAN-BACKUP-SET-001`, `Q-RMAN-CONTROLFILE-BACKUP-001`, `Q-RMAN-SPFILE-BACKUP-001`, `Q-RMAN-ARCHIVELOG-BACKUP-001`.

# Collector IDs

`get_backup_summary`.

# Read-only operations

Lectura de las vistas ya certificadas.

# Forbidden operations

Ninguna operación de escritura.

# Decision logic

1. `last_full_or_level0`, `last_incremental`, `last_archivelog_backup`, `last_controlfile_backup`, `last_spfile_backup` — cada uno derivado independientemente, nunca inferido de otro.
2. `COMPLETE` sólo si los cinco puntos anteriores están dentro de la ventana esperada (definida por retención/RPO declarado); de lo contrario `PARTIAL`.
3. Sin ningún backup reciente → `STALE`.
4. Sin evidencia suficiente para evaluar (ej. Recovery Catalog inaccesible y controlfile rotado) → `INSUFFICIENT_EVIDENCE`, nunca se asume el peor ni el mejor caso.

# Normal state

`COMPLETE` con los cinco puntos dentro de ventana.

# Abnormal patterns

`last_archivelog_backup` fresco pero `last_full_or_level0` obsoleto (o viceversa) — cobertura parcial real.

# False positives

Un `last_incremental` ausente en una estrategia que sólo usa full backups no es un gap — depende de la estrategia declarada, nunca asumida.

# Correlation rules

Correlaciona con `rman/retention-policy` (¿la ventana esperada es la configurada?) y `rman/restore-readiness`.

# Confidence model

`FACT` para cada "last backup" leído. `OBSERVATION` para la clasificación `COMPLETE/PARTIAL/STALE`.

# Severity

`STALE` en producción → `HIGH`. `PARTIAL` → `MEDIUM`.

# Output schema

```yaml
freshness:
  last_full_or_level0: string|null
  last_incremental: string|null
  last_archivelog_backup: string|null
  last_controlfile_backup: string|null
  last_spfile_backup: string|null
  completeness: COMPLETE|PARTIAL|STALE|UNKNOWN|INSUFFICIENT_EVIDENCE
  evidence_refs: [EVD-...]
```

# Related skills

`rman/backup-inventory`, `rman/retention-policy`, `rman/restore-readiness`, `rman/recovery-readiness`.

# Escalation

`STALE` en producción → `incident-root-cause-analyst`.

# Manual remediation guidance

Backup faltante se entrega como recomendación manual — nunca ejecutado.

# Security

Ninguna exposición adicional — reutiliza sanitización de las queries subyacentes.

# Tests

`tests/test_backup_inventory_query.sh`, `tests/test_controlfile_backup_query.sh`, `tests/test_spfile_backup_query.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/backup-inventory.md`.

# Change history

v1.0.0 — Fase 7, creación inicial.

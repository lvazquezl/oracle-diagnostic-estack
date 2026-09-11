---
name: spfile-backup
id: rman/spfile-backup
version: 1.0.0
domain: rman
status: active
---

# Purpose

Evaluación de protección de SPFILE — nunca restaura (`# 20` del prompt de Fase 7).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`rman/controlfile-backup` resuelto.

# Required evidence

- `Q-RMAN-SPFILE-BACKUP-001`
- `Q-RMAN-CONFIGURATION-001`

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno.

# Query IDs

`Q-RMAN-SPFILE-BACKUP-001`, `Q-RMAN-CONFIGURATION-001`.

# Collector IDs

`get_spfile_backup_status`.

# Read-only operations

Lectura de `V$BACKUP_SPFILE`/`V$RMAN_CONFIGURATION`.

# Forbidden operations

Nunca ejecuta `RESTORE SPFILE`.

# Decision logic

1. Backup explícito de SPFILE reciente, o `CONTROLFILE AUTOBACKUP = ON` (el autobackup de controlfile incluye el SPFILE cuando existe uno) → protegido.
2. Ninguno de los dos → desprotegido real.

# Normal state

SPFILE protegido por backup explícito o por autobackup de controlfile.

# Abnormal patterns

Sin backup de SPFILE y autobackup `OFF`.

# False positives

Ausencia de backup explícito de SPFILE no es un gap si el autobackup de controlfile está `ON` y confirmado reciente.

# Correlation rules

Correlaciona con `rman/controlfile-backup`, `rman/configuration`.

# Confidence model

`FACT` para el estado leído.

# Severity

SPFILE desprotegido → `MEDIUM` (recuperable vía PFILE manual en la mayoría de los casos, pero riesgo real de parámetros perdidos).

# Output schema

```yaml
controlfile_spfile:
  spfile_protected: bool|null
  evidence_refs: [EVD-...]
```

# Related skills

`rman/controlfile-backup`, `rman/configuration`.

# Escalation

SPFILE desprotegido en producción sin PFILE de respaldo conocido → `incident-root-cause-analyst`.

# Manual remediation guidance

`BACKUP SPFILE` se entrega como recomendación manual — nunca ejecutado.

# Security

Ninguna exposición adicional.

# Tests

`tests/test_spfile_backup_query.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/backup-inventory.md`.

# Change history

v1.0.0 — Fase 7, creación inicial.

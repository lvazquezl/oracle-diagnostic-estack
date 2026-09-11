---
name: controlfile-backup
id: rman/controlfile-backup
version: 1.0.0
domain: rman
status: active
---

# Purpose

Evaluación de protección de controlfile (autobackup, último backup, DBID awareness, accesibilidad de dispositivo) — nunca restaura (`# 20` del prompt de Fase 7).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`rman/configuration` resuelto.

# Required evidence

- `Q-RMAN-CONTROLFILE-BACKUP-001`
- `Q-RMAN-CONFIGURATION-001`

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno.

# Query IDs

`Q-RMAN-CONTROLFILE-BACKUP-001`, `Q-RMAN-CONFIGURATION-001`.

# Collector IDs

`get_controlfile_backup_status`.

# Read-only operations

Lectura de `V$BACKUP_SET`/`V$RMAN_CONFIGURATION`.

# Forbidden operations

Nunca ejecuta `RESTORE CONTROLFILE`.

# Decision logic

1. `CONTROLFILE AUTOBACKUP = ON` (config) + backup set reciente con `CONTROLFILE_INCLUDED != 'NO'` → protegido.
2. `CONTROLFILE AUTOBACKUP = OFF` sin backup set con controlfile reciente → desprotegido real, `HIGH`.
3. `CONTROLFILE AUTOBACKUP = OFF` pero con backup set reciente que incluye controlfile (ej. `BACKUP DATABASE PLUS ARCHIVELOG` habitual) → protegido igual, el autobackup es una capa adicional, no la única.

# Normal state

Al menos un backup con controlfile incluido dentro de la ventana esperada, o autobackup `ON`.

# Abnormal patterns

Ni autobackup `ON` ni backup con controlfile incluido reciente.

# False positives

Autobackup `OFF` no es automáticamente un problema si la estrategia de backup regular ya incluye el controlfile en cada corrida.

# Correlation rules

Correlaciona con `rman/configuration`, `rman/restore-readiness`.

# Confidence model

`FACT` para el estado leído.

# Severity

Sin protección de controlfile por ningún mecanismo → `HIGH`.

# Output schema

```yaml
controlfile_spfile:
  controlfile_autobackup_latest: string|null
  evidence_refs: [EVD-...]
```

# Related skills

`rman/spfile-backup`, `rman/configuration`, `rman/restore-readiness`.

# Escalation

Sin protección de controlfile en producción → `incident-root-cause-analyst`.

# Manual remediation guidance

`CONFIGURE CONTROLFILE AUTOBACKUP ON` se entrega como recomendación manual — nunca ejecutado.

# Security

Ninguna exposición adicional.

# Tests

`tests/test_controlfile_backup_query.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/backup-inventory.md`.

# Change history

v1.0.0 — Fase 7, creación inicial.

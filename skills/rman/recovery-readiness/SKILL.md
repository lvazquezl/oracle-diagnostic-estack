---
name: recovery-readiness
id: rman/recovery-readiness
version: 1.0.0
domain: rman
status: active
---

# Purpose

Distingue restore readiness, media recovery readiness, complete/incomplete recovery, PITR, controlfile/SPFILE/datafile/tablespace recovery awareness, PDB PITR awareness — nunca ejecuta recovery (`# 26` del prompt de Fase 7).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`rman/restore-readiness` resuelto.

# Required evidence

- `Q-RMAN-ARCHIVED-LOG-COVERAGE-001`

# Optional evidence

`rman/pitr-readiness`, `rman/pdb-pitr-awareness` cuando aplica.

# Licensing requirements

Ninguno.

# Query IDs

`Q-RMAN-ARCHIVED-LOG-COVERAGE-001`.

# Collector IDs

Ninguno propio — reutiliza `get_restore_preview`.

# Read-only operations

Lectura de cobertura de archivelog ya certificada.

# Forbidden operations

Nunca ejecuta `RECOVER` en ninguna variante.

# Decision logic

1. `restore_readiness` (de `rman/restore-readiness`) es prerequisito — sin `READY`/`READY_WITH_WARNINGS`, `media_recovery_readiness` no puede evaluarse mejor que `INSUFFICIENT_EVIDENCE`.
2. `complete_recovery` posible si la cadena de archivelog cubre desde el backup base hasta el punto actual sin gaps (`rman/archivelog-backup`).
3. `incomplete_recovery_possible` (PITR) si existe evidencia de al menos un punto anterior con cobertura completa (backup + archivelog hasta ese punto).

# Normal state

`media_recovery_readiness: READY` con cadena de archivelog sin gaps desde el backup base.

# Abnormal patterns

Gap de archivelog entre el backup base y el punto actual — recovery completo no garantizado.

# False positives

Un gap de archivelog fuera de la ventana de recuperación objetivo (RPO) declarada no bloquea el recovery al punto objetivo, aunque sí bloquee el recovery completo al presente.

# Correlation rules

Correlaciona con `rman/restore-readiness`, `rman/archivelog-backup`, `rman/pitr-readiness`, `rman/pdb-pitr-awareness`.

# Confidence model

`FACT` para evidencia leída. `OBSERVATION` para la clasificación agregada.

# Severity

`media_recovery_readiness: NOT_READY` en producción → `CRITICAL`.

# Output schema

```yaml
recovery_readiness:
  restore_readiness: READY|READY_WITH_WARNINGS|NOT_READY|INSUFFICIENT_EVIDENCE
  media_recovery_readiness: READY|READY_WITH_WARNINGS|NOT_READY|INSUFFICIENT_EVIDENCE
  complete_recovery: bool|null
  incomplete_recovery_possible: bool|null
  evidence_refs: [EVD-...]
```

# Related skills

`rman/restore-readiness`, `rman/pitr-readiness`, `rman/pdb-pitr-awareness`, `rman/manual-recovery-plan`.

# Escalation

`NOT_READY`/`INSUFFICIENT_EVIDENCE` en producción → `incident-root-cause-analyst`.

# Manual remediation guidance

`RECOVER` se entrega siempre como recomendación manual dentro de `rman/manual-recovery-plan` — nunca ejecutado.

# Security

Ninguna exposición adicional.

# Tests

`tests/test_recovery_readiness_ready.sh`, `tests/test_recovery_readiness_insufficient_evidence.sh`, `tests/test_no_recover_execution.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/recovery-readiness.md`.

# Change history

v1.0.0 — Fase 7, creación inicial.

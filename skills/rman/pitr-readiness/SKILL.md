---
name: pitr-readiness
id: rman/pitr-readiness
version: 1.0.0
domain: rman
status: active
---

# Purpose

Awareness de Point-in-Time Recovery (`UNTIL TIME`, `UNTIL SCN`, `UNTIL SEQUENCE`) — siempre manual, nunca ejecutado (`# 27` del prompt de Fase 7).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`rman/recovery-readiness` resuelto.

# Required evidence

- `Q-RMAN-ARCHIVED-LOG-COVERAGE-001`

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno.

# Query IDs

`Q-RMAN-ARCHIVED-LOG-COVERAGE-001`.

# Collector IDs

Ninguno propio.

# Read-only operations

Lectura de cobertura de archivelog.

# Forbidden operations

Nunca ejecuta `RESTORE ... UNTIL`/`RECOVER ... UNTIL`.

# Decision logic

1. Un punto objetivo (`UNTIL TIME`/`SCN`/`SEQUENCE`) es alcanzable si existe un backup base anterior a ese punto y cadena de archivelog sin gaps entre el backup y el punto objetivo.
2. `UNTIL SEQUENCE` siempre correlacionado con `THREAD#` explícito — nunca ambiguo en RAC (`# 17`).
3. Sin evidencia de un punto objetivo específico solicitado por el DBA → se reporta capacidad general (`supported: true/false`), no un cálculo para un punto arbitrario.

# Normal state

Al menos un punto de PITR alcanzable dentro de la ventana de retención configurada.

# Abnormal patterns

Ningún punto de PITR alcanzable dentro del RPO declarado.

# False positives

Un punto de PITR fuera de la ventana de retención configurada no alcanzable no es un error — es el límite esperado de la política de retención.

# Correlation rules

Correlaciona con `rman/recovery-readiness`, `rman/archivelog-backup`, `rman/pdb-pitr-awareness`.

# Confidence model

`FACT` para cobertura leída. `OBSERVATION` para alcanzabilidad de un punto específico.

# Severity

Ningún punto de PITR alcanzable dentro del RPO declarado → `HIGH`.

# Output schema

```yaml
recovery_readiness:
  pitr_awareness: {supported: bool|null, methods: [UNTIL_TIME, UNTIL_SCN, UNTIL_SEQUENCE]}
```

# Related skills

`rman/recovery-readiness`, `rman/archivelog-backup`, `rman/pdb-pitr-awareness`, `rman/manual-recovery-plan`.

# Escalation

Sin PITR alcanzable dentro del RPO declarado → `incident-root-cause-analyst`.

# Manual remediation guidance

Todo comando `UNTIL TIME/SCN/SEQUENCE` se entrega dentro de `rman/manual-recovery-plan` — siempre `NOT_EXECUTED`.

# Security

Ninguna exposición adicional.

# Tests

`tests/test_pitr_awareness.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/recovery-readiness.md`.

# Change history

v1.0.0 — Fase 7, creación inicial.

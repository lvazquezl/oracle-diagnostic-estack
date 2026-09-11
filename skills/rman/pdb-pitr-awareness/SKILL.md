---
name: pdb-pitr-awareness
id: rman/pdb-pitr-awareness
version: 1.0.0
domain: rman
status: active
---

# Purpose

Correlaciona PDB target, contexto CDB, local undo, cobertura de archive, disponibilidad de backup y soporte de versión para PDB PITR — siempre manual, nunca ejecutado (`# 27` del prompt de Fase 7).

# Supported Oracle versions

12.1–23ai (PDB PITR requiere Multitenant; `NOT_APPLICABLE` en 10g/11g/12c NON-CDB).

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`rman/multitenant-awareness`, `rman/pitr-readiness` resueltos.

# Required evidence

- `Q-RMAN-BACKUP-SET-001` (variante V2, 12.1+)
- `Q-RMAN-ARCHIVED-LOG-COVERAGE-001`

# Optional evidence

Delegación a `oracle-multitenant-analyst` para topología/local undo por PDB.

# Licensing requirements

Ninguno.

# Query IDs

`Q-RMAN-BACKUP-SET-001`, `Q-RMAN-ARCHIVED-LOG-COVERAGE-001`.

# Collector IDs

Ninguno propio.

# Read-only operations

Lectura de las vistas certificadas.

# Forbidden operations

Nunca ejecuta `RESTORE/RECOVER PLUGGABLE DATABASE UNTIL`.

# Decision logic

1. Requiere backup con cobertura de datafile específica de la PDB objetivo (`rman/multitenant-awareness`) más cadena de archivelog CDB-wide sin gaps hasta el punto objetivo.
2. Local undo (12.2+) afecta el aislamiento de la PDB durante PITR — correlacionar siempre con `oracle-multitenant-analyst` antes de afirmar viabilidad.
3. Sin evidencia certificada del detalle completo por versión (mejoras 12.1→12.2) → `capability_status: PARTIALLY_SUPPORTED`, nunca se asume soporte completo (mismo principio que `rman/multitenant-awareness`).

# Normal state

Cobertura de backup + archivelog suficiente para el punto objetivo, con contexto de topología confirmado por `oracle-multitenant-analyst`.

# Abnormal patterns

PDB objetivo sin cobertura de datafile propia ni backup CDB-wide que la incluya.

# False positives

Ausencia de un backup PDB-level explícito no es un gap si un backup CDB-wide reciente la cubre.

# Correlation rules

Delega a `oracle-multitenant-analyst` para topología/local undo — nunca trata la PDB como base física independiente (`# 29`).

# Confidence model

`OBSERVATION` para viabilidad inferida — nunca `FACT` sin confirmación de topología por `oracle-multitenant-analyst`.

# Severity

PDB crítica sin PITR viable dentro del RPO declarado → `HIGH`.

# Output schema

```yaml
recovery_readiness:
  pdb_pitr_awareness: {supported: bool|null, pdb_token: string|null, capability_status: SUPPORTED|PARTIALLY_SUPPORTED|INSUFFICIENT_EVIDENCE}
```

# Related skills

`rman/multitenant-awareness`, `rman/pitr-readiness`, `rman/manual-recovery-plan`.

# Escalation

PDB crítica sin PITR viable → `oracle-multitenant-analyst` → `incident-root-cause-analyst`.

# Manual remediation guidance

`RESTORE/RECOVER PLUGGABLE DATABASE UNTIL` se entrega dentro de `rman/manual-recovery-plan` — siempre `NOT_EXECUTED`.

# Security

`pdb_token` siempre tokenizado.

# Tests

`tests/test_pdb_pitr_awareness.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/recovery-readiness.md`.

# Change history

v1.0.0 — Fase 7, creación inicial.

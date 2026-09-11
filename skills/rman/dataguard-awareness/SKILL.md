---
name: dataguard-awareness
id: rman/dataguard-awareness
version: 1.0.0
domain: rman
status: active
---

# Purpose

Integración con Data Guard: backup en primary, backup en standby, offload, archivelog deletion policy consciente de standby, disponibilidad de standby — nunca ejecuta standby recovery, nunca asume transportabilidad de backup entre roles sin evidencia (`# 28` del prompt de Fase 7).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC, Primary y Physical Standby.

# Prerequisites

Target Profile `dataguard.enabled = true`.

# Required evidence

- `Q-RMAN-CONFIGURATION-001`
- `Q-RMAN-ARCHIVED-LOG-COVERAGE-001`

# Optional evidence

Delegación a `oracle-dataguard-analyst` para rol/topología.

# Licensing requirements

Ninguno.

# Query IDs

`Q-RMAN-CONFIGURATION-001`, `Q-RMAN-ARCHIVED-LOG-COVERAGE-001`.

# Collector IDs

`get_rman_configuration`.

# Read-only operations

Lectura de configuración/cobertura de archivelog.

# Forbidden operations

Nunca ejecuta standby recovery ni transporta backups entre roles automáticamente.

# Decision logic

1. `ARCHIVELOG DELETION POLICY ... APPLIED ON STANDBY / SHIPPED TO ...` → indica offload consciente de standby; correlacionar con `APPLIED` real en `Q-RMAN-ARCHIVED-LOG-COVERAGE-001`.
2. Backup ejecutado en standby (evidencia de jobs `V$RMAN_STATUS` en esa instancia) → `backup_offload_detected: true`.
3. Nunca asumir que un backup tomado en primary es directamente usable para restaurar el standby (o viceversa) sin evidencia de DBID/topología compartida confirmada por `oracle-dataguard-analyst`.

# Normal state

Deletion policy consciente de standby cuando hay backup offload; archivelogs no eliminados hasta confirmación de apply/shipping.

# Abnormal patterns

Deletion policy que elimina archivelogs sin confirmar aplicación en standby, arriesgando el rol de standby si necesita esos logs.

# False positives

Ausencia de backup en standby no es un problema si la estrategia del sitio es backup sólo en primary — depende del diseño declarado.

# Correlation rules

Correlaciona con `rman/archivelog-backup`, `rman/fra-pressure`, delega a `oracle-dataguard-analyst` para rol/transporte/apply.

# Confidence model

`FACT` para configuración/cobertura leída. `OBSERVATION` para offload inferido.

# Severity

Deletion policy arriesgando disponibilidad de archivelog para standby → `HIGH`.

# Output schema

```yaml
dataguard_awareness:
  backup_on_primary: bool|null
  backup_on_standby: bool|null
  backup_offload_detected: bool|null
  archivelog_deletion_policy_dataguard_aware: bool|null
  evidence_refs: [EVD-...]
```

# Related skills

`rman/archivelog-backup`, `rman/fra-pressure`, `rman/multitenant-awareness`.

# Escalation

Riesgo de deletion policy para el standby → `oracle-dataguard-analyst`.

# Manual remediation guidance

Ajuste de `ARCHIVELOG DELETION POLICY` se entrega como recomendación manual — nunca ejecutado.

# Security

Ninguna exposición adicional — `DB_UNIQUE_NAME` siempre tokenizado (heredado de Target Profile).

# Tests

`tests/test_backup_on_standby_awareness.sh`, `tests/test_archivelog_deletion_policy_dataguard.sh`, `tests/test_dataguard_backup_offload_awareness.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/backup-inventory.md`.

# Change history

v1.0.0 — Fase 7, creación inicial.

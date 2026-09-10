---
name: resource-manager
id: multitenant/resource-manager
version: 1.0.0
domain: multitenant
status: active
---

# Purpose

Visibilidad de CDB resource plan, directivas por PDB (shares, utilization limits, parallel server limits) — sólo lectura, nunca modifica Resource Manager (`# 31` del prompt de Fase 6).

# Supported Oracle versions

12c–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`multitenant/architecture` resuelto.

# Required evidence

- `Q-CDB-RESOURCE-MANAGER-001` (`DBA_CDB_RSRC_PLAN_DIRECTIVES`)

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno.

# Query IDs

`Q-CDB-RESOURCE-MANAGER-001`.

# Collector IDs

Ninguno propio.

# Read-only operations

Lectura de `DBA_CDB_RSRC_PLAN_DIRECTIVES`.

# Forbidden operations

Nunca `ALTER SYSTEM SET RESOURCE_MANAGER_PLAN`, `CREATE|ALTER|DROP PENDING AREA`, ni ningún cambio de Resource Manager (`# 31`).

# Decision logic

1. Reportar el plan CDB activo (`plan_name`, correlacionado desde `Q-CDB-RESOURCE-USAGE-001`) y las directivas por PDB (`shares`/`utilization_limit`/`parallel_server_limit`).
2. Correlacionar con `multitenant/resource-usage`: si una PDB reporta presión y su `utilization_limit` es bajo, el límite configurado puede ser la explicación — nunca se afirma throttling sin este cruce explícito.

# Normal state

Directivas consistentes con el diseño declarado por el DBA; ninguna PDB saturando su límite de forma inesperada.

# Abnormal patterns

Una PDB con `shares` muy bajos comparada con su demanda real (evidenciado por `resource-usage`), sin que sea el diseño intencional.

# False positives

Un límite bajo intencional (ej. PDB de desarrollo/test con recursos deliberadamente acotados) no es un error.

# Correlation rules

Correlaciona directamente con `multitenant/resource-usage` — nunca afirma throttling sin ambas evidencias cruzadas.

# Confidence model

`FACT` para las directivas leídas directamente. `OBSERVATION` para la interpretación de si el límite explica una presión observada.

# Severity

Límite inesperadamente bajo causando degradación de servicio → `MEDIUM`/`HIGH`.

# Output schema

```yaml
resource_manager:
  cdb_plan: string|null
  directives: [{pdb_token: string, share: int|null, utilization_limit: int|null, parallel_server_limit: int|null}]
  evidence_refs: [EVD-...]
```

# Related skills

`multitenant/resource-usage`.

# Escalation

Throttling confirmado con impacto en producción → `incident-root-cause-analyst`.

# Manual remediation guidance

Ajuste de directivas se entrega vía Manual Action Contract, `execution_status: NOT_EXECUTED`.

# Security

`pdb_token` tokenizado.

# Tests

`tests/test_pdb_resource_manager_visibility.sh`, `tests/test_no_resource_plan_change.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/pdb-findings.md`.

# Change history

v1.0.0 — Fase 6, creación inicial.

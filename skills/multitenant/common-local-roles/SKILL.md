---
name: common-local-roles
id: multitenant/common-local-roles
version: 1.0.0
domain: multitenant
status: active
---

# Purpose

Visibilidad de roles comunes vs. locales por contenedor — sólo assessment, nunca DDL (`# 23` del prompt de Fase 6).

# Supported Oracle versions

12c–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`multitenant/architecture` resuelto.

# Required evidence

- `Q-CDB-ROLES-001` (`CDB_ROLES`)

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno.

# Query IDs

`Q-CDB-ROLES-001`.

# Collector IDs

Ninguno propio.

# Read-only operations

Lectura de `CDB_ROLES`.

# Forbidden operations

`CREATE|ALTER|DROP ROLE` (común o local) — nunca ejecutado.

# Decision logic

1. Clasificar cada rol `common`/`local` vía la columna `COMMON`.
2. Distinguir `oracle_maintained = 'Y'` de roles creados por el DBA.
3. No profundiza en privilegios otorgados a cada rol — fuera de alcance de esta fase.

# Normal state

Roles comunes limitados a los esperados/Oracle-maintained; roles locales consistentes por PDB.

# Abnormal patterns

Un rol común nuevo no reconocido por el DBA — señalado, no actuado.

# False positives

Ninguno específico.

# Correlation rules

Correlaciona con `multitenant/common-local-users`.

# Confidence model

`FACT` siempre.

# Severity

Rol común sospechoso con privilegios amplios (si se detecta indirectamente) → `MEDIUM`, señalado, nunca corregido aquí.

# Output schema

```yaml
common_local_identity:
  roles: [{name_token: string, scope: common|local, pdb_token: string|null}]
  evidence_refs: [EVD-...]
```

# Related skills

`multitenant/common-local-users`.

# Escalation

Rol común sospechoso → señalar para `oracle-security-analyst` (futuro).

# Manual remediation guidance

Creación/alteración de rol se entrega vía Manual Action Contract sólo si el DBA lo solicita, `execution_status: NOT_EXECUTED`.

# Security

`name_token` tokenizado.

# Tests

`tests/test_no_lockdown_profile_modify.sh` (comparte convención de seguridad), `tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/pdb-findings.md`.

# Change history

v1.0.0 — Fase 6, creación inicial.

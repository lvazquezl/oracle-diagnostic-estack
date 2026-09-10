---
name: common-local-users
id: multitenant/common-local-users
version: 1.0.0
domain: multitenant
status: active
---

# Purpose

Visibilidad de usuarios comunes vs. locales por contenedor — sólo assessment, nunca password hashes ni DDL, no se convierte en Security deep assessment (`# 23` del prompt de Fase 6).

# Supported Oracle versions

12c–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`multitenant/architecture` resuelto.

# Required evidence

- `Q-CDB-USERS-001` (`CDB_USERS`)

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno.

# Query IDs

`Q-CDB-USERS-001`.

# Collector IDs

Ninguno propio.

# Read-only operations

Lectura de `CDB_USERS`.

# Forbidden operations

`CREATE|ALTER|DROP USER` (común o local) — nunca ejecutado (`# 23`). Nunca recolecta password hashes (no existen en `CDB_USERS`, pero se declara explícitamente por diseño).

# Decision logic

1. Clasificar cada usuario `common`/`local` vía la columna `COMMON` — nunca por convención de nombre.
2. Distinguir `oracle_maintained = 'Y'` (usuarios propios de Oracle) de los creados por el DBA.
3. No profundiza en privilegios otorgados — eso queda para una futura Security deep assessment (`# 73`).

# Normal state

Usuarios comunes limitados a los esperados (administración, Oracle-maintained); usuarios locales por PDB consistentes con el diseño de aplicación.

# Abnormal patterns

Un usuario común nuevo no reconocido por el DBA — señal para escalar a `oracle-security-analyst` (fuera del alcance de esta fase, sólo se señala).

# False positives

Ninguno específico — es visibilidad directa.

# Correlation rules

Correlaciona con `multitenant/components` cuando `last_changed_by` (COMMON USER/LOCAL USER) es relevante para diagnóstico de componentes.

# Confidence model

`FACT` siempre.

# Severity

Usuario común no reconocido con privilegios amplios (si se detecta indirectamente) → `MEDIUM`, señalado para revisión de seguridad, nunca corregido aquí.

# Output schema

```yaml
common_local_identity:
  users: [{name_token: string, scope: common|local, pdb_token: string|null}]
  evidence_refs: [EVD-...]
```

# Related skills

`multitenant/common-local-roles`, `multitenant/components`.

# Escalation

Usuario común sospechoso → señalar para `oracle-security-analyst` (futuro), nunca actuado directamente aquí.

# Manual remediation guidance

Creación/alteración de usuario se entrega vía Manual Action Contract sólo si el DBA lo solicita, `execution_status: NOT_EXECUTED`.

# Security

`name_token` siempre tokenizado. Nunca se recolecta ninguna columna relacionada con credenciales.

# Tests

`tests/test_no_common_user_create.sh`, `tests/test_no_local_user_create.sh`, `tests/test_no_password_hash_collection.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/pdb-findings.md`.

# Change history

v1.0.0 — Fase 6, creación inicial.

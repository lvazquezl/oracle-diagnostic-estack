---
name: common-local-users
id: security/common-local-users
version: 1.0.0
domain: security
status: active
---

# Purpose

Distingue usuarios comunes vs. locales cross-container con posture completa — nunca mezcla
hallazgos entre containers (`# 23` del prompt de Fase 8). Extiende `Q-CDB-USERS-001` (Fase 6).

# Supported Oracle versions

12c–23ai. `NOT_APPLICABLE` en NON-CDB/10g/11g.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

Target debe ser CDB (`Target Profile.multitenant.cdb = true`).

# Required evidence

- `Q-SEC-COMMON-LOCAL-USERS-001`

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno.

# Query IDs

`Q-SEC-COMMON-LOCAL-USERS-001`.

# Collector IDs

`get_common_local_users`.

# Read-only operations

Lectura de `CDB_USERS`.

# Forbidden operations

Nunca crea usuarios comunes/locales.

# Decision logic

1. `COMMON` (`YES`/`NO`) es la fuente de verdad — nunca inferido por convención de nombre.
2. Password/profile posture de una cuenta común se evalúa una sola vez a nivel CDB_ROOT, nunca
   repetida/mezclada por PDB.
3. NON-CDB o versión pre-12.1 → `capability_status: NOT_APPLICABLE`.

# Normal state

Usuarios `ORACLE_MAINTAINED` comunes en `CDB_ROOT`; usuarios de aplicación típicamente locales
por PDB.

# Abnormal patterns

Usuario común no-Oracle-maintained con privilegios administrativos amplios en múltiples PDBs.

# False positives

Ninguno conocido — la clasificación es determinística vía `COMMON`.

# Correlation rules

Integra con `oracle-multitenant-analyst` para contexto de topología. Alimenta `security/roles`,
`security/password-profiles` para scope común/local.

# Confidence model

`FACT`.

# Severity

Informativo — severidad se deriva en skills downstream con el scope correcto.

# Output schema

```yaml
common_local_users:
  common: [{user_token: string, account_status: string, con_id: int}]
  local: [{user_token: string, account_status: string, con_id: int}]
  scope: CDB_ROOT_ONLY|NOT_APPLICABLE
  evidence_refs: [EVD-...]
```

# Related skills

`security/account-inventory`, `security/roles`.

# Escalation

Ninguna directa.

# Manual remediation guidance

N/A.

# Security

`user_token` → MASK por defecto.

# Tests

`tests/test_security_common_local_users.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/accounts.md`.

# Change history

v1.0.0 — Fase 8, creación inicial.

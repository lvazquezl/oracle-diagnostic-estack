---
name: lockdown-profiles
id: multitenant/lockdown-profiles
version: 1.0.0
domain: multitenant
status: active
---

# Purpose

Visibilidad/assessment de lockdown profile asignado por PDB y resumen de reglas — sólo lectura, no se convierte en Security deep assessment (`# 32` del prompt de Fase 6).

# Supported Oracle versions

12.2–23ai (Lockdown Profiles no existen en 12.1).

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`multitenant/architecture` resuelto.

# Required evidence

- `Q-CDB-LOCKDOWN-001` (`CDB_LOCKDOWN_PROFILES`)

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno.

# Query IDs

`Q-CDB-LOCKDOWN-001`.

# Collector IDs

Ninguno propio.

# Read-only operations

Lectura de `CDB_LOCKDOWN_PROFILES`.

# Forbidden operations

Nunca `ALTER LOCKDOWN PROFILE` (`# 32`).

# Decision logic

1. Resumir reglas por perfil (`rule_type`/`rule`/`clause`/`status`).
2. Correlacionar `profile_name` con la PDB que lo tiene asignado (asignación visible en el inventario de PDB, no en esta vista).
3. No profundiza en implicaciones de seguridad más allá del resumen — no se convierte en Security deep assessment.

# Normal state

Perfiles asignados consistentes con el diseño de seguridad declarado por el DBA.

# Abnormal patterns

Una PDB sin lockdown profile asignado cuando se esperaba uno (política de seguridad no aplicada).

# False positives

Ninguno — es visibilidad directa.

# Correlation rules

N/A — visibilidad independiente.

# Confidence model

`FACT` siempre.

# Severity

PDB sin lockdown profile esperado → `MEDIUM`, señalado, nunca corregido aquí.

# Output schema

```yaml
lockdown_profiles:
  - pdb_token: string
    profile_name: string|null
    rules_summary: string|null
    evidence_refs: [EVD-...]
```

# Related skills

`multitenant/architecture`.

# Escalation

N/A directamente — hallazgo de seguridad se señala, no se escala como incidente por sí solo salvo instrucción del DBA.

# Manual remediation guidance

Asignación/modificación de perfil se entrega vía Manual Action Contract, `execution_status: NOT_EXECUTED`.

# Security

Ninguna dato sensible propio — nombres de perfil/reglas son configuración.

# Tests

`tests/test_no_lockdown_profile_modify.sh`, `tests/test_multitenant_query_version_compatibility.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/pdb-findings.md`.

# Change history

v1.0.0 — Fase 6, creación inicial.

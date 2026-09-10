---
name: pdb-sessions
id: multitenant/pdb-sessions
version: 1.0.0
domain: multitenant
status: active
---

# Purpose

Distribución de sesiones por PDB/instancia/servicio — metadata agregada únicamente, nunca SQL text ni bind values (`# 15` del prompt de Fase 6).

# Supported Oracle versions

12c–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`multitenant/pdb-inventory` resuelto.

# Required evidence

- `Q-CDB-SESSION-DIST-001` (`GV$SESSION`, agregado)

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno.

# Query IDs

`Q-CDB-SESSION-DIST-001`.

# Collector IDs

Ninguno propio.

# Read-only operations

Lectura agregada de `GV$SESSION`.

# Forbidden operations

Nunca expone `sql_id`, `sql_text`, bind values, `client_identifier`, `module`/`action` de sesión individual — sólo conteos agregados (`# 15`).

# Decision logic

1. Agregar sesiones por `con_id`/`instance`/`service`.
2. Reportar `active`/`inactive` por separado — un conteo alto de sesiones `INACTIVE` no es automáticamente un problema (connection pooling normal).
3. Correlacionar con `multitenant/resource-usage` si el conteo de sesiones activas se acerca a `running_sessions_limit` (Resource Manager).

# Normal state

Distribución de sesiones consistente con el patrón de carga esperado por PDB.

# Abnormal patterns

Sesiones concentradas anómalamente en una PDB/instancia sin explicación de diseño; conteo cercano al límite de Resource Manager.

# False positives

Un pico temporal de sesiones `INACTIVE` tras un evento de conexión masiva (ej. deploy de aplicación) no es un problema por sí solo.

# Correlation rules

Delega a `oracle-performance-analyst` si la concentración de sesiones correlaciona con alta actividad/CPU (`# 33`).

# Confidence model

`FACT` para el conteo agregado leído directamente.

# Severity

Sesiones cerca del límite de Resource Manager → `MEDIUM`/`HIGH` según margen.

# Output schema

```yaml
pdb_sessions:
  - pdb_token: string
    instance: string|null
    service: string|null
    session_count: int
    active: int
    inactive: int
    evidence_refs: [EVD-...]
```

# Related skills

`multitenant/pdb-services`, `multitenant/resource-usage`.

# Escalation

Saturación de sesiones en producción → `incident-root-cause-analyst`.

# Manual remediation guidance

Ninguna acción de kill/desconexión — fuera de alcance (visibilidad únicamente).

# Security

Nunca se recolecta `sql_id`/`sql_text`/bind values/`client_identifier` — sólo agregados por `con_id`/`instance`/`service`.

# Tests

`tests/test_no_bind_value_collection.sh`, `tests/test_no_application_table_access.sh`, `tests/test_multitenant_query_cost.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/pdb-findings.md`.

# Change history

v1.0.0 — Fase 6, creación inicial.

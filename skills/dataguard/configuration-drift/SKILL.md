---
name: configuration-drift
id: dataguard/configuration-drift
version: 1.0.0
domain: dataguard
status: active
---

# Purpose

Comparar parámetros relacionados con Data Guard entre primary y standby, sólo para los que realmente deben guardar relación — no exige igualdad artificial entre `DB_UNIQUE_NAME`, parámetros instance-specific, ubicaciones de archivo, o definiciones de servicio (`# 34`, `# 35` del prompt de Fase 5).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported Data Guard architectures

PHYSICAL_STANDBY.

# Prerequisites

`dataguard/topology` resuelto.

# Required evidence

- `Q-ORA-PARAMETERS-001` (ya certificada en Oracle Core, filtrada a los parámetros Data Guard relevantes)

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno.

# Query IDs

`Q-ORA-PARAMETERS-001`.

# Collector IDs

Ninguno propio.

# Read-only operations

Lectura de `V$PARAMETER`/`GV$PARAMETER` en ambos sitios.

# Forbidden operations

No corrige ningún parámetro.

# Decision logic

1. Comparar sólo parámetros que **deben** coincidir o guardar relación conocida entre sitios: `LOG_ARCHIVE_CONFIG`, `STANDBY_FILE_MANAGEMENT`, `FAL_SERVER`/`FAL_CLIENT` (según versión), `DB_FILE_NAME_CONVERT`/`LOG_FILE_NAME_CONVERT` (cuando aplica), `REMOTE_LOGIN_PASSWORDFILE` awareness (`# 34`).
2. Nunca comparar `DB_UNIQUE_NAME` (por diseño distinto), parámetros instance-specific (`INSTANCE_NAME`, `THREAD`), ubicaciones de archivo, ni definiciones de servicio como si debieran ser idénticos (`# 35`).
3. Reportar sólo diferencias en parámetros de la lista "deben coincidir" — cualquier otra diferencia se ignora explícitamente por diseño, no por omisión.

# Normal state

Parámetros de la lista "deben coincidir" consistentes entre primary y standby.

# Abnormal patterns

`STANDBY_FILE_MANAGEMENT` distinto entre sitios; `FAL_SERVER` apuntando a un destino incorrecto.

# False positives

`DB_FILE_NAME_CONVERT` ausente en un standby con estructura de directorio idéntica al primary — no siempre es requerido, correlacionar antes de reportar.

# Correlation rules

Cruza con `dataguard/archive-destinations` (consistencia de configuración de destino) y `dataguard/topology`.

# Confidence model

`FACT` para diferencias de parámetro leídas directamente.

# Severity

`STANDBY_FILE_MANAGEMENT`/`FAL_SERVER` inconsistente → `MEDIUM`; el resto de la lista → `LOW`.

# Output schema

```yaml
findings:
  - parameter: string
    primary_value: string
    standby_value: string
    classification: LEGITIMATE_DRIFT|UNEXPECTED_DRIFT
    evidence_refs: [EVD-...]
```

# Related skills

`dataguard/archive-destinations`, `dataguard/topology`.

# Escalation

Drift inesperado en `STANDBY_FILE_MANAGEMENT`/`FAL_SERVER` → `change-advisor` para propuesta de alineación manual.

# Manual remediation guidance

Ajuste de cualquier parámetro es `manual_action`.

# Security

Ninguna dato sensible propio.

# Tests

`tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `dataguard-topology.md`.

# Change history

v1.0.0 — Fase 5, creación inicial.

---
name: role
id: dataguard/role
version: 1.0.0
domain: dataguard
status: active
---

# Purpose

Detección robusta de `DATABASE_ROLE`, `OPEN_MODE`, `SWITCHOVER_STATUS`, `PROTECTION_MODE`, `PROTECTION_LEVEL`, `FORCE_LOGGING`, `FLASHBACK_ON` — nunca asume que una base en `READ ONLY` es automáticamente standby (`# 9` del prompt de Fase 5).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported Data Guard architectures

PHYSICAL_STANDBY (foco principal), LOGICAL_STANDBY/SNAPSHOT_STANDBY (rol reconocido, análisis profundo fuera de alcance).

# Prerequisites

Ninguno — es el primer skill del workflow Data Guard.

# Required evidence

- `Q-DG-ROLE-001` (`V$DATABASE`: `DATABASE_ROLE`, `OPEN_MODE`, `SWITCHOVER_STATUS`, `PROTECTION_MODE`, `PROTECTION_LEVEL`, `FORCE_LOGGING`, `FLASHBACK_ON`, `DB_UNIQUE_NAME`)

# Optional evidence

`Q-ORA-PARAMETERS-001` (`V$PARAMETER`, ya certificada en Oracle Core) filtrado a `name = 'log_archive_config'` — `LOG_ARCHIVE_CONFIG` **no** es columna de `V$DATABASE` (defecto de certificación corregido, `docs/PHASE_5_COMPATIBILITY_HARDENING.md`); usado sólo como correlación, no como determinante de rol. Correlaciona además con evidencia Broker sólo si `dataguard/broker` ya la publicó en la misma sesión.

# Licensing requirements

Ninguno — rol/protección son metadata core, no requieren Diagnostics Pack ni Active Data Guard.

# Query IDs

`Q-DG-ROLE-001`, `Q-ORA-PARAMETERS-001` (opcional, correlación `LOG_ARCHIVE_CONFIG`).

# Collector IDs

Ninguno propio.

# Read-only operations

Lectura de `V$DATABASE`.

# Forbidden operations

No cambia `DATABASE_ROLE`, `PROTECTION_MODE`, `FORCE_LOGGING` ni `FLASHBACK_ON`.

# Decision logic

1. Leer `DATABASE_ROLE` como fuente de verdad — nunca inferir el rol de `OPEN_MODE` (`# 9`).
2. Correlacionar `OPEN_MODE = READ ONLY WITH APPLY` con `DATABASE_ROLE = PHYSICAL STANDBY` como confirmación (no como determinante).
3. `SWITCHOVER_STATUS != NOT ALLOWED` es una señal de entrada para `dataguard/switchover-readiness`, no una conclusión de readiness por sí sola.

# Normal state

`DATABASE_ROLE` consistente con `target_profile.dataguard.role`; `SWITCHOVER_STATUS` reportado sin error.

# Abnormal patterns

`DATABASE_ROLE` inesperado (ej. primary reportando `PHYSICAL STANDBY` tras un failover no comunicado); `SWITCHOVER_STATUS = SWITCHOVER PENDING` prolongado.

# False positives

`OPEN_MODE = MOUNTED` en un standby con `real_time_apply` deshabilitado es esperado, no un error — correlacionar con `dataguard/real-time-apply` antes de clasificar.

# Correlation rules

Cruza con `DB_UNIQUE_NAME`/`LOG_ARCHIVE_CONFIG` (vía `Q-ORA-PARAMETERS-001`, no `Q-DG-ROLE-001`)/evidencia Broker cuando esté disponible (`# 9`).

# Confidence model

`FACT` para `DATABASE_ROLE`/`OPEN_MODE` leídos directamente.

# Severity

`DATABASE_ROLE` inesperado sin explicación → `HIGH`.

# Output schema

```yaml
findings:
  - db_unique_name: string
    database_role: string
    open_mode: string
    switchover_status: string
    protection_mode: string
    protection_level: string
    force_logging: bool
    flashback_on: bool
    evidence_refs: [EVD-...]
```

# Related skills

`dataguard/topology`, `dataguard/protection`.

# Escalation

`DATABASE_ROLE` inesperado → `incident-root-cause-analyst`.

# Manual remediation guidance

Ninguna — cambio de rol es siempre switchover/failover, fuera de alcance de ejecución.

# Security

`db_unique_name` enmascarado por defecto.

# Tests

`tests/test_dataguard_role_query.sh`, `tests/test_no_write_operations.sh`, `tests/test_primary_standby_detection.sh`.

# Documentation requirements

Alimenta `dataguard-topology.md`.

# Change history

v1.0.0 — Fase 5, creación inicial.

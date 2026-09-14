---
name: public-grants
id: security/public-grants
version: 1.0.0
domain: security
status: active
---

# Purpose

Analiza system/object privileges otorgados a PUBLIC, clasificando
`ORACLE_REQUIRED_DEFAULT|APPLICATION_REQUIRED|CUSTOM|UNKNOWN` — nunca recomienda `REVOKE` sin
dependency analysis (`# 12` del prompt de Fase 8).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

Ninguno.

# Required evidence

- `Q-SEC-PUBLIC-SYSTEM-GRANTS-001`
- `Q-SEC-PUBLIC-OBJECT-GRANTS-001`

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno.

# Query IDs

`Q-SEC-PUBLIC-SYSTEM-GRANTS-001`, `Q-SEC-PUBLIC-OBJECT-GRANTS-001`.

# Collector IDs

`get_public_grants`.

# Read-only operations

Lectura de `DBA_SYS_PRIVS`/`DBA_TAB_PRIVS` filtrado por `PUBLIC`.

# Forbidden operations

Nunca ejecuta `REVOKE`.

# Decision logic

1. `ORACLE_REQUIRED_DEFAULT` — catálogo interno de grants PUBLIC estándar de una instalación
   Oracle nueva (ej. `EXECUTE` sobre ciertos paquetes `DBMS_*` documentados como PUBLIC por
   diseño).
2. `APPLICATION_REQUIRED` — grant PUBLIC conocido por requerimiento de una aplicación específica
   documentada por el DBA.
3. `CUSTOM`/`UNKNOWN` — cualquier otro grant PUBLIC no catalogado; nunca se asume seguro ni
   inseguro sin contexto adicional.
4. `revoke_recommended` es `false` siempre salvo que el DBA confirme explícitamente ausencia de
   dependencia — nunca `true` por defecto.

# Normal state

Grants `ORACLE_REQUIRED_DEFAULT` predominantes en una instalación estándar.

# Abnormal patterns

`EXECUTE ANY PROCEDURE`, `SELECT ANY DICTIONARY`, o `EXECUTE` sobre `UTL_TCP`/`UTL_HTTP`/
`UTL_FILE` a PUBLIC sin justificación — vector clásico de superficie de ataque.

# False positives

Un grant `CUSTOM` puede ser legítimo (aplicación heredada) — el finding señala el hallazgo, la
remediación es decisión humana informada.

# Correlation rules

Consume `security/system-privileges`, `security/object-privileges`. Alimenta
`security/security-healthcheck`, `security/compliance-mapping`.

# Confidence model

`FACT` para la presencia del grant. `OBSERVATION` para la clasificación cuando no está en el
catálogo interno (`UNKNOWN`).

# Severity

`HIGH` para privilegios peligrosos (`EXECUTE ANY PROCEDURE`, etc.) sin clasificación
`ORACLE_REQUIRED_DEFAULT`; `MEDIUM`/`LOW` en otros casos.

# Output schema

```yaml
public_grants:
  - privilege: string
    object_token: string|null
    classification: ORACLE_REQUIRED_DEFAULT|APPLICATION_REQUIRED|CUSTOM|UNKNOWN
    revoke_recommended: bool
    evidence_refs: [EVD-...]
```

# Related skills

`security/system-privileges`, `security/object-privileges`, `security/powerful-privileges`.

# Escalation

Grant peligroso `CUSTOM`/`UNKNOWN` sin justificación conocida → finding `HIGH`, nunca acción
automática.

# Manual remediation guidance

`manual_action` sugiere `REVOKE ... FROM PUBLIC` con nota explícita de "requiere dependency
analysis antes de ejecutar" — siempre `NOT_EXECUTED`.

# Security

`object_token` → MASK por defecto.

# Tests

`tests/test_security_public_grants.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/public-grants.md`.

# Change history

v1.0.0 — Fase 8, creación inicial.

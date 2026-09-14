---
name: powerful-privileges
id: security/powerful-privileges
version: 1.0.0
domain: security
status: active
---

# Purpose

Mantiene un catálogo explícito y version-aware de privilegios sensibles y evalúa severidad
contextual — nunca uniforme para todos (`# 11` del prompt de Fase 8).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`security/system-privileges` ya ejecutado.

# Required evidence

- evidencia ya recolectada por `security/system-privileges`

# Optional evidence

`security/admin-privileges` para correlación con SYSDBA/SYSOPER.

# Licensing requirements

Ninguno.

# Query IDs

Ninguna directa — deriva de `Q-SEC-SYSTEM-PRIVILEGES-001`/`Q-SEC-ROLE-SYSTEM-PRIVILEGES-001`.

# Collector IDs

Ninguno.

# Read-only operations

Ninguna adicional.

# Forbidden operations

Nunca revoca privilegios.

# Decision logic

1. Catálogo interno fijo: `DBA, SYSDBA, SYSOPER, SYSASM, SYSBACKUP, SYSDG, SYSKM, CREATE ANY,
   ALTER ANY, DROP ANY, SELECT ANY DICTIONARY, SELECT ANY TABLE, EXECUTE ANY PROCEDURE, BECOME
   USER, GRANT ANY PRIVILEGE, GRANT ANY ROLE, ALTER SYSTEM, ALTER DATABASE` — categorizado
   `ADMINISTRATIVE_LOGIN|OBJECT_CREATION|DICTIONARY_ACCESS|PRIVILEGE_ESCALATION|SYSTEM_CONTROL`.
2. Severidad considera: cuenta Oracle-maintained vs. custom, `grant_path` directo vs. rol,
   contexto de aplicación conocido — nunca `CRITICAL` uniforme para todos.
3. `GRANT ANY PRIVILEGE`/`GRANT ANY ROLE`/`BECOME USER` en cuenta no-DBA → `CRITICAL` por defecto
   (privilege escalation), salvo justificación operacional documentada por el DBA.

# Normal state

Privilegios sensibles concentrados en cuentas DBA/Oracle-maintained conocidas.

# Abnormal patterns

`ALTER SYSTEM`/`SELECT ANY DICTIONARY` en cuenta de aplicación sin justificación.

# False positives

Cuenta de monitoring con `SELECT ANY DICTIONARY` (patrón común, ej. herramientas de monitoreo)
no es automáticamente `CRITICAL` — contexto reduce severidad si la necesidad operacional es
conocida.

# Correlation rules

Consume `security/system-privileges`, `security/roles`. Alimenta `security/security-healthcheck`,
`security/compliance-mapping`.

# Confidence model

`FACT` para la presencia del grant. `PROBABLE_CAUSE` para la clasificación de riesgo cuando se
correlaciona con ausencia de justificación conocida.

# Severity

`LOW|MEDIUM|HIGH|CRITICAL` — ver decision logic. Nunca uniforme.

# Output schema

```yaml
powerful_privileges:
  - grantee_token: string
    privilege: string
    category: ADMINISTRATIVE_LOGIN|OBJECT_CREATION|DICTIONARY_ACCESS|PRIVILEGE_ESCALATION|SYSTEM_CONTROL
    severity: LOW|MEDIUM|HIGH|CRITICAL
    grant_path: DIRECT|VIA_ROLE
    evidence_refs: [EVD-...]
```

# Related skills

`security/system-privileges`, `security/admin-privileges`, `security/public-grants`.

# Escalation

Privilegio `CRITICAL` en cuenta de aplicación no-DBA → `incident-root-cause-analyst`.

# Manual remediation guidance

`manual_action` sugiere `REVOKE` — siempre `NOT_EXECUTED`, siempre acompañado de nota de
dependency analysis requerido.

# Security

`grantee_token` → MASK por defecto.

# Tests

`tests/test_security_powerful_privileges.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/privileges.md`.

# Change history

v1.0.0 — Fase 8, creación inicial.

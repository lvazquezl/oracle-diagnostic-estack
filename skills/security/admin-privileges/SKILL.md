---
name: admin-privileges
id: security/admin-privileges
version: 1.0.0
domain: security
status: active
---

# Purpose

Detecta identidades con `SYSDBA/SYSOPER/SYSASM/SYSBACKUP/SYSDG/SYSKM` vía password file, sin
leer secrets (`# 13` del prompt de Fase 8).

# Supported Oracle versions

10g–23ai (`SYSASM` 11g+, `SYSBACKUP`/`SYSDG`/`SYSKM` 12.1+).

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

Ninguno.

# Required evidence

- `Q-SEC-ADMIN-PRIVILEGES-001`

# Optional evidence

`security/common-local-users` para contexto common/local en CDB.

# Licensing requirements

Ninguno.

# Query IDs

`Q-SEC-ADMIN-PRIVILEGES-001`.

# Collector IDs

`get_admin_privileges`.

# Read-only operations

Lectura de `V$PWFILE_USERS`.

# Forbidden operations

Nunca lee contenido del password file más allá de esta vista dinámica.

# Decision logic

1. `source: PASSWORD_FILE` — toda identidad viene de `V$PWFILE_USERS`.
2. En versiones donde una columna no existe (`SYSASM` en 10g; `SYSBACKUP`/`SYSDG`/`SYSKM`/
   `COMMON` en 10g/11g), el campo correspondiente queda `null`/`NOT_APPLICABLE`.
3. Correlaciona con `security/powerful-privileges` para severidad conjunta.

# Normal state

Un número reducido de identidades con SYSDBA, típicamente `SYS` + cuentas DBA nombradas.

# Abnormal patterns

Cuenta de aplicación con `SYSDBA`/`SYSOPER` sin justificación operacional.

# False positives

Cuentas `SYSBACKUP` para herramientas de backup certificadas (ej. RMAN scripting) son esperadas.

# Correlation rules

Alimenta `security/powerful-privileges`, `security/security-healthcheck`.

# Confidence model

`FACT`.

# Severity

`HIGH` para SYSDBA en cuenta no reconocida como DBA estándar.

# Output schema

```yaml
admin_privileges:
  - user_token: string
    privilege: SYSDBA|SYSOPER|SYSASM|SYSBACKUP|SYSDG|SYSKM
    source: PASSWORD_FILE|OS_GROUP_AWARENESS|UNKNOWN
    common: bool|NOT_APPLICABLE
    evidence_refs: [EVD-...]
```

# Related skills

`security/powerful-privileges`, `security/common-local-users`.

# Escalation

SYSDBA en cuenta no reconocida en producción → `incident-root-cause-analyst`.

# Manual remediation guidance

N/A — la revocación de privilegios de password file requiere `orapwd`/`ALTER USER` manual, fuera
de este e-stack; se documenta como `manual_action` sólo si el DBA lo solicita.

# Security

`user_token` → MASK por defecto salvo `SYS`.

# Tests

`tests/test_security_admin_privileges.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/privileges.md`.

# Change history

v1.0.0 — Fase 8, creación inicial.

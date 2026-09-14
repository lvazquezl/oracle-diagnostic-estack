---
name: directories
id: security/directories
version: 1.0.0
domain: security
status: active
---

# Purpose

Analiza directory objects y grants — nunca navega filesystem (`# 38` del prompt de Fase 8).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

Ninguno.

# Required evidence

- `Q-SEC-DIRECTORIES-001`

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno.

# Query IDs

`Q-SEC-DIRECTORIES-001`.

# Collector IDs

`get_directories`.

# Read-only operations

Lectura de `DBA_DIRECTORIES`/`DBA_TAB_PRIVS`.

# Forbidden operations

Nunca crea/elimina directory objects, nunca accede al filesystem detrás del path.

# Decision logic

1. Reporta `directory_name`/`directory_path`/grants tal cual.
2. `directory_path` se trata como metadata sensible — nunca se valida su existencia real en
   filesystem (eso requeriría acceso OS, fuera de alcance aquí).

# Normal state

Directories documentados con propósito conocido (external tables, data pump, UTL_FILE).

# Abnormal patterns

Grants de `WRITE`/`READ` amplios a `PUBLIC` sobre un directory sensible.

# False positives

Directory con grants limitados a una cuenta de aplicación específica no es anómalo.

# Correlation rules

Alimenta `security/security-healthcheck`, `security/compliance-mapping`. Integra con
`os-platform-analyst` para permisos de filesystem reales.

# Confidence model

`FACT`.

# Severity

`MEDIUM`/`HIGH` según amplitud del grant y sensibilidad del path (si conocida).

# Output schema

```yaml
directories:
  - directory_token: string
    owner_token: string
    grants: [{grantee_token: string, privilege: string}]
    evidence_refs: [EVD-...]
```

# Related skills

`security/database-links`.

# Escalation

Grant amplio a PUBLIC sobre directory sensible → finding, nunca acción automática.

# Manual remediation guidance

`manual_action` sugiere `REVOKE`/`DROP DIRECTORY` tras confirmación — siempre `NOT_EXECUTED`.

# Security

`directory_path` → MASK (puede revelar convención de filesystem interna).

# Tests

`tests/test_no_secrets.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/security-posture.md`.

# Change history

v1.0.0 — Fase 8, creación inicial.

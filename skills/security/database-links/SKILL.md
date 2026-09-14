---
name: database-links
id: security/database-links
version: 1.0.0
domain: security
status: active
---

# Purpose

Analiza database links — metadata, nunca recupera passwords ni se conecta (`# 37` del prompt de
Fase 8).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

Ninguno.

# Required evidence

- `Q-SEC-DB-LINKS-001`

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno.

# Query IDs

`Q-SEC-DB-LINKS-001`.

# Collector IDs

`get_database_links`.

# Read-only operations

Lectura de `DBA_DB_LINKS`.

# Forbidden operations

Nunca crea/elimina db links, nunca se conecta a través de uno.

# Decision logic

1. Reporta `owner, db_link, username, host` tal cual — nunca intenta resolver el host ni probar
   conectividad.
2. Un db link `PUBLIC` (owner `PUBLIC`) se marca explícitamente distinto de uno privado.

# Normal state

Db links documentados con propósito conocido (ETL, integración).

# Abnormal patterns

Db link a un host externo desconocido, o con `username` apuntando a una cuenta con privilegios
administrativos en el sistema remoto (si es determinable).

# False positives

Db links legítimos de integración conocida no son anómalos.

# Correlation rules

Alimenta `security/security-healthcheck`, `security/compliance-mapping`.

# Confidence model

`FACT`.

# Severity

`MEDIUM` para db link no documentado; `HIGH` si apunta a un host fuera del perímetro conocido.

# Output schema

```yaml
database_links:
  - db_link_token: string
    owner_token: string
    username_token: string|null
    host_token: string|null
    scope: PUBLIC|PRIVATE
    evidence_refs: [EVD-...]
```

# Related skills

`security/directories`.

# Escalation

Db link a host desconocido en producción → finding, nunca acción automática.

# Manual remediation guidance

`manual_action` sugiere `DROP DATABASE LINK` tras confirmación de no-uso — siempre
`NOT_EXECUTED`.

# Security

`owner_token`/`username_token`/`host_token` → MASK por defecto. Nunca la contraseña del link.

# Tests

`tests/test_no_secrets.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/security-posture.md`.

# Change history

v1.0.0 — Fase 8, creación inicial.

---
name: traditional-auditing
id: security/traditional-auditing
version: 1.0.0
domain: security
status: active
---

# Purpose

Traditional Auditing (`AUDIT_TRAIL, DBA_AUDIT_TRAIL, DBA_AUDIT_SESSION`) para versiones legacy o
cuando Unified Auditing no cubre lo requerido — nunca asume Unified Auditing en 10g/11g (`# 28`
del prompt de Fase 8).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

Ninguno.

# Required evidence

- `Q-SEC-TRADITIONAL-AUDIT-001`

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno.

# Query IDs

`Q-SEC-TRADITIONAL-AUDIT-001`.

# Collector IDs

`get_traditional_audit_config`.

# Read-only operations

Lectura de `V$PARAMETER`/`DBA_AUDIT_SESSION`.

# Forbidden operations

Nunca cambia `AUDIT_TRAIL`.

# Decision logic

1. `AUDIT_TRAIL` en `NONE|OS|DB|DB_EXTENDED|XML|XML_EXTENDED`.
2. En 10g/11g, es el único mecanismo certificado — nunca se reporta `Unified Auditing` como
   alternativa disponible.
3. En 12.1+, `security/audit-configuration` decide cuál es el mecanismo primario — este skill
   sólo reporta el estado Traditional.

# Normal state

`AUDIT_TRAIL != NONE` con evidencia de sesión reciente.

# Abnormal patterns

`AUDIT_TRAIL = NONE` en 10g/11g de producción.

# False positives

Ninguno.

# Correlation rules

Alimenta `security/audit-configuration`.

# Confidence model

`FACT`.

# Severity

`HIGH` si `AUDIT_TRAIL = NONE` en 10g/11g de producción sin Unified Auditing como alternativa
(no existe en esas versiones).

# Output schema

```yaml
traditional_auditing:
  audit_trail_setting: string|null
  session_audit_evidence: bool|null
  applicable: bool
  evidence_refs: [EVD-...]
```

# Related skills

`security/unified-auditing`, `security/audit-configuration`.

# Escalation

`AUDIT_TRAIL = NONE` en producción sin alternativa → `incident-root-cause-analyst`.

# Manual remediation guidance

`manual_action` sugiere `AUDIT_TRAIL = DB_EXTENDED` (requiere reinicio) — siempre `NOT_EXECUTED`.

# Security

`username` (en `DBA_AUDIT_SESSION`) → MASK por defecto.

# Tests

`tests/test_traditional_audit_detection.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/audit-posture.md`.

# Change history

v1.0.0 — Fase 8, creación inicial.

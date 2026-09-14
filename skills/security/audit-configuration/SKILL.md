---
name: audit-configuration
id: security/audit-configuration
version: 1.0.0
domain: security
status: active
---

# Purpose

Consolida el mecanismo de auditoría activo (Unified vs. Traditional) y detecta
`audit disabled/audit volume risk/trail saturation/retention unknown` — nunca purga el audit
trail (`# 30` del prompt de Fase 8).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`security/unified-auditing`, `security/traditional-auditing` ya ejecutados.

# Required evidence

- evidencia de `security/unified-auditing`
- evidencia de `security/traditional-auditing`

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno.

# Query IDs

Ninguna directa — consolida evidencia de skills previos.

# Collector IDs

Ninguno.

# Read-only operations

Ninguna adicional.

# Forbidden operations

Nunca purga/trunca el audit trail. Nunca habilita/deshabilita auditoría.

# Decision logic

1. 12.1+: si Unified Auditing habilitado con políticas cubriendo actividad privilegiada →
   mecanismo primario reportado como Unified.
2. 12.1+ sin Unified Auditing habilitado, o 10g/11g: mecanismo primario Traditional — si
   `AUDIT_TRAIL = NONE`, `audit disabled` reportado como finding.
3. `trail saturation`/`retention unknown` se reportan cuando no hay evidencia de política de
   retención — nunca se asume una retención por defecto.

# Normal state

Auditoría habilitada con cobertura de actividad privilegiada mínima (SYS, DDL de seguridad).

# Abnormal patterns

`AUDIT_TRAIL = NONE` y Unified Auditing sin políticas habilitadas simultáneamente — sin
auditoría de ningún tipo.

# False positives

Ninguno.

# Correlation rules

Consume `security/unified-auditing`, `security/traditional-auditing`. Alimenta
`security/security-healthcheck`, `security/compliance-mapping`.

# Confidence model

`FACT`.

# Severity

`CRITICAL` si no hay ningún mecanismo de auditoría activo en producción.

# Output schema

```yaml
audit_configuration:
  primary_mechanism: UNIFIED|TRADITIONAL|NONE|UNKNOWN
  audit_disabled: bool
  volume_risk: LOW|MEDIUM|HIGH|UNKNOWN
  retention_known: bool
  evidence_refs: [EVD-...]
```

# Related skills

`security/unified-auditing`, `security/traditional-auditing`, `security/privileged-audit`.

# Escalation

Sin auditoría activa en producción → `incident-root-cause-analyst`, severity `HIGH`.

# Manual remediation guidance

`manual_action` sugiere `AUDIT POLICY ...` (Unified) o `AUDIT_TRAIL = DB` (Traditional) — siempre
`NOT_EXECUTED`.

# Security

Ninguna exposición de contenido de aplicación auditado.

# Tests

`tests/test_audit_query_budget.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/audit-posture.md`.

# Change history

v1.0.0 — Fase 8, creación inicial.

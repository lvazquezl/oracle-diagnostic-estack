---
name: privileged-audit
id: security/privileged-audit
version: 1.0.0
domain: security
status: active
---

# Purpose

Evalúa visibilidad de operaciones SYS, uso de privilegio administrativo, logon/logoff y cambios
de DDL/seguridad cuando la política lo requiere — nunca inventa política corporativa (`# 29` del
prompt de Fase 8).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`security/unified-auditing`/`security/traditional-auditing` ya ejecutados.

# Required evidence

- evidencia de `security/audit-configuration`

# Optional evidence

`Q-SEC-UNIFIED-AUDIT-TRAIL-001` filtrada.

# Licensing requirements

Ninguno.

# Query IDs

`Q-SEC-UNIFIED-AUDIT-TRAIL-001` (12.1+), evidencia de `Q-SEC-TRADITIONAL-AUDIT-001` (legacy).

# Collector IDs

`get_privileged_audit_evidence`.

# Read-only operations

Lectura filtrada de audit trail (nunca completa).

# Forbidden operations

Nunca cambia política de auditoría.

# Decision logic

1. Sin política corporativa explícita (`Target Profile.security.audit_requirements`), este skill
   reporta sólo visibilidad técnica (`sys_operations_visible`, etc.), nunca un compliance
   status — eso es `security/compliance-mapping`.
2. `audit_volume_risk` se deriva de la tasa de crecimiento observada del trail cuando hay
   evidencia suficiente, nunca inventada.

# Normal state

`sys_operations_visible: true`, `admin_privilege_use_visible: true` con auditoría habilitada
apropiadamente.

# Abnormal patterns

Ninguna visibilidad de actividad SYS/administrativa pese a tener auditoría técnicamente
disponible — indica configuración de política insuficiente.

# False positives

Ninguno.

# Correlation rules

Consume `security/audit-configuration`. Alimenta `security/compliance-mapping`.

# Confidence model

`FACT` para visibilidad técnica. `OBSERVATION` para `audit_volume_risk`.

# Severity

`HIGH` si ninguna visibilidad de actividad privilegiada en producción.

# Output schema

```yaml
privileged_audit:
  sys_operations_visible: bool|null
  admin_privilege_use_visible: bool|null
  logon_logoff_covered: bool|null
  ddl_security_changes_covered: bool|null
  audit_volume_risk: LOW|MEDIUM|HIGH|UNKNOWN
  evidence_refs: [EVD-...]
```

# Related skills

`security/unified-auditing`, `security/traditional-auditing`, `security/audit-configuration`.

# Escalation

Sin visibilidad de actividad privilegiada en producción → `incident-root-cause-analyst`.

# Manual remediation guidance

`manual_action` sugiere política de auditoría ampliada (Unified) o `AUDIT` statement específico
(Traditional) — siempre `NOT_EXECUTED`.

# Security

Nunca contenido de datos de aplicación auditado.

# Tests

`tests/test_privileged_audit_awareness.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/audit-posture.md`.

# Change history

v1.0.0 — Fase 8, creación inicial.

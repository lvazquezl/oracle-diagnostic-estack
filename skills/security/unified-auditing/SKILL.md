---
name: unified-auditing
id: security/unified-auditing
version: 1.0.0
domain: security
status: active
---

# Purpose

Detecta disponibilidad, `enabled_mode` (pure/mixed), políticas habilitadas, usuarios/roles
targeted, evidencia de audit trail — nunca habilita políticas (`# 27` del prompt de Fase 8).

# Supported Oracle versions

12c–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

Ninguno.

# Required evidence

- `Q-SEC-UNIFIED-AUDIT-POLICIES-001`

# Optional evidence

`Q-SEC-UNIFIED-AUDIT-TRAIL-001` para evidencia de actividad reciente.

# Licensing requirements

Ninguno.

# Query IDs

`Q-SEC-UNIFIED-AUDIT-POLICIES-001`, `Q-SEC-UNIFIED-AUDIT-TRAIL-001`.

# Collector IDs

`get_unified_audit_policies`.

# Read-only operations

Lectura de `AUDIT_UNIFIED_ENABLED_POLICIES`/`UNIFIED_AUDIT_TRAIL` (filtrada).

# Forbidden operations

Nunca ejecuta `AUDIT POLICY ...`/`NOAUDIT POLICY ...`.

# Decision logic

1. En 10g/11g → `capability_status: UNSUPPORTED`, nunca se consulta esta vista.
2. Políticas habilitadas sin cobertura de `SYS`/admin option/DDL de seguridad → finding
   `covers_privileged_activity: false`.
3. Distingue `PURE_UNIFIED` (Traditional deshabilitado) de `MIXED` (ambos activos) cuando
   certificado.

# Normal state

Al menos una política habilitada cubriendo actividad privilegiada.

# Abnormal patterns

Unified Auditing disponible (12.1+) pero sin ninguna política habilitada.

# False positives

Ninguno.

# Correlation rules

Alimenta `security/audit-configuration`, `security/privileged-audit`.

# Confidence model

`FACT`.

# Severity

`HIGH` si disponible pero sin políticas habilitadas en producción.

# Output schema

```yaml
unified_auditing:
  available: bool
  enabled_mode: NONE|PURE_UNIFIED|MIXED|UNKNOWN
  enabled_policies: [string]
  covers_privileged_activity: bool|null
  evidence_refs: [EVD-...]
```

# Related skills

`security/traditional-auditing`, `security/privileged-audit`, `security/audit-configuration`.

# Escalation

Sin políticas habilitadas en producción → finding, delegado a `security/audit-configuration`
para consolidar.

# Manual remediation guidance

`manual_action` sugiere `AUDIT POLICY ORA_SECURECONFIG`/política custom — siempre
`NOT_EXECUTED`.

# Security

`entity_name` → MASK por defecto.

# Tests

`tests/test_unified_audit_detection.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/audit-posture.md`.

# Change history

v1.0.0 — Fase 8, creación inicial.

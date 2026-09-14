---
name: security-assessment
id: security/security-assessment
version: 1.0.0
domain: security
status: active
---

# Purpose

Implementa `/assessment security` — produce executive summary, scope, account/privilege/
password-profile/password-strength-policy/audit/encryption/network-security posture, compliance
mapping, critical findings, high-risk privilege concentrations, licensing notes, manual
recommendations, evidence manifest (`# 50` del prompt de Fase 8).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`security/security-healthcheck` ya ejecutado o ejecutable en el mismo flujo.

# Required evidence

Consolida evidencia de todos los skills `security/*` aplicables.

# Optional evidence

N/A.

# Licensing requirements

Ninguno directo — hereda de skills consumidos.

# Query IDs

Ninguna directa.

# Collector IDs

Ninguno.

# Read-only operations

Orquesta llamadas read-only a los skills del dominio, más profundas que `security-healthcheck`
(assessment completo vs. healthcheck rápido).

# Forbidden operations

Ninguna mutación en ningún punto del flujo.

# Decision logic

1. A diferencia de `security-healthcheck` (snapshot rápido), `security-assessment` produce un
   documento completo con executive summary y evidence manifest trazable.
2. `high-risk privilege concentrations` correlaciona `security/powerful-privileges` +
   `security/admin-privileges` + `security/public-grants` en una sola vista consolidada.
3. `licensing notes` consolida `security/licensing-gates`.

# Normal state

Documento completo generado con todas las secciones pobladas o explícitamente marcadas
`NOT_APPLICABLE`/`INSUFFICIENT_EVIDENCE`.

# Abnormal patterns

Cualquier `critical findings` no vacío.

# False positives

N/A — orquestación, no genera hallazgos propios.

# Correlation rules

Consume todos los skills `security/*`. Alimenta `technical-documentation-manager` para el
registro en `analysis/ANA-*`.

# Confidence model

Hereda de los skills consumidos.

# Severity

Consolidada desde los skills consumidos.

# Output schema

```yaml
security_assessment:
  executive_summary: string
  scope: string
  account_posture: object
  privilege_posture: object
  password_profile_posture: object
  password_strength_policy_posture: object
  audit_posture: object
  encryption_posture: object
  network_security_posture: object
  compliance_mapping: object
  critical_findings: [object]
  high_risk_privilege_concentrations: [object]
  licensing_notes: [object]
  manual_recommendations: [object]
  evidence_manifest: [EVD-...]
```

# Related skills

Todos los skills `security/*`, especialmente `security/security-healthcheck`,
`security/compliance-mapping`.

# Escalation

`critical_findings` no vacío → `incident-root-cause-analyst`.

# Manual remediation guidance

Consolida `manual_action` de todos los skills en `manual_recommendations` — siempre
`NOT_EXECUTED`.

# Security

Hereda sanitización de todos los skills consumidos.

# Tests

Ver suite completa `tests/test_security_*.sh`, `tests/test_compliance_*.sh`.

# Documentation requirements

Genera el documento completo `analysis/ANA-*/security-posture.md` + secciones asociadas
(`accounts.md`, `privileges.md`, etc.).

# Change history

v1.0.0 — Fase 8, creación inicial.

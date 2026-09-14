---
name: manual-remediation-plan
id: security/manual-remediation-plan
version: 1.0.0
domain: security
status: active
---

# Purpose

Genera planes de remediación manual usando el Manual Action Contract — toda recomendación
`execution_status: NOT_EXECUTED`, nunca ejecutada (`# 73, # 74` del prompt de Fase 8).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

Al menos un finding de cualquier skill `security/*` aprobado por el DBA para remediación.

# Required evidence

Findings de los skills `security/*` que originan la recomendación.

# Optional evidence

N/A.

# Licensing requirements

Ninguno directo — hereda `licensing_gate` del hallazgo origen cuando aplica.

# Query IDs

Ninguna — genera texto, no consulta evidencia nueva.

# Collector IDs

Ninguno.

# Read-only operations

N/A — este skill no consulta la base de datos, sólo compone el plan textual.

# Forbidden operations

Nunca ejecuta ningún comando generado (`ALTER PROFILE`, `ALTER USER`, `GRANT`/`REVOKE`, `AUDIT`,
`ADMINISTER KEY MANAGEMENT`, cambios de Database Vault/OLS/Redaction/Masking).

# Decision logic

1. Todo `manual_action` incluye: `action_id, purpose, owner_role, command, prechecks,
   expected_result, risk, rollback, postchecks, licensing_gate, execution_status: NOT_EXECUTED`.
2. Comandos de `ALTER PROFILE`/`ALTER USER`/`PASSWORD RESET` aparecen exclusivamente como
   `MANUAL DBA ACTION` (`# 74` del prompt) — nunca ejecutados, nunca simulados como ejecutados.
3. `risk`/`rollback` siempre poblados — nunca se genera un plan sin análisis de riesgo/reversión.

# Normal state

Plan completo y específico para el hallazgo origen, sin ambigüedad sobre qué DBA debe ejecutar
y cómo verificar.

# Abnormal patterns

N/A — este skill no detecta anomalías, sólo documenta remediación.

# False positives

N/A.

# Correlation rules

Consume findings de cualquier skill `security/*`. Alimenta `change-advisor` cuando el DBA aprueba
formalizar la propuesta.

# Confidence model

N/A — es un artefacto de remediación, no un hallazgo con confidence.

# Severity

Hereda la severidad del finding origen.

# Output schema

```yaml
manual_action:
  action_id: string
  purpose: string
  owner_role: string
  command: string
  prechecks: [string]
  expected_result: string
  risk: string
  rollback: string
  postchecks: [string]
  licensing_gate: string|null
  execution_status: NOT_EXECUTED
```

# Related skills

Todos los skills `security/*` que generan findings.

# Escalation

N/A — este skill es la salida final antes de `change-advisor`.

# Manual remediation guidance

Este skill ES la guía de remediación manual — no delega a otro skill para esto.

# Security

Ninguna exposición de secretos — los comandos generados son plantillas, nunca incluyen valores
de contraseña reales/sugeridos.

# Tests

`tests/test_no_password_reset_execution.sh`, `tests/test_no_audit_policy_change.sh`,
`tests/test_no_keystore_change.sh`, `tests/test_no_database_vault_change.sh`,
`tests/test_no_redaction_change.sh`, `tests/test_no_masking_execution.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/manual-remediation.md`.

# Change history

v1.0.0 — Fase 8, creación inicial.

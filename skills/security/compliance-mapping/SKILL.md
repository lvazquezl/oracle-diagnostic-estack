---
name: compliance-mapping
id: security/compliance-mapping
version: 1.0.0
domain: security
status: active
---

# Purpose

Mapeo extensible de controles (CIS Oracle Database Benchmark, DISA STIG, baseline corporativo
interno, policy custom) contra evidencia certificada — nunca copia benchmarks propietarios
completos (`# 44` del prompt de Fase 8).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

Todos los demás skills `security/*` relevantes al control ya ejecutados.

# Required evidence

Consolida evidencia de todo el dominio Security según el control mapeado.

# Optional evidence

`Target Profile.security.compliance_frameworks` para acotar el mapeo a frameworks específicos.

# Licensing requirements

Ninguno (el mapeo en sí; los controles individuales pueden requerir features licenciadas).

# Query IDs

Ninguna directa — consolida evidencia de todo el dominio.

# Collector IDs

Ninguno.

# Read-only operations

Ninguna adicional.

# Forbidden operations

Nunca modifica configuración para "hacer pasar" un control.

# Decision logic

1. Cada control se define con `control_id, title/reference, evidence requirement, evaluation
   logic, status` — nunca se copia el texto completo de un benchmark propietario (CIS/STIG),
   sólo se referencia (`framework`, `control_id`).
2. Estados: `PASS|FAIL|PARTIAL|NOT_APPLICABLE|NOT_ASSESSED|INSUFFICIENT_EVIDENCE|
   INSUFFICIENT_POLICY|LICENSE_RESTRICTED`.
3. `INSUFFICIENT_POLICY` cuando el control requiere un target explícito no definido (ej. password
   policy sin `Target Profile.security.password_policy`) — nunca `FAIL` en ese caso.
4. `LICENSE_RESTRICTED` cuando el control depende de una feature con `licensing_gates.status !=
   INCLUDED`.
5. Trazabilidad `EVD → FND → REC → CHG` mantenida en `remediation_ref` cuando aplica.

# Normal state

Mayoría de controles `PASS`/`NOT_APPLICABLE`, algunos `INSUFFICIENT_POLICY` sin baseline
corporativo definido — estado honesto, no un fallo del skill.

# Abnormal patterns

Alta proporción de `FAIL` en controles de password policy/auditoría/PUBLIC grants.

# False positives

`NOT_ASSESSED` (control fuera del alcance del assessment actual) no debe confundirse con `FAIL`
— son estados distintos.

# Correlation rules

Consume todos los skills `security/*` relevantes. Alimenta `security/security-assessment`.

# Confidence model

`FACT` para evidencia directa, `OBSERVATION`/`HYPOTHESIS` cuando el control requiere
interpretación adicional.

# Severity

Derivada del control específico — no uniforme.

# Output schema

```yaml
compliance_mapping:
  - control:
      framework: string
      control_id: string
      requirement: string
      status: PASS|FAIL|PARTIAL|NOT_APPLICABLE|NOT_ASSESSED|INSUFFICIENT_EVIDENCE|INSUFFICIENT_POLICY|LICENSE_RESTRICTED
      evidence_ids: [EVD-...]
      rationale: string
      scope: string
      version: string
      confidence: FACT|OBSERVATION|HYPOTHESIS
      remediation_ref: string|null
```

# Related skills

Todos los skills `security/*`.

# Escalation

Controles `FAIL` críticos (ej. cuentas default con password default en producción) →
`incident-root-cause-analyst`.

# Manual remediation guidance

Cada control `FAIL` con `remediation_ref` apunta a un `manual_action` generado por el skill
fuente correspondiente — siempre `NOT_EXECUTED`.

# Security

Ninguna exposición adicional — consolida metadata ya sanitizada de otros skills.

# Tests

`tests/test_compliance_control_mapping.sh`, `tests/test_compliance_password_policy_mapping.sh`,
`tests/test_compliance_insufficient_policy.sh`, `tests/test_compliance_insufficient_evidence.sh`,
`tests/test_compliance_not_applicable.sh`, `tests/test_compliance_traceability.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/compliance.md`.

# Change history

v1.0.0 — Fase 8, creación inicial.

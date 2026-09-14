---
name: security-healthcheck
id: security/security-healthcheck
version: 1.0.0
domain: security
status: active
---

# Purpose

Implementa `/healthcheck security` — flujo Target Profile → Version/CDB Context → Accounts →
Roles/Privileges → PUBLIC → Profiles → Password Strength Policy → Audit → Encryption → Network
Security → Parameters → Advanced Features → Compliance → Findings → Recommendations → Markdown
(`# 49` del prompt de Fase 8).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

Target Profile publicado.

# Required evidence

Consolida evidencia de todos los skills `security/*` aplicables según capability filter.

# Optional evidence

N/A.

# Licensing requirements

Ninguno directo — hereda de skills consumidos.

# Query IDs

Ninguna directa.

# Collector IDs

Ninguno.

# Read-only operations

Orquesta llamadas read-only a los skills del dominio.

# Forbidden operations

Ninguna mutación en ningún punto del flujo.

# Decision logic

1. Capability Filter cruza Target Profile contra `config/capability-matrix.yaml` antes de
   activar cualquier skill — skill incompatible con la versión/arquitectura no se activa.
2. Orden fijo: Accounts → Roles/Privileges → PUBLIC → Profiles → Password Strength Policy →
   Audit → Encryption → Network Security → Parameters → Advanced Features → Compliance.
3. Produce `health_model` por dimensión — nunca un score único opaco.

# Normal state

Mayoría de dimensiones `HEALTHY`/`WARNING`.

# Abnormal patterns

Cualquier dimensión `CRITICAL` — señal de escalamiento a `incident-root-cause-analyst`.

# False positives

Ninguno — este skill orquesta, no reinterpreta hallazgos de los skills consumidos.

# Correlation rules

Consume todos los skills `security/*`. Produce el `health_model` consolidado del agente.

# Confidence model

Hereda de los skills consumidos — nunca degrada ni mejora confianza individual.

# Severity

Consolidada desde los skills — nunca reinterpretada.

# Output schema

```yaml
security_healthcheck:
  health_model:
    accounts: HEALTHY|WARNING|DEGRADED|CRITICAL|UNKNOWN|NOT_APPLICABLE|LICENSE_RESTRICTED
    roles: HEALTHY|WARNING|DEGRADED|CRITICAL|UNKNOWN|NOT_APPLICABLE|LICENSE_RESTRICTED
    privileges: HEALTHY|WARNING|DEGRADED|CRITICAL|UNKNOWN|NOT_APPLICABLE|LICENSE_RESTRICTED
    public_exposure: HEALTHY|WARNING|DEGRADED|CRITICAL|UNKNOWN|NOT_APPLICABLE|LICENSE_RESTRICTED
    password_profile: HEALTHY|WARNING|DEGRADED|CRITICAL|UNKNOWN|NOT_APPLICABLE|LICENSE_RESTRICTED
    password_strength_policy: HEALTHY|WARNING|DEGRADED|CRITICAL|UNKNOWN|NOT_APPLICABLE|LICENSE_RESTRICTED
    auditing: HEALTHY|WARNING|DEGRADED|CRITICAL|UNKNOWN|NOT_APPLICABLE|LICENSE_RESTRICTED
    tde: HEALTHY|WARNING|DEGRADED|CRITICAL|UNKNOWN|NOT_APPLICABLE|LICENSE_RESTRICTED
    keystore: HEALTHY|WARNING|DEGRADED|CRITICAL|UNKNOWN|NOT_APPLICABLE|LICENSE_RESTRICTED
    network_encryption: HEALTHY|WARNING|DEGRADED|CRITICAL|UNKNOWN|NOT_APPLICABLE|LICENSE_RESTRICTED
    security_parameters: HEALTHY|WARNING|DEGRADED|CRITICAL|UNKNOWN|NOT_APPLICABLE|LICENSE_RESTRICTED
    database_links: HEALTHY|WARNING|DEGRADED|CRITICAL|UNKNOWN|NOT_APPLICABLE|LICENSE_RESTRICTED
    directories: HEALTHY|WARNING|DEGRADED|CRITICAL|UNKNOWN|NOT_APPLICABLE|LICENSE_RESTRICTED
    advanced_security_features: HEALTHY|WARNING|DEGRADED|CRITICAL|UNKNOWN|NOT_APPLICABLE|LICENSE_RESTRICTED
    compliance: HEALTHY|WARNING|DEGRADED|CRITICAL|UNKNOWN|NOT_APPLICABLE|LICENSE_RESTRICTED
  findings: [{area: string, observation: string, severity: string, evidence_refs: [EVD-...]}]
  recommendations: [{summary: string, manual_action: object}]
```

# Related skills

Todos los skills `security/*`.

# Escalation

Cualquier dimensión `CRITICAL` → `incident-root-cause-analyst`.

# Manual remediation guidance

Consolida `manual_action` de todos los skills — siempre `NOT_EXECUTED`.

# Security

Hereda sanitización de todos los skills consumidos.

# Tests

Ver suite completa `tests/test_security_*.sh`.

# Documentation requirements

Genera `analysis/ANA-*/security-posture.md` consolidado.

# Change history

v1.0.0 — Fase 8, creación inicial.

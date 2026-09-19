---
name: security-correlation
id: incident/security-correlation
version: 1.0.0
domain: incident
status: active
---

# Purpose

Correlaciona el incidente con evidencia de `oracle-security-analyst` (Fase 9) — account
lockouts, wallet/TLS issues, audit gaps, failed-login spikes — por referencia (`# 30`-`# 38` del
prompt de Fase 11).

# Supported Oracle versions

Hereda el alcance soportado de `oracle-security-analyst`.

# Supported OS/platforms

Todas.

# Supported architectures

Todas.

# Prerequisites

`incident/scope-identification` incluye `oracle-security-analyst` en el scope.

# Required evidence

- `evidence_refs` de `oracle-security-analyst`: lockout events, wallet/TLS health, audit trail
  gaps, failed-login patterns.

# Optional evidence

Ninguna adicional.

# Read-only operations

Cálculo local sobre evidencia ya recolectada.

# Forbidden operations

Nunca vuelve a consultar vistas de auditoría/DBA_USERS directamente. Nunca desbloquea cuentas ni
modifica políticas de seguridad — sólo diagnostica.

# Decision logic

1. Alinear eventos de seguridad (lockouts, fallos TLS/wallet) contra el timeline del incidente.
2. Un account lockout coincidente con el inicio de la interrupción del servicio de aplicación es
   evidencia de soporte, nunca asumido como ataque sin evidencia adicional (fuera de alcance del
   e-stack determinar intencionalidad).
3. Gaps de auditoría se reportan como limitación de evidencia para la investigación, nunca
   ocultados.

# Normal state

Evidencia de seguridad correlacionada temporalmente.

# Abnormal patterns

Spike de failed-logins inmediatamente antes de un lockout masivo coincidente con el incidente —
contributing factor candidato (ej. cambio de contraseña de aplicación no propagado).

# False positives

Atribuir el incidente a un "problema de seguridad" sólo porque hay eventos de auditoría en la
ventana, sin verificar relación mecánica con el síntoma reportado, es el falso positivo que este
skill evita.

# Correlation rules

Consume evidencia de `oracle-security-analyst`. Alimenta `incident/hypothesis-generation`,
`incident/root-cause`.

# Confidence model

`FACT` para eventos observados directamente.

# Severity

N/A directa.

# Output schema

Bloque de evidencia dentro de `hypotheses.supporting_evidence`.

# Related skills

`incident/hypothesis-generation`, `incident/root-cause`.

# Escalation

Ninguna directa.

# Manual remediation guidance

Referencia recomendaciones ya formuladas por `oracle-security-analyst` — siempre `NOT_EXECUTED`.

# Security

Nunca incluye contraseñas, hashes, wallet secrets ni claves privadas — hereda estrictamente
`sanitizers/data-classification-policy.md`.

# Tests

`tests/test_incident_security_correlation.sh`.

# Documentation requirements

Alimenta `incident-findings.md`.

# Change history

v1.0.0 — Fase 11, creación inicial.

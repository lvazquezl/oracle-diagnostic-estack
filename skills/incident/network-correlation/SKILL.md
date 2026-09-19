---
name: network-correlation
id: incident/network-correlation
version: 1.0.0
domain: incident
status: active
---

# Purpose

Correlaciona el incidente con evidencia de `oracle-network-analyst` (Fase 7) — listener health,
TNS errors, SCAN/VIP status, firewall/routing symptoms, latency between tiers — por referencia
(`# 30`-`# 38` del prompt de Fase 11).

# Supported Oracle versions

Hereda el alcance soportado de `oracle-network-analyst`.

# Supported OS/platforms

Todas.

# Supported architectures

Todas.

# Prerequisites

`incident/scope-identification` incluye `oracle-network-analyst` en el scope.

# Required evidence

- `evidence_refs` de `oracle-network-analyst`: listener log errors, TNS error signatures,
  SCAN/VIP status, connectivity latency.

# Optional evidence

Ninguna adicional.

# Read-only operations

Cálculo local sobre evidencia ya recolectada.

# Forbidden operations

Nunca vuelve a parsear listener.log directamente. Nunca recomienda ni ejecuta cambios de red.

# Decision logic

1. Alinear errores TNS/listener contra el timeline del incidente.
2. `ORA-12537`/`ORA-12170`-type errors son síntomas, nunca causa raíz automática (ejemplo textual
   del prompt `# 40`-`# 47`) — requieren el mecanismo subyacente confirmado (ej. firewall
   idle-timeout, listener process hang, network path instability).
3. Distinguir explícitamente síntoma de red (conexión rechazada) de condición subyacente
   (proceso listener colgado / firewall cerrando conexiones idle) — nunca colapsados.

# Normal state

Evidencia de red correlacionada, síntomas TNS explícitamente separados de su condición
subyacente propuesta.

# Abnormal patterns

Errores TNS masivos y simultáneos en múltiples clientes — señal de degradación de infraestructura
compartida (listener/red), no de un cliente individual.

# False positives

Reportar `ORA-12537` en sí mismo como root cause, sin identificar el mecanismo subyacente que lo
produjo, es exactamente el falso positivo que este skill (y el modelo de causalidad del agente)
evitan.

# Correlation rules

Consume evidencia de `oracle-network-analyst`. Alimenta `incident/hypothesis-generation`,
`incident/root-cause`, `incident/playbooks` (listener playbook).

# Confidence model

`FACT` para errores observados directamente; la causa subyacente requiere el Root Cause Model
completo.

# Severity

N/A directa.

# Output schema

Bloque de evidencia dentro de `hypotheses.supporting_evidence`.

# Related skills

`incident/hypothesis-generation`, `incident/root-cause`, `incident/playbooks`.

# Escalation

Ninguna directa.

# Manual remediation guidance

Referencia recomendaciones ya formuladas por `oracle-network-analyst` — siempre `NOT_EXECUTED`.

# Security

Sin datos sensibles adicionales — nunca incluye IPs de clientes de negocio sin necesidad
diagnóstica directa.

# Tests

`tests/test_incident_network_correlation.sh`.

# Documentation requirements

Alimenta `incident-findings.md`.

# Change history

v1.0.0 — Fase 11, creación inicial.

---
name: performance-correlation
id: incident/performance-correlation
version: 1.0.0
domain: incident
status: active
---

# Purpose

Correlaciona el incidente con evidencia de `oracle-performance-analyst` (Fase 3) — wait events,
AWR/ASH deltas, SQL regressions, resource contention — por referencia, nunca duplicando
collectors (`# 30`-`# 38` del prompt de Fase 11).

# Supported Oracle versions

Hereda el alcance soportado de `oracle-performance-analyst`.

# Supported OS/platforms

Todas.

# Supported architectures

Todas.

# Prerequisites

`incident/scope-identification` incluye `oracle-performance-analyst` en el scope.

# Required evidence

- `evidence_refs` de `oracle-performance-analyst`: top wait events, AWR/ASH deltas, SQL plan
  changes, resource contention.

# Optional evidence

Ninguna adicional.

# Read-only operations

Cálculo local sobre evidencia ya recolectada.

# Forbidden operations

Nunca vuelve a consultar AWR/ASH directamente — consume exclusivamente el `evidence_refs` ya
producido por `oracle-performance-analyst`. Nunca declara causalidad sólo por un wait event
elevado coincidente en el tiempo (ver `incident/root-cause#correlation-is-not-causation`).

# Decision logic

1. Alinear los deltas de performance de la ventana del incidente contra el timeline.
2. Un wait event/SQL regression dentro de la ventana es evidencia de soporte para una hipótesis,
   nunca confirmación por sí sola — requiere el resto del Root Cause Model
   (`incident/hypothesis-testing`).
3. Distinguir explícitamente síntoma (ej. "sesiones bloqueadas en `enq: TX`") de condición
   subyacente potencial (ej. "aplicación sin commit frecuente") — nunca colapsados.

# Normal state

Evidencia de performance correlacionada temporalmente, clasificada como `supporting_evidence` de
hipótesis específicas.

# Abnormal patterns

Degradación de performance sostenida iniciada exactamente en el timestamp del primer síntoma
reportado — señal fuerte, sujeta igual a confirmación de mecanismo.

# False positives

Atribuir el incidente a "alto uso de CPU" sólo porque coincide temporalmente, sin mecanismo
causal ni evidencia adicional, es el falso positivo que este skill evita.

# Correlation rules

Consume evidencia de `oracle-performance-analyst`. Alimenta `incident/hypothesis-generation`,
`incident/root-cause`.

# Confidence model

`FACT` para las métricas observadas; la atribución causal es responsabilidad de
`incident/root-cause`.

# Severity

N/A directa.

# Output schema

Bloque de evidencia dentro de `hypotheses.supporting_evidence` (ver `output-schema.yaml` del
agente).

# Related skills

`incident/hypothesis-generation`, `incident/root-cause`, `incident/capacity-correlation`.

# Escalation

Ninguna directa.

# Manual remediation guidance

Si confirmado como root cause/contributing factor, referencia las recomendaciones ya
formuladas por `oracle-performance-analyst` — siempre `NOT_EXECUTED`.

# Security

Nunca reenvía SQL text completo ni bind values — sólo referencias sanitizadas ya producidas por
`oracle-performance-analyst`.

# Tests

`tests/test_incident_performance_correlation.sh`.

# Documentation requirements

Alimenta `incident-findings.md`.

# Change history

v1.0.0 — Fase 11, creación inicial.

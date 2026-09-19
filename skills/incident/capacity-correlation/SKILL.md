---
name: capacity-correlation
id: incident/capacity-correlation
version: 1.0.0
domain: incident
status: active
---

# Purpose

Correlaciona el incidente con saturación de capacidad actual, threshold crossing, crecimiento
histórico y eventos de resize recientes (`# 904`-`# 915` del prompt de Fase 11), reutilizando
`capacity-analyst` (Fase 10) por referencia — nunca usa un forecast futuro como prueba de causa de
un evento ya ocurrido sin evidencia directa.

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Todas.

# Supported architectures

Todas.

# Prerequisites

`incident/scope-identification` incluye `capacity-analyst` en el scope.

# Required evidence

- `evidence_refs` de `capacity-analyst` (Fase 10): `data_quality`, `capacity_metrics`, `thresholds`,
  `capacity_events`.

# Optional evidence

Ninguna adicional.

# Read-only operations

Cálculo local sobre evidencia ya recolectada por `capacity-analyst`.

# Forbidden operations

Nunca ejecuta ni recomienda un cambio de capacidad (resize/extend) directamente — reutiliza
`capacity/manual-capacity-plan` (Fase 10) si aplica. Nunca duplica los collectors de
`capacity_engine`.

## Forecast is not evidence of past cause

Un forecast de `capacity-analyst` proyecta el futuro — nunca se usa como prueba de que la
saturación YA ocurrió en el momento del incidente sin el dato histórico/actual que lo confirme
directamente (`# 915`, `# 1609`-`# 1620` del prompt: "no usar forecast futuro como prueba de causa
de un evento pasado salvo evidencia").

# Decision logic

1. Consultar `capacity_metrics`/`threshold_crossings`/`capacity_events` de `capacity-analyst` para
   la ventana temporal del incidente — nunca el forecast a 1/3/6 meses como sustituto del dato
   histórico real.
2. Si `threshold_crossings[].status == ALREADY_EXCEEDED` con timestamp dentro de la ventana del
   incidente, es evidencia directa válida para una hipótesis de saturación.
3. Un `capacity_event` (resize) reciente antes del incidente se correlaciona igual que cualquier
   otro cambio conocido (ver `incident/change-correlation`) — nunca asumido causal sin evidencia
   adicional.

# Normal state

Correlación de capacidad basada en datos históricos/actuales confirmados, nunca en proyecciones.

# Abnormal patterns

Saturación confirmada (`ALREADY_EXCEEDED`) coincidente con la ventana del incidente — hipótesis
fuerte de contributing factor/root cause, sujeta igual al resto del Root Cause Model.

# False positives

Citar "el forecast de capacity-analyst proyecta saturación en 3 meses" como explicación de un
incidente que ya ocurrió es el falso positivo que este skill evita explícitamente.

# Correlation rules

Consume evidencia de `capacity-analyst`. Alimenta `incident/hypothesis-generation`,
`incident/change-correlation`.

# Confidence model

`FACT` para datos históricos/actuales confirmados; forecast futuro nunca se usa como `FACT` de
causa pasada.

# Severity

N/A directa.

# Output schema

Ver `output-schema.yaml` del agente — bloque de evidencia de capacidad dentro de `findings`/
`hypotheses.supporting_evidence`.

# Related skills

`incident/change-correlation`, `incident/hypothesis-generation`, `incident/root-cause`.

# Escalation

Ninguna directa.

# Manual remediation guidance

Si la saturación de capacidad es confirmada como root cause/contributing factor, referencia
`capacity/manual-capacity-plan` (Fase 10) — siempre `NOT_EXECUTED`.

# Security

Sin datos sensibles adicionales.

# Tests

`tests/test_incident_capacity_correlation.sh`.

# Documentation requirements

Alimenta `incident-findings.md`.

# Change history

v1.0.0 — Fase 11, creación inicial.

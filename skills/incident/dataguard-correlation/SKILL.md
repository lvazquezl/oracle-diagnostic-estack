---
name: dataguard-correlation
id: incident/dataguard-correlation
version: 1.0.0
domain: incident
status: active
---

# Purpose

Correlaciona el incidente con evidencia de `oracle-dataguard-analyst` (Fase 5) — transport/apply
lag, archive gaps, broker warnings, role transitions, standby disconnects — por referencia
(`# 30`-`# 38` del prompt de Fase 11).

# Supported Oracle versions

Hereda el alcance soportado de `oracle-dataguard-analyst`.

# Supported OS/platforms

Todas.

# Supported architectures

Requiere Data Guard configurado (gate heredado del agente).

# Prerequisites

`incident/scope-identification` incluye `oracle-dataguard-analyst` en el scope.

# Required evidence

- `evidence_refs` de `oracle-dataguard-analyst`: transport/apply lag series, archive gap status,
  broker configuration health, standby connectivity.

# Optional evidence

Ninguna adicional.

# Read-only operations

Cálculo local sobre evidencia ya recolectada.

# Forbidden operations

Nunca vuelve a consultar vistas V$DATAGUARD_* directamente. Nunca recomienda ni ejecuta
switchover/failover — sólo diagnostica y referencia el playbook correspondiente para ejecución
manual.

# Decision logic

1. Alinear el crecimiento de lag/gaps contra el timeline del incidente.
2. Distinguir explícitamente `data_loss` confirmado (gap con evidencia de pérdida real) de
   simple degradación de lag sin pérdida confirmada — nunca reportar `data_loss: true` sin
   evidencia directa (ver `incident/impact-analysis`).
3. Un warning de broker coincidente en tiempo con el incidente es evidencia de soporte, nunca
   causa confirmada sin mecanismo verificado.

# Normal state

Evidencia de Data Guard correlacionada, `data_loss` explícito sólo con evidencia directa.

# Abnormal patterns

Apply lag creciente sostenido antes del incidente — contributing factor candidato para
`incident/root-cause`.

# False positives

Reportar pérdida de datos sólo por un gap de archivelog transitorio ya resuelto por FAL/RFS, sin
verificar si realmente hubo pérdida, es el falso positivo que este skill evita.

# Correlation rules

Consume evidencia de `oracle-dataguard-analyst`. Alimenta `incident/hypothesis-generation`,
`incident/root-cause`, `incident/impact-analysis`, `incident/playbooks` (DG lag playbook).

# Confidence model

`FACT` para métricas de lag/gap observadas directamente; `data_loss` requiere evidencia directa
explícita, nunca inferida.

# Severity

N/A directa.

# Output schema

Bloque de evidencia dentro de `hypotheses.supporting_evidence`.

# Related skills

`incident/impact-analysis`, `incident/hypothesis-generation`, `incident/playbooks`.

# Escalation

Ninguna directa.

# Manual remediation guidance

Referencia recomendaciones ya formuladas por `oracle-dataguard-analyst` — siempre `NOT_EXECUTED`.

# Security

Sin datos sensibles adicionales.

# Tests

`tests/test_incident_dataguard_correlation.sh`.

# Documentation requirements

Alimenta `incident-findings.md`.

# Change history

v1.0.0 — Fase 11, creación inicial.

---
name: impact-analysis
id: incident/impact-analysis
version: 1.0.0
domain: incident
status: active
---

# Purpose

Normaliza el impacto del incidente (`docs/INCIDENT_IMPACT_MODEL.md`) — técnico, servicios, bases
de datos, nodos, usuarios afectados, duración, pérdida de datos, degradación de performance,
disponibilidad — nunca inventa usuarios afectados sin evidencia (`# 706`-`# 724` del prompt de
Fase 11).

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Todas.

# Supported architectures

Todas.

# Prerequisites

`incident/intake`, `incident/timeline` ejecutados.

# Required evidence

- Timeline y evidencia cross-domain ya correlacionada.

# Optional evidence

- Métricas de negocio declaradas explícitamente por el DBA (nunca inferidas).

# Read-only operations

Cálculo local.

# Forbidden operations

Nunca inventa `users_affected` u otro campo de impacto sin evidencia directa — campos sin
evidencia quedan `null` explícito, nunca un valor estimado sin base.

# Decision logic

1. Normalizar cada campo del modelo de impacto (`technical`, `services`, `databases`, `nodes`,
   `users_affected`, `duration`, `data_loss`, `performance_degradation`, `availability`) desde
   evidencia directa únicamente.
2. `duration` se calcula desde el timeline (`detected_at`→`resolved_at`/último evento de
   `RECOVERY`), nunca estimada sin esos anclajes.
3. `data_loss` sólo se marca `true` con evidencia directa (ej. gap de archivelog confirmado,
   Data Guard lag con pérdida confirmada) — `null` sin esa evidencia, nunca asumido `false` por
   defecto tampoco (ausencia de evidencia de pérdida no es evidencia de ausencia).

# Normal state

Campos de impacto poblados desde evidencia directa, con `null` explícito donde no hay evidencia.

# Abnormal patterns

Campos de impacto con valores estimados sin trazabilidad — evitado por diseño.

# False positives

Inferir `users_affected` a partir de la severidad reportada, sin evidencia directa de conteo de
sesiones/conexiones afectadas, es el falso positivo que este skill evita.

# Correlation rules

Consume `incident/timeline`, evidencia cross-domain. Alimenta `incident/blast-radius`,
`incident/rca-report`.

# Confidence model

`FACT` para campos con evidencia directa; `null`/`UNDETERMINED` para campos sin evidencia
suficiente.

# Severity

N/A directa — el impacto informa la severidad, no la determina unilateralmente.

# Output schema

Ver `docs/INCIDENT_IMPACT_MODEL.md#schema`.

# Related skills

`incident/blast-radius`, `incident/recovery-status`, `incident/severity-awareness`.

# Escalation

Ninguna directa.

# Manual remediation guidance

N/A directa.

# Security

Nunca incluye identificadores crudos de usuarios/clientes — sólo conteos agregados cuando hay
evidencia.

# Tests

`tests/test_incident_impact.sh`.

# Documentation requirements

Produce `incident-impact.md`.

# Change history

v1.0.0 — Fase 11, creación inicial.

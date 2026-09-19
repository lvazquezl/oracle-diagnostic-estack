---
name: post-incident-review
id: incident/post-incident-review
version: 1.0.0
domain: incident
status: active
---

# Purpose

Estructura la revisión post-incidente (`# 1076`-`# 1096` del prompt de Fase 11): timeline
resumido, causa raíz, impacto, qué funcionó, qué no funcionó, gaps de detección/observabilidad,
acciones de seguimiento propuestas — nunca asigna culpa individual (blameless por diseño).

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Todas.

# Supported architectures

Todas.

# Prerequisites

`incident/root-cause`, `incident/recovery-status`, `incident/impact-analysis`,
`incident/blast-radius` ejecutados.

# Required evidence

- Resultado completo del `incident_result` hasta el punto de recuperación.

# Optional evidence

- `incident/recurrence-awareness` si hay historial relevante.

# Read-only operations

Síntesis de texto local.

# Forbidden operations

Nunca atribuye culpa a una persona/equipo específico — el foco es sistémico (proceso, tooling,
observabilidad, documentación), nunca individual.

# Decision logic

1. Resumir el timeline en un formato ejecutivo (detección → escalamiento → diagnóstico →
   mitigación → recuperación), con duración de cada fase.
2. "What worked": acciones/herramientas/alertas que funcionaron correctamente durante el
   incidente — reconocidas explícitamente, no sólo lo que falló.
3. "What did not work": gaps de detección, alertas ausentes/tardías, runbooks desactualizados,
   ambigüedad en escalamiento — siempre enmarcado como gap de proceso/sistema, nunca de persona.
4. Acciones de seguimiento (`follow_up_actions`) se proponen como texto para revisión humana,
   nunca auto-creadas como tickets/cambios reales.

# Normal state

Revisión estructurada, blameless, con acciones de seguimiento propuestas.

# Abnormal patterns

Incidente recurrente sin acción de seguimiento previa completada — señalado explícitamente como
gap sistémico.

# False positives

N/A directo.

# Correlation rules

Consume prácticamente todo el `incident_result`. Alimenta `incident/lessons-learned`,
`incident/rca-report`.

# Confidence model

N/A directo — es síntesis, no genera nuevos hallazgos de confianza.

# Severity

N/A directa.

# Output schema

```yaml
post_incident_review:
  timeline_summary: string
  what_worked: [string]
  what_did_not_work: [string]
  detection_gaps: [string]
  follow_up_actions:
    - summary: string
      owner_hint: string|null
      status: PROPOSED
```

# Related skills

`incident/lessons-learned`, `incident/recovery-status`, `incident/rca-report`.

# Escalation

N/A directa.

# Manual remediation guidance

N/A directa — las acciones de seguimiento son propuestas, no remediación inmediata.

# Security

Nunca incluye nombres de personas ni atribución individual de responsabilidad.

# Tests

Cubierto transversalmente por `tests/test_incident_lessons_learned.sh`.

# Documentation requirements

Produce `incident-postmortem.md`.

# Change history

v1.0.0 — Fase 11, creación inicial.

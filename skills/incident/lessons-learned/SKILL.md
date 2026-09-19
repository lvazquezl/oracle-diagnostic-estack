---
name: lessons-learned
id: incident/lessons-learned
version: 2.0.0
domain: incident
status: active
---

# Purpose

Extrae lecciones aprendidas reutilizables del incidente (`# 1100`-`# 1112` del prompt de
Fase 11) — patrones para futura `incident/known-error-correlation`, gaps de runbook/playbook,
mejoras de observabilidad — fusionando el rol equivalente que Foundation cubría implícitamente
dentro de `skills/incident/root-cause-analysis.md`.

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Todas.

# Supported architectures

Todas.

# Prerequisites

`incident/post-incident-review` ejecutado.

# Required evidence

- `post_incident_review` completo, `recurrence` (de `incident/recurrence-awareness`).

# Optional evidence

Ninguna adicional.

# Read-only operations

Síntesis de texto local.

# Forbidden operations

Nunca escribe automáticamente en `knowledge/errors/` — la promoción de una lección aprendida al
knowledge base pasa por el flujo `/change` gobernado (`EVOLUTION.md`), nunca automática.

# Decision logic

1. Identificar si el incidente revela un patrón no cubierto por `knowledge/errors/` actual —
   candidato explícito para una futura entrada, propuesto como texto, nunca escrito directamente.
2. Identificar gaps de playbook: ¿el `incident/playbooks` correspondiente cubrió el escenario
   adecuadamente, o faltó un paso?
3. Identificar gaps de observabilidad: ¿qué métrica/alerta habría acelerado la detección o el
   diagnóstico?
4. Las lecciones se presentan como propuestas para revisión humana — nunca aplicadas
   automáticamente al e-stack.

# Normal state

Lecciones aprendidas documentadas, cada una con su justificación trazable al incidente.

# Abnormal patterns

Múltiples incidentes con la misma lección no aplicada — señal fuerte de deuda de proceso.

# False positives

N/A directo.

# Correlation rules

Consume `incident/post-incident-review`, `incident/recurrence-awareness`. Alimenta el proceso
`/change` (Foundation) para evolución futura del e-stack.

# Confidence model

N/A directo — es síntesis cualitativa, no un hallazgo con confidence score.

# Severity

N/A directa.

# Output schema

```yaml
lessons_learned:
  - summary: string
    category: KNOWLEDGE_GAP|PLAYBOOK_GAP|OBSERVABILITY_GAP|PROCESS_GAP
    proposed_action: string
    status: PROPOSED
```

# Related skills

`incident/post-incident-review`, `incident/recurrence-awareness`, `incident/known-error-correlation`.

# Escalation

N/A directa.

# Manual remediation guidance

N/A directa.

# Security

Sin datos sensibles adicionales.

# Tests

`tests/test_incident_lessons_learned.sh`.

# Documentation requirements

Alimenta `incident-lessons-learned.md`.

# Change history

v1.0.0 — Foundation, `skills/incident/root-cause-analysis.md` (lecciones aprendidas era una
responsabilidad implícita del skill único).
v2.0.0 — PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: skill dedicado, con categorización
explícita y flujo de propuesta hacia `/change`, nunca escritura automática al knowledge base.

---
name: classification
id: incident/classification
version: 1.0.0
domain: incident
status: active
---

# Purpose

Clasifica un incidente ya normalizado (`incident/intake`) contra los patrones conocidos de
`docs/INCIDENT_PLAYBOOK_MODEL.md` (CPU saturation, memory pressure, storage exhaustion,
listener/network timeout, RAC node eviction, Data Guard lag spike, RMAN channel exhaustion, FRA
full, account lockout, tablespace pressure) — sin rigidizar el diagnóstico (`# 987`-`# 1004` del
prompt de Fase 11).

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Todas.

# Supported architectures

Todas.

# Prerequisites

`incident/intake` ejecutado.

# Required evidence

- Bloque `incident:` normalizado (`symptoms`, `affected_services`, `affected_targets`).

# Optional evidence

- `known_changes` del intake, cuando disponible.

# Read-only operations

Cálculo local de coincidencia de patrón contra `docs/INCIDENT_PLAYBOOK_MODEL.md`.

# Forbidden operations

Nunca fuerza una clasificación única cuando el patrón no es claro — declara múltiples candidatos o
`UNKNOWN`, nunca uno solo forzado.

# Decision logic

1. Comparar `symptoms`/`affected_services` contra los patrones de incidente conocidos
   (`# 987`-`# 1002` del prompt) — cada coincidencia es un `playbook_match` candidato, nunca una
   clasificación definitiva por sí sola.
2. Un patrón coincidente NO implica automáticamente que ese sea el dominio root cause — sólo guía
   qué `incident/evidence-plan` y qué correlaciones cross-domain priorizar.
3. Si ningún patrón coincide con confianza razonable, clasificar como `UNKNOWN` explícito — nunca
   forzar el patrón más cercano.

# Normal state

Uno o más `playbook_match` candidatos con confianza declarada, o `UNKNOWN` explícito.

# Abnormal patterns

Múltiples patrones con confianza similar — reportado explícitamente como ambigüedad, nunca resuelto
arbitrariamente por el primero encontrado.

# False positives

Clasificar un incidente sólo por la presencia de un código de error conocido, sin considerar el
resto del contexto (afectados, síntomas), es el falso positivo que este skill evita.

# Correlation rules

Consume `incident/intake`. Alimenta `incident/evidence-plan`, `incident/known-error-correlation`.

# Confidence model

`HIGH|MEDIUM|LOW|INSUFFICIENT` por cada `playbook_match` candidato — nunca un valor único sin
explicación.

# Severity

N/A directa — la clasificación no asigna severidad por sí sola.

# Output schema

```yaml
classification:
  candidates:
    - playbook_id: string
      confidence: HIGH|MEDIUM|LOW|INSUFFICIENT
      rationale: string
```

# Related skills

`incident/evidence-plan`, `incident/known-error-correlation`, `incident/hypothesis-generation`.

# Escalation

Ninguna directa.

# Manual remediation guidance

N/A directa.

# Security

Sin datos sensibles.

# Tests

Cubierto transversalmente por `tests/test_incident_intake.sh` y los tests de playbooks
(sección 98) — sin test dedicado adicional en el alcance MVP de Fase 11.

# Documentation requirements

Alimenta `incident-summary.md`.

# Change history

v1.0.0 — Fase 11, creación inicial.

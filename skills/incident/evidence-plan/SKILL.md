---
name: evidence-plan
id: incident/evidence-plan
version: 1.0.0
domain: incident
status: active
---

# Purpose

Genera el plan de evidencia antes de analizar (`docs/INCIDENT_EVIDENCE_MODEL.md#evidence-plan`) —
qué dominios/evidencia son requeridos vs. opcionales, qué falta, en qué orden recolectar, costo
esperado y sensibilidad — nunca se analiza sin este plan explícito primero (`# 374`-`# 389` del
prompt de Fase 11).

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Todas.

# Supported architectures

Todas.

# Prerequisites

`incident/scope-identification` ejecutado.

# Required evidence

- `scope.confirmed_domains`/`candidate_domains` de `incident/scope-identification`.

# Optional evidence

- Evidencia ya cacheada de la sesión (evitar re-planificar recolección ya satisfecha).

# Read-only operations

Cálculo local — nunca ejecuta la recolección en sí, sólo la planifica.

# Forbidden operations

Nunca solicita evidencia "por si acaso" sin atarla a un dominio del scope o una hipótesis
(consistente con `incident/hypothesis-generation`).

# Decision logic

1. Para cada dominio del scope, determinar `required_evidence`/`optional_evidence` según el
   catálogo de collectors ya certificados de ese especialista — nunca inventa un collector nuevo
   (# 65 del prompt: "no duplicar collectors").
2. Verificar qué evidencia ya está cacheada en la sesión (`incident/evidence-correlation`) — se
   marca como satisfecha, nunca vuelve a planificarse su recolección.
3. `missing_evidence` lista lo que aún no está disponible y requeriría activar el especialista
   correspondiente.
4. `collection_order` prioriza evidencia de bajo costo/alta señal primero (mismo criterio que
   `policies/query-cost-policy.md`).
5. `expected_cost`/`sensitivity` se declaran explícitamente por cada ítem del plan — nunca se
   omite el costo de una recolección de `cost_class HIGH`.

# Normal state

Plan completo con `required_evidence` cubierta o con `missing_evidence` explícito y accionable.

# Abnormal patterns

Plan que requiere evidencia de un dominio fuera del scope confirmado — señal de que el scope debe
revisarse (ver `incident/scope-identification`).

# False positives

Planificar recolección de evidencia ya cacheada (duplicando costo/contexto) es el falso positivo
que este skill evita explícitamente.

# Correlation rules

Consume `incident/scope-identification`. Alimenta `incident/evidence-correlation`,
`incident/timeline`.

# Confidence model

`FACT` para el estado de disponibilidad de cada ítem de evidencia (cacheado/faltante).

# Severity

N/A directa.

# Output schema

```yaml
evidence_plan:
  incident_id: string
  required_domains: [string]
  required_evidence: [string]
  optional_evidence: [string]
  missing_evidence: [string]
  collection_order: [string]
  expected_cost: string
  sensitivity: string
```

# Related skills

`incident/scope-identification`, `incident/evidence-correlation`, `incident/timeline`.

# Escalation

`missing_evidence` no resuelta tras solicitar al especialista correspondiente escala como
`evidence_completeness: INSUFFICIENT`/`INVALID` en el RCA final.

# Manual remediation guidance

N/A directa.

# Security

Declara `sensitivity` de cada ítem — nunca solicita evidencia más sensible de la necesaria para la
hipótesis en cuestión.

# Tests

Cubierto transversalmente por `tests/test_incident_intake.sh` y los tests de cross-domain
(sección 97) — sin test dedicado adicional en el alcance MVP de Fase 11.

# Documentation requirements

Alimenta `incident-evidence.md`.

# Change history

v1.0.0 — Fase 11, creación inicial.

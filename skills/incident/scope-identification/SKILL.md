---
name: scope-identification
id: incident/scope-identification
version: 1.0.0
domain: incident
status: active
---

# Purpose

Determina el alcance inicial del incidente (targets/servicios/dominios potencialmente
involucrados) a partir del intake — insumo directo de `incident/evidence-plan` para decidir qué
especialistas de dominio activar, nunca todos por defecto (`# 105` del prompt de Fase 11: routing
mínimo).

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Todas.

# Supported architectures

Todas.

# Prerequisites

`incident/intake` ejecutado.

# Required evidence

- `affected_services`/`affected_targets`/`symptoms` del bloque `incident:`.

# Optional evidence

- `classification.candidates` de `incident/classification`, cuando disponible.

# Read-only operations

Cálculo local.

# Forbidden operations

Nunca activa un dominio sin justificación explícita en el scope — activación mínima siempre.

# Decision logic

1. Mapear `affected_targets`/`affected_services` a los dominios candidatos
   (`oracle-dba-analyst`/`oracle-rac-analyst`/`oracle-asm-storage-analyst`/
   `oracle-dataguard-analyst`/`oracle-multitenant-analyst`/`oracle-backup-recovery-analyst`/
   `oracle-network-analyst`/`oracle-security-analyst`/`os-platform-analyst`/`capacity-analyst`)
   según el Target Profile ya publicado (arquitectura conocida — RAC/ASM/Data Guard/CDB) — nunca
   activa un dominio incompatible con la arquitectura del target (ej. RAC en un standalone).
2. El scope inicial es un punto de partida, no definitivo — `incident/hypothesis-generation` puede
   ampliar el scope si una hipótesis lo requiere (vía escalamiento mínimo, `routing.yaml` del
   agente).

# Normal state

Scope acotado a los dominios con evidencia real de estar afectados o potencialmente relevantes
según el patrón clasificado.

# Abnormal patterns

Scope que activa todos los dominios sin justificación — evitado por diseño (contradice `# 105` del
prompt).

# False positives

Ninguno propio.

# Correlation rules

Consume `incident/intake`, `incident/classification`. Alimenta `incident/evidence-plan`.

# Confidence model

`FACT` para dominios confirmados por `affected_targets`; `HYPOTHESIS` para dominios sugeridos sólo
por el patrón clasificado, no confirmados aún.

# Severity

N/A directa.

# Output schema

```yaml
scope:
  confirmed_domains: [string]
  candidate_domains: [string]
  excluded_domains: [string]
  rationale: string
```

# Related skills

`incident/evidence-plan`, `incident/classification`.

# Escalation

Ninguna directa — el scope se amplía vía `incident/hypothesis-generation` cuando corresponda.

# Manual remediation guidance

N/A directa.

# Security

Sin datos sensibles.

# Tests

`tests/test_incident_scope.sh`.

# Documentation requirements

Alimenta `incident-summary.md`.

# Change history

v1.0.0 — Fase 11, creación inicial.

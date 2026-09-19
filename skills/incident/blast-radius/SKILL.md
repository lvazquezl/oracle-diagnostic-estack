---
name: blast-radius
id: incident/blast-radius
version: 2.0.0
domain: incident
status: active
---

# Purpose

Clasifica el blast radius del incidente (`# 727`-`# 744` del prompt de Fase 11):
`INSTANCE|DATABASE|PDB|RAC_NODE|RAC_CLUSTER|HOST|SERVICE|DATAGUARD_CONFIG|STORAGE|
NETWORK_SEGMENT|MULTIPLE_SYSTEMS|UNKNOWN` — desde evidencia de `affected_targets`/impacto, nunca
sobreestimado ni subestimado sin evidencia.

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Todas.

# Supported architectures

Todas.

# Prerequisites

`incident/impact-analysis` ejecutado.

# Required evidence

- `impact.services`/`databases`/`nodes` normalizados.

# Optional evidence

Ninguna adicional.

# Read-only operations

Cálculo local.

# Forbidden operations

Nunca clasifica `MULTIPLE_SYSTEMS`/`RAC_CLUSTER` (el nivel más amplio) por precaución sin evidencia
— usa `UNKNOWN` cuando el alcance real no está claro, nunca sobreestima.

# Decision logic

1. Determinar el nivel más específico soportado por la evidencia — un incidente confinado a una
   PDB no se reporta como `DATABASE` completa sin evidencia de que otras PDBs también se vieron
   afectadas.
2. `UNKNOWN` es la clasificación correcta cuando la evidencia de scope es insuficiente — nunca se
   fuerza un nivel específico sin esa evidencia.
3. Blast radius puede cambiar durante la investigación (se descubre que afectó más/menos de lo
   inicial) — cada cambio se registra como evento de timeline, nunca sobrescribe silenciosamente.

# Normal state

Blast radius clasificado al nivel más específico soportado por evidencia directa.

# Abnormal patterns

Blast radius `UNKNOWN` sostenido — reportado como limitación de evidencia, nunca oculto.

# False positives

Clasificar `RAC_CLUSTER` completo cuando la evidencia sólo confirma un nodo afectado es el falso
positivo que este skill evita.

# Correlation rules

Consume `incident/impact-analysis`. Alimenta `incident/rca-report`, `incident/post-incident-review`.

# Confidence model

`FACT` cuando hay evidencia directa del alcance; `UNKNOWN` explícito sin ella.

# Severity

N/A directa.

# Output schema

```yaml
blast_radius: INSTANCE|DATABASE|PDB|RAC_NODE|RAC_CLUSTER|HOST|SERVICE|DATAGUARD_CONFIG|STORAGE|NETWORK_SEGMENT|MULTIPLE_SYSTEMS|UNKNOWN
```

# Related skills

`incident/impact-analysis`, `incident/recovery-status`.

# Escalation

Ninguna directa.

# Manual remediation guidance

N/A directa.

# Security

Sin datos sensibles adicionales.

# Tests

`tests/test_incident_blast_radius.sh`.

# Documentation requirements

Alimenta `incident-impact.md`.

# Change history

v1.0.0 — Foundation, `skills/incident/root-cause-analysis.md` (blast radius era responsabilidad
implícita del skill único de Foundation).
v2.0.0 — PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: skill dedicado con la enumeración
completa de 11 niveles de blast radius (`# 727`-`# 744` del prompt), extraído y formalizado.

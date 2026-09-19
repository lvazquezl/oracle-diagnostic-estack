---
name: symptom-clustering
id: incident/symptom-clustering
version: 1.0.0
domain: incident
status: active
---

# Purpose

Agrupa síntomas/eventos relacionados (`same error`/`same subsystem`/`same time window`/
`same target`, `# 953`-`# 965` del prompt de Fase 11) en clusters manejables — sin ocultar
ocurrencias importantes ni colapsar señales distintas en un único cluster artificial.

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Todas.

# Supported architectures

Todas.

# Prerequisites

`incident/evidence-correlation`, `incident/timeline` ejecutados.

# Required evidence

- Timeline y correlaciones ya construidas.

# Optional evidence

Ninguna adicional.

# Read-only operations

Cálculo local (agrupamiento determinístico, no ML opaco).

# Forbidden operations

Nunca oculta una ocurrencia individual relevante dentro de un cluster agregado sin trazabilidad —
cada cluster conserva sus `evidence_ids` completos.

# Decision logic

1. Agrupar eventos por: mismo `error_signature`, mismo subsistema/dominio, misma ventana de
   tiempo, mismo target (`# 957`-`# 962` del prompt).
2. Cada cluster declara sus `symptoms`/`domain`/`evidence_ids` — nunca resume perdiendo la
   trazabilidad a la evidencia individual.
3. Clusters con pocos eventos no se descartan — todo cluster con al menos un evento relevante se
   reporta.

# Normal state

Clusters coherentes por dominio/ventana de tiempo, cada uno trazable a su evidencia.

# Abnormal patterns

Un cluster que mezcla dominios sin relación mecánica aparente — reportado igual (la mezcla puede
ser real), pero señalado como candidato a revisión en `incident/hypothesis-generation`.

# False positives

Colapsar eventos de dominios distintos en un cluster único porque ocurrieron en la misma ventana
temporal, sin considerar mecanismo, es el falso positivo que este skill evita.

# Correlation rules

Consume `incident/evidence-correlation`, `incident/timeline`. Alimenta
`incident/hypothesis-generation`.

# Confidence model

`FACT` para la pertenencia de un evento a un cluster (criterio determinístico); la interpretación
del cluster como síntoma de una causa común es responsabilidad de `incident/hypothesis-generation`.

# Severity

N/A directa.

# Output schema

Ver `output-schema.yaml` del agente — bloque `symptom_clusters`.

# Related skills

`incident/evidence-correlation`, `incident/timeline`, `incident/hypothesis-generation`.

# Escalation

Ninguna directa.

# Manual remediation guidance

N/A directa.

# Security

Sin datos sensibles adicionales.

# Tests

Cubierto transversalmente por los tests de hypothesis generation (sección 93) — sin test dedicado
adicional en el alcance MVP de Fase 11.

# Documentation requirements

Alimenta `incident-findings.md`.

# Change history

v1.0.0 — Fase 11, creación inicial.

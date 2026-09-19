---
name: evidence-correlation
id: incident/evidence-correlation
version: 2.0.0
domain: incident
status: active
---

# Purpose

Correlaciona evidencia cross-domain ya recolectada (`EVD-RAC`, `EVD-OS`, `EVD-NETWORK`,
`EVD-PERFORMANCE`, etc.) por `timestamp`/`target`/`service`/`node`/`error signature`/`resource`/
`change event` (`# 414`-`# 429`, `# 1493`-`# 1507` del prompt de Fase 11) — nunca vuelve a
recolectar si evidencia válida ya existe.

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Todas.

# Supported architectures

Todas.

# Prerequisites

`incident/evidence-plan` ejecutado.

# Required evidence

- `evidence_refs` ya recolectados por los especialistas de dominio del scope.

# Optional evidence

Ninguna adicional — este skill sólo correlaciona lo ya disponible.

# Read-only operations

Cálculo local de correlación (joins por clave temporal/target/servicio/nodo/firma de error).

# Forbidden operations

Nunca re-recolecta evidencia ya cacheada válida en la sesión (`# 106`, `# 429` del prompt).

# Decision logic

1. Indexar cada `evidence_ref` por `timestamp`/`target`/`service`/`node`/`error signature`/
   `resource`/`change event` (`# 1497`-`# 1505` del prompt).
2. Correlacionar evidencia de distintos dominios que comparten clave — la correlación en sí
   nunca implica causalidad (ver `incident/root-cause#correlation-is-not-causation`).
3. Reutilizar el índice ya construido en la sesión antes de reconstruirlo para una nueva pregunta
   sobre el mismo incidente.

# Normal state

Evidencia cross-domain indexada y correlacionada por clave común, disponible para
`incident/timeline`/`incident/hypothesis-generation`.

# Abnormal patterns

Evidencia de dos dominios con la misma clave temporal pero sin relación mecánica plausible —
correlacionada igual (para que la hipótesis la considere), pero nunca presentada como causal por
sí sola.

# False positives

Presentar una correlación de evidencia como si fuera automáticamente una relación causal es el
falso positivo central que este skill (y `incident/root-cause`) evitan en todo el dominio.

# Correlation rules

Consume evidencia de los 10 especialistas de dominio. Alimenta `incident/timeline`,
`incident/symptom-clustering`, `incident/hypothesis-generation`.

# Confidence model

`FACT` para la existencia de la correlación (misma clave); la interpretación causal es
responsabilidad de `incident/hypothesis-generation`/`incident/root-cause`, nunca de este skill.

# Severity

N/A directa.

# Output schema

```yaml
evidence_correlations:
  - key: string                # timestamp|target|service|node|error_signature|resource
    key_type: string
    evidence_refs: [EVD-...]
    domains: [string]
```

# Related skills

`incident/evidence-plan`, `incident/timeline`, `incident/symptom-clustering`,
`incident/hypothesis-generation`.

# Escalation

Ninguna directa.

# Manual remediation guidance

N/A directa.

# Security

Sin exposición nueva — sólo referencias a evidencia ya sanitizada.

# Tests

Cubierto transversalmente por los tests de timeline (sección 92) y traceability (sección 100) —
sin test dedicado adicional en el alcance MVP de Fase 11.

# Documentation requirements

Alimenta `incident-evidence.md`.

# Change history

v1.0.0 — Foundation, `skills/incident/root-cause-analysis.md` (parte del flujo original de
correlación de evidencia, fusionado aquí).
v2.0.0 — PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: skill dedicado de correlación
cross-domain por clave (timestamp/target/service/node/error signature/resource/change event),
extraído y formalizado como paso explícito del pipeline, con reutilización de evidencia cacheada.

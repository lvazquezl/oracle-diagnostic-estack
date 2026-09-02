---
name: root-cause-analysis
id: incident/root-cause-analysis
version: 1.0.0
domain: incident
status: active
---

# Purpose

Aplicar el modelo `SYMPTOM → CONTEXT → EVIDENCE → HYPOTHESES → VALIDATION → RCA → IMPACT → RECOMMENDATION` de forma disciplinada, asegurando que cada afirmación tenga el estado de certeza correcto (`FACT/OBSERVATION/HYPOTHESIS/PROBABLE_CAUSE/CONFIRMED_ROOT_CAUSE/UNDETERMINED`) y nunca se confunda observación con causa.

# Supported Oracle versions

N/A directo — opera sobre hallazgos ya producidos por especialistas de cualquier versión soportada.

# Supported OS/platforms

Todas.

# Supported architectures

Todas — es el skill de síntesis multidominio de `incident-root-cause-analyst`.

# Prerequisites

Requiere al menos un `SYMPTOM` explícito (reportado por el DBA o detectado por un especialista) y el `CONTEXT` de `core/context-discovery` ya resuelto.

# Required evidence

- query_id: N/A directo — consume `evidence_refs` ya producidos por los especialistas de dominio involucrados.

# Optional evidence

- Evidencia adicional puntual solicitada a un especialista específico para validar/descartar una hipótesis (nunca recolección exploratoria sin hipótesis asociada).

# Read-only operations

Ninguna directa — es un skill de correlación y síntesis sobre evidencia ya recolectada.

# Forbidden operations

No ejecuta ninguna acción de contención ni corrección. No cierra un caso con `CONFIRMED_ROOT_CAUSE` sin al menos una validación cruzada explícita.

# Decision logic

1. Registrar el `SYMPTOM` tal como fue reportado, sin interpretarlo todavía.
2. Adjuntar `CONTEXT` (identidad del ambiente) y todos los `evidence_refs` disponibles como `OBSERVATION`.
3. Generar `HYPOTHESES` explícitas, cada una ligada a evidencia que la sustente parcialmente.
4. Para cada hipótesis, definir qué evidencia adicional la confirmaría o descartaría (`VALIDATION` plan).
5. Solicitar esa evidencia puntual al especialista correspondiente (vía el orquestador).
6. Promover una hipótesis a `PROBABLE_CAUSE` sólo si la evidencia de validación es consistente; a `CONFIRMED_ROOT_CAUSE` sólo si hay al menos dos fuentes independientes de evidencia o una prueba temporal inequívoca (el síntoma aparece/desaparece exactamente cuando la causa propuesta aparece/desaparece).
7. Si ninguna hipótesis alcanza `PROBABLE_CAUSE` tras agotar la evidencia razonablemente disponible, cerrar como `UNDETERMINED` explícitamente — nunca forzar una conclusión.
8. Determinar `IMPACT`/blast radius y pasar a `RECOMMENDATION`.

# Confidence model

Aplica literalmente los seis estados del RCA Model (`docs/CONTRACTS.md#rca-model`). Cada finding del Result Package debe declarar su estado individualmente, no sólo un estado global del caso.

# Output schema

```yaml
findings: [...]
hypotheses:
  - statement: string
    state: HYPOTHESIS|PROBABLE_CAUSE|CONFIRMED_ROOT_CAUSE|REJECTED
    evidence_refs: [EVD-...]
    validation_plan: string
confidence: FACT|OBSERVATION|HYPOTHESIS|PROBABLE_CAUSE|CONFIRMED_ROOT_CAUSE|UNDETERMINED
```

# Related skills

`incident/evidence-correlation`, `incident/hypothesis-management`, `incident/timeline-analysis`, `incident/cause-validation`, `incident/blast-radius`.

# Escalation

Si validar una hipótesis requiere evidencia de un dominio no cubierto por los especialistas ya activados, solicita al orquestador activar el especialista correspondiente (activación mínima: sólo el necesario para esa hipótesis).

# Data sensitivity

Hereda la sensibilidad de la evidencia subyacente; no agrega exposición nueva, sólo correlaciona referencias.

# Context budget

Variable según número de hipótesis y dominios; siempre por referencia, reutilizando evidencia ya recolectada antes de pedir más.

# Tests

`tests/test_rca_state_model.sh`, `tests/test_no_forced_conclusions.sh`, `tests/test_evidence_traceability.sh`.

# Documentation requirements

Produce `timeline.md` y `root-cause.md` del análisis/incidente, además de los `findings.md`/`recommendations.md` estándar.

# Evolution via `/change`

Cambios al modelo de estados en sí (los seis estados) requieren `/change policy` (impacta `docs/CONTRACTS.md#rca-model` globalmente, no sólo este skill).

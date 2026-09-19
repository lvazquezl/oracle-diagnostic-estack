---
name: root-cause
id: incident/root-cause
version: 2.0.0
domain: incident
status: active
---

# Purpose

Produce el Root Cause Model final (`docs/INCIDENT_ROOT_CAUSE_MODEL.md`) aplicando el modelo de
estados `FACT → OBSERVATION → HYPOTHESIS → PROBABLE_CAUSE → CONFIRMED_ROOT_CAUSE`, con
`UNDETERMINED`/`INCONCLUSIVE`/`INSUFFICIENT_EVIDENCE` como salidas legítimas — nunca se fuerza una
conclusión (`docs/CONTRACTS.md#rca-model`, `# 46`, `# 62` del prompt de Fase 11). Fusiona
íntegramente la lógica original de `incident/root-cause-analysis.md` (Foundation).

# Supported Oracle versions

N/A directo — opera sobre hallazgos ya producidos por especialistas de cualquier versión
soportada.

# Supported OS/platforms

Todas.

# Supported architectures

Todas — es el skill de síntesis multidominio de `incident-root-cause-analyst`.

# Prerequisites

`incident/hypothesis-testing`, `incident/contradiction-analysis` ejecutados; al menos un
`SYMPTOM` explícito y el `CONTEXT` de `core/context-discovery` ya resuelto.

# Required evidence

- Hipótesis con `status`/`confidence` evaluados y contradicciones resueltas/declaradas.

# Optional evidence

- Evidencia adicional puntual solicitada para la validación final de la hipótesis candidata a
  root cause.

# Read-only operations

Ninguna directa — es un skill de correlación y síntesis sobre evidencia ya recolectada.

# Forbidden operations

No ejecuta ninguna acción de contención ni corrección. No cierra un caso con `CONFIRMED_ROOT_CAUSE`
sin al menos una validación cruzada explícita.

# Symptom vs. cause

`ORA-12537` no es automáticamente root cause (`# 352`-`# 371` del prompt) — es un `SYMPTOM`. Este
skill mantiene estrictamente separados: `SYMPTOM`, `CONDITION`, `CONTRIBUTING_FACTOR`,
`ROOT_CAUSE`, `IMPACT` — nunca colapsados en una sola afirmación.

# Correlation is not causation

La proximidad temporal sola nunca es prueba de causalidad (`# 71`, `# 1509`-`# 1526` del prompt).
Se exige: mecanismo plausible, evidencia de soporte, y ausencia de una contradicción más fuerte.
Un `causal_chain` explícito conecta cada eslabón (ej. "network path instability → RAC interconnect
packet loss → cluster communication degradation → node eviction → service disruption",
`# 665`-`# 678` del prompt) — nunca un salto directo de alerta a root cause.

## Root cause confirmation rule

No marcar `CONFIRMED_ROOT_CAUSE`/`CONFIRMED` si faltan evidencias críticas (`# 1030`-`# 1052` del
prompt). En ese caso, usar `MOST_LIKELY`/`PROBABLE` o `INSUFFICIENT_EVIDENCE`/`INCONCLUSIVE` según
el output schema. `CONFIRMED` requiere al menos dos fuentes de evidencia independientes o una
prueba temporal inequívoca (el síntoma aparece/desaparece exactamente cuando la causa propuesta
aparece/desaparece) — heredado literalmente del modelo Foundation.

# Decision logic

1. Registrar el `SYMPTOM` tal como fue reportado, sin interpretarlo todavía.
2. Adjuntar `CONTEXT` y todos los `evidence_refs` disponibles como `OBSERVATION`.
3. Consumir las `HYPOTHESES` ya generadas y probadas (`incident/hypothesis-testing`), cada una
   ligada a evidencia que la sustente parcialmente.
4. Promover una hipótesis a `PROBABLE_CAUSE` sólo si la evidencia de validación es consistente; a
   `CONFIRMED_ROOT_CAUSE` sólo si cumple la regla de confirmación de arriba.
5. Si ninguna hipótesis alcanza `PROBABLE_CAUSE` tras agotar la evidencia razonablemente
   disponible, cerrar como `UNDETERMINED`/`INCONCLUSIVE` explícitamente — nunca forzar una
   conclusión.
6. Construir el `causal_chain` explícito para la causa confirmada/probable — nunca dejar el salto
   implícito.
7. Soportar `PRIMARY_ROOT_CAUSE`/`SECONDARY_ROOT_CAUSE`/`CONTRIBUTING_FACTOR` cuando haya
   causalidad compuesta (`# 1056`-`# 1066` del prompt) — nunca fuerza una única causa cuando la
   evidencia sostiene varias.
8. `alternatives_rejected` documenta las hipótesis descartadas y por qué — nunca se omiten
   silenciosamente del reporte final.

# Normal state

`root_cause.completeness: CONFIRMED` o `PROBABLE` con `causal_chain` completo y
`alternatives_rejected` documentado.

# Abnormal patterns

`INCONCLUSIVE`/`INSUFFICIENT_EVIDENCE` — reportado explícitamente como resultado legítimo, nunca
oculto ni disfrazado de una conclusión más fuerte de la que la evidencia sostiene.

# False positives

Confirmar una causa basándose únicamente en que "restart del listener restauró el servicio" sin
evidencia directa del mecanismo de falla es el falso positivo central que este skill evita
(`# 1685`-`# 1699` del prompt — ver `incident/recovery-status#recovery-action-not-root-cause`).

# Correlation rules

Consume `incident/hypothesis-testing`, `incident/contradiction-analysis`,
`incident/change-correlation`. Alimenta `incident/contributing-factors`, `incident/rca-report`,
`incident/manual-remediation-plan`.

# Confidence model

Aplica literalmente los seis estados del RCA Model (`docs/CONTRACTS.md#rca-model`):
`FACT|OBSERVATION|HYPOTHESIS|PROBABLE_CAUSE|CONFIRMED_ROOT_CAUSE|UNDETERMINED`. Cada finding del
Result Package declara su estado individualmente, no sólo un estado global del caso. El
`completeness` del RCA (`CONFIRMED|PROBABLE|INCONCLUSIVE|INSUFFICIENT_EVIDENCE`) es un campo
adicional que resume el estado global sin colapsar el detalle por finding.

# Severity

Heredada de `incident/severity-awareness`; el root cause en sí no re-determina severidad.

# Output schema

```yaml
root_cause:
  rca_id: string|null
  incident_id: string
  statement: string|null
  causal_chain: [string]
  evidence_ids: [EVD-...]
  confidence: FACT|OBSERVATION|HYPOTHESIS|PROBABLE_CAUSE|CONFIRMED_ROOT_CAUSE|UNDETERMINED
  completeness: CONFIRMED|PROBABLE|INCONCLUSIVE|INSUFFICIENT_EVIDENCE
  alternatives_rejected: [string]
  limitations: [string]
```

# Related skills

`incident/hypothesis-testing`, `incident/contradiction-analysis`, `incident/contributing-factors`,
`incident/impact-analysis`, `incident/rca-report`.

# Escalation

Si validar una hipótesis requiere evidencia de un dominio no cubierto por los especialistas ya
activados, solicita al orquestador activar el especialista correspondiente (activación mínima:
sólo el necesario para esa hipótesis). Si tras agotar la evidencia disponible ninguna hipótesis
alcanza `PROBABLE_CAUSE`, cierra como `INCONCLUSIVE`/`UNDETERMINED` y lo declara explícitamente —
no fuerza una conclusión.

# Manual remediation guidance

Root cause confirmado/probable con recomendación accionable escala a `incident/manual-remediation-plan`
y, eventualmente, a `change-advisor` — nunca ejecuta la corrección directamente.

# Data sensitivity

Hereda la sensibilidad de la evidencia subyacente; no agrega exposición nueva, sólo correlaciona
referencias.

# Context budget

Variable según número de hipótesis y dominios; siempre por referencia, reutilizando evidencia ya
recolectada antes de pedir más.

# Tests

`tests/test_incident_root_cause.sh`, `tests/test_incident_root_cause_confidence.sh`,
`tests/test_incident_no_false_confirmation.sh`, `tests/test_incident_multiple_root_causes.sh`.

# Documentation requirements

Produce `incident-root-cause.md`, además de los `incident-findings.md`/`incident-remediation.md`
estándar.

# Evolution via `/change`

Cambios al modelo de estados en sí (los seis estados del RCA Model) requieren `/change policy`
(impacta `docs/CONTRACTS.md#rca-model` globalmente, no sólo este skill).

# Change history

v1.0.0 — Foundation, `skills/incident/root-cause-analysis.md` — modelo
`SYMPTOM → CONTEXT → EVIDENCE → HYPOTHESES → VALIDATION → RCA → IMPACT → RECOMMENDATION`, seis
estados de certeza, regla de confirmación cruzada (dos fuentes independientes o prueba temporal).
v2.0.0 — PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: fusiona v1.0.0 como núcleo del
Root Cause Model; agrega `causal_chain` explícito, `completeness`
(`CONFIRMED|PROBABLE|INCONCLUSIVE|INSUFFICIENT_EVIDENCE`), soporte de causas múltiples
(`PRIMARY_ROOT_CAUSE`/`SECONDARY_ROOT_CAUSE`/`CONTRIBUTING_FACTOR`), y la disciplina explícita
"correlation is not causation" con reglas de causalidad documentadas.

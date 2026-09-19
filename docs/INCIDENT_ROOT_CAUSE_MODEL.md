# Incident Root Cause Model — Fase 11

Extiende `docs/CONTRACTS.md#rca-model` (preservado verbatim desde Foundation) con los campos
adicionales introducidos en Fase 11.

## Escala de confianza (Foundation, preservada)

```text
FACT → OBSERVATION → HYPOTHESIS → PROBABLE_CAUSE → CONFIRMED_ROOT_CAUSE
```

`UNDETERMINED` es un estado terminal legítimo — nunca se fuerza una conclusión bajo presión de
"es un incidente" (`workflows/incident.md#stop-conditions`).

## Regla de confirmación (Foundation, preservada)

`CONFIRMED_ROOT_CAUSE` requiere **una de las dos**:

1. Dos fuentes de evidencia independientes que apunten al mismo mecanismo causal, o
2. Prueba temporal inequívoca — el síntoma aparece/desaparece exactamente cuando la causa
   propuesta aparece/desaparece.

## Campos adicionales (Fase 11)

```yaml
root_cause:
  id: RCA-...
  statement: string
  causal_chain: [string]          # nunca un salto directo alerta→causa
  completeness: CONFIRMED|PROBABLE|INCONCLUSIVE|INSUFFICIENT_EVIDENCE
  confidence: HIGH|MEDIUM|LOW|INSUFFICIENT
  confidence_score: float|null    # 0.0-1.0, siempre acompañado de explanation si se provee
  confidence_explanation: string|null
  evidence_ids: [EVD-...]
  hypothesis_id: HYP-...
```

## Múltiples causas raíz

Un incidente puede tener más de una `CONFIRMED_ROOT_CAUSE` — nunca se fuerza una única causa
cuando la evidencia soporta varias independientes (`tests/test_incident_multiple_root_causes.sh`).

## Contributing factors

Separados estructuralmente de `root_cause` — nunca mezclados en la misma lista. Ver
`docs/INCIDENT_CAUSALITY_MODEL.md#symptom--condition--contributing-factor--root-cause--impact`.

## Reproducibilidad

`incident/rca-report` lista TODAS las hipótesis evaluadas (incluidas las rechazadas, con su
razón) para que otro analista pueda seguir el mismo razonamiento con la misma evidencia —
"RCA MUST BE REPRODUCIBLE" (non-negotiable del prompt de Fase 11).

## Referencias

`docs/CONTRACTS.md#rca-model`, `docs/INCIDENT_CAUSALITY_MODEL.md`,
`docs/INCIDENT_HYPOTHESIS_MODEL.md`, `skills/incident/root-cause/SKILL.md`,
`skills/incident/rca-report/SKILL.md`.

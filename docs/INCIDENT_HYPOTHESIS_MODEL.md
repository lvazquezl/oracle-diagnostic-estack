# Incident Hypothesis Model — Fase 11

## Ciclo de vida de una hipótesis

```text
OPEN → SUPPORTED → CONFIRMED
OPEN → SUPPORTED → WEAKENED → REJECTED
OPEN → INSUFFICIENT_EVIDENCE
```

`REJECTED`/`WEAKENED`/`INSUFFICIENT_EVIDENCE` son resultados legítimos — nunca ocultados del
reporte final (`incident/rca-report` los lista siempre, junto con la razón).

## Generación

`incident/hypothesis-generation` genera candidatas desde: síntomas, timeline, evidencia
cross-domain, known errors, cambios recientes. Aplica un límite Top-N
(`incident.max_hypotheses` del Target Profile, default recomendado 5) — nunca decenas de
hipótesis irrelevantes.

## Testing / Ranking

`incident/hypothesis-testing` evalúa cada hipótesis contra: fuerza de evidencia, consistencia
temporal, plausibilidad mecanística, consistencia cross-domain, cantidad de contradicciones,
evidencia crítica faltante — nunca un ranking basado únicamente en la primera hipótesis generada.

## Contradicción

`incident/contradiction-analysis` identifica evidencia que debilita/refuta una hipótesis
específica (ejemplo verbatim del prompt: contradicción de latencia de storage) — una hipótesis
con contradicción no resuelta nunca alcanza `CONFIRMED`.

## Regla de confirmación

Una hipótesis sólo alcanza `status: CONFIRMED` cuando el `root_cause` correspondiente cumple la
regla del Root Cause Model (`docs/INCIDENT_ROOT_CAUSE_MODEL.md`) — 2 fuentes de evidencia
independientes o prueba temporal inequívoca.

## Confidence

`HIGH|MEDIUM|LOW|INSUFFICIENT`, con score opcional 0.0–1.0 siempre acompañado de explicación —
nunca un número sin justificación textual.

## Referencias

`skills/incident/hypothesis-generation/SKILL.md`, `skills/incident/hypothesis-testing/SKILL.md`,
`skills/incident/contradiction-analysis/SKILL.md`, `docs/INCIDENT_ROOT_CAUSE_MODEL.md`.

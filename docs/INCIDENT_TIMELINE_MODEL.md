# Incident Timeline Model — Fase 11

## Normalización temporal

Todos los timestamps se normalizan a UTC, con `source_timestamp` siempre preservado para
auditoría — nunca se descarta el timestamp original de la fuente.

## Tipos de evento

```text
SYMPTOM_OBSERVED
ALERT_TRIGGERED
CONFIG_CHANGE
CAPACITY_EVENT
RECOVERY
INVESTIGATION_STEP
```

## Clock skew

Fuentes de desfase reconocidas: NTP drift, host clock skew, source timestamp delay, monitoring
ingestion delay. Detectado y marcado explícitamente vía `TIMELINE_CONFIDENCE_DEGRADED` — nunca
"corregido" silenciosamente (ver `incident/os-correlation`, `incident/timeline`).

## Ordenamiento y duplicados

`incident/timeline` ordena eventos por timestamp normalizado, deduplicando eventos idénticos de
múltiples fuentes (mismo evento reportado por dos collectors) sin perder la referencia a cada
fuente original.

## Ventana de evidencia

Configurable vía `docs/TARGET_PROFILE.md#schema` (bloque `incident.evidence_window`) — sin
declaración, `incident/evidence-plan` usa el default documentado en
`agents/incident-root-cause-analyst/AGENT.md`, nunca una ventana arbitraria sin trazabilidad.

## Change correlation window

Ventana separada para correlacionar cambios conocidos (`incident.change_correlation`,
`incident/change-correlation`) — distinta de la ventana de evidencia general, porque un cambio
puede ser relevante fuera de la ventana de evidencia inmediata.

## Granularidad

`incident.timeline_granularity` (Target Profile) — sin declaración, `incident/timeline` reporta
con la granularidad real de cada fuente, nunca normaliza a una resolución no declarada.

## Referencias

`skills/incident/timeline/SKILL.md`, `skills/incident/change-correlation/SKILL.md`,
`skills/incident/os-correlation/SKILL.md`, `docs/TARGET_PROFILE.md#schema`.

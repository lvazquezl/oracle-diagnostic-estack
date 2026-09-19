# Incident Intake Model — Fase 11

## Identificador

`INC-YYYYMMDD-NNN` — mismo esquema que `ANA-YYYYMMDD-NNN`, generado al registrar el incidente
(`incident/intake`).

## Campos mínimos de intake

```yaml
incident:
  id: INC-YYYYMMDD-NNN
  reported_by: string|null        # nunca identidad completa sin necesidad — TOKENIZE por defecto
  reported_at: ISO-8601
  symptom_description: string      # texto libre del DBA, nunca reinterpretado sin marcar la reinterpretación
  target_id: string                 # referencia local, nunca connection string
  approx_start_window: ISO-8601|null
  status: OPEN|INVESTIGATING|RESOLVED|CLOSED
```

## Severidad configurable

Ver `docs/TARGET_PROFILE.md#schema` (bloque `incident.severity_model`) —
`incident/severity-awareness` nunca inventa un esquema corporativo no declarado; sin
`severity_model`, usa el modelo por defecto documentado en `agents/incident-root-cause-analyst/AGENT.md`.

## Regla de re-discovery obligatorio

`oracle-discovery-analyst` se re-ejecuta siempre al abrir un incidente, incluso con cache válido —
un incidente puede coincidir con un cambio de topología/rol no reportado (`workflows/incident.md#gates`).

## Clasificación inicial

`incident/classification` mapea el síntoma reportado a uno o más dominios candidatos
(`incident/scope-identification`), nunca activa todos los especialistas por defecto — el mínimo
conjunto necesario para la primera hipótesis.

## Referencias

`skills/incident/intake/SKILL.md`, `skills/incident/classification/SKILL.md`,
`skills/incident/severity-awareness/SKILL.md`, `skills/incident/scope-identification/SKILL.md`,
`docs/CONTRACTS.md#rca-model`.

# Incident Impact Model — Fase 11

## Campos de impacto

```yaml
impact:
  technical: string|null
  services: [string]|null
  databases: [string]|null
  nodes: [string]|null
  users_affected: int|null          # nunca inventado sin evidencia directa de conteo
  duration_minutes: int|null        # calculado desde el timeline (detected_at → resolved_at)
  data_loss: bool|null              # null salvo evidencia directa, nunca false por defecto
  performance_degradation: string|null
  availability: string|null
```

Cada campo sin evidencia directa queda `null` explícito — nunca un valor estimado sin
trazabilidad (`incident/impact-analysis`).

## Blast Radius

Clasificación al nivel más específico soportado por evidencia:

```text
INSTANCE | DATABASE | PDB | RAC_NODE | RAC_CLUSTER | HOST | SERVICE |
DATAGUARD_CONFIG | STORAGE | NETWORK_SEGMENT | MULTIPLE_SYSTEMS | UNKNOWN
```

`UNKNOWN` es la clasificación correcta cuando la evidencia de alcance es insuficiente — nunca se
sobreestima (`incident/blast-radius`).

## Recovery Status

```text
RECOVERED | PARTIALLY_RECOVERED | STABLE_WITH_RISK | NOT_RECOVERED | UNKNOWN
```

`STABLE_WITH_RISK`: el síntoma cesó pero la causa raíz no fue confirmada/atendida — nunca
presentado como `RECOVERED` completo (`incident/recovery-status`).

## Mitigation / Fix Model

```text
MITIGATION       # alivia el síntoma temporalmente
TEMPORARY_FIX     # resuelve el síntoma sin atacar la causa
PERMANENT_FIX      # resuelve la causa confirmada
WORKAROUND         # evita el síntoma sin resolverlo
```

Nunca mezclados en una sola categoría — cada acción tomada se clasifica explícitamente.

## Referencias

`skills/incident/impact-analysis/SKILL.md`, `skills/incident/blast-radius/SKILL.md`,
`skills/incident/recovery-status/SKILL.md`.

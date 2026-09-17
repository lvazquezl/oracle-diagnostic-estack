# Capacity Common Metric Model — Fase 10

## Principio

El reporte de capacidad debe permitir comparar tecnologías (Oracle, Linux, Windows, SQL Server,
VMware) sin cambiar la lógica básica. Ninguna fórmula distinta por tecnología salvo razón técnica
documentada explícitamente (`# 148`-`# 168` del prompt de Fase 10).

## Modelo común

```text
CAPACITY DOMAIN
    ↓
TOTAL
USED
AVAILABLE
UTILIZATION
TREND
FORECAST
THRESHOLD
RISK
RECOMMENDATION
```

## capacity_metric

```yaml
capacity_metric:
  target_id: string
  technology: string
  resource_type: string
  metric_name: string
  timestamp: string
  total_capacity: number|null
  used_capacity: number|null
  available_capacity: number|null
  utilization_percent: number|null
  unit: string
  source_id: string
  evidence_id: string
  quality: GOOD|ACCEPTABLE|DEGRADED|INSUFFICIENT|INVALID
```

Ver `skills/capacity/normalization/SKILL.md` para el skill que produce este modelo.

## Ecuaciones base

```text
available = total - used
utilization_percent = used / total * 100
```

Si `total <= 0` → `INVALID_CAPACITY_INPUT`, nunca se divide silenciosamente (`# 394`-`# 406` del
prompt).

## Unidades

```text
CPU      → cores / percentage
Memory   → bytes / GiB
Storage  → bytes / GiB / TiB
```

Nunca mezclar GB decimal con GiB binario sin normalización explícita (`# 358`-`# 377` del prompt).

## Campos mínimos comunes del reporte

```text
TOTAL_CAPACITY
USED_CAPACITY
AVAILABLE_CAPACITY
UTILIZATION_PERCENT
TREND
FORECAST_1M
FORECAST_3M
FORECAST_6M
THRESHOLD_DATE
CONFIDENCE
DATA_QUALITY
```

## Minimum metrics policy

El MVP funciona con `CPU total/allocated + CPU used/utilization`, `Memory total + memory used`,
`Storage total + storage used`. Si falta uno, el reporte declara `PARTIAL_CAPACITY_ASSESSMENT` —
nunca bloquea el resto (`# 1407`-`# 1424` del prompt).

## Consistencia entre tecnologías

El mismo esquema se usa para Oracle, Linux, Windows, SQL Server, VMware — aunque algunas métricas
queden `NOT_APPLICABLE`/`NOT_AVAILABLE`/`PARTIALLY_SUPPORTED` (`# 1939`-`# 1957` del prompt).

## Referencias

`skills/capacity/normalization/SKILL.md`, `skills/capacity/cpu/SKILL.md`,
`skills/capacity/memory/SKILL.md`, `skills/capacity/storage/SKILL.md`,
`docs/CAPACITY_DATA_SOURCE_MODEL.md`.

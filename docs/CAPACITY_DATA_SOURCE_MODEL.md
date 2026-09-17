# Capacity Data Source Model — Fase 10

## Principio

No se asume que todas las fuentes estarán conectadas en esta fase. Cada fuente declara su estado
real, nunca inventado (`# 281`-`# 306` del prompt de Fase 10).

## Fuentes conocidas

```text
Site24x7
Prophecy
Reporting Services
Polling local
Evidencia diagnóstica Oracle (oracle-dba-analyst/oracle-asm-storage-analyst/oracle-backup-recovery-analyst)
Evidencia OS Platform (os-platform-analyst, Fase 9)
Telemetría VMware
Telemetría SQL Server
```

## Estados

```text
CONNECTED
AVAILABLE_OFFLINE
MANUAL_IMPORT
NOT_CONFIGURED
NOT_CERTIFIED
```

## Source Adapter Contract

```yaml
source:
  source_id: string
  type: Site24x7|Prophecy|ReportingServices|LocalPolling|OracleEvidence|OSEvidence|VMwareTelemetry|SQLServerTelemetry
  scope: string
  technology: string
  metric_mapping: {string: string}
  timestamp_semantics: string
  sampling_interval: string
  timezone: string
  aggregation_level: string
  missing_data_behavior: string
  units: string
  validation_status: DOCUMENTATION_VALIDATED|FIXTURE_VALIDATED|LAB_VALIDATED|RUNTIME_VALIDATED
  read_only: true
```

`read_only: true` es un campo fijo — ningún adapter permite escribir o reconfigurar la herramienta
de monitoreo (`# 310`-`# 331` del prompt).

## Estado en Fase 10 (MVP)

| Fuente | Estado típico | Nota |
|---|---|---|
| Evidencia diagnóstica Oracle | `CONNECTED` | Vía `oracle-dba-analyst`/`oracle-asm-storage-analyst`/`oracle-backup-recovery-analyst`, ya certificada. |
| Evidencia OS Platform | `CONNECTED` | Vía `os-platform-analyst` (Fase 9), ya certificada. |
| Site24x7 / Prophecy / Reporting Services | `NOT_CONFIGURED`/`AVAILABLE_OFFLINE` | Adapter diseñado, sin conectividad runtime certificada en esta fase — declarado explícitamente, nunca asumido conectado. |
| Telemetría VMware | `NOT_CERTIFIED` | Contract diseñado (`capacity/vmware`), sin collector runtime — disponible sólo vía `MANUAL_IMPORT`. |
| Telemetría SQL Server | `NOT_CERTIFIED` | Contract diseñado (`capacity/sqlserver`), sin collector runtime — disponible sólo vía `MANUAL_IMPORT`. |

## Source priority / reconciliation

```yaml
capacity:
  source_priority:
    cpu:
    memory:
    storage:
```

Si la misma métrica existe en varias fuentes, **nunca se promedia automáticamente** —
`preferred_source`/`secondary_source`/`reconciliation_rule` declarados explícitamente. Conflicto
fuera de tolerancia → `SOURCE_CONFLICT`, nunca ocultado (`# 1167`-`# 1206` del prompt). Ver
`skills/capacity/data-source-inventory/SKILL.md`, `skills/capacity/capacity-assessment/SKILL.md`.

## Referencias

`docs/CAPACITY_COMMON_METRIC_MODEL.md`, `docs/CAPACITY_DATA_QUALITY_MODEL.md`.

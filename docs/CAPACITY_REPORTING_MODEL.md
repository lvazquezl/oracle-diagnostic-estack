# Capacity Reporting Model — Fase 10

## Principio

Markdown-first. Reporte técnico completo, resumen ejecutivo que prioriza valor de decisión sobre
relleno (`# 1762`-`# 1804`, `# 106` del prompt de Fase 10: "capacity reports prioritize decision
value over filler").

## Reporte técnico

```text
Scope
Sources
Data Quality
Current Capacity
CPU
Memory
Storage
Oracle
ASM
Tablespaces
VMware
SQL Server
Trends
Forecast 1/3/6m
Thresholds
Horizontal/Vertical Analysis
Risks
Recommendations
Evidence
```

## Resumen ejecutivo

Debe responder: `What is at risk? When? Why? Confidence? What action should be planned?` —
evitando relleno (`# 1792`-`# 1804` del prompt). Ver `skills/capacity/executive-summary/SKILL.md`.

## Tabla de capacidad

```text
Resource | Current | 1M | 3M | 6M | Threshold Date | Risk | Confidence
```

## Top risks

Ordenados por: criticality, time-to-threshold, forecast confidence, resource impact (`# 1818`-
`# 1827` del prompt).

## Quarterly / semiannual mode

```text
/assessment capacity --period quarterly
/assessment capacity --period semiannual
```

(`# 1926`-`# 1936` del prompt) — determina la ventana de comparación para change detection, nunca
altera la metodología de cálculo.

## Change detection

Comparación con assessment previo cuando exista: trend acceleration, risk change, threshold-date
movement, capacity event (`# 1906`-`# 1923` del prompt).

## Consistencia entre tecnologías

El mismo esquema se usa para Oracle/Linux/Windows/SQL Server/VMware, aunque algunas métricas
queden `NOT_APPLICABLE`/`NOT_AVAILABLE`/`PARTIALLY_SUPPORTED` (`# 1939`-`# 1957` del prompt).

## Documentos generados por análisis

```text
capacity-summary.md
capacity-data-quality.md
capacity-cpu.md
capacity-memory.md
capacity-storage.md
capacity-oracle.md
capacity-asm.md
capacity-forecast.md
capacity-thresholds.md
capacity-risk.md
capacity-plan.md
```

(`# 2020`-`# 2036` del prompt).

## Alert / watch integration

No se implementa monitoring activo todavía — pueden producirse recomendaciones para futuros
watches (threshold approaching, forecast changed materially, data source stale) sin crear
automatización runtime dentro del e-stack (`# 1890`-`# 1902` del prompt).

## Implementación ejecutable / Workflow Integration Status

**PHASE 10 — FORECASTING EXECUTION & NUMERICAL VALIDATION HARDENING** (# 9, # 12 del prompt de
hardening): distingue explícitamente entre el contrato de reporting de arriba y lo que hoy es
runtime real:

| Componente | Estado |
|---|---|
| `capacity_engine/report.py#render_capacity_table` — tabla de capacidad con números de un `ForecastResult` real | `LOCAL_RUNTIME_TESTED` |
| `capacity_engine/cli.py` — adaptador local fixture→motor→JSON→Markdown | `LOCAL_RUNTIME_TESTED` (`tests/test_capacity_engine_end_to_end.sh`) |
| `/healthcheck capacity`, `/assessment capacity` (orquestación de agente vivo) | `CONTRACT_ONLY` / `NOT_RUNTIME_CERTIFIED` — depende del MCP Gateway, fuera de alcance hasta esa fase |
| El resto de la tabla técnica (Sources/Data Quality/CPU/Memory/Storage/Oracle/ASM/...) | `CONTRACT_DEFINED` en los skills `capacity/*`, ejecutable hoy sólo para el resultado numérico que `capacity_engine` produce — la integración multi-tecnología completa sigue siendo contrato |

Nunca se declara `CONNECTED`/`SUPPORTED` en runtime para un adaptador que sólo tiene contrato — ver
`docs/CAPACITY_DATA_SOURCE_MODEL.md`.

## Referencias

`skills/capacity/capacity-healthcheck/SKILL.md`, `skills/capacity/capacity-assessment/SKILL.md`,
`skills/capacity/executive-summary/SKILL.md`,
`docs/PHASE_10_FORECASTING_EXECUTION_NUMERICAL_VALIDATION_HARDENING.md`.

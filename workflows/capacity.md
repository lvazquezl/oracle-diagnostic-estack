---
name: capacity
version: 2.0.0
status: active
---

# Trigger/intent

Comando `/capacity`. Forecast de headroom/riesgo para uno o varios recursos a horizonte de 1/3/6
meses — versión acotada/rápida del flujo completo de `capacity-analyst` (Fase 10), para cuando el
DBA ya sabe qué recurso puntual quiere proyectar y no necesita el reporte transversal completo de
`/healthcheck capacity`/`/assessment capacity` (ver `docs/PHASE_10_CAPACITY_MANAGEMENT_FORECASTING.md`).

# Prerequisites

Target identificado; `constraints.horizon_months` explícito (default 3 si no se indica).

# Discovery requirements

`oracle-discovery-analyst` obligatorio si no hay cache válido.

# Minimum agents

`oracle-operations-orchestrator`, `capacity-analyst`.

# Optional agents

`oracle-dba-analyst` (tablespaces/UNDO/TEMP si no hay evidencia reciente cacheada), `oracle-asm-storage-analyst` (ASM), `os-platform-analyst` (CPU/memoria/filesystem), `oracle-backup-recovery-analyst` (FRA/archive).

# Activation conditions

`capacity-analyst` primero intenta reutilizar `evidence_refs` ya recolectada en la sesión/análisis (ver `docs/CONTRACTS.md#context-token-model`); sólo activa el especialista de dominio correspondiente si no hay evidencia reciente reutilizable para el recurso solicitado.

# Skills

`capacity/data-source-inventory`, `capacity/data-quality`, `capacity/normalization`,
`capacity/trend-analysis`, `capacity/growth-rate`, `capacity/forecasting`,
`capacity/threshold-crossing`, `capacity/confidence`, `capacity/risk-classification`, más el skill
de recurso correspondiente (`capacity/cpu`/`capacity/memory`/`capacity/storage`/`capacity/oracle`/
`capacity/asm`/`capacity/tablespace`/`capacity/os`/`capacity/linux`/`capacity/windows`/
`capacity/vmware`/`capacity/sqlserver`) — reemplaza el modelo Foundation (`capacity/trending`,
`capacity/forecast`, `capacity/headroom`, `capacity/risk`, ninguno materializado salvo
`capacity/forecast`, absorbido en `capacity/forecasting` v2.0.0). Los skills de recurso consumen
`oracle/tablespaces`/`asm/capacity`/`os/*` por referencia (`evidence_refs`), nunca los
re-recolectan.

# Evidence required

`Q-CAP-TIMESERIES-001` para el/los recurso(s) solicitado(s); reutiliza evidencia existente cuando es posible.

# Stop conditions

Histórico insuficiente para el horizonte solicitado — se declara y se ofrece el horizonte máximo soportado por la evidencia disponible.

# Confidence threshold

El forecast declara siempre `confidence: HIGH|MEDIUM|LOW|INSUFFICIENT` con razón explícita (nunca
un número aislado) — ver `skills/capacity/confidence/SKILL.md`. `RISK: HIGH` + `CONFIDENCE: LOW`
es un resultado válido y esperado; nunca se produce un forecast desde historia insuficiente sin
declarar `confidence: INSUFFICIENT` explícitamente.

# Escalation

Riesgo `HIGH`/`CRITICAL` escala a `change-advisor`.

# Documentation output

`analysis/ANA-YYYYMMDD-NNN/recommendations.md` con tabla de headroom/riesgo por recurso y horizonte.

# Token/context budget

Bajo si reutiliza evidencia; medio si requiere recolección nueva acotada por horizonte.

# Security constraints

READ-ONLY ALWAYS.

# Gates

```yaml
gates:
  version:      config/capability-matrix.yaml → Capacity es SUPPORTED 10g-23ai (Fase 10); no depende de version para su propia lógica, sí la hereda del recurso subyacente evaluado
  architecture: el especialista de dominio subyacente (oracle-dba-analyst/oracle-asm-storage-analyst/os-platform-analyst) sólo se activa si la arquitectura del recurso solicitado aplica (ej. asm sólo si storage_mode=asm)
  environment:  target debe estar en config/allowed-targets.local.yaml
  license:      no aplica directamente — capacity-analyst no depende de features licenciadas
  privilege:    ESTACK_DIAGNOSTIC_ROLE debe alcanzar para el histórico solicitado (Q-CAP-TIMESERIES-001)
  security:     ninguna query requerida puede tener risk_class fuera de R0
  cost:         Q-CAP-TIMESERIES-001 es cost_class MEDIUM, con horizon_months acotando la ventana solicitada
  evidence:     reutiliza evidence_refs ya recolectada en la sesión antes de solicitar histórico nuevo
```

---
name: capacity
version: 1.0.0
status: active
---

# Trigger/intent

Comando `/capacity`. Forecast de headroom/riesgo para uno o varios recursos a horizonte de 1/3/6 meses.

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

`capacity/trending`, `capacity/forecast`, `capacity/headroom`, `capacity/risk`, más el/los skill(s) de dominio (`oracle/tablespaces`, `asm/capacity`, `os/*/memory`, etc.) si se activan sus agentes.

# Evidence required

`Q-CAP-TIMESERIES-001` para el/los recurso(s) solicitado(s); reutiliza evidencia existente cuando es posible.

# Stop conditions

Histórico insuficiente para el horizonte solicitado — se declara y se ofrece el horizonte máximo soportado por la evidencia disponible.

# Confidence threshold

El forecast nunca excede `PROBABLE_CAUSE`/`HYPOTHESIS` como estado de confianza (ver `skills/capacity/forecast.md#confidence-model`).

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
  version:      config/capability-matrix.yaml → Capacity es PARTIAL en todas las versiones soportadas; no depende de version para su propia lógica, sí la hereda del recurso subyacente evaluado
  architecture: el especialista de dominio subyacente (oracle-dba-analyst/oracle-asm-storage-analyst/os-platform-analyst) sólo se activa si la arquitectura del recurso solicitado aplica (ej. asm sólo si storage_mode=asm)
  environment:  target debe estar en config/allowed-targets.local.yaml
  license:      no aplica directamente — capacity-analyst no depende de features licenciadas
  privilege:    ESTACK_DIAGNOSTIC_ROLE debe alcanzar para el histórico solicitado (Q-CAP-TIMESERIES-001)
  security:     ninguna query requerida puede tener risk_class fuera de R0
  cost:         Q-CAP-TIMESERIES-001 es cost_class MEDIUM, con horizon_months acotando la ventana solicitada
  evidence:     reutiliza evidence_refs ya recolectada en la sesión antes de solicitar histórico nuevo
```

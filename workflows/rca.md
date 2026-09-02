---
name: rca
version: 1.0.0
status: active
---

# Trigger/intent

Comando `/rca`. Solicitud explícita de un Root Cause Analysis formal sobre un incidente/análisis ya cerrado o en curso — a diferencia de `/incident`, que declara el incidente activo, `/rca` puede invocarse post-mortem sobre evidencia ya recolectada.

# Prerequisites

Un `ANA-*`/`INC-*` existente con evidencia suficiente, o evidencia nueva provista explícitamente por el DBA (logs, capturas) para un caso no gestionado previamente por el e-stack.

# Discovery requirements

Reutiliza el discovery del `ANA-*`/`INC-*` de origen si existe; si es un caso nuevo, `oracle-discovery-analyst` obligatorio.

# Minimum agents

`oracle-operations-orchestrator`, `incident-root-cause-analyst`.

# Optional agents

Los especialistas de dominio necesarios para validar cada hipótesis (activados por `incident-root-cause-analyst` según su propio contrato).

# Activation conditions

Igual que `agents/incident-root-cause-analyst.md` — sólo se activa un especialista adicional cuando hay una hipótesis concreta que requiere su evidencia.

# Skills

`incident/root-cause-analysis`, `incident/hypothesis-management`, `incident/cause-validation`, `incident/timeline-analysis`.

# Evidence required

Reutiliza `evidence_refs` existentes del `ANA-*`/`INC-*` de origen; sólo solicita evidencia nueva puntual por hipótesis.

# Stop conditions

Igual que `incident-root-cause-analyst`: se cierra `UNDETERMINED` si la evidencia no alcanza, nunca se fuerza `CONFIRMED_ROOT_CAUSE`.

# Confidence threshold

Modelo RCA estricto (`docs/CONTRACTS.md#rca-model`).

# Escalation

Causa confirmada y accionable → `change-advisor`. Caso cerrado con causa confirmada → `knowledge-curator`.

# Documentation output

`root-cause.md`, `timeline.md`, `lessons-learned.md` bajo el `ANA-*`/`INC-*` correspondiente.

# Token/context budget

Medio — mayormente reutiliza evidencia existente en vez de recolectar desde cero.

# Security constraints

READ-ONLY ALWAYS.

# Gates

```yaml
gates:
  version:      hereda el discovery del ANA-*/INC-* de origen; si es un caso nuevo, se evalúa igual que /diagnose
  architecture: cada especialista adicional activado para validar una hipótesis pasa por el mismo gate de arquitectura que su workflow nativo
  environment:  target(s) del ANA-*/INC-* de origen deben seguir en config/allowed-targets.local.yaml
  license:      igual que el dominio de la hipótesis en validación
  privilege:    ESTACK_DIAGNOSTIC_ROLE debe alcanzar para la evidencia puntual adicional solicitada
  security:     ninguna query requerida puede tener risk_class fuera de R0
  cost:         evidencia adicional se solicita siempre acotada a la hipótesis, nunca exploratoria de alto costo sin justificación
  evidence:     reutiliza evidence_refs del ANA-*/INC-* de origen; sólo solicita evidencia nueva puntual por hipótesis abierta
```

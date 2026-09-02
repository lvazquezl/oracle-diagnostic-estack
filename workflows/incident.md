---
name: incident
version: 1.0.0
status: active
---

# Trigger/intent

Comando `/incident`. El DBA declara explícitamente un incidente activo (no sólo un síntoma a explorar) — implica prioridad alta y activación más agresiva de especialistas en paralelo.

# Prerequisites

Target identificado; descripción del incidente y, si existe, ventana de tiempo aproximada de inicio.

# Discovery requirements

`oracle-discovery-analyst` obligatorio, incluso si hay cache, para confirmar que el ambiente no cambió de topología/rol desde la última vez (un incidente puede coincidir con un cambio no reportado).

# Minimum agents

`oracle-operations-orchestrator`, `oracle-discovery-analyst`, `incident-root-cause-analyst`.

# Optional agents

Cualquiera del registro, activado en paralelo por `incident-root-cause-analyst` según las hipótesis iniciales (a diferencia de `/diagnose`, que activa secuencialmente, `/incident` puede activar 2-3 especialistas candidatos en paralelo dado el costo de un incidente activo).

# Activation conditions

`incident-root-cause-analyst` clasifica el incidente por síntoma (similar a `/diagnose`) pero con umbral más bajo para activar en paralelo en vez de secuencialmente, priorizando tiempo de respuesta.

# Skills

`incident/root-cause-analysis`, `incident/timeline-analysis`, `incident/blast-radius`, más los skills de dominio de cada especialista activado.

# Evidence required

Discovery + evidencia de los dominios candidatos; ventana de tiempo centrada en el inicio del incidente reportado.

# Stop conditions

Ninguna hipótesis alcanza `PROBABLE_CAUSE` tras agotar los dominios candidatos razonables — se cierra como `UNDETERMINED` explícito, nunca se fuerza una conclusión bajo presión de "es un incidente".

# Confidence threshold

Igual al modelo RCA general (`docs/CONTRACTS.md#rca-model`); la urgencia del incidente no baja el estándar de evidencia para `CONFIRMED_ROOT_CAUSE`.

# Escalation

Blast radius amplio o `CONFIRMED_ROOT_CAUSE` con recomendación urgente → `change-advisor` inmediato. Al cerrar, `knowledge-curator` para candidato de conocimiento.

# Documentation output

`incident/INC-YYYYMMDD-NNN/` con `timeline.md`, `root-cause.md`, `lessons-learned.md` además de los archivos estándar.

# Token/context budget

Alto — activación en paralelo es intencionalmente más costosa a cambio de menor tiempo de respuesta.

# Security constraints

READ-ONLY ALWAYS. Ningún agente ejecuta contención automática — toda acción de contención/corrección es una propuesta de `change-advisor` para ejecución humana inmediata.

# Gates

```yaml
gates:
  version:      config/capability-matrix.yaml consultado por cada dominio candidato antes de activarlo en paralelo — la urgencia no salta este gate
  architecture: cada especialista candidato en paralelo se filtra igual que en /diagnose; nunca se activa un agente incompatible con la topología sólo por ser un incidente
  environment:  target(s) deben estar en config/allowed-targets.local.yaml
  license:      dominios LICENSE_DEPENDENT candidatos se activan igual (urgencia), con capability_status LICENSE_RESTRICTED si no se confirma, buscando alternativa no licenciada
  privilege:    ESTACK_DIAGNOSTIC_ROLE debe alcanzar para cada dominio activado en paralelo; si no, ese dominio queda INSUFFICIENT_PRIVILEGES sin bloquear el resto
  security:     ninguna query requerida puede tener risk_class fuera de R0
  cost:         cost_class HIGH permitido dado el contexto de incidente, siempre con timeout/max_rows reforzados (policies/query-cost-policy.md)
  evidence:     discovery se re-ejecuta siempre (no se confía en cache) por si el incidente coincide con un cambio de topología no reportado
```

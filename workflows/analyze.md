---
name: analyze
version: 1.0.0
status: active
---

# Trigger/intent

Comando `/analyze`. Análisis dirigido a un dominio específico ya conocido por el DBA (ej. "analiza el uso de UNDO", "analiza los invalid objects"), a diferencia de `/diagnose` que parte de un síntoma sin dominio claro.

# Prerequisites

Target identificado y dominio/objeto explícito en `question`.

# Discovery requirements

`oracle-discovery-analyst` obligatorio si no hay cache válido.

# Minimum agents

`oracle-operations-orchestrator` + el especialista de dominio que mapea directamente al área solicitada (resuelto por nombre, no por clasificación de síntoma como en `/diagnose`).

# Optional agents

Cualquiera, si el hallazgo del especialista principal amerita correlación cruzada.

# Activation conditions

Mapeo directo `área solicitada → agente` (ej. "UNDO" → `oracle-dba-analyst`; "AWR" → `oracle-performance-analyst`; "disk group" → `oracle-asm-storage-analyst`). Si el área no mapea a ningún agente conocido, el orquestador lo declara y sugiere `/change agent` o `/change skill` en vez de improvisar.

# Skills

El/los skill(s) específico(s) del área solicitada dentro del agente activado.

# Evidence required

Sólo la evidencia certificada del área solicitada.

# Stop conditions

El área solicitada no tiene agente/skill que la cubra (`registered` pero no `active`) — se declara la limitación y se ofrece `/change skill` para materializarla.

# Confidence threshold

Igual al general del stack.

# Escalation

Si el análisis dirigido revela un hallazgo `HIGH` con indicios de incidente activo, escala a `workflows/incident.md`.

# Documentation output

`analysis/ANA-YYYYMMDD-NNN/` estándar, acotado al dominio analizado.

# Token/context budget

Bajo — es el workflow más acotado por diseño (un dominio, una pregunta).

# Security constraints

READ-ONLY ALWAYS.

# Gates

```yaml
gates:
  version:      config/capability-matrix.yaml consultado para el dominio solicitado antes de mapear a agente/skill
  architecture: si el área solicitada no aplica a la arquitectura detectada (ej. "ASM" sobre storage_mode=filesystem), capability_status UNSUPPORTED inmediato, no se activa el agente
  environment:  target debe estar en config/allowed-targets.local.yaml
  license:      si el área es LICENSE_DEPENDENT y no se confirma, LICENSE_RESTRICTED con alternativa si existe
  privilege:    ESTACK_DIAGNOSTIC_ROLE debe alcanzar para la evidencia del área solicitada
  security:     ninguna query requerida puede tener risk_class fuera de R0
  cost:         cost_class de las queries del área se respeta según policies/query-cost-policy.md, sin excepción por ser análisis dirigido
  evidence:     reutiliza evidencia existente en la sesión si responde la misma pregunta
``` Identidad `ESTACK_DIAG_*`.

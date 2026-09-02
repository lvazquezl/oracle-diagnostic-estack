---
description: Declarar y diagnosticar un incidente activo (prioridad alta, activación en paralelo)
---

Actúa como `oracle-operations-orchestrator` y ejecuta el workflow `workflows/incident.md` para el siguiente incidente:

$ARGUMENTS

Invoca `oracle-discovery-analyst` (siempre, incluso con cache) e `incident-root-cause-analyst`, activando en paralelo los especialistas de dominio candidatos. Aplica el modelo RCA estricto (`docs/CONTRACTS.md#rca-model`) — la urgencia no baja el estándar de evidencia para `CONFIRMED_ROOT_CAUSE`; si no alcanza, cierra `UNDETERMINED` explícitamente. READ-ONLY ALWAYS: cualquier acción de contención es una propuesta de `change-advisor` para ejecución humana inmediata, nunca automática.

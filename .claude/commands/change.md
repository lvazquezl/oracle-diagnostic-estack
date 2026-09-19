---
description: Proponer y gestionar un cambio gobernado al propio e-stack (skill/agent/query/workflow/policy/knowledge/compatibility/documentation/security)
---

Actúa como `oracle-operations-orchestrator` invocando a `estack-evolution-architect` y ejecuta el workflow `workflows/change.md` para:

$ARGUMENTS

Sigue el flujo completo sin saltar pasos: DETECT GAP → CHANGE REQUEST → GAP ANALYSIS → IMPACT ANALYSIS → PROPOSAL → IMPLEMENT → TEST → SECURITY VALIDATION → REGRESSION VALIDATION → DOCUMENT → HUMAN REVIEW → PROMOTE (ver `EVOLUTION.md`). Para `skill`/`query`/`compatibility`, valida además IDs canónicos domain-qualified, consistencia con `config/capability-matrix.yaml`/`docs/CAPABILITY_MATRIX.md`, cobertura de versión/arquitectura, impacto de licenciamiento, `cost_class` (nunca `BLOCKED`), el schema completo del Query Contract v2, e impacto de regresión (ver `EVOLUTION.md#13-change-compatibility--validaciones-obligatorias-foundation-hardening`). Detente siempre en HUMAN REVIEW — nunca promuevas un artefacto por tu cuenta, incluso si todos los tests pasaron.

Fase 12: distingue el plano A (asesoría de cambio operativo: `advise` del motor local `change_documentation_knowledge`, sólo texto para ejecución humana, `execution_status: NOT_EXECUTED_BY_ESTACK`) del plano B (evolución del e-stack en la rama de desarrollo: `advise --mode estack`, que informa `PENDING_HUMAN_REVIEW`). `PROMOTE`, merge, tag y push son siempre acciones humanas; nunca autoapruebes ni marques `APPROVED_BY_HUMAN` sin un registro externo verificable.

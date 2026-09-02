---
description: Health check general (o de un módulo específico) de un target Oracle
---

Actúa como `oracle-operations-orchestrator` y ejecuta el workflow `workflows/healthcheck.md` sobre el siguiente target/alcance:

$ARGUMENTS

Confirma discovery (`oracle-discovery-analyst`) si no hay cache válido, activa `oracle-dba-analyst` como mínimo y los especialistas opcionales según topología detectada (`workflows/healthcheck.md#activation-conditions`). READ-ONLY ALWAYS. Cierra generando `analysis/ANA-YYYYMMDD-NNN/` vía `technical-documentation-manager`.

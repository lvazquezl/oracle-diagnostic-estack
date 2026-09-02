---
description: Diagnóstico de rol, lag, gaps, Broker y readiness de Data Guard
---

Actúa como `oracle-operations-orchestrator` y ejecuta el workflow `workflows/dataguard.md` para:

$ARGUMENTS

Invoca `oracle-dataguard-analyst`; si sólo hay acceso a un sitio, continúa con lo disponible y declara explícitamente qué no pudo confirmarse. Nunca ejecutes switchover/failover ni cambies protection mode — sólo evalúa readiness. READ-ONLY ALWAYS.

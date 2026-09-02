---
description: Diagnóstico de topología, servicios, Cache Fusion o recursos CRS de un cluster RAC
---

Actúa como `oracle-operations-orchestrator` y ejecuta el workflow `workflows/rac.md` para:

$ARGUMENTS

Confirma vía discovery que el target es RAC antes de continuar; si es standalone, detente y avísale al DBA. Invoca `oracle-rac-analyst` y escala según `workflows/rac.md#activation-conditions`. Nunca invoques `srvctl`/`crsctl` de cambio ni relocate/failover — READ-ONLY ALWAYS.

---
description: Root Cause Analysis formal sobre un análisis/incidente existente
---

Actúa como `oracle-operations-orchestrator` y ejecuta el workflow `workflows/rca.md` sobre:

$ARGUMENTS

Invoca `incident-root-cause-analyst`, reutilizando evidencia del `ANA-*`/`INC-*` referenciado y solicitando sólo evidencia puntual adicional por hipótesis. Aplica el modelo RCA estricto. Al cerrar con causa confirmada, ofrece invocar `knowledge-curator`. READ-ONLY ALWAYS.

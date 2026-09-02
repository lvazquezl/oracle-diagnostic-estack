---
description: Forecast de headroom/riesgo de capacidad a 1/3/6 meses
---

Actúa como `oracle-operations-orchestrator` y ejecuta el workflow `workflows/capacity.md` para:

$ARGUMENTS

Invoca `capacity-analyst`, reutilizando evidencia ya recolectada en la sesión antes de pedir evidencia nueva. Si el histórico disponible no alcanza el horizonte solicitado, decláralo y ofrece el horizonte máximo soportado. READ-ONLY ALWAYS.

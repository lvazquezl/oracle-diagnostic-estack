---
description: Análisis de performance sobre una ventana AWR/ASH (opcionalmente comparando dos períodos)
---

Actúa como `oracle-operations-orchestrator` y ejecuta el workflow `workflows/awr.md` con la siguiente ventana/pregunta:

$ARGUMENTS

Invoca `oracle-performance-analyst` con `constraints.time_window` explícito (exige que el DBA la provea si no vino en la solicitud). Si Diagnostics Pack no está licenciado, usa el fallback a Statspack y márcalo. Escala a `oracle-rac-analyst`/`os-platform-analyst`/`oracle-asm-storage-analyst` según el wait dominante. READ-ONLY ALWAYS — nunca envíes SQL text completo ni bind values sin autorización explícita del DBA para esta sesión.

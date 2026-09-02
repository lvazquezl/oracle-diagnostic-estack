---
description: Evaluación integral de un target Oracle (cobertura completa según topología)
---

Actúa como `oracle-operations-orchestrator` y ejecuta el workflow `workflows/assessment.md` sobre el siguiente target:

$ARGUMENTS

Ejecuta discovery completo, activa todos los especialistas cuya "Activation condition" se cumpla según la topología detectada (no esperes a que el DBA los pida uno por uno), incluyendo `capacity-analyst` para forecast. READ-ONLY ALWAYS. Cierra con `analysis/ANA-YYYYMMDD-NNN/` completo, listo como base para `/document assessment --format pptx` si el DBA lo solicita.

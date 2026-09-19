---
description: Convertir una recomendación existente en una propuesta de cambio formal para ejecución humana
---

Actúa como `oracle-operations-orchestrator` y ejecuta el workflow `workflows/recommend.md` sobre la siguiente recomendación:

$ARGUMENTS

Invoca `change-advisor` para producir el `CHG-*` completo (Problem, Evidence IDs, Root cause, Proposed change, Justification, Compatibility, Risk, Impact, Preconditions, Prechecks, Exact commands, Expected output, Rollback, Postchecks, Success criteria). Si toca seguridad, invoca también `oracle-security-analyst`. Nunca ejecutes los comandos generados — son texto para el DBA.

Fase 12: si el motor local está disponible, `advise --rca-result <RCA_JSON>` produce `change_advisory.json/.md` desde el RCA real; un RCA no confirmado no genera `CHG`. Los pasos manuales son texto: nunca incluyas ni ejecutes sintaxis de comando.

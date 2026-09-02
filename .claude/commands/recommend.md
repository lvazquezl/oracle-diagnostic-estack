---
description: Convertir una recomendación existente en una propuesta de cambio formal para ejecución humana
---

Actúa como `oracle-operations-orchestrator` y ejecuta el workflow `workflows/recommend.md` sobre la siguiente recomendación:

$ARGUMENTS

Invoca `change-advisor` para producir el `CHG-*` completo (Problem, Evidence IDs, Root cause, Proposed change, Justification, Compatibility, Risk, Impact, Preconditions, Prechecks, Exact commands, Expected output, Rollback, Postchecks, Success criteria). Si toca seguridad, invoca también `oracle-security-analyst`. Nunca ejecutes los comandos generados — son texto para el DBA.

---
description: Diagnosticar un síntoma puntual reportado por el DBA (dominio no conocido de antemano)
---

Actúa como `oracle-operations-orchestrator` (ver `agents/oracle-operations-orchestrator.md`) y ejecuta el workflow `workflows/diagnose.md` para la siguiente solicitud del DBA:

$ARGUMENTS

Recuerda: READ-ONLY ALWAYS (`CLAUDE.md`, `SECURITY.md`). Si no hay contexto de discovery cacheado y válido para el target, invoca primero `oracle-discovery-analyst`. Activa el mínimo número de especialistas necesario según `workflows/diagnose.md#activation-conditions`, usando Task Packages mínimos (`docs/CONTRACTS.md#context-token-model`) — nunca reenvíes evidencia cruda completa entre agentes. Al cerrar, registra automáticamente `analysis/ANA-YYYYMMDD-NNN/` vía `technical-documentation-manager`, y si hay una recomendación accionable, ofrece invocar `change-advisor` (nunca ejecutes nada tú mismo).

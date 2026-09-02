# Data Minimization Policy

## Alcance por defecto

| Tipo de dato | Acceso por defecto |
|---|---|
| Metadata operacional (diccionario, `V$`/`GV$`/`DBA_HIST_*`, estado de recursos) | Permitido según el catálogo certificado (`queries/REGISTRY.md`) |
| Datos de aplicación (contenido de tablas de negocio) | Prohibido |
| Bind values | Prohibido siempre |
| Secretos (passwords, wallets, API keys, tokens) | Prohibido siempre, sin excepción configurable |
| SQL text completo | Condicional — requiere autorización explícita del DBA para la sesión; por defecto se usa SQL_ID + plan hash + métricas |
| AWR/ASH/Statspack/logs completos | Prohibido enviar el artefacto completo; se preprocesa localmente y se envían secciones relevantes a la pregunta activa |
| Hostnames/IPs/service names/schema names/nombres internos | Enmascarados por defecto (`MASK`), ver `sanitizers/data-classification-policy.md` |

## Principio

Se solicita y se envía al modelo la **mínima evidencia suficiente** para responder la pregunta activa del Task Package — nunca "toda la evidencia disponible por si acaso". Cada skill declara su `Required evidence`/`Optional evidence` explícitamente (Skill Contract); no se recolecta evidencia fuera de esa declaración sin justificarlo en el `question` del Task Package.

## Reutilización antes de recolección

Antes de solicitar evidencia nueva, todo agente/skill verifica el cache de evidencia de la sesión/análisis actual (`evidence/`) y reutiliza un `EVD-*` existente si responde la misma pregunta, evitando recolección duplicada (ver `docs/CONTRACTS.md#context-token-model`).

## Excepciones

Cualquier excepción (ej. enviar SQL text completo, ampliar ventana de AWR más allá del default) requiere autorización explícita del DBA en la solicitud original, se registra en `metadata.yaml` del análisis correspondiente, y no se vuelve el comportamiento por defecto para sesiones futuras.

## Referencia

`sanitizers/data-classification-policy.md`, `docs/CONTRACTS.md#evidence-model`, `SECURITY.md#data-minimization-y-sanitización`.

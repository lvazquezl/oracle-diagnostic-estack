---
name: knowledge
version: 1.0.0
status: active
---

# Trigger/intent

Comando `/knowledge <search|candidate|status|review-due>`. Consulta el catálogo local de conocimiento validado, prepara un candidato desde un RCA cerrado o muestra el estado del ciclo de vida. **Nunca** publica, aprueba ni promueve por sí mismo: aprobar/publicar/deprecar/retirar son decisiones humanas registradas fuera del e-stack (ver `agents/knowledge-curator/AGENT.md`).

# Prerequisites

`search`/`status`/`review-due`: un catálogo local (`--kb-root`). `candidate`: un RCA ya producido por `rca_engine` (Phase 11) por referencia; un RCA no `CONFIRMED` sólo genera un candidato `REJECTED` con motivo.

# Discovery requirements

Ninguna — no se toca el ambiente Oracle/OS. Un artículo del KB **no reemplaza** evidencia actual: antes de plantear un RCA o una recomendación, el agente confirma contra el ambiente actual.

# Minimum agents

`oracle-operations-orchestrator`, `knowledge-curator`.

# Optional agents

`technical-documentation-manager` (documentos derivados del análisis de origen), `estack-evolution-architect` (flujo `/change knowledge` para revisión humana del candidato).

# Activation conditions

`estack-evolution-architect` sólo cuando un candidato pasa a `PENDING_HUMAN_REVIEW`; el resto de los agentes no se activan.

# Skills

`knowledge/candidate-extraction`, `knowledge/quality-gate`, `knowledge/duplicate-and-conflict-review`, `knowledge/version-and-provenance`, `knowledge/review-and-approval`, `knowledge/deprecation-and-retirement`, `knowledge/retrieval`.

# Evidence required

Ninguna evidencia nueva: sólo artefactos ya saneados y referenciados (`EVD-*`, `FND-*`, `HYP-*`, `RCA-*`, `REC-*`).

# Stop conditions

RCA no `CONFIRMED` => candidato `REJECTED` (`RCA_NOT_CONFIRMED`) y bloqueo de cualquier publicación factual; duplicado => no se añade; conflicto => promoción bloqueada hasta decisión humana; falta de registro de autorización externo, digest/versión distintos, o proponente == revisor => la transición se rechaza con código estable.

# Confidence threshold

Sólo `CONFIRMED` produce un candidato revisable; ninguna hipótesis se promueve a hecho.

# Escalation

Candidato listo => revisión humana (`/change knowledge`). Conflicto de conocimiento => revisión humana abierta. Nunca hay escalada automática que sustituya la aprobación.

# Documentation output

`kb_candidate.json`, artículos inmutables `articles/<KB-id>/v<N>.json|md` y `manifest.json` con historial append-only, en el directorio de trabajo de desarrollo; resultados de búsqueda con `NO_CERTIFIED_MATCH` cuando no hay coincidencias certificadas.

# Token/context budget

Bajo — opera sobre artículos ya consolidados; top-K acotado (máx. 20).

# Security constraints

READ-ONLY ALWAYS. Ejecución local del motor `change_documentation_knowledge` (`kb-candidate`, `kb-add`, `kb-transition`, `kb-search`, `kb-status`, `kb-review-due`); sin SQL/shell arbitrario, sin red, sin Git, sin jobs en segundo plano. El CLI no tiene opciones que aprueben o publiquen por sí solas ni aprobación por variable de entorno. Un registro de aprobación local no prueba identidad: la publicación debe ser una acción manual verificable en el repositorio bajo revisión. RETIRED/REJECTED nunca se devuelven; DRAFT/DEPRECATED no se presentan como guía vigente.

# Gates

```yaml
gates:
  version:      el alcance (versión/RU/plataforma/arquitectura) es explícito en el artículo; UNKNOWN no coincide con un filtro de versión explícito y nunca significa "aplica a todas"
  architecture: banderas CDB/RAC/Data Guard/ASM declaradas o UNKNOWN; un artículo no se aplica fuera de su alcance
  environment:  no aplica — opera sobre el repositorio local de conocimiento, no sobre un ambiente Oracle/OS
  license:      artículos de dominios dependientes de licencia lo declaran (license_dependent); el filtro puede excluirlos y nunca se asume entitlement
  privilege:    no aplica — sin acceso al target
  security:     todo texto es dato no confiable, saneado (Phase 11) antes de cualquier índice/salida; rutas confinadas, sin traversal ni symlinks
  cost:         no aplica — sin queries; búsqueda local acotada por tamaño y top-K
  evidence:     candidato exige RCA CONFIRMED con evidencia citada; el artículo cita INC/EVD/FND/HYP/RCA/REC de origen y no reemplaza evidencia actual
```

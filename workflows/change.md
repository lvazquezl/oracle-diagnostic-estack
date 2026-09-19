---
name: change
version: 1.0.0
status: active
---

# Trigger/intent

Comando `/change <skill|agent|query|workflow|policy|knowledge|compatibility|documentation|security>`. Crecimiento gobernado del propio e-stack.

# Prerequisites

Un gap identificado (por un agente durante el análisis, o directamente por el DBA/arquitecto).

# Discovery requirements

N/A sobre el ambiente Oracle/OS — este workflow opera sobre el repositorio del e-stack.

# Minimum agents

`oracle-operations-orchestrator`, `estack-evolution-architect`.

# Optional agents

`oracle-security-analyst` (SECURITY VALIDATION obligatoria si el cambio toca seguridad/catálogo de queries/identidades), `technical-documentation-manager` (DOCUMENT), `knowledge-curator` (sólo para `/change knowledge`).

# Activation conditions

`oracle-security-analyst` se activa siempre para `/change query`, `/change security`, y cualquier `/change agent`/`/change skill` cuyo `Forbidden capabilities`/`Allowed skills` cambie.

# Skills

`change/gap-analysis`, `change/impact-analysis`, y el skill de evolución específico del tipo (`change/skill-evolution`, `change/agent-evolution`, etc.), siempre cerrando con `change/regression-validation`.

# Evidence required

N/A — la "evidencia" son los contratos/registros del propio repositorio.

# Stop conditions

SECURITY VALIDATION o REGRESSION VALIDATION fallan → el cambio vuelve a `proposal`, nunca avanza a `PROMOTE`.

# Confidence threshold

N/A — es un flujo de gobierno, no de diagnóstico.

# Escalation

Toda promoción requiere HUMAN REVIEW explícito — no hay escalada automática que la reemplace.

# Documentation output

Actualización de `CHANGELOG.md`, versión semántica del artefacto, y el registro correspondiente (`agents/REGISTRY.md`, `skills/REGISTRY.md`, `queries/REGISTRY.md`).

# Token/context budget

Variable según el tipo de cambio; acotado al artefacto y sus dependientes directos.

# Security constraints

Ningún cambio se promueve si introduce una operación de escritura, una tool no certificada, o una fuga de datos — motivo automático de fallo en SECURITY VALIDATION (ver `EVOLUTION.md`).

# Gates

```yaml
gates:
  version:      /change compatibility valida cobertura de versión contra config/capability-matrix.yaml antes de IMPLEMENT
  architecture: IMPACT ANALYSIS evalúa qué arquitecturas quedan afectadas por el cambio propuesto
  environment:  no aplica — opera sobre el repositorio del e-stack, no un ambiente Oracle/OS específico
  license:      /change query valida license_requirements del Query Contract v2 antes de certificar una nueva entrada
  privilege:    no aplica directamente — el cambio se implementa en el repositorio, no requiere privilegio sobre un target
  security:     oracle-security-analyst ejecuta SECURITY VALIDATION obligatoria para todo /change query, /change security, y cualquier /change agent|skill que altere Forbidden capabilities/Allowed skills
  cost:         nueva query certificada debe declarar cost_class válido (LOW|MEDIUM|HIGH, nunca BLOCKED) antes de TEST
  evidence:     REGRESSION VALIDATION confirma que artefactos existentes siguen pasando sus tests tras el cambio
```

# Phase 12 — dos planos de cambio (Change Advisory, Documentation & Knowledge Lifecycle)

`/change` cubre dos planos que **no** deben confundirse:

- **Plano A — asesoría de cambio operativo (`OPERATIONAL_MANUAL`)**: `change-advisor` convierte un RCA/REC ya existente en una propuesta `CHG` para ejecución humana externa (`advise` del motor local `change_documentation_knowledge`; skills `change/operational-advisory`, `change/impact-and-risk`, `change/compatibility-and-license-gates`, `change/manual-execution-plan`, `change/rollback-and-validation`). Sólo propuesta y documentación: `execution_status: NOT_EXECUTED_BY_ESTACK` inmutable; `APPROVED_BY_HUMAN` únicamente desde una declaración externa verificable que coincida con el digest vigente (identidad no verificada por el e-stack).
- **Plano B — evolución del propio e-stack (`ESTACK_DEVELOPMENT`)**: sólo edita la rama de desarrollo. Skill `change/stack-evolution-handoff` (`advise --mode estack`): el motor **informa** la etapa (`IN_PROGRESS`, `RETURNED_TO_PROPOSAL`, `PENDING_HUMAN_REVIEW`, `BLOCKED`); `PROMOTE` es siempre una acción humana explícita (`promote_status: HUMAN_ACTION_REQUIRED`), nunca del agente. Sin autovalidación circular: quien propone no puede ser el revisor humano (`E_AUTH_SELF_APPROVAL`).

`/change compatibility` verifica cobertura de versión, Query Contract, columnas de diccionario, arquitectura, coste/licencia y cobertura de pruebas; un check `UNKNOWN` no es "soportado" y bloquea el paso a `PENDING_HUMAN_REVIEW`. Cambios de skill, query, rule, schema, template o conocimiento requieren análisis de dependencias, impacto y plan de regresión; los changelogs se actualizan sin inventar aprobaciones. El motor nunca hace push, tag, merge ni commit.

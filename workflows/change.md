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

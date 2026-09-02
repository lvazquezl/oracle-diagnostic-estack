---
name: gap-analysis
id: change/gap-analysis
version: 1.0.0
domain: change
status: active
---

# Purpose

Determinar exactamente qué falta en el stack (agente, skill, query, workflow, policy, knowledge, compatibility, documentation, security) frente a una necesidad detectada, como primer paso obligatorio de todo `/change`.

# Supported Oracle versions

N/A directo — el gap puede ser sobre soporte de una versión Oracle específica no cubierta aún.

# Supported OS/platforms

N/A directo — igual aplica a un gap de plataforma OS no cubierta.

# Supported architectures

N/A directo — el propio gap analysis es agnóstico; documenta la arquitectura afectada como parte de su output.

# Prerequisites

Requiere un `CHANGE REQUEST` (`CHG-REQ-*`) ya clasificado por tipo por `estack-evolution-architect`.

# Required evidence

- Los registros existentes relevantes: `agents/REGISTRY.md`, `skills/REGISTRY.md`, `queries/REGISTRY.md`, `workflows/*.md`, `policies/*.md`, según el tipo de cambio.

# Optional evidence

- El `ANA-*`/`INC-*` que originó la detección del gap, si aplica.

# Read-only operations

Lectura de los registros y contratos del propio repositorio del e-stack (no del ambiente Oracle/OS del cliente).

# Forbidden operations

No crea ni modifica ningún artefacto todavía — el gap analysis es puramente diagnóstico dentro del flujo `/change`; la creación ocurre en la etapa `IMPLEMENT` posterior.

# Decision logic

1. Clasificar el gap: ¿falta el artefacto por completo, o existe pero no cubre la versión/plataforma/arquitectura requerida?
2. Si existe un artefacto `registered` (no materializado) que ya cubre el gap conceptualmente (ver `skills/REGISTRY.md`), el gap es "materializar", no "crear desde cero".
3. Si no existe ninguna entrada ni siquiera `registered`, el gap es "nuevo artefacto" y requiere pasar también por `IMPACT ANALYSIS` para ver qué otros artefactos lo consumirían.
4. Documentar explícitamente qué contrato (`Agent/Skill/Workflow/Query Contract`) debe satisfacer el artefacto resultante.

# Confidence model

N/A — es un análisis estructural del repositorio, no un diagnóstico de ambiente con estados FACT/HYPOTHESIS.

# Output schema

```yaml
gap_analysis:
  change_request_id: CHG-REQ-...
  gap_type: missing_new|missing_materialization|missing_version_platform_coverage
  affected_registry: agents|skills|queries|workflows|policies|knowledge
  contract_to_satisfy: string
  description: string
```

# Related skills

`change/impact-analysis`, `change/skill-evolution`, `change/agent-evolution`, `change/query-evolution`.

# Escalation

Si el gap analysis revela que la necesidad ya está cubierta por un artefacto `active` existente, se rechaza el `CHANGE REQUEST` como innecesario y se lo informa al solicitante en vez de crear duplicados.

# Data sensitivity

N/A — opera sobre metadata del propio repositorio.

# Context budget

Bajo: lectura acotada de registros relevantes al tipo de cambio.

# Tests

`tests/test_change_governance_flow.sh`.

# Documentation requirements

El resultado alimenta la `PROPOSAL` siguiente en el flujo `/change` (ver `EVOLUTION.md`).

# Evolution via `/change`

Este skill mismo evoluciona vía `/change skill`, siguiendo su propio flujo (dogfooding del proceso de gobierno).

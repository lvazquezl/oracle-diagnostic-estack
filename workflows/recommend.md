---
name: recommend
version: 1.0.0
status: active
---

# Trigger/intent

Comando `/recommend`. El DBA solicita explícitamente que una recomendación ya presentada (de un `ANA-*`/`INC-*` previo) se convierta en una propuesta de cambio formal (`CHG-*`) lista para revisión humana.

# Prerequisites

Un `REC-*` existente dentro de un `ANA-*`/`INC-*` referenciado explícitamente por el DBA.

# Discovery requirements

Reutiliza el discovery del análisis de origen; no vuelve a ejecutar discovery.

# Minimum agents

`oracle-operations-orchestrator`, `change-advisor`.

# Optional agents

`oracle-security-analyst` (si el cambio tiene superficie de seguridad), el especialista de dominio de origen (si `change-advisor` necesita aclarar un detalle técnico de la recomendación).

# Activation conditions

`oracle-security-analyst` se activa siempre que el cambio toque `policies/`, usuarios/roles/privilegios, configuración de red/TLS, o cualquier parámetro con impacto de seguridad declarado en `agents/oracle-security-analyst.md`.

# Skills

`core/change-proposal`, `core/command-generation`, `core/rollback-generation`, `core/postcheck-generation`, `core/risk-classification`.

# Evidence required

Reutiliza `evidence_refs` del `REC-*`/`ANA-*` de origen; no recolecta evidencia nueva.

# Stop conditions

Compatibilidad de versión/plataforma del cambio propuesto no puede confirmarse contra el ambiente identificado — la propuesta se marca `BLOCKED: compatibility unconfirmed` en vez de generar comandos.

# Confidence threshold

N/A — este workflow no genera diagnóstico nuevo, estructura una recomendación ya validada.

# Escalation

N/A — es en sí mismo el paso de escalada desde diagnóstico hacia acción humana.

# Documentation output

`analysis/ANA-*/proposed-changes.md` actualizado con el `CHG-*` completo.

# Token/context budget

Bajo — opera sobre una recomendación ya consolidada.

# Security constraints

READ-ONLY ALWAYS. El `CHG-*` producido es texto para ejecución humana, nunca ejecutable por el stack.

# Gates

```yaml
gates:
  version:      change-advisor verifica version_platform_compatibility contra el ambiente identificado antes de redactar comandos exactos
  architecture: si la arquitectura del ambiente no coincide con la de la recomendación de origen, la propuesta se marca BLOCKED: compatibility unconfirmed
  environment:  target del REC-*/ANA-* de origen debe seguir en config/allowed-targets.local.yaml
  license:      license_check_required se propaga desde la recomendación de origen a la propuesta de cambio
  privilege:    no aplica recolección nueva — opera sobre evidence_refs ya existentes
  security:     oracle-security-analyst se activa siempre que el cambio toque policies/, usuarios/roles/privilegios o configuración de red/TLS
  cost:         no aplica — este workflow no recolecta evidencia nueva
  evidence:     reutiliza evidence_refs del REC-*/ANA-* de origen; no solicita evidencia nueva
```

# Phase 12 — ejecución local del advisory

Cuando el motor local está disponible, `change-advisor` produce el `CHG` con `advise` (`change_advisory.json` + `change_advisory.md`) a partir del RCA real: sin `requires_change` o con un RCA `INCONCLUSIVE`/`INSUFFICIENT_EVIDENCE` no se genera un `CHG` (sólo notas y advertencias). Los gates capability/license/privilege/change_window quedan `UNKNOWN` salvo que el contexto declarado los resuelva. El texto de los pasos es manual: el guard de contenido ejecutable rechaza sintaxis de comando. Si el motor no está disponible se degrada al contrato declarativo y se declara `CONTRACT_ONLY`.

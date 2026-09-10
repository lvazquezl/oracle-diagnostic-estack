---
name: configuration-drift
id: multitenant/configuration-drift
version: 1.0.0
domain: multitenant
status: active
---

# Purpose

Clasificar diferencias de configuración entre PDBs — una diferencia no es automáticamente drift incorrecto (`# 22` del prompt de Fase 6).

# Supported Oracle versions

12c–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`multitenant/parameters` resuelto.

# Required evidence

Reutiliza la evidencia ya publicada por `multitenant/parameters` (`Q-CDB-PARAMETERS-001`) — nunca vuelve a consultar `GV$SYSTEM_PARAMETER` por su cuenta.

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno.

# Query IDs

`Q-CDB-PARAMETERS-001` (reutilizada).

# Collector IDs

Ninguno propio.

# Read-only operations

Ninguna consulta propia — trabaja sobre evidencia ya recolectada.

# Forbidden operations

Nunca ejecuta ningún cambio de configuración.

# Decision logic

1. Para cada diferencia detectada por `multitenant/parameters` (`pdb_override`), clasificar:
   - `EXPECTED_DIFFERENCE`: el DBA declaró explícitamente esta diferencia como intencional (ej. `NLS_*` por región, vía `constraints`), o el patrón es un caso conocido documentado (ej. `SERVICE_NAMES` naturalmente distinto por PDB).
   - `UNEXPECTED_DIFFERENCE`: no hay explicación conocida ni declarada.
   - `INSUFFICIENT_CONTEXT`: no hay suficiente información para clasificar (ej. no se sabe si el DBA lo intentó documentar).
2. Ejemplo del prompt (`# 22`): "PDB_A parameter override, PDB_B inherited" no es automáticamente drift incorrecto — se clasifica según el contexto disponible, nunca por defecto como error.

# Normal state

Diferencias clasificadas mayormente como `EXPECTED_DIFFERENCE` o `INSUFFICIENT_CONTEXT` sin impacto reportado.

# Abnormal patterns

Una diferencia `UNEXPECTED_DIFFERENCE` que coincide con un síntoma de comportamiento inconsistente entre PDBs reportado por el DBA.

# False positives

Cualquier diferencia sin clasificación explícita — este skill nunca reporta "drift" sin pasar por las tres categorías.

# Correlation rules

Alimentado directamente por `multitenant/parameters` — nunca duplica la recolección de evidencia.

# Confidence model

`OBSERVATION` para la clasificación; `PROBABLE_CAUSE` sólo si `UNEXPECTED_DIFFERENCE` coincide con un síntoma reportado.

# Severity

`UNEXPECTED_DIFFERENCE` correlacionado con un síntoma → `MEDIUM`/`HIGH` según impacto.

# Output schema

```yaml
configuration_drift:
  - area: string
    pdb_tokens_affected: [string]
    classification: EXPECTED_DIFFERENCE|UNEXPECTED_DIFFERENCE|INSUFFICIENT_CONTEXT
    evidence_refs: [EVD-...]
```

# Related skills

`multitenant/parameters`.

# Escalation

`UNEXPECTED_DIFFERENCE` con impacto confirmado → `incident-root-cause-analyst`.

# Manual remediation guidance

Alineación de parámetro se entrega vía Manual Action Contract sólo si el DBA lo aprueba tras revisar la clasificación, `execution_status: NOT_EXECUTED` — nunca se recomienda igualdad indiscriminada (`# 21`).

# Security

`pdb_tokens_affected` tokenizados.

# Tests

`tests/test_no_parameter_change.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/pdb-findings.md`.

# Change history

v1.0.0 — Fase 6, creación inicial.

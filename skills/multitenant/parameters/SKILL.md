---
name: parameters
id: multitenant/parameters
version: 1.0.0
domain: multitenant
status: active
---

# Purpose

Analizar scope de parámetros entre CDB$ROOT y cada PDB — diferenciar heredado, override a nivel PDB, e instance-specific, nunca recomendar igualdad indiscriminada (`# 21` del prompt de Fase 6).

# Supported Oracle versions

12c–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`multitenant/architecture` resuelto.

# Required evidence

- `Q-CDB-PARAMETERS-001` (`GV$SYSTEM_PARAMETER`, filtrado `ispdb_modifiable='TRUE'`)

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno.

# Query IDs

`Q-CDB-PARAMETERS-001`.

# Collector IDs

Ninguno propio.

# Read-only operations

Lectura de `GV$SYSTEM_PARAMETER`.

# Forbidden operations

Nunca ejecuta `ALTER SYSTEM SET` a ningún nivel (CDB/PDB/instancia).

# Decision logic

1. Comparar el valor de cada parámetro `ispdb_modifiable` en `con_id=1` (CDB$ROOT, valor base) contra cada PDB.
2. Si el valor coincide con el de CDB$ROOT: `scope: inherited`.
3. Si difiere: `scope: pdb_override` — nunca se reporta como error por sí solo, es simplemente informativo (`multitenant/configuration-drift` hace la clasificación de si es esperado o no).
4. Si difiere entre instancias de la misma PDB (RAC): `scope: instance_specific`.

# Normal state

Mezcla de `inherited`/`pdb_override` consistente con el diseño declarado por el DBA.

# Abnormal patterns

Un override no documentado que coincide con un síntoma reportado (ej. comportamiento distinto entre PDBs para la misma aplicación).

# False positives

Un override intencional (ej. `NLS_*` distinto por PDB para clientes de diferentes regiones) no es un error — se reclasifica como `EXPECTED_DIFFERENCE` por `multitenant/configuration-drift`.

# Correlation rules

Alimenta directamente `multitenant/configuration-drift` para la clasificación final.

# Confidence model

`FACT` para el valor leído directamente. La clasificación de si el override es esperado es responsabilidad de `multitenant/configuration-drift`, no de este skill.

# Severity

N/A — este skill reporta scope, no severidad; eso lo determina `configuration-drift` según la clasificación.

# Output schema

```yaml
parameter_scope:
  - name: string
    cdb_root_value: string|null
    pdb_overrides: [{pdb_token: string, value: string, scope: inherited|pdb_override|instance_specific}]
    evidence_refs: [EVD-...]
```

# Related skills

`multitenant/configuration-drift`.

# Escalation

N/A directamente — ver `multitenant/configuration-drift`.

# Manual remediation guidance

Cambio de parámetro se entrega vía Manual Action Contract, `execution_status: NOT_EXECUTED` — nunca ejecutado, nunca recomendado "por consistencia" sin justificación (`# 21`: no recomendar igualdad indiscriminada).

# Security

`value` → condicional (DROP si sugiere contenido sensible).

# Tests

`tests/test_multitenant_query_cost.sh`, `tests/test_no_parameter_change.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/pdb-findings.md`.

# Change history

v1.0.0 — Fase 6, creación inicial.

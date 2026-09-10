---
name: components
id: multitenant/components
version: 1.0.0
domain: multitenant
status: active
---

# Purpose

Salud de componentes registrados, distinguiendo problemas de CDB$ROOT de problemas específicos de PDB — integra con `CDB_REGISTRY`/invalid objects, nunca recompila automáticamente (`# 24`, `# 25` del prompt de Fase 6).

# Supported Oracle versions

12c–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`multitenant/architecture` resuelto.

# Required evidence

- `Q-CDB-COMPONENTS-001` (`CDB_REGISTRY`)

# Optional evidence

Evidencia de invalid objects de Oracle Core (`Q-ORA-INVALID-OBJECTS-001`), correlacionada por contenedor cuando sea relevante — nunca duplicada aquí.

# Licensing requirements

Ninguno.

# Query IDs

`Q-CDB-COMPONENTS-001`.

# Collector IDs

Ninguno propio.

# Read-only operations

Lectura de `CDB_REGISTRY`.

# Forbidden operations

Nunca ejecuta `utlrp.sql`/recompilación ni ninguna acción de reparación (`# 25`: no intenta recompilar automáticamente).

# Decision logic

1. Clasificar cada componente `VALID|INVALID|OPTION_OFF|UPGRADED|LOADING` por `con_id`.
2. Distinguir explícitamente si el problema está en CDB$ROOT o es específico de una PDB — nunca mezclar ambos en un solo hallazgo.
3. Correlacionar con `multitenant/plugin-violations` cuando un componente `INVALID` coincide con una violación de plug-in reciente.

# Normal state

Todos los componentes `VALID`.

# Abnormal patterns

Componente `INVALID` en CDB$ROOT (afecta a todas las PDBs) vs. `INVALID` sólo en una PDB (aislado).

# False positives

`OPTION_OFF` es esperado para componentes no licenciados/no instalados intencionalmente — no es un error.

# Correlation rules

Correlaciona con `multitenant/plugin-violations` y con `oracle-dba-analyst`/Oracle Core para invalid objects generales (sin duplicar ese análisis).

# Confidence model

`FACT` para el estado leído directamente.

# Severity

Componente `INVALID` en CDB$ROOT → `HIGH` (afecta a todo el CDB). `INVALID` sólo en una PDB → `MEDIUM`.

# Output schema

```yaml
components:
  - container: CDB_ROOT|string
    name: string
    status: VALID|INVALID|OPTION_OFF|UPGRADED|LOADING
    evidence_refs: [EVD-...]
```

# Related skills

`multitenant/plugin-violations`.

# Escalation

Componente `INVALID` en CDB$ROOT sin explicación → `incident-root-cause-analyst`.

# Manual remediation guidance

Recompilación/reparación se entrega vía Manual Action Contract, `execution_status: NOT_EXECUTED`.

# Security

Ninguna dato sensible propio.

# Tests

`tests/test_multitenant_container_scope.sh`, `tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/pdb-findings.md`.

# Change history

v1.0.0 — Fase 6, creación inicial.

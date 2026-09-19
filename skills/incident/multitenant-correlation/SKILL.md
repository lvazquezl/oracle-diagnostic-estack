---
name: multitenant-correlation
id: incident/multitenant-correlation
version: 1.0.0
domain: incident
status: active
---

# Purpose

Correlaciona el incidente con evidencia de `oracle-multitenant-analyst` (Fase 6) — PDB-level
resource contention, CDB-wide resource pressure affecting specific PDBs, PDB open-mode issues,
lockdown profile symptoms — por referencia (`# 30`-`# 38` del prompt de Fase 11).

# Supported Oracle versions

Hereda el alcance soportado de `oracle-multitenant-analyst`.

# Supported OS/platforms

Todas.

# Supported architectures

Requiere CDB/PDB (gate heredado del agente).

# Prerequisites

`incident/scope-identification` incluye `oracle-multitenant-analyst` en el scope.

# Required evidence

- `evidence_refs` de `oracle-multitenant-analyst`: PDB resource metrics, CDB resource plan
  status, PDB open-mode/state, lockdown profile denials.

# Optional evidence

Ninguna adicional.

# Read-only operations

Cálculo local sobre evidencia ya recolectada.

# Forbidden operations

Nunca vuelve a consultar CDB_* directamente. Nunca abre/cierra ni modifica una PDB.

# Decision logic

1. Alinear presión de recursos a nivel CDB/PDB contra el timeline del incidente — distinguir
   explícitamente si el incidente afectó una PDB específica o el CDB completo (ver
   `incident/blast-radius`).
2. Un "noisy neighbor" (otra PDB consumiendo recursos compartidos del CDB) es una hipótesis
   válida, sujeta al mismo rigor de confirmación que cualquier otra — nunca asumida sin evidencia
   de resource plan/consumo específico de la PDB vecina.
3. Una denegación de lockdown profile coincidente con el síntoma reportado por la aplicación
   puede explicar errores de aplicación que de otro modo parecerían un fallo de infraestructura —
   se reporta explícitamente cuando aplica.

# Normal state

Evidencia multitenant correlacionada, con el nivel de blast radius (PDB vs CDB) explícito.

# Abnormal patterns

Una PDB específica saturando el resource plan del CDB compartido — contributing factor candidato
para incidentes que afectan a otras PDBs del mismo CDB.

# False positives

Atribuir un incidente a nivel de PDB a una causa a nivel de CDB (o viceversa) sin verificar el
blast radius real es el falso positivo que este skill evita.

# Correlation rules

Consume evidencia de `oracle-multitenant-analyst`. Alimenta `incident/hypothesis-generation`,
`incident/root-cause`, `incident/blast-radius`.

# Confidence model

`FACT` para métricas observadas directamente.

# Severity

N/A directa.

# Output schema

Bloque de evidencia dentro de `hypotheses.supporting_evidence`.

# Related skills

`incident/blast-radius`, `incident/hypothesis-generation`, `incident/root-cause`.

# Escalation

Ninguna directa.

# Manual remediation guidance

Referencia recomendaciones ya formuladas por `oracle-multitenant-analyst` — siempre
`NOT_EXECUTED`.

# Security

Nunca cruza datos entre PDBs de forma que exponga aislamiento de tenant — respeta el mismo
aislamiento que el agente fuente.

# Tests

`tests/test_incident_asm_correlation.sh` cubre el patrón de correlación cross-domain genérico;
sin test dedicado adicional en el alcance MVP de Fase 11 (multitenant no está en la lista
explícita de 9 tests de la sección 98 del prompt — cubierto transversalmente por
`test_incident_root_cause.sh`).

# Documentation requirements

Alimenta `incident-findings.md`.

# Change history

v1.0.0 — Fase 11, creación inicial.

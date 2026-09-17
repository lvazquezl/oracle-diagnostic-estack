---
name: oracle
id: capacity/oracle
version: 1.0.0
domain: capacity
status: active
---

# Purpose

Integra evidencia de capacidad Oracle Database — tamaño de base de datos, tablespaces, datafiles,
diskgroups ASM, FRA, crecimiento de archivelog, histórico AWR/performance cuando esté permitido,
SGA/PGA, awareness de crecimiento de sesiones/procesos. **Nunca consulta datos de negocio.**

# Supported Oracle versions

10g–23ai (histórico disponible limitado por retención de AWR/Statspack, heredado de
`oracle-performance-analyst`).

# Supported OS/platforms

N/A directo — opera sobre evidencia Oracle, agnóstico de OS.

# Supported architectures

Standalone y RAC (agregado a nivel cluster cuando aplica); NON-CDB y CDB (capacidad por PDB
cuando el discovery lo requiere).

# Prerequisites

Target Profile publicado; `capacity/normalization` ejecutado.

# Required evidence

- `evidence_refs` de `oracle/tablespaces` (Oracle Core, Fase 2), `oracle/database-state`
  (tamaño de base de datos).

# Optional evidence

- `evidence_refs` de `asm/capacity` (ASM), `rman/fra`/`rman/fra-pressure` (FRA, Fase 7),
  `oracle-performance-analyst` (SGA/PGA, histórico AWR cuando licenciado), `oracle/processes`
  (crecimiento de sesión/proceso).

# Read-only operations

Cálculo local sobre evidencia ya recolectada por los especialistas de dominio.

# Forbidden operations

Nunca crea datafiles, nunca altera tablespaces, nunca cambia parámetros de base de datos. **Nunca
inspecciona business data ni bind values** (`# 481`-`# 498` del prompt de Fase 10).

# Decision logic

1. Consolidar tamaño de base de datos, tablespaces (vía `capacity/tablespace`), diskgroups ASM
   (vía `capacity/asm`), FRA (space_limit/space_used/space_reclaimable, archivelog growth,
   interacción con retención de backup — integrado con Fase 7), SGA/PGA, y awareness de
   crecimiento de sesión/proceso.
2. Histórico AWR/performance se consulta **sólo** cuando `oracle-performance-analyst` ya confirmó
   licencia (Diagnostics Pack) — nunca licencia asumida por este skill.
3. Nunca duplica la recolección de `oracle-dba-analyst`/`oracle-asm-storage-analyst`/
   `oracle-backup-recovery-analyst`/`oracle-performance-analyst` — consume `evidence_refs` por
   referencia exclusivamente.

# Normal state

Todos los sub-recursos (tablespaces/ASM/FRA/SGA/PGA) con margen suficiente sobre threshold
configurado.

# Abnormal patterns

Cualquier sub-recurso cerca del threshold, correlacionado con growth rate creciente.

# False positives

Ninguno propio — hereda la disciplina anti-falso-positivo de cada sub-skill consolidado.

# Correlation rules

Consolida `capacity/asm`, `capacity/tablespace`. Alimenta `capacity/trend-analysis`,
`capacity/forecasting`, `capacity/capacity-assessment`.

# Confidence model

`FACT` para valores leídos directamente; `LICENSE_RESTRICTED` explícito para AWR/histórico sin
confirmación de licencia (nunca `SUPPORTED` fingido).

# Severity

Heredada del sub-recurso más severo entre los consolidados.

# Output schema

```yaml
oracle_capacity:
  database_size_bytes: number|null
  tablespaces_ref: string|null       # evidence_id de capacity/tablespace
  asm_ref: string|null               # evidence_id de capacity/asm
  fra: {space_limit: number|null, space_used: number|null, space_reclaimable: number|null, archivelog_growth_rate: number|null}
  sga_pga: {sga_bytes: number|null, pga_bytes: number|null}
  session_process_growth: {current_count: number|null, trend: string|null}
  evidence_refs: [EVD-...]
```

# Related skills

`capacity/asm`, `capacity/tablespace`, `capacity/storage`, `capacity/trend-analysis`,
`capacity/forecasting`.

# Escalation

Cualquier sub-recurso `HIGH`/`CRITICAL` escala a `capacity/risk-classification`/
`capacity/manual-capacity-plan`.

# Manual remediation guidance

Consolida las `manual_action` de los sub-skills — siempre `NOT_EXECUTED`.

# Security

Sin business data ni bind values — sólo metadata de capacidad.

# Tests

`tests/test_capacity_oracle_database_growth.sh`, `tests/test_capacity_no_storage_double_counting.sh`.

# Documentation requirements

Alimenta `capacity-oracle.md`.

# Change history

v1.0.0 — Fase 10, creación inicial.

---
name: storage
id: capacity/storage
version: 1.0.0
domain: capacity
status: active
---

# Purpose

Analiza capacidad de storage — filesystem, ASM diskgroup, tablespace, VM datastore, volumen
Windows, capa de storage de SQL Server — modelando explícitamente la relación entre capas para
**nunca sumar capas lógicas y físicas como si fueran capacidad independiente** (double counting).

# Supported Oracle versions

N/A directo para filesystem/datastore; tablespace/ASM heredan el alcance de
`oracle-dba-analyst`/`oracle-asm-storage-analyst`.

# Supported OS/platforms

Linux/Windows Server (filesystem, vía `os-platform-analyst`): `SUPPORTED`/`PARTIALLY_SUPPORTED`.
VMware (datastore): `PARTIALLY_SUPPORTED`. SQL Server (data/log files): `PARTIALLY_SUPPORTED`.

# Supported architectures

Standalone y RAC.

# Prerequisites

`capacity/normalization` ejecutado; evidencia de `os/filesystems` (Fase 9), `asm/capacity`
(Fase 4), `oracle/tablespaces` (Fase 2) disponible por referencia.

# Required evidence

- `evidence_refs` de `os/filesystems` (filesystem), `asm/capacity` (ASM), `oracle/tablespaces`
  (tablespace) según el recurso solicitado.

# Optional evidence

- evidencia de datastore VMware o storage SQL Server cuando disponible.

# Read-only operations

Cálculo local sobre evidencia ya recolectada.

# Forbidden operations

Nunca extiende filesystem/volumen, nunca agrega disco a diskgroup ASM, nunca altera tablespace,
nunca expande datastore.

# Storage layer model

```text
physical / datastore
        ↓
volume / filesystem / ASM
        ↓
database logical layer
        ↓
tablespace / datafile
```

Cada capa se reporta con su propio `total`/`used`/`available` — **nunca se suman capas distintas
como si fueran capacidad independiente** (`# 463`-`# 479` del prompt de Fase 10): un datafile
dentro de un diskgroup ASM no agrega capacidad nueva al total físico, sólo consume la capacidad ya
contada en la capa `volume/ASM`.

# Decision logic

1. Reportar cada capa por separado (`filesystem`, `ASM diskgroup`, `tablespace`, `VM datastore`,
   `Windows volume`, `SQL Server file/storage layer`) con su propio `total_capacity`/
   `used_capacity` (`# 446`-`# 459` del prompt).
2. Correlacionar capas cuando la relación física→lógica sea conocida (ej. tablespace dentro de un
   diskgroup ASM específico) — nunca reportar el mismo espacio físico dos veces bajo dos
   `resource_type` distintos como si fueran independientes.
3. Storage sí puede modelarse acumulativamente (a diferencia de CPU) — priorizar growth rate,
   threshold crossing, exhaustion date (ver `capacity/threshold-crossing#storage-forecast-
   semantics`).

# Normal state

Cada capa con margen suficiente, sin doble conteo detectado.

# Abnormal patterns

Capa específica (filesystem/ASM/tablespace/datastore) cerca del threshold configurado.

# False positives

Sumar la capacidad de la capa física y la capa lógica que reside sobre ella como si fueran dos
recursos independientes es el falso positivo que este skill evita explícitamente.

# Correlation rules

Alimenta `capacity/asm`, `capacity/tablespace`, `capacity/oracle`, `capacity/trend-analysis`,
`capacity/forecasting`, `capacity/threshold-crossing`.

# Confidence model

`FACT` para valores leídos/agregados de evidencia ya certificada.

# Severity

`HIGH`/`CRITICAL` según proximidad al threshold configurado por capa (ver
`capacity/threshold-crossing`).

# Output schema

```yaml
storage_capacity:
  - layer: physical_datastore|volume_filesystem_asm|database_logical|tablespace_datafile
    resource_type: string
    total: number|null
    used: number|null
    available: number|null
    unit: bytes|GiB|TiB
    evidence_refs: [EVD-...]
```

# Related skills

`capacity/asm`, `capacity/tablespace`, `capacity/oracle`, `capacity/trend-analysis`,
`capacity/forecasting`, `capacity/threshold-crossing`.

# Escalation

Capa crítica cerca de agotarse escala a `capacity/risk-classification`/
`capacity/manual-capacity-plan`.

# Manual remediation guidance

`manual_action` sugiere extender la capa correspondiente — siempre `NOT_EXECUTED`.

# Security

`mount_point`/paths → tokenizados por defecto, heredado de `os/filesystems`.

# Tests

`tests/test_capacity_storage_current.sh`, `tests/test_capacity_storage_growth.sh`,
`tests/test_capacity_storage_threshold_date.sh`, `tests/test_capacity_storage_exhaustion_date.sh`,
`tests/test_capacity_resize_segmentation.sh`, `tests/test_capacity_no_storage_double_counting.sh`.

# Documentation requirements

Alimenta `capacity-storage.md`.

# Change history

v1.0.0 — Fase 10, creación inicial.

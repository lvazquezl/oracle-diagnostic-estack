---
name: tablespace
id: capacity/tablespace
version: 1.0.0
domain: capacity
status: active
---

# Purpose

Analiza capacidad de tablespaces distinguiendo `allocated`, `maxsize`, `autoextend`, `used`,
`free` — **nunca declara capacidad usando sólo el espacio actualmente asignado si autoextend
cambia el techo real**. Reutiliza por referencia `oracle/tablespaces` (Fase 2).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

N/A directo.

# Supported architectures

Standalone y RAC; NON-CDB y CDB (por PDB cuando aplique).

# Prerequisites

`oracle/tablespaces` (Fase 2) ya ejecutado; `capacity/normalization` ejecutado.

# Required evidence

- `evidence_refs` de `oracle/tablespaces` (allocated, used, free, autoextend, maxsize por
  datafile/tablespace).

# Optional evidence

Ninguna adicional.

# Read-only operations

Cálculo local sobre evidencia ya recolectada.

# Forbidden operations

Nunca altera tablespace, nunca crea datafile, nunca cambia autoextend/maxsize.

# Decision logic

1. Distinguir explícitamente `allocated` (tamaño actual de los datafiles), `maxsize` (techo
   configurado por `autoextend`, cuando aplique), `autoextend` (habilitado/deshabilitado), `used`,
   `free` (`# 523`-`# 536` del prompt de Fase 10).
2. Si `autoextend` está habilitado con `maxsize` mayor al `allocated` actual, la capacidad real
   disponible para crecimiento es `maxsize - used`, **no** `allocated - used` — nunca declarar
   capacidad usando sólo el espacio ya asignado cuando el techo real es mayor.
3. Si `autoextend` está deshabilitado, `allocated` **es** el techo real — reportado sin
   distinción adicional.
4. Correlacionar con la capa física/ASM subyacente (`capacity/storage#storage-layer-model`) —
   `maxsize` del tablespace nunca excede la capacidad física/ASM disponible sin señalarlo como un
   riesgo latente (el autoextend puede fallar en la práctica pese a `maxsize` configurado alto).

# Normal state

`used`/`maxsize` (o `used`/`allocated` si autoextend deshabilitado) con margen suficiente.

# Abnormal patterns

`used` cerca de `maxsize` con `autoextend` habilitado pero la capa física/ASM subyacente sin
espacio suficiente para soportar ese `maxsize` — riesgo real de fallo de autoextend pese a
`maxsize` configurado alto.

# False positives

Declarar un tablespace "sano" porque `used < allocated` cuando `autoextend` está deshabilitado y
`allocated` es de hecho el techo real y está cerca de agotarse — evitado reportando `allocated`
como techo real en ese caso, nunca asumiendo margen que no existe.

# Correlation rules

Alimenta `capacity/oracle`, `capacity/storage`, `capacity/trend-analysis`,
`capacity/forecasting`.

# Confidence model

`FACT` para valores leídos directamente de `oracle/tablespaces`.

# Severity

`HIGH`/`CRITICAL` según proximidad de `used` al techo real (`maxsize` o `allocated` según
autoextend).

# Output schema

```yaml
tablespace_capacity:
  - tablespace: string
    allocated: number|null
    maxsize: number|null
    autoextend: bool|null
    used: number|null
    free: number|null
    effective_ceiling: number|null    # maxsize si autoextend, allocated si no
    evidence_refs: [EVD-...]
```

# Related skills

`capacity/oracle`, `capacity/storage`, `capacity/trend-analysis`, `capacity/forecasting`.

# Escalation

`used` cerca del `effective_ceiling` escala a `capacity/risk-classification`/
`capacity/manual-capacity-plan`.

# Manual remediation guidance

`manual_action` sugiere ampliar `maxsize`/agregar datafile — siempre `NOT_EXECUTED`.

# Security

Sin datos sensibles.

# Tests

`tests/test_capacity_tablespace_autoextend.sh`, `tests/test_capacity_no_storage_double_counting.sh`.

# Documentation requirements

Alimenta `capacity-storage.md`.

# Change history

v1.0.0 — Fase 10, creación inicial.

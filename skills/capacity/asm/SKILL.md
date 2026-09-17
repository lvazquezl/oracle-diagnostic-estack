---
name: asm
id: capacity/asm
version: 1.0.0
domain: capacity
status: active
---

# Purpose

Analiza capacidad de diskgroups ASM usando `USABLE_FILE_MB` como métrica de capacidad realmente
utilizable — nunca `FREE_MB / TOTAL_MB` simple cuando `USABLE_FILE_MB` es la métrica correcta
(considera redundancia y `required_mirror_free_mb`). Reutiliza por referencia `asm/capacity`
(Fase 4) — nunca duplica el collector.

# Supported Oracle versions

11gR2+ (ASM deep diagnostics, heredado de `oracle-asm-storage-analyst`, Fase 4). 10g fuera de
soporte activo.

# Supported OS/platforms

N/A directo.

# Supported architectures

Standalone y RAC.

# Prerequisites

`asm/capacity` (Fase 4) ya ejecutado; `capacity/normalization` ejecutado.

# Required evidence

- `evidence_refs` de `asm/capacity` (`TOTAL_MB`, `FREE_MB`, `USABLE_FILE_MB`, redundancia por
  diskgroup).

# Optional evidence

Ninguna adicional.

# Read-only operations

Cálculo local sobre evidencia ya recolectada.

# Forbidden operations

Nunca agrega disco a un diskgroup, nunca cambia redundancia.

# Decision logic

1. Reportar `TOTAL_MB`, `FREE_MB`, `USABLE_FILE_MB` por diskgroup — `USABLE_FILE_MB` es la
   capacidad real disponible para nuevos archivos considerando redundancia y
   `required_mirror_free_mb`, **nunca** se usa `FREE_MB / TOTAL_MB` como sustituto simplificado
   cuando `USABLE_FILE_MB` está disponible (`# 501`-`# 519` del prompt de Fase 10).
2. Awareness de redundancia (`EXTERNAL`/`NORMAL`/`HIGH`) — el cálculo de `USABLE_FILE_MB` ya
   incorpora esto vía la vista Oracle certificada, este skill no reimplementa la fórmula, sólo la
   reporta y la usa como base de `utilization_percent`.
3. `utilization_percent = (TOTAL_MB - USABLE_FILE_MB) / TOTAL_MB * 100` cuando `USABLE_FILE_MB`
   esté disponible — nunca `(TOTAL_MB - FREE_MB) / TOTAL_MB` como aproximación cuando la métrica
   correcta existe.

# Normal state

`USABLE_FILE_MB` con margen suficiente sobre el crecimiento esperado.

# Abnormal patterns

`USABLE_FILE_MB` cerca de cero pese a `FREE_MB` aparentemente alto — típico bajo redundancia
`HIGH`/`NORMAL` con poco margen de mirror — reportado explícitamente, nunca oculto por un cálculo
simplificado.

# False positives

Reportar un diskgroup como "sano" basándose en `FREE_MB / TOTAL_MB` cuando `USABLE_FILE_MB` real
es bajo es el falso positivo que este skill evita explícitamente.

# Correlation rules

Alimenta `capacity/storage`, `capacity/oracle`, `capacity/trend-analysis`, `capacity/forecasting`.

# Confidence model

`FACT` para valores leídos directamente de `asm/capacity`.

# Severity

`HIGH`/`CRITICAL` según proximidad de `USABLE_FILE_MB` al threshold configurado.

# Output schema

```yaml
asm_capacity:
  - diskgroup: string
    total_mb: number|null
    free_mb: number|null
    usable_file_mb: number|null
    redundancy: EXTERNAL|NORMAL|HIGH|null
    utilization_percent: number|null
    evidence_refs: [EVD-...]
```

# Related skills

`capacity/storage`, `capacity/oracle`, `capacity/trend-analysis`, `capacity/forecasting`.

# Escalation

`USABLE_FILE_MB` cerca del threshold escala a `capacity/risk-classification`/
`capacity/manual-capacity-plan`.

# Manual remediation guidance

`manual_action` sugiere agregar disco al diskgroup — siempre `NOT_EXECUTED`, dirigida al
administrador ASM.

# Security

Sin datos sensibles.

# Tests

`tests/test_capacity_asm_usable_file_mb.sh`, `tests/test_capacity_no_storage_double_counting.sh`.

# Documentation requirements

Alimenta `capacity-asm.md`.

# Change history

v1.0.0 — Fase 10, creación inicial.

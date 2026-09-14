---
name: swap
id: os/swap
version: 1.0.0
domain: os
status: active
---

# Purpose

Evalúa swap/pagefile configurado, usado y actividad reciente — nunca declara incidente sólo
porque `swap_used > 0`.

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Linux (`/proc/swaps`, `vmstat`): `SUPPORTED`. Solaris (`swap -s`): `SUPPORTED`. Windows
(`get_windows_pagefile_summary`): `SUPPORTED`.

# Supported architectures

Standalone y RAC (por nodo).

# Prerequisites

`os/memory` ya ejecutado.

# Required evidence

- collector `get_swap_summary`

# Optional evidence

- `vmstat` (actividad de paging, `si`/`so`)

# Read-only operations

Lectura de swap/pagefile vía collector semántico.

# Forbidden operations

Nunca configura/redimensiona swap o pagefile.

# Decision logic

1. Reportar `swap_configured`, `swap_used`, `swap_used_pct`.
2. **`swap_used_pct > 0` NO es por sí solo un incidente** (`# 15` del prompt: "No declarar
   incidente sólo por swap used > 0") — el kernel puede swappear páginas inactivas de forma
   normal. El hallazgo real es **actividad sostenida** de paging (`si`/`so` de `vmstat`
   consistentemente > 0), correlacionada con `os/memory-pressure` y SGA/HugePages.
3. Swap activo sostenido + SGA grande + HugePages mal configuradas → correlación fuerte de
   sub-dimensionamiento, `HIGH`.

# Normal state

Swap configurado (buena práctica en la mayoría de plataformas) con actividad de paging nula o
transitoria.

# Abnormal patterns

Actividad de paging sostenida, especialmente con SGA grande configurada.

# False positives

`swap_used_pct > 0` estático, sin actividad de paging reciente, no es un hallazgo — es común y
esperado en muchos hosts Linux.

# Correlation rules

Alimenta `os/memory-pressure`, `os/hugepages`, `performance`.

# Confidence model

`FACT` para métricas leídas. `PROBABLE_CAUSE` cuando actividad sostenida coincide con degradación
Oracle reportada.

# Severity

`HIGH` sólo con actividad de paging sostenida + correlación de impacto; `LOW`/`INFO` para
`swap_used > 0` sin actividad.

# Output schema

```yaml
swap:
  swap_configured_bytes: int|null
  swap_used_bytes: int|null
  swap_used_pct: number|null
  paging_activity_sustained: bool|null
  findings: [{observation: string, severity: string, confidence: string, evidence_refs: [EVD-...]}]
```

# Related skills

`os/memory`, `os/memory-pressure`, `os/hugepages`.

# Escalation

Actividad sostenida con impacto reportado escala a `oracle-performance-analyst`.

# Manual remediation guidance

`manual_action` sugiere revisar sizing de RAM/HugePages — `NOT_EXECUTED`.

# Security

Sin datos sensibles.

# Tests

`tests/test_swap_summary.sh`.

# Documentation requirements

Alimenta `memory-swap.md`.

# Change history

v1.0.0 — Fase 9, creación inicial.

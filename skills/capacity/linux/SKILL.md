---
name: linux
id: capacity/linux
version: 1.0.0
domain: capacity
status: active
---

# Purpose

Contract de capacidad específico de Linux — CPU, memoria (con la disciplina anti-page-cache de
`capacity/memory`), swap, filesystems, inodes — reutilizando por referencia la evidencia Linux de
`os-platform-analyst` (Fase 9), `SUPPORTED` sin restricciones adicionales.

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Oracle Linux/RHEL/SUSE/LinuxONE: `SUPPORTED` (hereda el alcance de `os-platform-analyst`, Fase 9).

# Supported architectures

Standalone y RAC.

# Prerequisites

`capacity/os` ejecutado.

# Required evidence

- `evidence_refs` de `os/cpu-topology`, `os/memory`, `os/swap`, `os/filesystems`, `os/inodes`
  (Fase 9, family: linux).

# Optional evidence

Ninguna adicional.

# Read-only operations

Cálculo local sobre evidencia ya recolectada.

# Forbidden operations

Hereda todas las prohibiciones OS de Fase 9.

# Decision logic

1. Mapear evidencia Linux de Fase 9 al Common Metric Model sin transformación adicional más allá
   de la normalización estándar (`capacity/normalization`).
2. Filesystems/inodes se reportan ambos — un filesystem puede tener espacio disponible pero
   inodes agotados (heredado de `os/inodes`, Fase 9) — nunca colapsados en un solo indicador.

# Normal state

Heredado de `capacity/cpu`/`capacity/memory`/`capacity/storage` para hosts Linux.

# Abnormal patterns

Heredado de los sub-recursos.

# False positives

Heredado de `capacity/memory` (page cache) y `os/inodes` (inode pressure independiente de espacio).

# Correlation rules

Consume `capacity/cpu`, `capacity/memory`, `capacity/storage` con `family: linux`. Alimenta
`capacity/capacity-assessment`.

# Confidence model

`FACT` para valores leídos directamente.

# Severity

Heredada de los sub-recursos.

# Output schema

```yaml
linux_capacity:
  cpu_ref: string|null
  memory_ref: string|null
  filesystem_ref: string|null
  inodes_ref: string|null
  evidence_refs: [EVD-...]
```

# Related skills

`capacity/os`, `capacity/cpu`, `capacity/memory`, `capacity/storage`.

# Escalation

Heredada de los sub-recursos.

# Manual remediation guidance

Consolida las `manual_action` de los sub-skills — siempre `NOT_EXECUTED`.

# Security

Sin datos sensibles.

# Tests

`tests/test_linux_cache_not_treated_as_unavailable.sh`.

# Documentation requirements

Alimenta `capacity-cpu.md`, `capacity-memory.md`, `capacity-storage.md`.

# Change history

v1.0.0 — Fase 10, creación inicial.

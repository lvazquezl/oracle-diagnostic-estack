---
name: windows
id: capacity/windows
version: 1.0.0
domain: capacity
status: active
---

# Purpose

Contract de capacidad específico de Windows Server — CPU, memoria, volumen — reutilizando por
referencia la evidencia Windows de `os-platform-analyst` (Fase 9, collectors WMI
`DOCUMENTATION_VALIDATED`). `PARTIALLY_SUPPORTED` heredando los mismos límites que Fase 9
(ulimits/hugepages/aio `NOT_APPLICABLE`).

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Windows Server: `PARTIALLY_SUPPORTED` (hereda el alcance de `os-platform-analyst`, Fase 9 —
collectors WMI sin runtime certificado todavía, ver `docs/OS_READONLY_COLLECTOR_MODEL.md`).

# Supported architectures

Standalone y RAC.

# Prerequisites

`capacity/os` ejecutado.

# Required evidence

- `evidence_refs` de `os/cpu-topology`/`os/memory`/`os/filesystems` (Fase 9, family: windows) vía
  `get_windows_cpu_topology`/`get_windows_memory_summary` — `DOCUMENTATION_VALIDATED`.

# Optional evidence

- `os/mount-options` no aplica (Windows usa volúmenes, no mount options POSIX) — se reporta
  `NOT_APPLICABLE` explícitamente para esa dimensión.

# Read-only operations

Cálculo local sobre evidencia ya recolectada.

# Forbidden operations

Hereda todas las prohibiciones OS de Fase 9 (nunca modifica Windows Registry, nunca start/stop de
servicio Windows).

# Decision logic

1. Mapear evidencia Windows de Fase 9 al Common Metric Model.
2. `ulimits`/`hugepages` (Large Pages nativo, mecanismo distinto)/`aio` (IOCP, no AIO POSIX) →
   `NOT_APPLICABLE` para este contexto de capacidad, consistente con `os-platform-analyst`
   (Fase 9) — nunca se fuerza semántica Linux sobre Windows.

# Normal state

Heredado de `capacity/cpu`/`capacity/memory`/`capacity/storage` para hosts Windows.

# Abnormal patterns

Heredado de los sub-recursos.

# False positives

Ninguno propio.

# Correlation rules

Consume `capacity/cpu`, `capacity/memory`, `capacity/storage` con `family: windows`. Alimenta
`capacity/capacity-assessment`.

# Confidence model

`FACT` para valores leídos directamente; collectors WMI declarados `DOCUMENTATION_VALIDATED`
(sin runtime certificado en esta fase), consistente con Fase 9.

# Severity

Heredada de los sub-recursos.

# Output schema

```yaml
windows_capacity:
  cpu_ref: string|null
  memory_ref: string|null
  volume_ref: string|null
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

`tests/test_capacity_consumes_os_evidence_by_reference.sh`.

# Documentation requirements

Alimenta `capacity-cpu.md`, `capacity-memory.md`, `capacity-storage.md`.

# Change history

v1.0.0 — Fase 10, creación inicial.

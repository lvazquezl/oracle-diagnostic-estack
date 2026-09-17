---
name: os
id: capacity/os
version: 1.0.0
domain: capacity
status: active
---

# Purpose

Consolida capacidad de sistema operativo (CPU, memoria, swap, filesystems, inodes, process
constraints) integrando por referencia la evidencia ya certificada de `os-platform-analyst`
(Fase 9) — **nunca duplica collectors**. Es el punto de entrada de capacidad OS antes de
diferenciar por plataforma (`capacity/windows`/`capacity/linux`).

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Linux/Windows Server/Solaris (heredado de `os-platform-analyst`, Fase 9).

# Supported architectures

Standalone y RAC.

# Prerequisites

`os-platform-analyst` (Fase 9) ya ejecutado en la sesión — Target Profile con `os_platform`
publicado.

# Required evidence

- `evidence_refs` de `os/cpu-topology`, `os/memory`, `os/swap`, `os/filesystems`, `os/inodes`,
  `os/process-limits` (Fase 9), por nodo cuando RAC.

# Optional evidence

Ninguna adicional.

# Read-only operations

Cálculo local sobre evidencia ya recolectada por `os-platform-analyst`.

# Forbidden operations

Nunca cambia recursos OS — hereda todas las prohibiciones de `os-platform-analyst` (Fase 9)
transitivamente al consumir su evidencia.

# Decision logic

1. Consolidar CPU/memoria/swap/filesystems/inodes/process constraints por nodo, delegando el
   detalle específico de plataforma a `capacity/windows`/`capacity/linux` cuando corresponda.
2. **Nunca duplicar** los collectors de Fase 9 — si `os-platform-analyst` ya recolectó la
   evidencia en la sesión, este skill la consume por `evidence_refs`, nunca vuelve a invocar el
   collector.
3. Agregar a nivel cluster cuando RAC lo requiera (ej. CPU/memoria total del cluster), declarando
   explícitamente que es un agregado, nunca presentado como si fuera un solo nodo.

# Normal state

Todos los sub-recursos OS con margen suficiente, consistente con `os-platform-analyst`.

# Abnormal patterns

Heredadas de `capacity/cpu`/`capacity/memory`/`capacity/storage` para el contexto OS específico.

# False positives

Ninguno propio.

# Correlation rules

Consolida `capacity/cpu`, `capacity/memory`, `capacity/storage` (contexto OS). Alimenta
`capacity/windows`, `capacity/linux`, `capacity/capacity-assessment`.

# Confidence model

`FACT` para valores leídos directamente de evidencia ya certificada.

# Severity

Heredada del sub-recurso más severo.

# Output schema

```yaml
os_capacity:
  cpu_ref: string|null
  memory_ref: string|null
  storage_ref: string|null
  process_limits_ref: string|null
  nodes: [string]
  evidence_refs: [EVD-...]
```

# Related skills

`capacity/cpu`, `capacity/memory`, `capacity/storage`, `capacity/windows`, `capacity/linux`.

# Escalation

Heredada de los sub-recursos consolidados.

# Manual remediation guidance

Consolida las `manual_action` de los sub-skills — siempre `NOT_EXECUTED`.

# Security

Sin datos sensibles.

# Tests

`tests/test_capacity_consumes_os_evidence_by_reference.sh`, `tests/test_capacity_no_duplicate_collectors.sh`.

# Documentation requirements

Alimenta `capacity-cpu.md`, `capacity-memory.md`, `capacity-storage.md`.

# Change history

v1.0.0 — Fase 10, creación inicial.

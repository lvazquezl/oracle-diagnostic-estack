---
name: block-devices
id: os/block-devices
version: 1.0.0
domain: os
status: active
---

# Purpose

Inventario de dispositivos de bloque: tamaño, tipo, awareness de rotacional/no-rotacional
(SSD/HDD), cola y scheduler — visibilidad para dispositivos relacionados con ASM, sin ejecutar
cambios.

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Linux (`lsblk`): `SUPPORTED`. Solaris (`format -e` listado, sólo lectura): `PARTIALLY_SUPPORTED`.
Windows: `PARTIALLY_SUPPORTED` (modelo de disco distinto).

# Supported architectures

Standalone y RAC (visibilidad de dispositivo compartido en RAC/ASM).

# Prerequisites

`os/discovery` ya ejecutado.

# Required evidence

- collector `get_block_device_summary` (`lsblk` equivalente)

# Optional evidence

Ninguna.

# Read-only operations

Lectura de inventario de dispositivos vía collector semántico.

# Forbidden operations

Nunca particiona, formatea ni modifica ningún dispositivo.

# Decision logic

1. Reportar `device`, `size`, `type`, `rotational` (cuando observable), `scheduler` (cuando
   observable de forma segura, ej. `/sys/block/<dev>/queue/scheduler` de sólo lectura).
2. Este skill es **visibilidad de dispositivo relacionado con ASM** — nunca reemplaza a
   `oracle-asm-storage-analyst`, que posee el análisis de diskgroups/redundancia; correlaciona
   por referencia, nunca duplica.
3. Scheduler inconsistente entre dispositivos de un mismo diskgroup ASM es un hallazgo
   informativo, correlacionado con `oracle-asm-storage-analyst`, nunca concluido aquí como causa
   de performance sin ese contexto.

# Normal state

Dispositivos visibles con tamaño/tipo consistentes con el diseño de storage declarado.

# Abnormal patterns

Dispositivo esperado no visible, tamaño inconsistente con lo declarado.

# False positives

Scheduler distinto entre dispositivos no rotacionales (SSD) generalmente no importa tanto como
en HDD — el skill correlaciona `rotational` antes de asignar severidad al scheduler.

# Correlation rules

Alimenta `os/multipath-awareness`, `os/io-performance`, `oracle-asm-storage-analyst` (por
referencia).

# Confidence model

`FACT` para inventario leído directamente.

# Severity

`MEDIUM` si dispositivo ASM esperado no es visible; `LOW`/`INFO` para el resto.

# Output schema

```yaml
block_devices:
  - device: string   # TOKENIZE si convención interna sensible
    size_bytes: int|null
    type: string|null
    rotational: bool|null
    scheduler: string|null
findings: [{observation: string, severity: string, evidence_refs: [EVD-...]}]
```

# Related skills

`os/multipath-awareness`, `os/io-performance`.

# Escalation

Dispositivo ASM esperado no visible escala a `oracle-asm-storage-analyst`.

# Manual remediation guidance

N/A directa — cualquier cambio de dispositivo es competencia del administrador de storage,
siempre `NOT_EXECUTED` si se sugiere.

# Security

Nombres de dispositivo → `TOKENIZE` si revelan convención interna.

# Tests

`tests/test_block_device_summary.sh`, `tests/test_no_storage_change_execution.sh`.

# Documentation requirements

Alimenta `filesystem-storage.md`.

# Change history

v1.0.0 — Fase 9, creación inicial.

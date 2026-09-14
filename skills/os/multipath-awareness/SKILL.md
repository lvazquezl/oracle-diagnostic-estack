---
name: multipath-awareness
id: os/multipath-awareness
version: 1.0.0
domain: os
status: active
---

# Purpose

Detecta si multipath está configurado, número de paths por dispositivo y estado (activo/
degradado) — sólo si hay un collector certificado disponible. Nunca ejecuta `multipathd
reconfigure`.

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Linux (`multipath -ll`, sólo lectura): `SUPPORTED` donde `multipathd` esté presente. Solaris/
Windows (MPIO nativo, mecanismo distinto): `PARTIALLY_SUPPORTED` — awareness, sin collector
dedicado en esta fase.

# Supported architectures

Standalone y RAC (storage compartido en RAC frecuentemente usa multipath).

# Prerequisites

`os/block-devices` ya ejecutado.

# Required evidence

- collector `get_multipath_summary` (`multipath -ll`, sólo lectura, `# 9`/`# 33` del prompt:
  "multipath -ll read-only when permitted")

# Optional evidence

Ninguna.

# Read-only operations

Lectura de `multipath -ll` vía collector semántico — nunca `multipathd reconfigure` (`# 33`:
"No ejecutar multipathd reconfigure").

# Forbidden operations

Nunca reconfigura multipath, nunca falla/reactiva un path manualmente.

# Decision logic

1. Sin collector certificado disponible para la plataforma → `NOT_APPLICABLE`/
   `INSUFFICIENT_PRIVILEGES`, nunca se asume que multipath no está configurado.
2. Reportar `path_count` por dispositivo y estado de cada path (`active`/`failed`/`ghost`).
3. Dispositivo con menos paths activos que los configurados (`degraded`) → `HIGH` — riesgo real
   de pérdida de redundancia de storage.

# Normal state

Todos los paths configurados en estado `active`.

# Abnormal patterns

Uno o más paths en `failed`/`ghost` inesperado — reducción de redundancia.

# False positives

Un path en `ghost` esperado (storage array en modo ALUA con paths standby por diseño) no es un
hallazgo si el diseño lo declara.

# Correlation rules

Alimenta `os/block-devices`, `os/io-performance`.

# Confidence model

`FACT` para estado leído directamente.

# Severity

`HIGH` si hay path degradado sin explicación de diseño.

# Output schema

```yaml
multipath:
  - device: string   # TOKENIZE
    path_count_configured: int|null
    path_count_active: int|null
    degraded: bool|null
findings: [{observation: string, severity: string, evidence_refs: [EVD-...]}]
```

# Related skills

`os/block-devices`, `os/io-performance`.

# Escalation

Path degradado escala a `oracle-asm-storage-analyst`/administrador de storage.

# Manual remediation guidance

`manual_action` para investigación de path físico/HBA/switch — siempre `NOT_EXECUTED`, nunca
`multipathd reconfigure` ejecutado por el e-stack.

# Security

Nombres de dispositivo → `TOKENIZE`.

# Tests

`tests/test_multipath_awareness.sh`, `tests/test_no_storage_change_execution.sh`.

# Documentation requirements

Alimenta `filesystem-storage.md`.

# Change history

v1.0.0 — Fase 9, creación inicial.

---
name: log-pressure
id: os/log-pressure
version: 1.0.0
domain: os
status: active
---

# Purpose

Consolida `os/filesystems` + `os/inodes` específicamente para destinos de log/trace/diagnostic
(`diagnostic_dest`, `audit_file_dest`, alert log, listener log, GI logs) — evita que un mount de
logs cerca de agotarse se pierda entre hallazgos genéricos de filesystem.

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Linux/Solaris/Windows: `SUPPORTED` (hereda de `os/filesystems`).

# Supported architectures

Standalone y RAC (por nodo).

# Prerequisites

`os/filesystems` ya ejecutado.

# Required evidence

- evidencia de `os/filesystems` filtrada a mounts con rol de log/diagnostic

# Optional evidence

- evidencia de `os/inodes` para el mismo mount

# Read-only operations

Ninguna adicional — consolida evidencia ya recolectada.

# Forbidden operations

Nunca purga logs, nunca rota archivos.

# Decision logic

1. Filtrar `os/filesystems`/`os/inodes` a mounts con rol `diagnostic_dest`/`audit_file_dest`/
   logs GI/listener — reportar su estado específicamente, con mayor prioridad que un mount
   genérico.
2. Presión de espacio O de inodes en un destino de log activo → `HIGH`, porque puede impedir que
   Oracle escriba el alert log/trace necesario para diagnosticar el propio incidente que
   generó la presión (riesgo de "silencio" diagnóstico).
3. Correlacionar con volumen de generación reciente (si observable) — un destino de log que
   creció rápidamente correlaciona con un evento reciente (errores en bucle, trace excesivo).

# Normal state

Destinos de log/diagnostic con margen suficiente de espacio e inodes.

# Abnormal patterns

Destino de log cerca de agotarse — riesgo de pérdida de capacidad diagnóstica.

# False positives

Ninguno propio — hereda la disciplina de `os/filesystems`/`os/inodes`.

# Correlation rules

Consolida `os/filesystems`, `os/inodes`. Alimenta `os/platform-healthcheck`.

# Confidence model

`FACT` para uso leído directamente.

# Severity

`HIGH` si un destino de log activo está cerca de agotarse (espacio o inodes).

# Output schema

```yaml
log_pressure:
  - destination: diagnostic_dest|audit_file_dest|gi_log|listener_log
    mount_point: string   # MASK/TOKENIZE
    percent_used: number|null
    inode_percent: number|null
findings: [{observation: string, severity: string, evidence_refs: [EVD-...]}]
```

# Related skills

`os/filesystems`, `os/inodes`.

# Escalation

Presión en destino de log activo escala a `oracle-dba-analyst`.

# Manual remediation guidance

`manual_action` sugiere purga manual de logs/trace antiguos — siempre `NOT_EXECUTED`.

# Security

`mount_point` → `MASK`/`TOKENIZE` por defecto.

# Tests

`tests/test_filesystem_usage.sh`.

# Documentation requirements

Alimenta `filesystem-storage.md`.

# Change history

v1.0.0 — Fase 9, creación inicial.

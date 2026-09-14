---
name: platform-version
id: os/platform-version
version: 1.0.0
domain: os
status: active
---

# Purpose

Certifica el estado de soporte (`SUPPORTED|PARTIALLY_SUPPORTED|NOT_APPLICABLE|
COMPATIBILITY_VALIDATION_REQUIRED`) de la distribución/kernel/versión detectada por
`os/discovery` contra el catálogo de plataformas certificadas — nunca asume equivalencia entre
distribuciones.

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Oracle Linux, RHEL, SUSE: `SUPPORTED`. LinuxONE/Linux on Z: `PARTIALLY_SUPPORTED`. Solaris,
Windows Server: `SUPPORTED`. Rocky Linux/compatible: `PARTIALLY_SUPPORTED` (awareness vía
family/distribution, sin collectors dedicados). AIX/HP-UX: `NOT_APPLICABLE`.

# Supported architectures

Standalone y RAC (por nodo).

# Prerequisites

`os/discovery` ya ejecutado.

# Required evidence

- `os_target` de `os/discovery`

# Optional evidence

Ninguna.

# Read-only operations

Ninguna adicional — reutiliza la evidencia de `os/discovery`.

# Forbidden operations

Ninguna capacidad de cambio.

# Decision logic

1. Buscar `os_target.distribution`/`version` en el catálogo de plataformas certificadas
   (`agents/os-platform-analyst/manifest.yaml#supported_platforms`).
2. Match exacto → `SUPPORTED`/`PARTIALLY_SUPPORTED` según lo declarado. Sin match → `family`
   reconocida pero versión desconocida → `COMPATIBILITY_VALIDATION_REQUIRED`, nunca
   auto-certificado (`# 81` del prompt: "Unknown future platform/version: no auto-certificar").
3. No asumir que dos distribuciones RHEL-compatible se comportan idénticamente — cada una
   certificada independientemente cuando exista evidencia.

# Normal state

Distribución/versión dentro del catálogo certificado.

# Abnormal patterns

Distribución/kernel no reconocido, o versión mayor a la más alta certificada (futuro
desconocido).

# False positives

Ninguno — este skill nunca degrada por versiones patch menores dentro de una distribución ya
certificada.

# Correlation rules

Alimenta el `capability_status` que el resto de skills `os/*` heredan para esa plataforma.

# Confidence model

`FACT` para el match contra el catálogo.

# Severity

N/A.

# Output schema

```yaml
platform_support:
  status: SUPPORTED|PARTIALLY_SUPPORTED|NOT_APPLICABLE|COMPATIBILITY_VALIDATION_REQUIRED
  note: string|null
  evidence_refs: [EVD-...]
```

# Related skills

`os/discovery`, `os/kernel-parameter-assessment`.

# Escalation

Plataforma nueva no certificada → `/change compatibility`.

# Manual remediation guidance

N/A.

# Security

Sin datos sensibles adicionales más allá de `os/discovery`.

# Tests

`tests/test_os_platform_version.sh`.

# Documentation requirements

Alimenta `os-summary.md`.

# Change history

v1.0.0 — Fase 9, creación inicial.

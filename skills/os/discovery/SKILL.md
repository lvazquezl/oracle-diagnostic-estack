---
name: discovery
id: os/discovery
version: 1.0.0
domain: os
status: active
---

# Purpose

Identifica y normaliza `os_target` (family/distribution/version/kernel/architecture/
virtualization/hostname_token) para el host analizado — punto de entrada de todo el dominio OS,
consumido por el resto de skills `os/*` sin que cada uno vuelva a determinar plataforma por su
cuenta.

# Supported Oracle versions

N/A directo — aplica a cualquier versión Oracle sobre el host analizado.

# Supported OS/platforms

Oracle Linux, RHEL, SUSE (`SUPPORTED`); LinuxONE/Linux on Z (`PARTIALLY_SUPPORTED`, awareness de
arquitectura `s390x`); Solaris, Windows Server (`SUPPORTED`); AIX/HP-UX (`NOT_APPLICABLE`, fuera
de alcance de Fase 9).

# Supported architectures

Standalone y RAC (por nodo).

# Prerequisites

Ninguno — primer skill en la cadena de discovery OS.

# Required evidence

- collector `get_os_identity` (Linux: `uname`/`/etc/os-release` vía collector semántico; Solaris:
  `uname`/`prtdiag` header; Windows: `get_windows_os_identity`)

# Optional evidence

- collector `get_host_identity` (ya certificado desde Fase 4, `docs/GI_READONLY_COLLECTORS.md`)

# Read-only operations

Lectura de identidad de OS vía collector semántico allowlisted — nunca lectura de archivo
arbitrario.

# Forbidden operations

Nunca ejecuta shell arbitrario, nunca instala paquetes, nunca modifica configuración de OS.

# Decision logic

1. Normalizar `os_target: {family, distribution, version, kernel, architecture, virtualization,
   hostname_token}` — modelo propio (`docs/OS_PLATFORM_DIAGNOSTIC_MODEL.md#os-version-model`),
   nunca reutiliza `scripts/lib/version.sh` (Oracle-specific).
2. `virtualization` detectado cuando sea observable de forma segura (VMware/KVM/Hyper-V/LPAR/bare
   metal); si no es determinable → `unknown`, nunca inventado.
3. Plataforma no reconocida por ningún collector certificado → `family: unknown`,
   `capability_status: COMPATIBILITY_VALIDATION_REQUIRED` — nunca se asume Linux por defecto.

# Normal state

`os_target` completo con `family`/`distribution`/`version` determinados con `confidence: FACT`.

# Abnormal patterns

Plataforma/versión no reconocida por el catálogo — degrada explícitamente, nunca se fuerza un
match aproximado.

# False positives

Ninguno conocido — discovery de identidad es de bajo riesgo de falso positivo cuando el collector
retorna evidencia.

# Correlation rules

Alimenta todo el resto de skills `os/*` — ningún otro skill vuelve a determinar `os_target` por
su cuenta (mismo principio que el Target Profile Oracle).

# Confidence model

`FACT` para identidad leída directamente del collector. `UNDETERMINED` cuando el collector no
retorna evidencia suficiente.

# Severity

N/A — este skill no emite severidad, sólo identidad.

# Output schema

```yaml
os_target:
  family: linux|solaris|windows|unknown
  distribution: string|null
  version: string|null
  kernel: string|null
  architecture: string|null
  virtualization: string|null
  hostname_token: string   # MASK por defecto
  evidence_refs: [EVD-...]
```

# Related skills

`os/platform-version`, `os/cpu-topology`, `os/memory`.

# Escalation

Plataforma no reconocida → `/change compatibility` en vez de improvisar un comando no certificado.

# Manual remediation guidance

N/A — skill de identidad, sin remediación.

# Security

`hostname_token` → MASK por defecto salvo autorización explícita del DBA para la sesión.

# Tests

`tests/test_os_discovery.sh`, `tests/test_no_arbitrary_shell.sh`.

# Documentation requirements

Alimenta `os-summary.md`.

# Change history

v1.0.0 — Fase 9, creación inicial (reemplaza el modelo `os/<plataforma>/<skill>` de Foundation).

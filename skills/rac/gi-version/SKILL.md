---
name: gi-version
id: rac/gi-version
version: 1.0.0
domain: rac
status: active
---

# Purpose

Capturar de forma segura la versión de Grid Infrastructure (`crsctl query crs activeversion`/`softwareversion`) para version-awareness del resto de skills GI — sólo visibilidad, nunca patching (`# 56` del prompt de Fase 4).

# Supported Oracle versions

11gR2–23ai.

# Supported OS/platforms

Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server.

# Supported architectures

RAC y RAC One Node.

# Prerequisites

Ninguno.

# Required evidence

- collector `get_cluster_version` (`crsctl query crs activeversion`/`softwareversion`)

# Optional evidence

Ninguna.

# Read-only operations

Ejecución allowlisted de `crsctl query crs activeversion`/`softwareversion`.

# Forbidden operations

No ejecuta `OPatch` ni ninguna operación de cambio.

# Decision logic

1. Leer versión activa y de software de GI.
2. Si difieren (rolling upgrade en curso o incompleto), reportarlo como observación explícita — no como error.
3. Publicar la versión para que otros skills GI apliquen su propia lógica `KNOWN_SUPPORTED`/`KNOWN_UNSUPPORTED`/`COMPATIBILITY_VALIDATION_REQUIRED`.

# Confidence model

`FACT` para la versión leída directamente.

# Output schema

```yaml
findings:
  - active_version: string
    software_version: string
    rolling_upgrade_in_progress: bool
    evidence_refs: [EVD-...]
```

# Related skills

`rac/configuration-drift`, `rac/gi-node-status`.

# Escalation

Version mismatch inesperado entre nodos → `rac/configuration-drift`.

# Data sensitivity

Baja — versión de software no es sensible.

# Context budget

Bajo.

# Tests

`tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `rac-topology.md`.

# Evolution via `/change`

Nuevas familias de versión GI vía `/change compatibility`.

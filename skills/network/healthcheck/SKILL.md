---
name: healthcheck
id: network/healthcheck
version: 1.0.0
domain: network
status: active
---

# Purpose

Orquestar `/healthcheck network` (`# 41` del prompt de Fase 4): SCAN resolution, listeners, service registration, LOCAL_LISTENER, REMOTE_LISTENER, connection topology y known errors/evidence.

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

Target Profile publicado.

# Required evidence

- Evidencia agregada de `network/scan-resolution` (si RAC), `network/listeners`, `network/service-registration`, `network/local-listener`, `network/remote-listener`.

# Optional evidence

Ninguna adicional.

# Read-only operations

Orquesta lecturas ya cubiertas por skills subordinados.

# Forbidden operations

No ejecuta ninguna acción correctiva.

# Decision logic

1. Ejecutar cada skill subordinado.
2. Consolidar en `NETWORK HEALTH` único para que `rac/healthcheck` lo consuma por referencia.

# Confidence model

Hereda el `confidence` de cada skill subordinado.

# Output schema

```yaml
findings:
  - dimension: SCAN|LISTENERS|REGISTRATION|CONNECTION_PATH
    status: HEALTHY|DEGRADED|WARNING|CRITICAL|UNKNOWN
    evidence_refs: [EVD-...]
```

# Related skills

`network/scan-resolution`, `network/listeners`, `network/service-registration`, `rac/healthcheck`.

# Escalation

Cualquier dimensión `CRITICAL` → `incident-root-cause-analyst`.

# Data sensitivity

Media-alta.

# Context budget

Alta — se resume por dimensión.

# Tests

`tests/test_listener_healthcheck.sh`, `tests/test_no_write_operations.sh`.

# Documentation requirements

Genera el healthcheck en Markdown vía `technical-documentation-manager`.

# Evolution via `/change`

Nuevas dimensiones vía `/change workflow`.

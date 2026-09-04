---
name: troubleshooting
id: network/troubleshooting
version: 1.0.0
domain: network
status: active
---

# Purpose

Punto de entrada de `/diagnose` para los escenarios `scan`, `listener`, `connection` (`# 43` del prompt de Fase 4) — enruta al skill correcto, no crea un comando slash por cada código de error.

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

Target Profile publicado.

# Required evidence

Ninguna propia.

# Optional evidence

- collector `get_listener_configuration` como contexto base.

# Read-only operations

Ninguna propia.

# Forbidden operations

No ejecuta ninguna acción correctiva.

# Decision logic

1. Clasificar el síntoma: error TNS específico → `network/tns-errors`; SCAN no resuelve → `network/scan-resolution`; servicio no registrado → `network/service-registration`; timeout → `network/timeouts`.
2. Delegar al skill correcto.

# Confidence model

Hereda el `confidence` del skill al que enruta.

# Output schema

```yaml
findings:
  - symptom: string
    routed_to: string
    evidence_refs: [EVD-...]
```

# Related skills

`network/tns-errors`, `network/connection-path`, `network/scan-resolution`.

# Escalation

Síntoma correlacionable con Clusterware (SCAN VIP OFFLINE) → remite a `oracle-rac-analyst`.

# Data sensitivity

Media.

# Context budget

Media.

# Tests

`tests/test_no_write_operations.sh`.

# Documentation requirements

N/A propio.

# Evolution via `/change`

Nuevos patrones de síntoma vía `/change knowledge` (`knowledge/errors/tns/`).

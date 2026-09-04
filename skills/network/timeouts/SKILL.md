---
name: timeouts
id: network/timeouts
version: 1.0.0
domain: network
status: active
---

# Purpose

Revisar parámetros de timeout relevantes del lado Oracle Net (`SQLNET.OUTBOUND_CONNECT_TIMEOUT`, `SQLNET.RECV_TIMEOUT`, `CONNECT_TIMEOUT` del listener) — read-only, correlaciona con `TNS-12170` (`# 51`).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

Ninguno.

# Required evidence

- `Q-ORA-PARAMETERS-001` (parámetros de red relevantes) + lectura de `sqlnet.ora` vía `network/oracle-net`.

# Optional evidence

Ninguna.

# Read-only operations

Lectura de parámetros y `sqlnet.ora`.

# Forbidden operations

No modifica ningún timeout.

# Decision logic

1. Leer los valores de timeout configurados.
2. Un `TNS-12170` correlacionado con un timeout configurado muy bajo respecto a la latencia de red observada (si hay evidencia) → observación de configuración; sin esa evidencia, se reporta el timeout tal cual, sin conclusión.

# Confidence model

`FACT` para valores leídos directamente.

# Output schema

```yaml
findings:
  - parameter: string
    value: string
    evidence_refs: [EVD-...]
```

# Related skills

`network/tns-errors`, `network/connection-path`.

# Escalation

Timeout sospechosamente bajo correlacionado con síntoma reportado → recomendación manual de ajuste (nunca ejecutado).

# Data sensitivity

Baja — valores de configuración, no datos sensibles.

# Context budget

Bajo.

# Tests

`tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `network-analysis.md`.

# Evolution via `/change`

N/A — parámetros estables.

---
name: remote-listener
id: network/remote-listener
version: 1.0.0
domain: network
status: active
---

# Purpose

Leer `REMOTE_LISTENER` (típicamente apuntando al SCAN en RAC) y confirmar consistencia con `network/scan`.

# Supported Oracle versions

10g–23ai (RAC: normalmente apunta a SCAN desde 11gR2; en configuraciones legacy puede apuntar a una lista de listeners).

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

Ninguno.

# Required evidence

- `Q-ORA-PARAMETERS-001` (filtrada a `remote_listener`)

# Optional evidence

- `network/scan` para comparar el valor contra el SCAN name configurado.

# Read-only operations

Lectura de `V$PARAMETER`/`GV$PARAMETER`.

# Forbidden operations

No modifica `REMOTE_LISTENER`.

# Decision logic

1. Leer `REMOTE_LISTENER` por instancia.
2. En RAC, si no apunta al SCAN configurado, reportarlo como observación de configuración — puede ser legítimo en topologías legacy, correlacionar antes de clasificar como error.

# Confidence model

`FACT` para el parámetro leído directamente.

# Output schema

```yaml
findings:
  - instance: string
    remote_listener: string
    matches_scan: bool|null
    evidence_refs: [EVD-...]
```

# Related skills

`network/local-listener`, `network/scan`.

# Escalation

Inconsistencia con SCAN sin explicación → `network/scan` para diagnóstico.

# Data sensitivity

Media.

# Context budget

Bajo.

# Tests

`tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `network-analysis.md`.

# Evolution via `/change`

N/A — parámetro estable.

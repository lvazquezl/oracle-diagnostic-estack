---
name: local-listener
id: network/local-listener
version: 1.0.0
domain: network
status: active
---

# Purpose

Leer el parámetro `LOCAL_LISTENER` de cada instancia y confirmar que apunta a un endpoint válido y consistente con el listener local realmente en ejecución.

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

Ninguno.

# Required evidence

- `Q-ORA-PARAMETERS-001` (ya certificada en Oracle Core, filtrada a `local_listener`)

# Optional evidence

Ninguna.

# Read-only operations

Lectura de `V$PARAMETER`/`GV$PARAMETER`.

# Forbidden operations

No modifica `LOCAL_LISTENER`.

# Decision logic

1. Leer `LOCAL_LISTENER` por instancia.
2. Vacío o apuntando a un endpoint inexistente → observación, correlacionar con `network/listeners` (¿el listener local realmente escucha en ese endpoint?).

# Confidence model

`FACT` para el parámetro leído directamente.

# Output schema

```yaml
findings:
  - instance: string
    local_listener: string
    consistent_with_actual_listener: bool
    evidence_refs: [EVD-...]
```

# Related skills

`network/listeners`, `network/remote-listener`.

# Escalation

`LOCAL_LISTENER` inconsistente con el listener real → `network/listeners` para diagnóstico detallado.

# Data sensitivity

Media — puede contener hostname/puerto, enmascarado por defecto.

# Context budget

Bajo.

# Tests

`tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `network-analysis.md`.

# Evolution via `/change`

N/A — parámetro estable.

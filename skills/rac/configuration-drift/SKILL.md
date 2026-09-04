---
name: configuration-drift
id: rac/configuration-drift
version: 1.0.0
domain: rac
status: active
---

# Purpose

Detectar diferencias entre nodos/instancias en parámetros relevantes, evidencia de configuración de listener, placement de servicio y versión de Oracle Home/GI — sin comparar configuraciones no equivalentes como si debieran ser idénticas (`# 55` del prompt de Fase 4).

# Supported Oracle versions

11gR2–23ai.

# Supported OS/platforms

Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server.

# Supported architectures

RAC y RAC One Node.

# Prerequisites

`rac/topology` resuelto.

# Required evidence

- `Q-ORA-PARAMETERS-RAC-DIFF-001` (parámetros que difieren entre instancias — ya certificada en Oracle Core)

# Optional evidence

- collector `get_listener_configuration` para comparar configuración de listener entre nodos.
- `rac/gi-version` para detectar version mismatch de GI/Oracle Home entre nodos.

# Read-only operations

Lectura de `GV$PARAMETER` (diff), salida estructurada de `lsnrctl status` por nodo.

# Forbidden operations

No sincroniza ni corrige configuración entre nodos.

# Decision logic

1. Comparar parámetros instance-specific que deberían ser iguales (ej. `db_block_size` sí; `instance_name`/`thread` no, son legítimamente distintos por diseño).
2. Reportar sólo diferencias en parámetros que la política declara como "deben ser idénticos" — nunca marcar como drift un parámetro legítimamente instance-specific.
3. Version mismatch de GI/Oracle Home entre nodos → observación explícita, correlacionada con `# 56` (sólo visibilidad, nunca patching).

# Confidence model

`FACT` para diferencias de parámetro leídas directamente.

# Output schema

```yaml
findings:
  - parameter: string
    instance_values: [{instance: string, value: string}]
    classification: LEGITIMATE_DRIFT|UNEXPECTED_DRIFT
    evidence_refs: [EVD-...]
```

# Related skills

`rac/gi-configuration-consistency`, `network/listeners`.

# Escalation

Drift inesperado en un parámetro crítico (ej. `compatible`, `cluster_database`) → escala a `change-advisor` para propuesta de alineación manual.

# Data sensitivity

Media — nombres de instancia enmascarados.

# Context budget

Media.

# Tests

`tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `rac-topology.md`.

# Evolution via `/change`

Lista de parámetros "deben ser idénticos" vía `/change policy`.

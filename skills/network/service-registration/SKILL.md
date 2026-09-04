---
name: service-registration
id: network/service-registration
version: 1.0.0
domain: network
status: active
---

# Purpose

Confirmar que cada servicio de base de datos declarado (`rac/services`) está efectivamente registrado en el/los listener(s) esperados — la causa más común de `TNS-12514`.

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`network/listeners` resuelto.

# Required evidence

- collector `get_listener_configuration` (`lsnrctl status`, servicios registrados)

# Optional evidence

- `Q-RAC-SERVICES-001` (servicios declarados, para comparar contra lo efectivamente registrado, en RAC).

# Read-only operations

Lectura de `lsnrctl status` ya cubierta por `network/listeners`.

# Forbidden operations

No registra/desregistra servicios manualmente (`ALTER SYSTEM REGISTER` no se ejecuta desde este stack).

# Decision logic

1. Comparar servicios declarados/esperados contra los efectivamente registrados en el listener.
2. Servicio esperado sin registro → `HIGH`, candidato directo a explicar `TNS-12514`.
3. Registro dinámico (`PMON`) puede tardar hasta el intervalo de `service_register` — una ausencia momentánea tras un reinicio reciente de instancia no es necesariamente un error (correlacionar con `rac/instance-state`).

# Confidence model

`FACT` para registro leído directamente. `PROBABLE_CAUSE` para "servicio no registrado explica el TNS-12514 reportado".

# Output schema

```yaml
findings:
  - service_name: string        # MASK
    registered_on: [string]
    expected: bool
    evidence_refs: [EVD-...]
```

# Related skills

`network/listeners`, `rac/services`.

# Escalation

Servicio esperado sin registro y sin explicación de reinicio reciente → `incident-root-cause-analyst`.

# Data sensitivity

Media — `service_name` enmascarado.

# Context budget

Bajo.

# Tests

`tests/test_service_registration.sh`, `tests/test_tns_12541_path.sh`, `tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `network-analysis.md`.

# Evolution via `/change`

N/A — comportamiento estable.

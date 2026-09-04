---
name: listeners
id: network/listeners
version: 1.0.0
domain: network
status: active
---

# Purpose

Parsear `lsnrctl status` de forma estructurada: protocolo, host, puerto, servicios registrados, handlers — la conectividad, no el estado de recurso Clusterware (eso es `rac/gi-listeners`, ver boundary explícito).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

Ninguno.

# Required evidence

- collector `get_listener_configuration` (`lsnrctl status`, ver `parsers/rac/lsnrctl_status_parser.py`)

# Optional evidence

Ninguna.

# Read-only operations

Ejecución allowlisted de `lsnrctl status`.

# Forbidden operations

No reinicia el listener (`lsnrctl stop/start/reload` prohibido).

# Decision logic

1. Parsear endpoints (protocolo/host/puerto) y servicios registrados con sus handlers.
2. Un servicio esperado sin registro → candidato a `network/service-registration` para diagnóstico detallado.
3. Sólo se detallan al modelo los handlers/servicios anómalos — el resto se resume (`# 76`).

# Confidence model

`FACT` para configuración/estado leído directamente.

# Output schema

```yaml
findings:
  - listener: string
    endpoints: [{protocol: string, host: string, port: number}]
    services_registered: [{service: string, handlers: number}]
    evidence_refs: [EVD-...]
```

# Related skills

`network/local-listener`, `network/remote-listener`, `network/service-registration`, `rac/gi-listeners`.

# Escalation

Servicio esperado sin registro → `network/service-registration`.

# Data sensitivity

Media-alta — hosts/IPs enmascarados por defecto.

# Context budget

Bajo.

# Tests

`tests/test_lsnrctl_status_parser.sh`, `tests/test_listener_healthcheck.sh`, `tests/test_no_listener_reload.sh`, `tests/test_no_listener_stop.sh`, `tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `network-analysis.md`.

# Evolution via `/change`

Nuevos formatos de salida `lsnrctl` por versión vía `/change compatibility`.

---
name: oracle-net
id: network/oracle-net
version: 1.0.0
domain: network
status: active
---

# Purpose

Vista general de la configuración Oracle Net del target (listeners conocidos, `sqlnet.ora` relevante) — punto de entrada para el resto de skills de red, sin duplicar su detalle.

# Supported Oracle versions

10g–23ai (sintaxis Easy Connect evoluciona; diferencias documentadas por skill específico).

# Supported OS/platforms

Todas las soportadas.

# Supported architectures

Standalone y RAC.

# Prerequisites

Ninguno.

# Required evidence

- collector `get_listener_configuration` (lectura de `listener.ora`/`sqlnet.ora`, contenido enmascarado)

# Optional evidence

Ninguna.

# Read-only operations

Lectura de archivos de configuración Oracle Net vía collector semántico.

# Forbidden operations

No edita `listener.ora`/`sqlnet.ora`/`tnsnames.ora`.

# Decision logic

1. Confirmar presencia y ubicación de los archivos de configuración relevantes.
2. Si un archivo contiene credenciales embebidas, el sanitizer lo bloquea antes de llegar al modelo — este skill nunca envía el archivo completo en ese caso.
3. Delegar el detalle a `network/listeners`/`network/connection-path` según el síntoma.

# Confidence model

`FACT` para presencia/ubicación de archivos leída directamente.

# Output schema

```yaml
findings:
  - config_files_found: [string]
    sanitization_blocked: bool
    evidence_refs: [EVD-...]
```

# Related skills

`network/listeners`, `network/connection-path`.

# Escalation

Credenciales detectadas en un archivo de configuración → alerta de seguridad, nunca se envía el contenido.

# Data sensitivity

Alta — contenido de configuración puede incluir credenciales; bloqueado por el sanitizer cuando corresponde.

# Context budget

Bajo.

# Tests

`tests/test_no_write_operations.sh`, `tests/test_no_credential_exposure.sh`.

# Documentation requirements

Alimenta `network-analysis.md`.

# Evolution via `/change`

N/A — visión general estable.

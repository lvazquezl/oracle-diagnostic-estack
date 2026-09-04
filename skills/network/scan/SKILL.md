---
name: scan
id: network/scan
version: 1.0.0
domain: network
status: active
---

# Purpose

Modelar SCAN desde la óptica de **conectividad**: nombre, IPs configuradas, endpoints, y si el runtime observado (IP vs. hostname) es consistente con lo configurado — sin asumir automáticamente que una discrepancia es un error (`# 29` del prompt de Fase 4).

# Supported Oracle versions

11gR2–23ai (SCAN no existe pre-11gR2).

# Supported OS/platforms

Todas.

# Supported architectures

RAC y RAC One Node.

# Prerequisites

Ninguno.

# Required evidence

- collector `get_scan_configuration` (`srvctl config scan`)

# Optional evidence

- `network/scan-resolution` para el estado de resolución DNS actual.

# Read-only operations

Ejecución allowlisted de `srvctl config scan`.

# Forbidden operations

No modifica configuración de SCAN.

# Decision logic

1. Leer SCAN name y endpoints configurados.
2. Cruzar con `network/scan-resolution` para confirmar consistencia — "SCAN configurado con hostname pero runtime muestra IP" se reporta como observación, no como error automático.
3. Estado del recurso Clusterware (ONLINE/OFFLINE) es responsabilidad de `rac/gi-scan` — este skill nunca lo duplica.

# Confidence model

`FACT` para configuración leída directamente. `OBSERVATION` para inconsistencias configuración↔runtime sin evidencia adicional.

# Output schema

```yaml
findings:
  - scan_name: string           # MASK
    configured_endpoints: [string]
    evidence_refs: [EVD-...]
```

# Related skills

`network/scan-resolution`, `network/service-registration`, `rac/gi-scan` (dominio de `oracle-rac-analyst`, citado por referencia).

# Escalation

SCAN configurado inconsistente con arquitectura esperada (ej. un solo IP donde se esperan 3) → observación correlacionada con `network/scan-resolution`.

# Data sensitivity

Alta — SCAN name/IPs enmascarados por defecto.

# Context budget

Bajo.

# Tests

`tests/test_scan_listener.sh`, `tests/test_scan_multiple_ips.sh`, `tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `network-analysis.md`.

# Evolution via `/change`

N/A — comando estable desde 11gR2.

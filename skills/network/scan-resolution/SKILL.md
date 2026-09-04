---
name: scan-resolution
id: network/scan-resolution
version: 1.0.0
domain: network
status: active
---

# Purpose

Collector local seguro para resolver `SCAN hostname → IPs` (`# 30` del prompt de Fase 4) y detectar: sin resolución, un solo IP donde se esperan más, respuestas inconsistentes, `SERVFAIL`, timeout, y override de hosts file cuando sea detectable. Nunca modifica DNS.

# Supported Oracle versions

11gR2–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

RAC y RAC One Node.

# Prerequisites

`network/scan` resuelto (nombre SCAN configurado).

# Required evidence

- collector `get_name_resolution` — resolución vía librería estándar/comandos allowlisted (`getent`/`nslookup` según plataforma), nunca shell arbitrario.

# Optional evidence

Ninguna.

# Read-only operations

Resolución DNS de sólo lectura.

# Forbidden operations

No modifica DNS, `/etc/hosts`, ni configuración de resolver.

# Decision logic

1. Resolver el SCAN name configurado y comparar con las IPs esperadas por arquitectura (típicamente 3).
2. Clasificar: `RESOLVED` (consistente), `NO_RESOLUTION`, `SINGLE_IP_WHERE_MORE_EXPECTED`, `INCONSISTENT_ANSWERS`, `SERVFAIL`, `TIMEOUT`, `UNKNOWN`.
3. Si hosts file local resuelve el nombre de forma distinta al DNS configurado (detectable), señalarlo explícitamente como override.

# Confidence model

`FACT` para el resultado de resolución leído directamente.

# Output schema

```yaml
findings:
  - scan_name: string          # MASK
    resolution_status: RESOLVED|NO_RESOLUTION|SINGLE_IP_WHERE_MORE_EXPECTED|INCONSISTENT_ANSWERS|SERVFAIL|TIMEOUT|UNKNOWN
    resolved_ips: [string]
    hosts_file_override_detected: bool
    evidence_refs: [EVD-...]
```

# Related skills

`network/scan`, `network/name-resolution`.

# Escalation

`NO_RESOLUTION`/`SERVFAIL` → hipótesis de name-resolution, recomendación manual al equipo de red/DNS.

# Data sensitivity

Alta — SCAN name/IPs enmascarados por defecto.

# Context budget

Bajo.

# Tests

`tests/test_scan_resolution.sh`, `tests/test_scan_resolution_failure.sh`, `tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `network-analysis.md`.

# Evolution via `/change`

Nuevos comandos allowlisted por plataforma vía `/change compatibility`.

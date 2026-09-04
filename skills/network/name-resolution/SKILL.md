---
name: name-resolution
id: network/name-resolution
version: 1.0.0
domain: network
status: active
---

# Purpose

Resolución de nombres general (hostnames de nodo, VIP, entradas de `tnsnames.ora`) — complementa `network/scan-resolution`, que está acotado específicamente a SCAN.

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

Ninguno.

# Required evidence

- collector `get_name_resolution` (`getent`/`nslookup` según plataforma, allowlisted)

# Optional evidence

Ninguna.

# Read-only operations

Resolución DNS de sólo lectura.

# Forbidden operations

No modifica DNS/hosts.

# Decision logic

1. Resolver los nombres relevantes al síntoma (host de nodo, VIP, entrada `tnsnames.ora` específica).
2. Clasificar igual que `network/scan-resolution`: resuelto/no resuelto/inconsistente/timeout.

# Confidence model

`FACT` para el resultado de resolución leído directamente.

# Output schema

```yaml
findings:
  - name: string                # MASK
    resolution_status: RESOLVED|NO_RESOLUTION|INCONSISTENT_ANSWERS|SERVFAIL|TIMEOUT|UNKNOWN
    evidence_refs: [EVD-...]
```

# Related skills

`network/scan-resolution`, `os/linux/dns` (y equivalentes por plataforma vía `os-platform-analyst`).

# Escalation

Fallo de resolución no relacionado con SCAN → recomendación manual al equipo de red/DNS.

# Data sensitivity

Alta — hostnames/IPs enmascarados por defecto.

# Context budget

Bajo.

# Tests

`tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `network-analysis.md`.

# Evolution via `/change`

Nuevos comandos allowlisted por plataforma vía `/change compatibility`.

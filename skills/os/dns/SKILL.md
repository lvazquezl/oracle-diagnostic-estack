---
name: dns
id: os/dns
version: 1.0.0
domain: os
status: active
---

# Purpose

Analiza configuración de resolver y consistencia de lookup a nivel OS — formaliza como skill
completo el collector `get_name_resolution`, ya certificado desde Fase 4. El contexto SCAN/DNS
específico de RAC lo posee `oracle-network-analyst` (`network/name-resolution`,
`network/scan-resolution`) — este skill es la capa OS genérica, nunca duplica esa lógica de
dominio Oracle.

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Linux (`/etc/resolv.conf` awareness, `getent hosts`): `SUPPORTED`. Solaris (`nslookup`/`getent`):
`SUPPORTED`. Windows (`get_windows_network_summary`, sección DNS): `SUPPORTED`.

# Supported architectures

Standalone y RAC.

# Prerequisites

`os/network-interfaces` ya ejecutado.

# Required evidence

- collector `get_name_resolution` (ya certificado desde Fase 4 — mismo `collector_id`, nunca
  duplicado)

# Optional evidence

Ninguna.

# Read-only operations

Lectura de configuración de resolver y lookups vía collector semántico.

# Forbidden operations

Nunca modifica `/etc/resolv.conf`/configuración DNS.

# Decision logic

1. Reportar servidores DNS configurados (tokenizados) y consistencia de resolución para hostnames
   relevantes (nunca ejecuta lookups arbitrarios sobre dominios no relacionados con el análisis).
2. Inconsistencia de resolución entre nodos (mismo hostname resuelve distinto) → `HIGH`,
   correlacionado con `oracle-network-analyst` para el contexto SCAN específico.
3. **No duplica** `network/name-resolution`/`network/scan-resolution` — este skill reporta la
   capa OS genérica (resolver funcional, servidores DNS accesibles); el contexto Oracle Net
   específico (SCAN, TNS) lo interpreta `oracle-network-analyst` consumiendo esta evidencia por
   referencia.

# Normal state

Resolución consistente entre nodos, servidores DNS accesibles.

# Abnormal patterns

Resolución inconsistente entre nodos, servidor DNS inaccesible, timeout de resolución.

# False positives

Ninguno conocido.

# Correlation rules

Alimenta `oracle-network-analyst` (`network/name-resolution`, `network/scan-resolution`) por
referencia — nunca re-implementado ahí.

# Confidence model

`FACT` para configuración/resultado de lookup leído directamente.

# Severity

`HIGH` si hay inconsistencia entre nodos RAC.

# Output schema

```yaml
dns:
  resolvers: [string]   # TOKENIZE
  resolution_consistency: bool|null
findings: [{observation: string, severity: string, evidence_refs: [EVD-...]}]
```

# Related skills

`os/routing`, `os/rac-interconnect-awareness`.

# Escalation

Inconsistencia entre nodos escala a `oracle-network-analyst`.

# Manual remediation guidance

`manual_action` para intervención de DNS — siempre `NOT_EXECUTED`.

# Security

Servidores DNS → `TOKENIZE` por defecto.

# Tests

`tests/test_dns_awareness.sh`, `tests/test_no_network_change_execution.sh`.

# Documentation requirements

Alimenta `network.md`.

# Change history

v1.0.0 — Fase 9, creación inicial (formaliza `get_name_resolution`, collector ya certificado
desde Fase 4).

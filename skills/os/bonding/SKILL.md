---
name: bonding
id: os/bonding
version: 1.0.0
domain: os
status: active
---

# Purpose

Analiza modo de bond, slave activo, estado de slaves, fallas de enlace y política de hash —
correlaciona con problemas de interconnect RAC. Nunca modifica configuración de bonding.

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Linux (`/proc/net/bonding/<bond>`, `ip link` awareness): `SUPPORTED`. Solaris (`dladm
show-aggr`): `SUPPORTED` (terminología "aggregation", no "bonding" — mapeado explícitamente).
Windows: `PARTIALLY_SUPPORTED` (NIC Teaming, awareness).

# Supported architectures

Standalone (uso general) y RAC (interconnect crítico).

# Prerequisites

`os/network-interfaces` ya ejecutado.

# Required evidence

- collector `get_bonding_summary`

# Optional evidence

Ninguna.

# Read-only operations

Lectura de `/proc/net/bonding/*`/`dladm show-aggr` vía collector semántico.

# Forbidden operations

Nunca modifica modo de bond, nunca agrega/quita slaves.

# Decision logic

1. Reportar `bond_mode`, `active_slave` (para modos active-backup), estado de cada slave,
   `link_failures` acumuladas, `hash_policy` (para modos LACP/balance).
2. Un slave `down` en un bond redundante es `MEDIUM`/`HIGH` según si es el único slave activo
   restante — nunca reportado igual que "todos los slaves up".
3. En RAC, un bond del interconnect con historial de `link_failures` correlaciona con Cache
   Fusion degradado reportado por `oracle-rac-analyst` — correlación, nunca causa asumida sin
   esa evidencia.

# Normal state

Todos los slaves `up`, sin `link_failures` recientes, modo consistente con el diseño declarado.

# Abnormal patterns

Slave `down`, `link_failures` recurrentes, modo de bond inconsistente entre nodos RAC.

# False positives

Un slave intencionalmente en standby (active-backup) no es un hallazgo por sí solo — sólo si el
slave activo también falla.

# Correlation rules

Alimenta `os/rac-interconnect-awareness`, `oracle-rac-analyst` (vía escalada).

# Confidence model

`FACT` para estado leído directamente. `PROBABLE_CAUSE` cuando `link_failures` correlacionan con
degradación de Cache Fusion reportada.

# Severity

`HIGH` si el único slave activo restante está degradado; `MEDIUM`/`LOW` con redundancia intacta.

# Output schema

```yaml
bonding:
  - bond: string
    mode: string
    active_slave: string|null
    slaves: [{slave: string, state: up|down, link_failures: int}]
    hash_policy: string|null
findings: [{observation: string, severity: string, confidence: string, evidence_refs: [EVD-...]}]
```

# Related skills

`os/network-interfaces`, `os/rac-interconnect-awareness`.

# Escalation

Degradación de interconnect escala a `oracle-rac-analyst`.

# Manual remediation guidance

`manual_action` para intervención de red — siempre `NOT_EXECUTED`.

# Security

Sin datos sensibles adicionales más allá de nombres de interfaz.

# Tests

`tests/test_bonding_awareness.sh`, `tests/test_no_network_change_execution.sh`.

# Documentation requirements

Alimenta `network.md`.

# Change history

v1.0.0 — Fase 9, creación inicial.

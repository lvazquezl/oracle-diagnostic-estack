---
name: proxy-pdb
id: multitenant/proxy-pdb
version: 1.0.0
domain: multitenant
status: active
---

# Purpose

Awareness de Proxy PDB — nunca abre conexiones remotas arbitrarias, nunca almacena connect strings sensibles (`# 29` del prompt de Fase 6).

# Supported Oracle versions

12.2–23ai (`PROXY_PDB`, columna real de `V$PDBS`, introducida en 12.2).

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`multitenant/pdb-inventory` resuelto.

# Required evidence

- `Q-CDB-PDB-STATE-001` (`V$PDBS.proxy_pdb`, variante 12.2+)

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno.

# Query IDs

`Q-CDB-PDB-STATE-001`.

# Collector IDs

Ninguno propio.

# Read-only operations

Lectura de `V$PDBS.proxy_pdb`.

# Forbidden operations

Nunca abre una conexión remota hacia el PDB real referenciado por el proxy — sólo reporta el flag local. Nunca almacena/expone el connect string del PDB remoto.

# Decision logic

1. Reportar qué PDBs son `proxy_pdb = YES`.
2. Si diagnosticar el estado real del PDB remoto requeriría una conexión adicional, declarar `capability_status: PARTIALLY_SUPPORTED` en vez de intentarlo (`# 29`) — nunca se conecta de forma insegura.

# Normal state

Proxy PDBs identificadas correctamente, sin intento de conexión remota.

# Abnormal patterns

N/A — este skill es puramente de visibilidad local, no evalúa salud del PDB remoto.

# False positives

N/A.

# Correlation rules

Correlaciona con `multitenant/application-containers` cuando ambos conceptos coexisten.

# Confidence model

`FACT` para el flag leído directamente.

# Severity

N/A — awareness informativo.

# Output schema

```yaml
proxy_pdb:
  - pdb_token: string
    capability_status: SUPPORTED|PARTIALLY_SUPPORTED|INSUFFICIENT_EVIDENCE
    evidence_refs: [EVD-...]
```

# Related skills

`multitenant/application-containers`.

# Escalation

N/A.

# Manual remediation guidance

Ninguna — visibilidad únicamente.

# Security

Nunca se recolecta ni expone el connect descriptor/connect string del PDB proxy remoto — bloqueado por diseño, no sólo por sanitización posterior.

# Tests

`tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/cdb-topology.md`.

# Change history

v1.0.0 — Fase 6, creación inicial.

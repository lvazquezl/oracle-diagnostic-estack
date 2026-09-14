---
name: numa
id: os/numa
version: 1.0.0
domain: os
status: active
---

# Purpose

Analiza si NUMA está habilitado, número de nodos, memoria/CPU por nodo y riesgo de acceso a
memoria remota — nunca recomienda deshabilitar NUMA automáticamente.

# Supported Oracle versions

N/A directo — correlaciona con guidance de Oracle por versión/plataforma cuando exista.

# Supported OS/platforms

Linux (`numactl --hardware`): `SUPPORTED` donde el paquete esté disponible. Solaris (`kstat`
lgroup awareness): `SUPPORTED`. Windows: `NOT_APPLICABLE` (NUMA gestionado diferente, sin
collector certificado en esta fase).

# Supported architectures

Standalone y RAC (por nodo).

# Prerequisites

`os/cpu-topology` ya ejecutado.

# Required evidence

- collector `get_cpu_topology` (incluye sección NUMA cuando el comando la expone)

# Optional evidence

Ninguna.

# Read-only operations

Lectura de topología NUMA vía collector semántico.

# Forbidden operations

Nunca deshabilita NUMA, nunca cambia `numactl`/memory policy.

# Decision logic

1. Reportar `numa_enabled`, `node_count`, `memory_per_node`, `cpu_distribution`.
2. Si `node_count > 1` y no hay evidencia de que Oracle esté NUMA-aware configurado (guidance
   depende de versión/plataforma) → reportar como observación de riesgo de memoria remota, nunca
   como hallazgo definitivo sin correlación con guidance Oracle aplicable.
3. Nunca recomendar `numa=off` en boot args — cualquier sugerencia de ese tipo queda como
   `manual_action` con contexto explícito de riesgo/rollback (`# 13` del prompt: "No recomendar
   deshabilitar NUMA automáticamente").

# Normal state

Distribución de memoria/CPU balanceada entre nodos NUMA, o NUMA no aplica (single-node/Windows).

# Abnormal patterns

Fuerte desbalance de memoria libre entre nodos NUMA con SGA grande — riesgo de acceso remoto.

# False positives

`node_count > 1` por sí solo no es anómalo — la mayoría de hosts modernos multi-socket lo tienen;
sólo es hallazgo cuando se correlaciona con evidencia de desbalance real.

# Correlation rules

Alimenta `os/memory`, `os/cpu-topology`.

# Confidence model

`OBSERVATION` para riesgo de memoria remota sin confirmación de impacto real; `FACT` para
topología leída directamente.

# Severity

`LOW`/`MEDIUM` según desbalance observado — nunca `HIGH` sin evidencia de impacto correlacionado.

# Output schema

```yaml
numa:
  numa_enabled: bool|null
  node_count: int|null
  memory_per_node: [{node: int, memory_bytes: int}]|null
  findings: [{observation: string, severity: string, evidence_refs: [EVD-...]}]
```

# Related skills

`os/cpu-topology`, `os/memory`.

# Escalation

Ninguna directa — correlación informativa para `oracle-performance-analyst`.

# Manual remediation guidance

N/A por defecto — cualquier sugerencia de política NUMA requiere guidance Oracle específica de
versión/plataforma, documentada explícitamente antes de emitirse como `manual_action`.

# Security

Sin datos sensibles.

# Tests

`tests/test_numa_awareness.sh`.

# Documentation requirements

Alimenta `cpu-numa.md`.

# Change history

v1.0.0 — Fase 9, creación inicial.

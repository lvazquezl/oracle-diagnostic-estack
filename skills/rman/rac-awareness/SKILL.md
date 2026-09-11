---
name: rac-awareness
id: rman/rac-awareness
version: 1.0.0
domain: rman
status: active
---

# Purpose

Awareness RAC: configuración a nivel database, canales a nivel instancia, acceso compartido a media manager, snapshot controlfile, distribución de canales — nunca asume participación de todos los nodos (`# 22` del prompt de Fase 7).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

RAC, RAC One Node (`NOT_APPLICABLE` en standalone).

# Prerequisites

`rman/channels` resuelto.

# Required evidence

- `Q-RMAN-CONFIGURATION-001`
- `Q-RMAN-BACKUP-DEVICE-001`

# Optional evidence

Target Profile `rac.instances`, delegación a `oracle-rac-analyst`.

# Licensing requirements

Ninguno.

# Query IDs

`Q-RMAN-CONFIGURATION-001`, `Q-RMAN-BACKUP-DEVICE-001`.

# Collector IDs

`get_rman_configuration`.

# Read-only operations

Lectura de configuración/canales.

# Forbidden operations

Ninguna operación de escritura.

# Decision logic

1. RMAN configuration es a nivel database (no por instancia) — un canal `CONFIGURE ... CONNECT ...` específico de instancia es la única excepción real.
2. Un backup ejecutado desde una sola instancia es válido — nunca se asume que todos los nodos deben participar en cada backup (`# 22`).
3. Snapshot controlfile y FRA compartidos (ASM) son la base de accesibilidad multi-instancia — correlacionar con `rman/snapshot-controlfile`.

# Normal state

Configuración consistente vista desde cualquier instancia; canales distribuidos según diseño (aunque sea una sola instancia por diseño).

# Abnormal patterns

Un job que requiere acceso multi-instancia (ej. restore coordinado) con snapshot controlfile en path local-only.

# False positives

Backups ejecutados siempre desde la misma instancia no son un problema si es el diseño del sitio.

# Correlation rules

Correlaciona con `rman/snapshot-controlfile`, `rman/channels`, delega a `oracle-rac-analyst` para afinidad/distribución de instancia.

# Confidence model

`FACT` para configuración leída. `OBSERVATION` para distribución de canales.

# Severity

Dependiente de `rman/snapshot-controlfile` (riesgo de accesibilidad compartida).

# Output schema

```yaml
rac_awareness:
  channel_distribution: string|null
  snapshot_controlfile_shared: bool|null
  fra_shared: bool|null
  evidence_refs: [EVD-...]
```

# Related skills

`rman/snapshot-controlfile`, `rman/channels`, `rman/channel-contention`.

# Escalation

Desbalance de canales entre instancias con impacto en ventana de backup → `oracle-rac-analyst`.

# Manual remediation guidance

Ajuste de afinidad de canal se entrega como recomendación manual — nunca ejecutado.

# Security

`instance_affinity` → MASK.

# Tests

`tests/test_rman_rac_channel_awareness.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/channel-analysis.md`.

# Change history

v1.0.0 — Fase 7, creación inicial.

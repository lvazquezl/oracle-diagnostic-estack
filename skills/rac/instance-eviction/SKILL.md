---
name: instance-eviction
id: rac/instance-eviction
version: 1.0.0
domain: rac
status: active
---

# Purpose

Reconocer evidencia de una eviction reciente (reinicio inesperado de instancia/nodo, discontinuidad de membership) a partir de metadata ya disponible — nunca provoca ni simula una eviction.

# Supported Oracle versions

11gR2–23ai.

# Supported OS/platforms

Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server.

# Supported architectures

RAC y RAC One Node.

# Prerequisites

`rac/instance-state` y `rac/node-membership` resueltos.

# Required evidence

- collector `get_cluster_nodes` (membership actual vs. esperado)

# Optional evidence

- collector `get_voting_status` cuando se sospecha causa de voting disk I/O.

# Read-only operations

Lectura de `olsnodes`, `crsctl query css votedisk` (status).

# Forbidden operations

No reinicia ni reincorpora nodos/instancias.

# Decision logic

1. Cruzar `startup_time` reciente (`rac/instance-state`) con membership discontinua.
2. Si coincide con evidencia de voting disk I/O degradado, elevar a `HIGH` inmediatamente y escalar.
3. Sin esa correlación, reportar `HYPOTHESIS` de eviction — nunca `FACT` sin log/evento explícito.

# Confidence model

`HYPOTHESIS` para reinicio reciente sin explicación. `PROBABLE_CAUSE` cuando coincide con voting disk I/O degradado. `UNDETERMINED` cuando el log de evicción no está disponible o excede la ventana de retención.

# Output schema

```yaml
findings:
  - node: string
    instance: string
    suspected_eviction: bool
    confidence: HYPOTHESIS|PROBABLE_CAUSE|UNDETERMINED
    evidence_refs: [EVD-...]
```

# Related skills

`rac/instance-state`, `rac/node-membership`, `rac/gi-voting-status`.

# Escalation

Indicio de eviction reciente o inminente → escala inmediatamente a `incident-root-cause-analyst`, severity `HIGH`.

# Data sensitivity

Media — nombres de nodo/instancia enmascarados.

# Context budget

Bajo.

# Tests

`tests/test_no_write_operations.sh`, `tests/test_rac_node_membership.sh`.

# Documentation requirements

Alimenta `findings.md` cuando hay indicio de eviction.

# Evolution via `/change`

Correlación con logs Clusterware más ricos vía `/change query` cuando el log ingest lo soporte.

---
name: topology
id: rac/topology
version: 1.0.0
domain: rac
status: active
---

# Purpose

Mapear la topología del cluster: nodos, instancias y su distribución — la base sobre la que se apoya todo otro skill RAC/GI de esta sesión.

# Supported Oracle versions

11gR2–23ai (Grid Infrastructure moderno). 10g/11gR1 (CRS legacy) `PARTIALLY_SUPPORTED` — sólo instancias vía `GV$INSTANCE`, sin visibilidad de recursos Clusterware.

# Supported OS/platforms

Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server.

# Supported architectures

RAC y RAC One Node exclusivamente — el orquestador no lo activa sobre un target standalone (Capability Filter).

# Prerequisites

Target Profile publicado con `architecture.cluster_mode` en `rac`/`rac_one_node`.

# Required evidence

- `Q-RAC-TOPOLOGY-001` (`GV$INSTANCE`, `V$ACTIVE_INSTANCES`)

# Optional evidence

- collector `get_cluster_nodes` (`olsnodes`, ver `docs/GI_READONLY_COLLECTORS.md`) — nombre/estado de nodo a nivel Clusterware, complementa la vista de instancia de base de datos.

# Read-only operations

Lectura de `GV$INSTANCE`/`V$ACTIVE_INSTANCES` y, cuando el collector está disponible, salida estructurada de `olsnodes`.

# Forbidden operations

No inicia/detiene/relocaliza nodos ni instancias. No es una fuente de control, sólo de visibilidad.

# Decision logic

1. Enumerar instancias visibles vía `GV$INSTANCE` y cruzarlas con `V$ACTIVE_INSTANCES`.
2. Si `olsnodes` está disponible, cruzar nodos Clusterware vs. instancias de base de datos — una discrepancia (nodo Clusterware ONLINE sin instancia asociada activa) se reporta como observación, no como error automático (puede ser un nodo GI-only o una instancia deliberadamente detenida).
3. Publicar el conteo de nodos/instancias para que el resto de skills RAC lo reutilicen sin recalcularlo.

# Confidence model

`FACT` para instancias/nodos leídos directamente. `OBSERVATION` para discrepancias Clusterware↔instancia sin explicación conocida.

# Output schema

```yaml
findings:
  - nodes: [{node_id: string, status: string}]
    instances: [{instance_name: string, node: string, status: string}]
    evidence_refs: [EVD-...]
```

# Related skills

`rac/node-membership`, `rac/instance-state`, `rac/gi-node-status`, `rac/cluster-resources`.

# Escalation

Si el número de instancias activas es menor al esperado por el Target Profile sin explicación de mantenimiento, escala a `incident-root-cause-analyst`.

# Data sensitivity

Media: nombres de nodo/instancia se enmascaran por defecto.

# Context budget

Bajo — topología es compacta, se cachea para el resto de la sesión de análisis.

# Tests

`tests/test_rac_topology.sh`, `tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `rac-topology.md` con la tabla nodo↔instancia.

# Evolution via `/change`

Nuevas columnas/vistas de topología vía `/change query`; nuevas familias de versión vía `/change compatibility`.

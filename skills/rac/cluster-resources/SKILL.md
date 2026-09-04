---
name: cluster-resources
id: rac/cluster-resources
version: 1.0.0
domain: rac
status: active
---

# Purpose

Parsear `crsctl stat res -t` de forma estructurada y clasificar cada recurso Clusterware por estado (`ONLINE`/`OFFLINE`/`INTERMEDIATE`/`UNKNOWN`), resumiendo en vez de propagar el dump completo.

# Supported Oracle versions

11gR2–23ai. Formato de salida de `crsctl stat res -t` estable en esta familia; no certificado para CRS 10g legacy.

# Supported OS/platforms

Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server.

# Supported architectures

RAC y RAC One Node.

# Prerequisites

`rac/topology` resuelto.

# Required evidence

- collector `get_cluster_resources` (`crsctl stat res -t`, ver `parsers/rac/crsctl_resource_parser.py`)

# Optional evidence

- `get_scan_configuration`, `get_vip_configuration` para detalle de recurso específico cuando el resumen señala una anomalía.

# Read-only operations

Ejecución allowlisted de `crsctl stat res -t` (sin flags de cambio) vía collector semántico.

# Forbidden operations

No inicia/detiene/relocaliza ningún recurso; no ejecuta `crsctl modify/start/stop`.

# Decision logic

1. Parsear cada recurso a `{resource, type, target, state, server, state_details}`.
2. Clasificar: `total_resources`, `online`, `offline`, `intermediate`, `unknown`.
3. Un recurso `OFFLINE` con `TARGET: OFFLINE` (deshabilitado deliberadamente) se reporta `INFO`, no anomalía — no se infiere causa únicamente por `OFFLINE` (`# 36` del prompt de Fase 4).
4. Un recurso `OFFLINE` con `TARGET: ONLINE` sin ventana de mantenimiento conocida → `HIGH`, candidato a `incident-root-cause-analyst`.
5. Sólo se detallan al modelo los recursos anómalos — el resto se resume como conteo (`# 76`).

# Confidence model

`FACT` para el estado leído directamente. `PROBABLE_CAUSE` para "recurso caído por dependencia" cuando otro recurso del que depende también está `OFFLINE` en la misma lectura.

# Output schema

```yaml
findings:
  - total_resources: number
    online: number
    offline: number
    intermediate: number
    unknown: number
    anomalous_resources: [{resource: string, type: string, target: string, state: string, server: string}]
    evidence_refs: [EVD-...]
```

# Related skills

`rac/gi-resource-status`, `rac/gi-resource-properties`, `rac/healthcheck`, `rac/gi-scan`, `rac/gi-vip`.

# Escalation

Recurso crítico (OCR, voting, VIP, SCAN) `OFFLINE` inesperado → `incident-root-cause-analyst`, severity `HIGH`.

# Data sensitivity

Media — nombres de recurso/servidor enmascarados por defecto.

# Context budget

Media — escala con el número de recursos; se resume salvo anomalía.

# Tests

`tests/test_crsctl_resource_parser.sh`, `tests/test_no_crsctl_modify.sh`, `tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `rac-topology.md` con el resumen de recursos.

# Evolution via `/change`

Nuevos tipos de recurso vía `/change compatibility`.

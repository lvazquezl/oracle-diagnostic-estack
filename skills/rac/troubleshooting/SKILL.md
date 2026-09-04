---
name: troubleshooting
id: rac/troubleshooting
version: 1.0.0
domain: rac
status: active
---

# Purpose

Punto de entrada de `/diagnose rac` (`# 43` del prompt de Fase 4) para síntomas no cubiertos por un skill específico — enruta al skill correcto en vez de improvisar diagnóstico ad-hoc. No sustituye a `rac/instance-eviction`/`rac/cluster-resources`/`rac/interconnect` para sus escenarios propios.

# Supported Oracle versions

11gR2–23ai.

# Supported OS/platforms

Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server.

# Supported architectures

RAC y RAC One Node.

# Prerequisites

Target Profile publicado.

# Required evidence

Ninguna propia — enruta a la evidencia del skill correspondiente al síntoma.

# Optional evidence

- `Q-RAC-TOPOLOGY-001` como contexto base para cualquier triage.

# Read-only operations

Ninguna propia.

# Forbidden operations

No ejecuta ninguna acción correctiva.

# Decision logic

1. Clasificar el síntoma reportado: nodo caído → `rac/node-membership`/`rac/instance-eviction`; servicio no disponible → `rac/services`/`rac/failover`; recurso OFFLINE → `rac/cluster-resources`; desbalance → `rac/load-balancing`; interconnect → `rac/interconnect`.
2. Delegar al skill correcto — nunca reconstruye su lógica aquí.
3. No se crea un comando slash por cada código ORA/TNS/CRS individual (`# 31`, `# 43`) — la taxonomía vive en `knowledge/errors/crs/` (CRS-*/PRV*/PRK*, Grid Infrastructure).

# Confidence model

Hereda el `confidence` del skill al que enruta.

# Output schema

```yaml
findings:
  - symptom: string
    routed_to: string
    evidence_refs: [EVD-...]
```

# Related skills

`rac/instance-eviction`, `rac/cluster-resources`, `rac/interconnect`, `rac/load-balancing`, `rac/failover`.

# Escalation

Síntoma correlacionable con múltiples dominios → `incident-root-cause-analyst`.

# Data sensitivity

Media.

# Context budget

Media.

# Tests

`tests/test_no_write_operations.sh`.

# Documentation requirements

N/A propio — el skill destino documenta.

# Evolution via `/change`

Nuevos patrones de síntoma vía `/change knowledge` (`knowledge/errors/crs/`).

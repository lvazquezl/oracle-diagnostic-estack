---
name: rac
version: 2.0.0
status: active
---

# Trigger/intent

Comando `/rac`. Diagnóstico dirigido a topología, servicios, load balancing (CLB/RLB), Cache Fusion, recursos Clusterware, OCR/voting, SCAN/VIP/listener, o interconnect de un cluster RAC (Fase 4 — `agents/oracle-rac-analyst/AGENT.md`).

# Prerequisites

Target identificado con `instance_mode = rac` confirmado por discovery (si discovery reporta standalone, el workflow se detiene y lo informa).

# Discovery requirements

`oracle-discovery-analyst` obligatorio si no hay cache válido.

# Minimum agents

`oracle-operations-orchestrator`, `oracle-rac-analyst`.

# Optional agents

`oracle-performance-analyst` (si hay wait events `gc *` a caracterizar), `oracle-network-analyst` (SCAN/DNS/listener), `oracle-asm-storage-analyst` (disk groups compartidos), `os-platform-analyst` (interconnect/bonding a nivel host), `incident-root-cause-analyst` (node eviction o pérdida de quorum).

# Activation conditions

Igual que `agents/oracle-rac-analyst/routing.yaml#activation_conditions`.

# Skills

`rac/topology`, `rac/session-distribution`, `rac/load-balancing`, `rac/global-cache`, `rac/cluster-resources`, `rac/gi-scan`, `rac/gi-vip`, `rac/gi-listeners`, `rac/gi-ocr-status`, `rac/gi-voting-status`, y el resto de `rac/*` (31 skills, incluye la sub-familia `gi-*`) según la pregunta.

# Evidence required

`Q-DISC-RAC-001`, `Q-RAC-TOPOLOGY-001`, `Q-RAC-SESSION-DIST-001` como mínimo; el resto según activación.

# Stop conditions

Target no es RAC (discovery lo confirma standalone) — el workflow no aplica y se lo informa al DBA en vez de forzar el análisis.

# Confidence threshold

Igual al general del stack.

# Escalation

Indicios de node eviction o pérdida de quorum → escala inmediatamente a `incident-root-cause-analyst` con severidad `HIGH`.

# Documentation output

`analysis/ANA-YYYYMMDD-NNN/` con `findings.md` centrado en topología/servicios/Cache Fusion.

# Token/context budget

Medio, escalable con el número de nodos del cluster.

# Security constraints

READ-ONLY ALWAYS. Nunca invoca `srvctl`/`crsctl` de cambio ni relocate/failover.

# Gates

```yaml
gates:
  version:      config/capability-matrix.yaml → RAC topology/services/load-balancing es PARTIALLY_SUPPORTED en 10g/11gR1 (CRS legacy, sin visibilidad de recursos Clusterware moderno), SUPPORTED desde 11gR2 — 10g/11gR1 no activa oracle-rac-analyst para las capacidades GI modernas
  architecture: si core/context-discovery reporta instance_mode = single, el workflow SE DETIENE aquí (no activa oracle-rac-analyst) y lo informa al DBA — éste es el ejemplo canónico del gate 'architecture'
  environment:  target debe estar en config/allowed-targets.local.yaml
  license:      ninguna capability de este workflow es LICENSE_DEPENDENT por sí sola (RAC topología no requiere Diagnostics Pack); gc waits → oracle-performance-analyst aplica su propio Licensing Gate
  privilege:    ESTACK_DIAGNOSTIC_ROLE debe alcanzar GV$SESSION/GV$SERVICES/GV$INSTANCE/GV$CLUSTER_INTERCONNECTS/GV$GES_STATISTICS/GV$GCS_STATISTICS; identidad diagnóstica GI/OS de sólo lectura para collectors (docs/GI_READONLY_COLLECTORS.md) — INSUFFICIENT_PRIVILEGES si no está disponible, nunca escalamiento automático
  security:     ninguna query requerida puede tener risk_class fuera de R0; ninguna tool srvctl/crsctl de escritura existe en el catálogo (tests/test_no_crsctl_modify.sh, tests/test_no_srvctl_modify_execution.sh)
  cost:         Q-RAC-SESSION-DIST-001/Q-RAC-GES-GCS-001 son cost_class MEDIUM, max_rows proporcional al número de instancias (policies/rate-limiting-policy.md#gv-y-rac)
  evidence:     reutiliza topología ya cacheada por oracle-discovery-analyst (target_profile.rac/.gi/.asm/.network, docs/TARGET_PROFILE.md)
```

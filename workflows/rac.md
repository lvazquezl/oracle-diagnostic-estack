---
name: rac
version: 1.0.0
status: active
---

# Trigger/intent

Comando `/rac`. Diagnóstico dirigido a topología, servicios, Cache Fusion o recursos CRS de un cluster RAC.

# Prerequisites

Target identificado con `instance_mode = rac` confirmado por discovery (si discovery reporta standalone, el workflow se detiene y lo informa).

# Discovery requirements

`oracle-discovery-analyst` obligatorio si no hay cache válido.

# Minimum agents

`oracle-operations-orchestrator`, `oracle-rac-analyst`.

# Optional agents

`oracle-performance-analyst` (si hay wait events `gc *` a caracterizar), `oracle-network-analyst` (SCAN/DNS/listener), `oracle-asm-storage-analyst` (disk groups compartidos), `os-platform-analyst` (interconnect/bonding a nivel host), `incident-root-cause-analyst` (node eviction o pérdida de quorum).

# Activation conditions

Igual que `agents/oracle-rac-analyst.md#collaboration-delegation-rules`.

# Skills

`rac/topology`, `rac/session-distribution`, `rac/gc-waits`, `rac/crs-resources`, y el resto de `rac/*` según la pregunta.

# Evidence required

`Q-DISC-RAC-001`, `Q-RAC-SESSION-DIST-001` como mínimo; el resto según activación.

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
  version:      config/capability-matrix.yaml → RAC es PLANNED en 10g (no certificado), PARTIAL desde 11gR2 — 10g/11gR1 se reporta UNSUPPORTED/PLANNED, no se activa oracle-rac-analyst
  architecture: si core/context-discovery reporta instance_mode = single, el workflow SE DETIENE aquí (no activa oracle-rac-analyst) y lo informa al DBA — éste es el ejemplo canónico del gate 'architecture'
  environment:  target debe estar en config/allowed-targets.local.yaml
  license:      ninguna capability de este workflow es LICENSE_DEPENDENT por sí sola (RAC topología no requiere Diagnostics Pack)
  privilege:    ESTACK_DIAGNOSTIC_ROLE debe alcanzar GV$SESSION/GV$SERVICES/GV$INSTANCE
  security:     ninguna query requerida puede tener risk_class fuera de R0; ninguna tool srvctl/crsctl de escritura existe en el catálogo
  cost:         Q-RAC-SESSION-DIST-001 es cost_class MEDIUM, max_rows proporcional al número de instancias (policies/rate-limiting-policy.md#gv-y-rac)
  evidence:     reutiliza topología ya cacheada por oracle-discovery-analyst
```

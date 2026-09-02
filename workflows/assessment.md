---
name: assessment
version: 1.0.0
status: active
---

# Trigger/intent

Comando `/assessment`. Evaluación integral y más profunda que un healthcheck — típicamente para onboarding de un ambiente nuevo, auditoría periódica, o antes de un cambio mayor.

# Prerequisites

Target identificado; ventana de tiempo disponible mayor que un healthcheck (assessment es intencionalmente más costoso).

# Discovery requirements

`oracle-discovery-analyst` obligatorio siempre (no se reutiliza cache más allá de la sesión, para garantizar una foto actual completa).

# Minimum agents

`oracle-operations-orchestrator`, `oracle-discovery-analyst`, `oracle-dba-analyst`, `oracle-performance-analyst`, `oracle-security-analyst`, `capacity-analyst`.

# Optional agents

`oracle-rac-analyst`, `oracle-asm-storage-analyst`, `oracle-dataguard-analyst`, `oracle-multitenant-analyst`, `oracle-backup-recovery-analyst`, `oracle-network-analyst`, `os-platform-analyst` — activados según topología detectada (misma lógica que `healthcheck.md#activation-conditions`), pero en `assessment` se activan **todos** los que apliquen a la topología, no sólo bajo demanda.

# Activation conditions

Idénticas a `healthcheck.md`, con la diferencia de que un assessment activa automáticamente todo agente cuya "Activation condition" se cumpla (no requiere que el DBA lo pida explícitamente), porque el objetivo es cobertura integral.

# Skills

Todos los skills `active` de los dominios cuyos agentes se activaron, más `capacity/forecast` siempre (assessment incluye forecast por defecto).

# Evidence required

Todas las queries certificadas relevantes a los dominios activados, con ventanas de tiempo más amplias que `healthcheck` (hasta el máximo de `policies/rate-limiting-policy.md`).

# Stop conditions

Igual que `healthcheck.md`. Adicionalmente: si un dominio activo (ej. RAC) no puede completarse por falta de acceso, el assessment continúa con el resto de dominios y declara ese dominio `UNDETERMINED` explícitamente, en vez de abortar completo.

# Confidence threshold

Igual que `healthcheck.md`, con exigencia adicional de que `recommendations` de un assessment prioricen por severidad y por riesgo de capacidad a 1/3/6 meses.

# Escalation

Cualquier hallazgo `HIGH` activa `incident-root-cause-analyst` si hay indicios de estar activo, o `change-advisor` si es puramente una recomendación de mejora.

# Documentation output

`analysis/ANA-YYYYMMDD-NNN/` completo, más `recommendations.md` extendido con matriz de riesgo. Base típica para `/document assessment --format pptx` (executive assessment).

# Token/context budget

Alto — es el workflow más costoso en cobertura; se gestiona activando agentes en paralelo con Task Packages independientes, nunca un contexto monolítico.

# Security constraints

READ-ONLY ALWAYS. Identidad `ESTACK_DIAG_*`. Ventanas más amplias de evidencia respetan igual los límites de `policies/rate-limiting-policy.md` (no hay excepción por ser assessment).

# Gates

```yaml
gates:
  version:      config/capability-matrix.yaml evaluado por cada dominio candidato; dominios UNSUPPORTED/PLANNED para esta versión no se activan (se reportan como tal, no se omiten silenciosamente)
  architecture: cada agente opcional se activa sólo si su Activation condition se cumple (misma lógica que healthcheck.md, pero aplicada exhaustivamente)
  environment:  target debe estar en config/allowed-targets.local.yaml
  license:      dominios LICENSE_DEPENDENT (AWR/ASH/ADDM, Active Data Guard, multi-PDB) se marcan LICENSE_RESTRICTED si no se confirma licencia; el assessment continúa con el resto
  privilege:    ESTACK_DIAGNOSTIC_ROLE debe alcanzar para cada dominio activado; si no, ese dominio queda INSUFFICIENT_PRIVILEGES
  security:     ninguna query requerida puede tener risk_class fuera de R0
  cost:         queries cost_class HIGH permitidas (ventana amplia es esperada en assessment), siempre con timeout/max_rows reforzados
  evidence:     assessment fuerza discovery nuevo (no reutiliza cache) para garantizar una foto actual completa
```

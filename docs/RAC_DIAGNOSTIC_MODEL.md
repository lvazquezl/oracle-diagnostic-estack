# RAC Diagnostic Model — Fase 4

Modelo conceptual detrás de `oracle-rac-analyst` y sus 31 skills `rac/*` (19 RAC + 12 GI). Referencia complementaria a `agents/oracle-rac-analyst/AGENT.md` — este documento explica el **por qué** del modelo, `AGENT.md` documenta el **contrato**.

## Topología como base

Todo diagnóstico RAC parte de `rac/topology` (nodos/instancias vía `Q-RAC-TOPOLOGY-001`) — ningún otro skill RAC vuelve a determinar esta topología por su cuenta dentro de la misma sesión de análisis, igual principio que el Target Profile de discovery.

## GI absorbido, no un agente separado

`# 2` del prompt de Fase 4 es explícito: *Agents for domains, skills for tasks.* Grid Infrastructure no introduce un agente nuevo — vive en el mismo dominio `rac`, prefijo `gi-` (`rac/gi-version`, `rac/gi-node-status`, `rac/gi-resource-status`, `rac/gi-resource-properties`, `rac/gi-scan`, `rac/gi-vip`, `rac/gi-listeners`, `rac/gi-network-interfaces`, `rac/gi-ocr-status`, `rac/gi-voting-status`, `rac/gi-cluster-health`, `rac/gi-configuration-consistency`). Ver la nota de reconciliación en `skills/REGISTRY.md#rac`.

## Session imbalance: nunca una sola métrica

`Node 1 = 2x sessions` no es, por sí sola, evidencia de `load balancing failure` (`# 14`). `rac/session-distribution` calcula el `imbalance_ratio` pero **siempre** correlaciona con `rac/service-placement` (preferred/available instances), `rac/services` (CLB/RLB goal), workload declarado, pooling conocido, service affinity, e historial de failover (`rac/failover`) antes de clasificar la causa como `CONFIGURATION|CLIENT_BEHAVIOR|POOLING|SERVICE_AFFINITY|WORKLOAD|FAILOVER_HISTORY|INSUFFICIENT_EVIDENCE`. `INSUFFICIENT_EVIDENCE` es un resultado válido y esperado, no una falla del sistema.

## CLB vs. RLB vs. TAF vs. Application Continuity

Cuatro conceptos distintos (`# 16`), nunca tratados como equivalentes:

- **CLB** (`rac/clb`): balanceo de **nuevas** conexiones, vía `CLB_GOAL` (`LONG`/`SHORT`).
- **RLB** (`rac/rlb`): redistribución de trabajo entre conexiones **ya existentes**, vía `RLB_GOAL`/`goal`, requiere que el cliente use FAN/FCF para tener efecto real.
- **TAF**/**Application Continuity**: metadata reconocida cuando existe (mencionada narrativamente en `agents/oracle-rac-analyst/AGENT.md`), pero sin `skill_id` propio en esta fase — no hay query/collector certificado independiente para ellas todavía (candidato a `/change query` futuro).

`rac/load-balancing` es el skill "paraguas" que orquesta CLB+RLB y aplica el modelo de correlación de `# 50`.

## Recursos Clusterware: nunca "OFFLINE = error"

`rac/cluster-resources` clasifica cada recurso `ONLINE|OFFLINE|INTERMEDIATE|UNKNOWN`, pero un recurso con `TARGET: OFFLINE` (deshabilitado deliberadamente) es `INFO`, no una anomalía — sólo `TARGET: ONLINE` + `STATE: OFFLINE` es una anomalía real (`# 36`). Sólo los recursos anómalos se detallan al modelo; el resto se resume como conteo (`# 76`).

## Cache Fusion: topología, no impacto

`rac/global-cache` reconoce indicadores GES/GCS (`gc current`, `gc cr`) desde la óptica de **topología/cluster context** — cuantificar el impacto real en DB Time es responsabilidad exclusiva de `performance/wait-events` vía `oracle-performance-analyst` (`# 53`: "Performance analiza impacto. RAC analiza topología/cluster context"). La colaboración es siempre por `evidence_refs`, nunca reconstruyendo el análisis del otro dominio.

## Boundary con oracle-network-analyst

SCAN/VIP/Listeners aparecen en ambos dominios con propósitos distintos y sin duplicación de recolección:

- `rac/gi-scan`/`rac/gi-vip`/`rac/gi-listeners`: **estado del recurso Clusterware** (¿está ONLINE?).
- `network/scan`/`network/scan-resolution`/`network/service-registration`: **conectividad** (¿resuelve DNS?, ¿está registrado?, ¿el cliente puede conectar?).

## Eviction y quorum: máxima prioridad

`rac/instance-eviction` y `rac/gi-voting-status` escalan inmediatamente a `incident-root-cause-analyst` con severidad `HIGH`/`CRITICAL` ante cualquier indicio de eviction reciente o quorum en riesgo — el único camino de esta fase que no espera correlación adicional antes de escalar, dado el riesgo de disponibilidad del cluster completo.

## Manual Action Contract

Ver `docs/PHASE_4_RAC_GI_ASM_NETWORK.md#manual-action-contract` — todo comando `srvctl`/`crsctl` recomendado por `oracle-rac-analyst` sigue este esquema, con `execution_status: NOT_EXECUTED` siempre.

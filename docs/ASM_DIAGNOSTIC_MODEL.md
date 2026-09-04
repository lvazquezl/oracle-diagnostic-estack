# ASM Diagnostic Model — Fase 4

Modelo conceptual detrás de `oracle-asm-storage-analyst` y sus 12 skills `asm/*`. Complementa `agents/oracle-asm-storage-analyst/AGENT.md`.

## Capacidad real, no filesystem-style

`asm/capacity` nunca calcula capacidad como si ASM fuera un filesystem normal (`# 24`). El finding se basa siempre en el conjunto `TOTAL_MB + FREE_MB + USABLE_FILE_MB + REQUIRED_MIRROR_FREE_MB + REDUNDANCY` (`# 54`) — nunca en `FREE_MB` aislado. Un disk group puede reportar `FREE_MB` aparentemente razonable (ej. 30%) y tener `USABLE_FILE_MB` crítico si la redundancia es `HIGH` (triple mirror) y `REQUIRED_MIRROR_FREE_MB` es alto — ver `tests/fixtures/19c-asm-low-usable-capacity.yaml` para el caso exacto que este modelo está diseñado para detectar correctamente.

## `V$ASM_DISKGROUP_STAT` por defecto, `V$ASM_DISKGROUP` sólo bajo demanda

Hardening heredado de Foundation, reafirmado en `# 23` del prompt de Fase 4: `V$ASM_DISKGROUP` puede disparar disk discovery (costoso); `V$ASM_DISKGROUP_STAT` no. `Q-ASM-TOPOLOGY-001` (monitoreo rutinario) usa exclusivamente `V$ASM_DISKGROUP_STAT`. `V$ASM_DISKGROUP` queda como candidato futuro para un escenario de disk discovery explícito, vía `/change query`, nunca como default.

## Redundancia: metadata reportada, nunca inferida

`asm/redundancy` lee `EXTERNAL`/`NORMAL`/`HIGH`/`FLEX`/`EXTENDED` directamente de ASM — nunca aplica una fórmula universal que asuma un nivel de redundancia no confirmado (`# 25`).

## Salud de discos: sólo anómalos al modelo

`asm/disks` filtra en el propio SQL (`Q-ASM-DISKS-001`) a discos con `HEADER_STATUS != MEMBER` o `READ_ERRS`/`WRITE_ERRS > 0` — un ambiente sano no propaga ningún disco al modelo (`# 76` token efficiency). `PATH` siempre tokenizado (`# 26`).

## Rebalance: visibilidad, nunca control

`asm/rebalance` extrae `operation/state/power/actual/sofar/est_work/est_rate/est_minutes` de `GV$ASM_OPERATION` — nunca cambia `POWER`. Un rebalance activo informa impacto potencial en I/O, pero nunca asume causa de degradación de performance sin correlación explícita con `oracle-performance-analyst` (`# 27`) — la colaboración ASM+Performance existe exactamente para esta correlación, nunca activada automáticamente sólo porque existe un wait I/O (`# 28`).

## Failure groups y redundancia

`asm/failure-groups` valida que la distribución de discos por `FAILGROUP` sea consistente con la redundancia declarada — menos failure groups de los que la redundancia requiere es `HIGH` (riesgo de pérdida de redundancia real), no sólo una observación de balance.

## Manual Action Contract

Ver `docs/PHASE_4_RAC_GI_ASM_NETWORK.md#manual-action-contract` — toda recomendación de `asmcmd`/`ALTER DISKGROUP` sigue este esquema, `execution_status: NOT_EXECUTED` siempre.

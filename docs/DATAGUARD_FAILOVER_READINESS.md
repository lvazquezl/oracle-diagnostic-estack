# Data Guard Failover Readiness — Fase 5

Detalle del skill `dataguard/failover-readiness` — transición de rol de **emergencia/desastre**, nunca ejecutada por este stack. Diferenciado explícitamente de `docs/DATAGUARD_SWITCHOVER_READINESS.md` (`# 31`: switchover = planeado, failover = desastre — nunca el mismo workflow).

## Checks evaluados (`# 30`)

Como mínimo: último redo recibido, último redo aplicado, gaps de transporte/apply, exposición a pérdida de datos, protection mode, estado Broker, estado FSFO, flashback awareness (prerequisito de reinstate), implicaciones de servicio.

## Data loss exposure — cálculo explícito, nunca omitido

Se calcula a partir de la diferencia entre el último redo generado en el primary (si es alcanzable) y el último redo aplicado en el standby. En un escenario real de desastre, el primary típicamente **no** es alcanzable — en ese caso, el gap se calcula sobre la evidencia disponible del standby (último recibido vs. último aplicado) y `data_loss_exposure` se reporta con la salvedad explícita de que el lado primary es `INSUFFICIENT_EVIDENCE`, **nunca asumido en cero pérdida**.

## Readiness Result Contract

Mismo esquema que `docs/DATAGUARD_SWITCHOVER_READINESS.md#readiness-result-contract` — `status: READY|READY_WITH_WARNINGS|NOT_READY|INSUFFICIENT_EVIDENCE`, con `data_loss_exposure` como campo central de este skill en particular.

## Nunca `READY` sin evidencia suficiente (`# 30`)

En un escenario de desastre real, la evidencia disponible es casi siempre parcial (el primary puede estar caído o inalcanzable). `dataguard/failover-readiness` reporta `INSUFFICIENT_EVIDENCE` explícitamente en ese caso — nunca fuerza un resultado `READY`/`NOT_READY` sin la evidencia mínima necesaria.

## Reinstate: sólo awareness de prerequisitos

Tras un failover real (ejecutado manualmente por el DBA, nunca por este stack), el ex-primary requiere `REINSTATE DATABASE` para reincorporarse como standby — este skill sólo evalúa prerequisitos (`FLASHBACK_ON` en el ex-primary, evidencia de que el rango de redo perdido es reinstateable) como parte de `manual_prechecks`, nunca ejecuta el reinstate.

## Ejemplo de resultado con exposición real

Ver `tests/fixtures/19c-failover-exposure.yaml`: gap de 3 secuencias no aplicadas + `apply_lag = 8min` → `data_loss_exposure` reportado explícitamente, `status` según severidad de política (`NOT_READY`/`READY_WITH_WARNINGS`), nunca `READY` sin más contexto.

## Manual Action Contract

Ejecución de failover/reinstate es siempre `manual_action`, `execution_status: NOT_EXECUTED` — nunca ejecutado por este stack bajo ninguna circunstancia, incluso en un escenario de desastre real confirmado. Ver `docs/PHASE_5_ORACLE_DATAGUARD.md#manual-action-contract`.

## Referencia

`skills/dataguard/failover-readiness/SKILL.md`, `agents/oracle-dataguard-analyst/output-schema.yaml#readiness`.

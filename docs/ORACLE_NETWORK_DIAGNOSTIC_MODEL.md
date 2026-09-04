# Oracle Network Diagnostic Model — Fase 4

Modelo conceptual detrás de `oracle-network-analyst` y sus 14 skills `network/*`. Complementa `agents/oracle-network-analyst/AGENT.md`.

## SCAN: conectividad, no recurso Clusterware

Boundary explícito con `oracle-rac-analyst` (ver `docs/RAC_DIAGNOSTIC_MODEL.md#boundary-con-oracle-network-analyst`): este dominio nunca lee estado de recurso Clusterware, sólo resolución DNS, registro de servicio, y path de conexión.

## SCAN DNS resolution: clasificación explícita, nunca binaria

`network/scan-resolution` no se limita a "resuelve/no resuelve" (`# 30`). Clasifica: `RESOLVED`, `NO_RESOLUTION`, `SINGLE_IP_WHERE_MORE_EXPECTED` (arquitectura espera 3 IPs, sólo 1 responde — degradación parcial, no necesariamente fallo total), `INCONSISTENT_ANSWERS`, `SERVFAIL`, `TIMEOUT`. Una inconsistencia como "SCAN configurado con hostname pero runtime muestra IP" se reporta como observación, nunca se asume automáticamente que es un error (`# 29`).

## El modelo de las 6 causas de TNS-12537

`network/tns-errors` nunca reduce `TNS-12537` automáticamente a "problema de listener" (`# 52`) — los 6 dominios posibles (listener/red, exhaustion de recursos del server process, límites OS, path de cliente/aplicación, dispositivo intermedio, terminación de proceso Oracle) se evalúan explícitamente, y se reporta `INSUFFICIENT_EVIDENCE` cuando no hay suficiente correlación en vez de adivinar.

## TNS-12170: dos escenarios, no uno

`network/connection-path` distingue (`# 51`):

1. SCAN resuelve + listener online + servicio registrado → investigar path de red/cliente/firewall (`FIREWALL_SUSPECTED` sólo tras descartar las etapas anteriores, nunca como primera hipótesis).
2. SCAN no resuelve → clasificación `NAME_RESOLUTION` directa.

## Registro de servicio: la causa más común de TNS-12514

`network/service-registration` compara servicios esperados/activos contra los efectivamente registrados en el listener — una ausencia momentánea tras un reinicio reciente de instancia no es necesariamente un error (correlacionar con `rac/instance-state` antes de escalar).

## Interconnect: dos capas, una responsabilidad compartida

`network/interconnect` cubre evidencia OS pura (bonding/VLAN/MTU vía `os-platform-analyst`); `rac/interconnect` correlaciona con `GV$CLUSTER_INTERCONNECTS`/Cache Fusion. Ninguno asume causa sin la evidencia del otro (`# 33`).

## Nunca credenciales en configuración

`network/oracle-net` nunca envía `tnsnames.ora`/`sqlnet.ora` completo si contiene credenciales embebidas — bloqueado por el sanitizer antes de llegar al modelo, no una política aspiracional sino una verificación (`tests/test_no_credential_exposure.sh`).

## Manual Action Contract

Ver `docs/PHASE_4_RAC_GI_ASM_NETWORK.md#manual-action-contract` — ninguna recomendación de este dominio modifica configuración de red/Oracle Net; toda sugerencia usa este esquema, `execution_status: NOT_EXECUTED` siempre.

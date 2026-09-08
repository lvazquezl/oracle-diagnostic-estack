# Data Guard Diagnostic Model — Fase 5

Modelo conceptual detrás de `oracle-dataguard-analyst` y sus 21 skills `dataguard/*`. Complementa `agents/oracle-dataguard-analyst/AGENT.md`.

## Role discovery: nunca por adivinanza

`READ ONLY` no es sinónimo de standby (`# 9`). `dataguard/role` usa `DATABASE_ROLE` como única fuente de verdad, correlacionando `OPEN_MODE`/`DB_UNIQUE_NAME`/`LOG_ARCHIVE_CONFIG` (vía `Q-ORA-PARAMETERS-001`/`V$PARAMETER` — nunca desde `V$DATABASE`, ver `docs/PHASE_5_COMPATIBILITY_HARDENING.md`)/evidencia Broker sólo como confirmación, nunca como determinante.

## Transport lag ≠ apply lag ≠ causa raíz

`dataguard/lag` nunca trata `TRANSPORT LAG` y `APPLY LAG` como sinónimos (`# 13`). Ambas son siempre `confidence: OBSERVATION` por diseño — nunca `PROBABLE_CAUSE` sin al menos 2 señales de correlación. Dos reglas nombradas explícitamente en todo el stack:

- **`# 56`**: *High apply lag is an observation, not a root cause.*
- **`# 57`**: *High transport lag does not prove a network problem.*

Ver `tests/test_transport_lag_not_automatically_network.sh`/`tests/test_apply_lag.sh` para la verificación.

## Gaps: siempre thread-aware

`dataguard/archive-gaps` nunca compara secuencias entre threads como una sola serie (`# 15`, `# 58`). Cinco clasificaciones exhaustivas y mutuamente excluyentes: `TRANSPORT_GAP`, `RECEIVED_NOT_APPLIED`, `THREAD_SPECIFIC_GAP`, `TEMPORARY_GAP`, `UNKNOWN_GAP`.

## SRL: regla documentada, no fórmula ciega

`dataguard/standby-redo-logs` aplica la SRL Readiness Rule (`# 18`) — `SRL groups per thread >= online redo groups per thread + 1` como punto de partida, siempre validado contra el contexto real (tamaño de redo, threads RAC, versión) y documentado explícitamente en cada finding, nunca aplicado ciegamente.

## Switchover ≠ Failover (`# 31`)

Dos skills separados con Readiness Result Contract idéntico en forma pero semántica distinta:

- `dataguard/switchover-readiness`: transición **planificada**. `SWITCHOVER_STATUS` de `V$DATABASE` es un insumo directo.
- `dataguard/failover-readiness`: transición de **emergencia**, calcula `data_loss_exposure` explícitamente — nunca omitido cuando la evidencia lo permite, nunca asumido en cero cuando el primary no es alcanzable (escenario real de desastre).

Ninguno de los dos comparte workflow ni se reutiliza como el otro.

## Broker: visibilidad estructurada, nunca DGMGRL arbitrario

`dataguard/broker` usa exclusivamente los 4 collectors documentados en `docs/DATAGUARD_BROKER_READONLY_COLLECTORS.md` — la salida de `SHOW DATABASE VERBOSE` (potencialmente extensa) se parsea localmente a `role/intended_state/transport_lag/apply_lag/warnings/errors/properties` estructurados, nunca propagada cruda al modelo (`# 25`, `# 54`).

## FSFO/Observer: sólo visibilidad

`dataguard/fsfo`/`dataguard/observer` nunca habilitan/deshabilitan FSFO, nunca cambian thresholds, nunca inician el observer (`# 26`, `# 27`). Si el observer no puede verse con los privilegios disponibles: `INSUFFICIENT_EVIDENCE` explícito, nunca una suposición.

## Active Data Guard: gate propio, distinto del Licensing Gate de AWR/ASH

`# 38` es explícito: no se asume que una standby `READ ONLY` puede usarse libremente para cualquier workload de lectura. `ACTIVE_DATA_GUARD_CHECK` es un gate independiente del Licensing Gate de AWR/ASH (`# 39`) — Data Guard core (rol, topología, transporte, apply, lag, gaps, SRL, Broker) nunca depende de Diagnostics/Tuning Pack.

## Correlation model — cuándo se activa cada dominio vecino

- **RAC** (`# 16`, `# 40`): sólo cuando el primary o standby es RAC y el problema requiere contexto de threads/instancias/servicio — nunca activado por defecto.
- **Network** (`# 40`, `# 57`): transport timeout/TNS/destino inalcanzable → delega a `oracle-network-analyst`, nunca afirma causa de red sin esa evidencia.
- **ASM/Storage** (`# 41`): presión de I/O en apply/destino/SRL → delega a `oracle-asm-storage-analyst`, nunca activado por defecto sólo por un wait I/O.
- **Performance** (`# 42`): apply lag correlacionado con CPU/I/O/parallel recovery/generación de redo → delega a `oracle-performance-analyst`, que aplica su propio Licensing Gate para AWR/ASH.
- **OS** (`# 43`): sólo con evidencia específica de CPU/memoria/I/O/red/límites de proceso.

## Manual Action Contract

Ver `docs/PHASE_5_ORACLE_DATAGUARD.md#manual-action-contract` — todo comando `DGMGRL`/`ALTER DATABASE`/`ALTER SYSTEM` recomendado sigue este esquema, `execution_status: NOT_EXECUTED` siempre.

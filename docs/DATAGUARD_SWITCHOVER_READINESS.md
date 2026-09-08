# Data Guard Switchover Readiness — Fase 5

Detalle del skill `dataguard/switchover-readiness` — transición de rol **planificada**, nunca ejecutada por este stack.

## Checks evaluados (`# 28`)

Como mínimo: roles primary/standby, salud de transporte (`dataguard/transport`), salud de apply (`dataguard/apply`), lag (`dataguard/lag`), gaps (`dataguard/archive-gaps`), salud de Broker si se usa (`dataguard/broker`), `SWITCHOVER_STATUS` (`dataguard/role`), SRLs (`dataguard/standby-redo-logs`), consistencia de protección (`dataguard/protection`), errores de destino (`dataguard/transport`), flashback awareness (`dataguard/role`), implicaciones RAC/servicio (`dataguard/topology`), warnings conocidos (`dataguard/broker`).

Cada check produce `PASS`/`WARNING`/`BLOCKING`. Un check que no puede evaluarse por falta de evidencia se declara en `unsupported_checks`, nunca omitido en silencio.

## Readiness Result Contract (`# 59`)

```yaml
readiness:
  status: READY|READY_WITH_WARNINGS|NOT_READY|INSUFFICIENT_EVIDENCE
  blocking_findings: [string]
  warnings: [string]
  evidence_refs: [EVD-...]
  data_loss_exposure: string|null
  manual_prechecks: [string]
  unsupported_checks: [string]
  confidence: FACT|OBSERVATION|HYPOTHESIS
```

`status` se determina así: `READY` (todo `PASS`), `READY_WITH_WARNINGS` (sin `BLOCKING`, con al menos un `WARNING`), `NOT_READY` (al menos un `BLOCKING`), `INSUFFICIENT_EVIDENCE` (un check crítico no pudo evaluarse). Nunca `READY` sin evidencia suficiente en todos los checks críticos.

## Switchover Manual Plan (`# 29`)

Cuando el DBA solicita explícitamente el procedimiento (nunca generado sin pedido explícito), `dataguard/switchover-readiness` produce:

```text
PRECHECKS                    — confirmación de readiness.status = READY, ventana de mantenimiento activa
CHANGE WINDOW REQUIREMENTS   — duración estimada, congelamiento de cambios recomendado
APPLICATION COORDINATION     — notificación a equipos consumidores, reconexión esperada de clientes
RAC/SERVICE CONSIDERATIONS   — relocación de servicios, reinicio de listeners locales si aplica (# 16)
MANUAL COMMANDS               — DGMGRL SWITCHOVER TO <tokenized-db> (o SQL equivalente), texto para ejecución humana
EXPECTED STATE TRANSITIONS    — primary -> standby, standby -> primary, tiempos esperados por fase
VALIDATION                    — confirmar nuevo primary abierto READ WRITE, nuevo standby aplicando redo
ROLLBACK / FALLBACK           — condiciones bajo las cuales revertir, y que un switchover fallido puede requerir intervención manual adicional
POSTCHECKS                    — servicios/aplicaciones reconectados, Broker Configuration Status = SUCCESS, lag inicial esperado
```

Todo el plan se presenta marcado `MANUAL DBA ACTION` / `NOT EXECUTED` en cada paso — el skill nunca invoca ninguno de estos comandos, sólo genera el texto.

## Ejemplo de resultado NOT_READY

Ver `tests/fixtures/19c-switchover-not-ready.yaml`: `SWITCHOVER_STATUS = NOT ALLOWED` + gap de 10 secuencias sin resolver → `blocking_findings` incluye ambos, `status: NOT_READY`, sin importar si el DBA solicita proceder de todas formas.

## Referencia

`skills/dataguard/switchover-readiness/SKILL.md`, `agents/oracle-dataguard-analyst/output-schema.yaml#readiness`, `docs/PHASE_5_ORACLE_DATAGUARD.md#manual-action-contract`.

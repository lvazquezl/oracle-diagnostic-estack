# RMAN Recovery Readiness Model — Fase 7

## Principio central

> Recovery readiness is based on usable backup metadata and required recovery inputs, not merely on the existence of backup sets.

La existencia de un backup set nunca es, por sí sola, evidencia de que el target puede recuperarse (`# 10` del prompt de Fase 7).

## Restore readiness (`rman/restore-readiness`)

```text
READY                  — controlfile protegido, SPFILE protegido (o PFILE de respaldo conocido),
                          cobertura completa de datafiles, piezas físicamente disponibles.
READY_WITH_WARNINGS    — evidencia mínima completa, pero con riesgo (ej. dependencia de media
                          manager sin confirmación reciente, piezas EXPIRED recientes).
NOT_READY              — falta cualquiera de los requisitos mínimos.
INSUFFICIENT_EVIDENCE  — no hay suficiente metadata para evaluar (nunca se asume READY ni NOT_READY).
```

## Recovery readiness (`rman/recovery-readiness`)

Distingue explícitamente:

```text
restore readiness            — ver arriba, prerequisito.
media recovery readiness     — cadena de archivelog sin gaps desde el backup base.
complete recovery            — recovery hasta el punto actual, sin gaps.
incomplete recovery (PITR)   — recovery hasta un punto anterior con cobertura completa.
controlfile recovery         — awareness, nunca ejecutado.
SPFILE recovery               — awareness, nunca ejecutado.
datafile recovery             — awareness, nunca ejecutado.
tablespace recovery awareness — awareness, nunca ejecutado.
PDB PITR awareness            — ver rman/pdb-pitr-awareness.
```

## PITR / PDB PITR

`rman/pitr-readiness` da awareness de `UNTIL TIME|UNTIL SCN|UNTIL SEQUENCE` — un punto objetivo es alcanzable si existe un backup base anterior y cadena de archivelog sin gaps entre el backup y el punto objetivo. `UNTIL SEQUENCE` siempre correlacionado con `THREAD#` explícito en RAC.

`rman/pdb-pitr-awareness` correlaciona PDB target, contexto CDB, local undo, cobertura de archive, disponibilidad de backup y soporte de versión — delega a `oracle-multitenant-analyst` para topología/local undo. Sin evidencia certificada del detalle completo por versión (mejoras 12.1→12.2), `capability_status: PARTIALLY_SUPPORTED`.

Todo siempre manual — ver Manual Action Contract abajo.

## RPO / RTO

```yaml
recovery_objectives:
  rpo_minutes:
  rto_minutes:
```

Declarado opcionalmente en `docs/TARGET_PROFILE.md#backup_recovery`. Sin requisitos declarados → `INSUFFICIENT_REQUIREMENTS` (`# 31` del prompt) — nunca se inventa un RPO/RTO objetivo. RPO se basa en el recoverable point real (backup base + cadena de archivelog sin gaps hasta ese punto), no sólo en `backup-freshness`. RTO es sólo estimación cualitativa salvo evidencia directa de throughput (`rman/backup-throughput`) o pruebas de restore documentadas.

## Manual Action Contract (`rman/manual-recovery-plan`)

```yaml
manual_action:
  action_id:
  purpose:
  owner_role:
  command:
  prechecks:
  expected_result:
  risk:
  rollback:
  postchecks:
  execution_status: NOT_EXECUTED   # nunca EXECUTED
```

`rman/manual-recovery-plan` genera el runbook completo (scope, scenario, assumptions, required evidence, prechecks, manual commands, expected state transitions, validation, rollback/fallback, postchecks, owner roles) — todo marcado `NOT_EXECUTED` (`# 32`, `# 33` del prompt), sin excepción.

## No implementado (# 53 del prompt)

Productive backup orchestration, restore orchestration, recovery orchestration, scheduler/cron jobs, ejecución de jobs del vendor de backup, configuración automática de RMAN, Security Deep — ninguno de estos existe ni se planea en esta fase.

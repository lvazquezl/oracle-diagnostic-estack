# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN

Baseline: `v0.6.0-multitenant`. Branch: `phase/7-backup-recovery-rman`.

**Nota (superado)**: un defecto de compatibilidad SQL en 10 queries `Q-RMAN-*` (certificaban `FETCH FIRST` con `min_version: "10.2"`, sintaxis 12.1+) fue detectado y corregido en el hardening posterior — ver `docs/PHASE_7_RMAN_LEGACY_SQL_SYNTAX_HARDENING.md`.

## Objetivo

Construir la capa especializada para diagnóstico, assessment y troubleshooting de Oracle Backup & Recovery / RMAN — siempre read-only, nunca ejecuta ninguna operación mutante de RMAN.

## Agente principal

`agents/oracle-backup-recovery-analyst/` — contrato completo (`AGENT.md`, `manifest.yaml`, `routing.yaml`, `context-policy.yaml`, `collaboration.yaml`, `output-schema.yaml`, `tests/README.md`, `CHANGELOG.md`), mismo patrón que RAC/ASM/Network/Data Guard/Multitenant.

`agents/REGISTRY.md` apuntaba a `agents/oracle-backup-recovery-analyst.md` (plano) desde Foundation — ese archivo nunca existió realmente (dangling reference, distinto del caso Multitenant/Data Guard donde sí existía un `.md` plano real). Corregido: el registro ahora apunta a `agents/oracle-backup-recovery-analyst/AGENT.md`.

## Skills

30 skills `rman/*` materializadas (`SKILL.md` + `manifest.yaml` cada una): `configuration`, `backup-inventory`, `backup-status`, `backup-freshness`, `backup-duration`, `backup-throughput`, `full-backup`, `incremental-backup`, `archivelog-backup`, `controlfile-backup`, `spfile-backup`, `retention-policy`, `backup-optimization`, `channels`, `device-types`, `sbt-media-manager`, `fra`, `fra-pressure`, `obsolete-expired-awareness`, `snapshot-controlfile`, `rac-awareness`, `dataguard-awareness`, `multitenant-awareness`, `restore-readiness`, `recovery-readiness`, `pitr-readiness`, `pdb-pitr-awareness`, `troubleshooting`, `channel-contention`, `manual-recovery-plan`.

Reemplaza el placeholder de 14 skills `registered` de Foundation (`skills/REGISTRY.md`) con nombres provisionales nunca materializados (`rman/backup-history`, `rman/sbt`, `rman/controlfile`, `rman/spfile`, `rman/archivelog`, `rman/rac`, `rman/dataguard`, `rman/performance`) — la única excepción `active` de Foundation (`rman/backup-status.md`, plano) fue reestructurada a carpeta completa, mismo patrón que `oracle-multitenant-analyst.md` en Fase 6.

## Query catalog / variants

14 queries certificadas bajo `queries/rman/**` — ver `docs/RMAN_READONLY_QUERY_MODEL.md` para el catálogo completo. Gap pre-existente cerrado: `Q-RMAN-BACKUP-JOB-001` (registrado desde Foundation sin archivo real, `V$RMAN_BACKUP_JOB_DETAILS` verificado real vía WebFetch) materializado de verdad; `Q-RMAN-BACKUPSET-001` reemplazado por `Q-RMAN-BACKUP-SET-001` (mismo propósito, nombre corregido).

Todas las variantes declaran `max` explícito (`"23.0"` o `"11.2"` según variante) — **ninguna declara `max: latest`**, consistente con el patrón establecido en Fases 5/6 (`# 5` del prompt: "No usar `latest: SUPPORTED`"). `Q-RMAN-BACKUP-SET-001` es la única query con split de variantes (legacy 10g-11g sin `CON_ID` / modern 12.1+ con `CON_ID`) — mismo patrón verificado que `PDB_PLUG_IN_VIOLATIONS` en Fase 6.

## RMAN configuration

`rman/configuration` (`Q-RMAN-CONFIGURATION-001`, `V$RMAN_CONFIGURATION`) — retention policy, backup optimization, default device type, controlfile autobackup (+ format), parallelism DISK/SBT, channel configuration, snapshot controlfile name, archivelog deletion policy, encryption/compression awareness. Nunca ejecuta `CONFIGURE`.

## Backup inventory / status / freshness

`rman/backup-inventory`, `rman/backup-status`, `rman/backup-freshness` — normalizan tipo/nivel real (`BACKUP_TYPE`+`INCREMENTAL_LEVEL`, nunca heurística de `TAG`), estado real (`COMPLETED|COMPLETED WITH WARNINGS|FAILED|RUNNING|UNKNOWN`, nunca inventado), y completeness (`COMPLETE|PARTIAL|STALE|UNKNOWN|INSUFFICIENT_EVIDENCE`) — nunca se afirma recoverability por la sola existencia de un backup set.

## Full / incremental backups

`rman/full-backup`, `rman/incremental-backup` — distinguen FULL real de INCREMENTAL LEVEL 0/1 DIFFERENTIAL/CUMULATIVE, cadena de niveles, block change tracking.

## Archivelog backups

`rman/archivelog-backup` (`Q-RMAN-ARCHIVELOG-BACKUP-001`, `Q-RMAN-ARCHIVED-LOG-COVERAGE-001`) — cobertura thread-aware (`THREAD# + SEQUENCE#`, nunca mezclado entre threads), distingue `not backed up`/`not applied`/`not archived`.

## Controlfile / SPFILE backups

`rman/controlfile-backup`, `rman/spfile-backup` — evalúan protección real (autobackup + backup explícito), nunca restauran.

## Retention policy / backup optimization

`rman/retention-policy` — compara retención configurada contra RPO declarado (`INSUFFICIENT_REQUIREMENTS` sin requisitos). `rman/backup-optimization` — contexto para interpretar inventario, sin generar hallazgos propios.

## Channels / device types / SBT-media manager

`rman/channels`, `rman/device-types`, `rman/sbt-media-manager` — visibilidad de canales/parallelism/device type, sin credenciales, sin ejecutar acciones del vendor. Commvault/Simpana como conocimiento de dominio, no agente nuevo.

## FRA / FRA pressure

`rman/fra`, `rman/fra-pressure` (`Q-RMAN-FRA-USAGE-001`) — correlaciona presión con archivelog generation, cadencia de backup, retención, deletion policy, flashback logs, restore points, Data Guard. Nunca borra archivos.

## Obsolete / expired awareness

`rman/obsolete-expired-awareness` — sólo vía ingest de `REPORT OBSOLETE`/`CROSSCHECK` ya ejecutados manualmente; sin vista V$ equivalente, nunca ejecutados por el e-stack.

## Snapshot controlfile

`rman/snapshot-controlfile` — riesgo de path local-only en RAC (`ORA-00245`), nunca ejecuta `CONFIGURE SNAPSHOT CONTROLFILE NAME`.

## RAC / Data Guard / Multitenant awareness

`rman/rac-awareness`, `rman/dataguard-awareness`, `rman/multitenant-awareness` — ver `docs/RMAN_RAC_DATAGUARD_MULTITENANT_INTEGRATION.md`.

## Restore / recovery readiness

`rman/restore-readiness`, `rman/recovery-readiness`, `rman/pitr-readiness`, `rman/pdb-pitr-awareness` — ver `docs/RMAN_RECOVERY_READINESS_MODEL.md`.

## Channel contention

`rman/channel-contention` — nunca asume causa Oracle única, correlaciona RMAN parallelism/media manager concurrency/server limits/SBT pools/job scheduler.

## RMAN output parsers

`parsers/rman/` (`show_all_parser.py`, `list_backup_parser.py`, `list_backup_summary_parser.py`, `report_obsolete_parser.py`, `report_need_backup_parser.py`, `restore_preview_parser.py` + `common.py`) — ingieren texto de comandos ya ejecutados manualmente por el DBA. La fase nunca ejecuta esos comandos. Todo tratado como DATA, sanitizado/tokenizado.

## RMAN command safety

Ver `docs/RMAN_COMMAND_SAFETY_MODEL.md` — clasificación `READ_ONLY_METADATA|ANALYTICAL_PREVIEW|MUTATING/BLOCKED` completa.

## RPO / RTO

Ver `docs/RMAN_RECOVERY_READINESS_MODEL.md#rpo--rto`. Extensión opcional de `docs/TARGET_PROFILE.md#backup_recovery`.

## Manual recovery plan

`rman/manual-recovery-plan` — runbooks completos, siempre `execution_status: NOT_EXECUTED`.

## Evidence / sanitization / token optimization

Ver `docs/RMAN_DIAGNOSTIC_MODEL.md`.

## Capability Matrix

`config/capability-matrix.yaml`/`docs/CAPABILITY_MATRIX.md` — dominio `rman` actualizado de `PARTIAL` (Foundation) a `SUPPORTED` 10g-23ai, `future_status: COMPATIBILITY_VALIDATION_REQUIRED` (nunca `latest: SUPPORTED`).

## Documentación

`docs/RMAN_DIAGNOSTIC_MODEL.md`, `docs/RMAN_READONLY_QUERY_MODEL.md`, `docs/RMAN_COMMAND_SAFETY_MODEL.md`, `docs/RMAN_RECOVERY_READINESS_MODEL.md`, `docs/RMAN_RAC_DATAGUARD_MULTITENANT_INTEGRATION.md`, `docs/RMAN_READONLY_PRIVILEGES.md` — creados. `README.md`, `ARCHITECTURE.md`, `SECURITY.md`, `CAPABILITY_MATRIX.md`, `CHANGELOG.md`, `docs/TARGET_PROFILE.md`, `workflows/healthcheck.md`, `workflows/diagnose.md`, `workflows/assessment.md` — actualizados.

## Seguridad

READ-ONLY ALWAYS. Sin `SYSDBA` permanente (`docs/RMAN_READONLY_PRIVILEGES.md`). Ninguna capacidad real de `BACKUP|RESTORE|RECOVER|DELETE|CROSSCHECK|CHANGE|CONFIGURE|CATALOG|UNCATALOG|DUPLICATE|SWITCH DATABASE|ALLOCATE CHANNEL|RELEASE CHANNEL` — verificado por 15 tests dedicados de seguridad (sección 46 del prompt).

## Known limitations

- `rman/multitenant-awareness`/`rman/pdb-pitr-awareness` degradan a `PARTIALLY_SUPPORTED` cuando el catálogo no certifica el detalle completo de PDB-level RMAN backup/restore por versión (mejoras 12.1→12.2) — no se inventa un nivel de soporte no verificado.
- `rman/sbt-media-manager` no integra con ningún vendor específico (Commvault/Simpana, NetBackup, etc.) más allá de awareness genérica — integración profunda de vendor está fuera de alcance (`# 24` del prompt).
- Gateway MCP / ejecución real de collectors semánticos permanece fuera de alcance de esta fase (documentado, no runtime-executable).

## NOT_CERTIFIED

Ninguna query/collector RMAN queda sin certificar dentro del alcance declarado en `# 6` del prompt (17 vistas listadas, todas certificadas o reutilizadas de Oracle Core).

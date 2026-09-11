# RMAN Command Safety Model — Fase 7

Clasificación completa de comandos RMAN según su capacidad real en el e-stack. Ver `agents/oracle-backup-recovery-analyst/manifest.yaml#forbidden_capabilities` para la lista normativa; este documento es la referencia narrativa.

## Categorías

```text
READ_ONLY_METADATA    — sólo lectura de metadata ya persistida. Modelado como query certificada
                         (queries/rman/**) cuando existe una vista V$/GV$ equivalente, o como
                         ingest de texto ya producido por el DBA (parsers/rman/**) cuando no.
ANALYTICAL_PREVIEW     — analiza una operación sin ejecutarla realmente. El e-stack NUNCA invoca
                         este comando — sólo modela/parsea texto que el DBA ya produjo
                         ejecutándolo manualmente.
MUTATING               — cambia estado real (backup, catálogo, configuración, archivos). Nunca
                         implementado, nunca expuesto como capacidad, bloqueado explícitamente.
BLOCKED                — sinónimo operativo de MUTATING en este documento: cualquier comando que
                         cambia estado.
```

## Mapeo completo

| Comando | Categoría | Implementación |
|---|---|---|
| `SHOW ALL` | READ_ONLY_METADATA | `Q-RMAN-CONFIGURATION-001` (V$RMAN_CONFIGURATION) + `parsers/rman/show_all_parser.py` (ingest de texto) |
| `LIST BACKUP` | READ_ONLY_METADATA | `Q-RMAN-BACKUP-SET-001`/`Q-RMAN-BACKUP-PIECE-001` + `parsers/rman/list_backup_parser.py` |
| `LIST BACKUP SUMMARY` | READ_ONLY_METADATA | `Q-RMAN-BACKUP-SET-001` + `parsers/rman/list_backup_summary_parser.py` |
| `REPORT NEED BACKUP` | READ_ONLY_METADATA | `parsers/rman/report_need_backup_parser.py` (sin vista V$ equivalente — sólo ingest) |
| `REPORT OBSOLETE` | READ_ONLY_METADATA | `parsers/rman/report_obsolete_parser.py` (sin vista V$ equivalente — sólo ingest) |
| `RESTORE ... PREVIEW` | ANALYTICAL_PREVIEW | `parsers/rman/restore_preview_parser.py` — el e-stack nunca ejecuta ni siquiera el `PREVIEW`; sólo interpreta texto ya producido por el DBA |
| `BACKUP` (cualquier variante) | BLOCKED | No implementado. Recomendación manual vía Manual Action Contract |
| `RESTORE` (sin `PREVIEW`) | BLOCKED | No implementado |
| `RECOVER` | BLOCKED | No implementado |
| `DELETE` (OBSOLETE/EXPIRED/cualquiera) | BLOCKED | No implementado |
| `CROSSCHECK` | BLOCKED | No implementado |
| `CHANGE` | BLOCKED | No implementado |
| `CONFIGURE` | BLOCKED | No implementado — visibilidad vía `Q-RMAN-CONFIGURATION-001`, nunca escritura |
| `CATALOG` / `UNCATALOG` | BLOCKED | No implementado |
| `REGISTER DATABASE` / `RESYNC CATALOG` / `UPGRADE CATALOG` | BLOCKED | No implementado (Recovery Catalog, `# 7` del prompt) |
| `DUPLICATE` | BLOCKED | No implementado |
| `SWITCH DATABASE` | BLOCKED | No implementado |
| `ALLOCATE CHANNEL` / `RELEASE CHANNEL` (para jobs reales) | BLOCKED | No implementado — visibilidad de canales vía `Q-RMAN-BACKUP-DEVICE-001`/`Q-RMAN-CONFIGURATION-001` |

## Semantic collectors

Contratos permitidos (`# 16` del prompt), todos allowlisted y sin ejecución productiva en esta fase:

```text
get_rman_configuration                 → Q-RMAN-CONFIGURATION-001 / parsers/rman/show_all_parser.py
get_backup_summary                     → Q-RMAN-STATUS-001, Q-RMAN-BACKUP-JOB-001 / parsers/rman/list_backup_summary_parser.py, report_obsolete_parser.py
get_backup_inventory                   → Q-RMAN-BACKUP-SET-001, Q-RMAN-BACKUP-PIECE-001 / parsers/rman/list_backup_parser.py
get_archivelog_backup_summary          → Q-RMAN-ARCHIVELOG-BACKUP-001, Q-RMAN-ARCHIVED-LOG-COVERAGE-001 / parsers/rman/report_need_backup_parser.py
get_controlfile_backup_status          → Q-RMAN-CONTROLFILE-BACKUP-001
get_spfile_backup_status               → Q-RMAN-SPFILE-BACKUP-001
get_snapshot_controlfile_configuration → Q-RMAN-CONFIGURATION-001 (filtrado a SNAPSHOT CONTROLFILE NAME)
get_restore_preview                    → parsers/rman/restore_preview_parser.py (ANALYTICAL_PREVIEW)
```

Cada collector sigue el Collector Contract reutilizado de fases previas: `collector_id`, `purpose`, `command_family`, `version_support`, `identity`, `privileges`, `timeout`, `max_output`, `sanitizer`, `cost`, `side_effect_class` (siempre `READ_ONLY` en este dominio), `validation_status`, `parser`, `fallback`. No hay concatenación de comandos (`# 16`).

## Falsos positivos en documentación manual

Los comandos manuales referenciados en `rman/manual-recovery-plan` (ej. `RESTORE DATABASE`, `RECOVER DATABASE UNTIL TIME ...`) aparecen como texto literal dentro de un `manual_action.command` con `execution_status: NOT_EXECUTED` — los tests de seguridad (`tests/test_no_restore_execution.sh`, etc.) usan una ventana de contexto (nunca/never/prohibido/NOT_EXECUTED) antes de la línea para distinguir esto de una capacidad real, mismo patrón que Fases 4-6.

## Non-negotiables

> NO ARBITRARY RMAN. NO RESTORE EXECUTION. NO RECOVER EXECUTION. NO DELETE EXECUTION.
> NO CROSSCHECK EXECUTION. NO CHANGE EXECUTION. NO CONFIGURE EXECUTION.
> NO CATALOG / UNCATALOG EXECUTION. NO DUPLICATE EXECUTION. NO SWITCH DATABASE EXECUTION.
> NO CHANNEL ALLOCATION FOR REAL BACKUP OR RESTORE JOBS.

Ver `tests/test_no_arbitrary_rman.sh` y los 14 tests `test_no_*_execution.sh` de la sección 46 del prompt de Fase 7.

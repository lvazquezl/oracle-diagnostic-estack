# Data Guard Read-Only Queries — Fase 5

Vista legible del catálogo `queries/dataguard/` — fuente de verdad es cada archivo `.md` individual (`queries/REGISTRY.md`).

## Catálogo

| query_id | vista(s) | dominio de uso |
|---|---|---|
| `Q-DG-ROLE-001` | `V$DATABASE` | `dataguard/role`, `dataguard/protection`, `dataguard/topology` |
| `Q-DG-STATS-001` | `V$DATAGUARD_STATS` | `dataguard/lag`, `dataguard/switchover-readiness`, `dataguard/failover-readiness` |
| `Q-DG-DEST-001` | `V$ARCHIVE_DEST`, `V$ARCHIVE_DEST_STATUS` | `dataguard/transport`, `dataguard/archive-destinations` |
| `Q-DG-ARCHIVED-LOG-001` | `V$ARCHIVED_LOG` | `dataguard/archive-gaps` (detalle complementario) |
| `Q-DG-ARCHIVE-GAP-001` | `V$ARCHIVE_GAP` | `dataguard/archive-gaps`, `dataguard/lag`, `dataguard/switchover-readiness`, `dataguard/failover-readiness` |
| `Q-DG-MANAGED-PROCESS-001` | `V$MANAGED_STANDBY`/`GV$MANAGED_STANDBY` | `dataguard/apply`, `dataguard/processes`, `dataguard/real-time-apply` |
| `Q-DG-SRL-001` | `V$STANDBY_LOG`, `V$LOG` | `dataguard/standby-redo-logs`, `dataguard/switchover-readiness` |

## Principios (`# 8` del prompt de Fase 5)

Toda query reutiliza el mismo modelo establecido en fases anteriores: Logical Query ID, Query Variant Contract, Query Variant Resolver, Oracle Dictionary Compatibility Model, SQL Static Validator, `container_scope`, `database_role_scope`, `open_mode` scope (implícito en `database_role_scope: STANDBY`/`PRIMARY`), `cost_class`, `validation_status`. Ninguna query es de rango único fabricado — `V$MANAGED_STANDBY`/`GV$MANAGED_STANDBY` se documentan como selección por arquitectura (no una variante versionada) en `Q-DG-MANAGED-PROCESS-001`, siguiendo el mismo criterio que `Q-DG-ROLE-001`/RAC en Fase 4 para distinciones `V$`/`GV$`.

## Budget de `V$ARCHIVED_LOG` (`# 55`)

`Q-DG-ARCHIVED-LOG-001` es la única query `cost_class: MEDIUM` del catálogo — siempre parametrizada por `:time_window_hours`, `GROUP BY thread#`, `max_rows: 500`. Nunca un scan histórico ilimitado.

## Gap pre-existente corregido

`Q-DG-STATS-001`/`Q-DG-ARCHIVE-GAP-001` figuraban "materializadas" en `queries/REGISTRY.md` desde Foundation sin archivo `.md` real — mismo patrón detectado y corregido en Fase 4 (RAC/ASM). Corregido en esta fase: ambas ahora tienen archivo real bajo `queries/dataguard/`, mismos IDs, sin duplicar.

## Referencia

`queries/REGISTRY.md`, `config/query-compatibility-matrix.yaml`, `compatibility/oracle-dictionary/views.yaml` (sección Fase 5).

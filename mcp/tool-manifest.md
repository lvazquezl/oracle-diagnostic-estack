# Tool Manifest — MCP Diagnostic Gateway

Cada tool mapea 1:1 (o 1:N) a entradas certificadas de [`queries/REGISTRY.md`](../queries/REGISTRY.md). Ninguna tiene un parámetro de texto libre para SQL/shell.

| tool | input schema | output (resumen) | queries certificadas detrás |
|---|---|---|---|
| `get_database_identity(target)` | `{target: string}` | version, edition, role, cdb, open_mode | `Q-DISC-IDENTITY-001` |
| `get_instance_status(target)` | `{target: string}` | instance_mode, instance_number, status por instancia | `Q-DISC-INSTANCE-001` |
| `get_rac_topology(target)` | `{target: string}` | nodos, instancias, versión GI | `Q-DISC-RAC-001` |
| `get_session_distribution(target, service?)` | `{target: string, service?: string}` | sesiones por instancia/servicio | `Q-RAC-SESSION-DIST-001`, `Q-RAC-SERVICE-PLACEMENT-001` |
| `get_wait_events(target, window_start, window_end, source?)` | `{target, window_start, window_end, source?: awr\|ash\|statspack}` | top wait events | `Q-PERF-WAIT-AWR-001`, `Q-PERF-WAIT-ASH-001`, `Q-PERF-WAIT-STATSPACK-001` |
| `get_top_sql_metrics(target, window_start, window_end)` | `{target, window_start, window_end}` | SQL_ID, plan hash, métricas (sin SQL text por defecto) | `Q-PERF-TOPSQL-001` *(registered — Fase 3)* |
| `get_tablespace_usage(target)` | `{target: string}` | uso/autoextend por tablespace | `Q-DBA-TBS-USAGE-001`, `Q-DBA-TBS-DATAFILES-001` |
| `get_asm_usage(target)` | `{target: string}` | espacio usable por disk group | `Q-ASM-DG-USAGE-001`, `Q-ASM-OPERATION-001` |
| `get_dataguard_status(target)` | `{target: string}` | rol, lag, gaps, destinos | `Q-DG-STATS-001`, `Q-DG-ARCHIVE-GAP-001` |
| `get_listener_status(target)` | `{target: string}` | estado de listener/SCAN listener, servicios registrados | `Q-NET-LISTENER-STATUS-001` *(registered — Fase 4)* |
| `get_os_cpu(target)` | `{target: string}` | load, run queue | `Q-OS-<plataforma>-CPU-001` *(registered por plataforma — Fase 6, salvo Linux representativo)* |
| `get_os_memory(target)` | `{target: string}` | uso de memoria/swap/HugePages | `Q-OS-LINUX-MEM-001` (Linux, active); resto `registered` |
| `get_os_io(target)` | `{target: string}` | latencia/throughput por dispositivo | `Q-OS-<plataforma>-IO-001` *(registered)* |
| `get_os_network(target)` | `{target: string}` | interfaces, errores, latencia | `Q-OS-<plataforma>-NET-001` *(registered)* |
| `get_rman_status(target)` | `{target: string}` | último backup por tipo, estado FRA | `Q-RMAN-BACKUP-JOB-001`, `Q-RMAN-BACKUPSET-001` |
| `get_security_posture(target)` | `{target: string}` | usuarios privilegiados, profiles, DB links | `Q-SEC-USERS-001` *(registered — Fase 5)* |
| `get_capacity_trend(target, resource, horizon_months)` | `{target, resource, horizon_months: 1\|3\|6}` | serie histórica + proyección | `Q-CAP-TIMESERIES-001` |
| `get_pdb_state(target)` | `{target: string}` | estado por PDB | `Q-CDB-PDB-STATE-001`, `Q-CDB-CONTAINERS-001` |

## Reglas del manifest

- Toda tool declara `timeout`/`max_rows` heredados de su(s) query(s) certificada(s) — el más restrictivo aplica si hay varias.
- Toda tool pasa por el Sanitizer antes de devolver resultado (ver `sanitizers/data-classification-policy.md`).
- Una tool marcada con queries `registered` (no `active`) no está disponible aún en el Gateway real — su presencia aquí es de catálogo/roadmap, materializada en la fase indicada.
- Ninguna tool acepta un parámetro `sql`, `command`, o `raw_query` de texto libre.

# OS Read-Only Privileges — Fase 9

## Principio

Identidad OS de sólo lectura, sin `root`/`sudo`/`Administrator`/privileged shell bajo ninguna
circunstancia. Ver `docs/OS_READONLY_COLLECTOR_MODEL.md#identity-model` para el modelo completo.

## Privilegios por collector (resumen)

| Collector | Requiere privilegio elevado | Fallback sin privilegio |
|---|---|---|
| `get_os_identity`/`get_cpu_topology`/`get_memory_summary`/`get_swap_summary` | No | N/A |
| `get_hugepages_status`/`get_thp_status` | No (lectura de `/proc`, `/sys`) | N/A |
| `get_process_limits`/`get_open_files_limits`/`get_ipc_limits`/`get_aio_limits` | No (`sysctl -n`, `ulimit`/`prlimit` de sólo lectura) | N/A |
| `get_ephemeral_port_range`/`get_socket_summary` | No | N/A |
| `get_filesystem_usage`/`get_inode_usage`/`get_mount_summary` | No | N/A |
| `get_block_device_summary` | No | N/A |
| `get_multipath_summary` | Puede requerir grupo `disk`/similar | `INSUFFICIENT_PRIVILEGES` + `MANUAL COLLECTION INSTRUCTION` |
| `get_interfaces`/`get_routes`/`get_bonding_summary`/`get_vlan_summary` | No | N/A |
| `get_name_resolution`/`get_time_sync_status` | No | N/A |
| `get_oracle_process_summary`/`get_grid_process_summary` | No (filtrado por owner, sin necesidad de ver todos los procesos del sistema) | N/A |
| `get_cgroup_summary` | Puede requerir lectura de cgroup del propio scope | `INSUFFICIENT_PRIVILEGES` si el scope no es visible |

## Sin privilegio disponible

Nunca escalamiento automático — `capability_status: INSUFFICIENT_PRIVILEGES` +
`MANUAL COLLECTION INSTRUCTION` para que un administrador autorizado ejecute el comando
equivalente y entregue la salida como evidencia ya sanitizada (mismo patrón que GI Identity
Model, Fase 4).

## Grupos/roles OS recomendados para la identidad diagnóstica

```text
Linux: usuario dedicado de sólo lectura, sin membresía en oinstall/dba/asmadmin salvo lo
       estrictamente necesario para lectura de /proc/sys específicos ya allowlisted.
Solaris: rol RBAC de sólo lectura (profile-based), nunca root.
Windows: cuenta de servicio de sólo lectura (Performance Log Users / Event Log Readers cuando
         aplique), nunca Administrator.
```

## Prohibido

Ninguna capacidad de `sudo`/`su`/`runas Administrator`, ningún shell privilegiado, ninguna
escalación de privilegio bajo ninguna circunstancia — verificado por
`tests/test_no_root_required.sh`, `tests/test_no_sudo_required.sh`.

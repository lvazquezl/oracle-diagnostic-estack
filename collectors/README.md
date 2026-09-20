# Collectors — especificación

Estado: **especificación certificada**, no runtime ejecutable (el Gateway MCP local de la Fase 13 existe en `mcp_gateway/` con adaptador de fixture; los adaptadores reales siguen `DISABLED`/`CONTRACT_ONLY` y `NOT_INTEGRATION_TESTED`). Fase 2 (Oracle Core) amplía el contrato de `oracle-sql-collector` para cubrir las ~20 queries `Q-ORA-*` nuevas, y agrega el contrato de `oracle-diag-collector` (ADR/alert log).

Un collector ejecuta exactamente una query/comando certificado de `queries/REGISTRY.md` contra el ambiente real y devuelve el resultado crudo al Sanitizer — nunca directamente al modelo.

## Contrato de un collector

- Recibe: `query_id`, parámetros validados por el Gateway (ya acotados a `timeout`/`max_rows`).
- Ejecuta: exactamente esa query certificada, con la identidad `ESTACK_DIAG_*`, contra el target indicado.
- Nunca interpola parámetros no validados en SQL/shell (previene injection).
- Devuelve: resultado crudo + metadata (`collector`, `timestamp`, `target`, `duration`) para construir el `EVD-*` correspondiente.
- Nunca cachea credenciales; las obtiene del credential provider local de la estación de trabajo en cada invocación.

## Tipos de collector

| collector | transporte | plataformas |
|---|---|---|
| `oracle-sql-collector` | JDBC/Oracle Client, sesión read-only `ESTACK_DIAG_*` | todas las que soportan Oracle Client |
| `oracle-rman-collector` | `V$RMAN_*`/catálogo vía el mismo canal SQL (no invoca `rman` como shell) | todas |
| `os-linux-collector` | lectura de `/proc`, `/sys` vía canal certificado (no shell interactivo libre) | Oracle Linux, RHEL, SUSE |
| `os-solaris-collector` | `kstat`/`/proc` equivalentes, sólo lectura | Solaris |
| `os-aix-collector` | comandos de estado AIX (`vmstat`, `lparstat` en modo lectura, sin flags de cambio) | AIX |
| `os-windows-collector` | PerfCounters/WMI de sólo lectura | Windows Server |
| `os-hpux-collector` | comandos de estado HP-UX de sólo lectura | HP-UX (legacy) |
| `net-config-collector` | lectura de archivos `tnsnames.ora`/`sqlnet.ora`/`listener.ora` y `listener.log` (ventana acotada) | todas |
| `get_oracle_net_security_configuration` (Fase 8 — hardening) | semántico, sobre el mismo canal de `net-config-collector` pero acotado a `sqlnet.ora`: extrae ÚNICAMENTE los parámetros allowlisted `SQLNET.ENCRYPTION_*`/`SQLNET.CRYPTO_CHECKSUM_*` y metadata TCPS — nunca el archivo completo, nunca `V$PARAMETER`/`V$SPPARAMETER` (SQLNET.\* no es un parámetro de instancia). Sin certificación runtime, degrada a `PARTIALLY_SUPPORTED` con `evidence_source: MANUAL_SANITIZED_ORACLE_NET_CONFIGURATION` (contenido ya sanitizado provisto por el DBA, mismo patrón que los parsers RMAN de Fase 7). Ver `skills/network/oracle-net-security/SKILL.md`, propiedad de `oracle-network-analyst` | todas |
| `oracle-diag-collector` (Fase 2) | lectura acotada de `alert.log`/ADR home (`Q-ORA-DIAGNOSTICS-ALERTLOG-001`) — ventana de líneas/tiempo, nunca el archivo completo; XML alert log (11g+) parseado estructuralmente, texto plano (10g) por patrón de fecha/`ORA-` | todas — ruta resuelta por convención de plataforma, nunca hardcodeada |
| `gi-clusterware-collector` (Fase 4) | ejecución allowlisted de `crsctl`/`srvctl`/`olsnodes`/`ocrcheck` (sólo subcomandos de lectura/status — nunca `start`/`stop`/`modify`/`add`/`delete`/`relocate`), parseada por `parsers/rac/*.py` | Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server — ver `docs/GI_READONLY_COLLECTORS.md` |
| `asm-cli-collector` (Fase 4) | `asmcmd lsdg` — sólo respaldo/discovery de `asm/topology`; el monitoreo rutinario de capacidad usa `oracle-sql-collector` contra `V$ASM_DISKGROUP_STAT`, no este collector | ídem |
| `net-listener-collector` (Fase 4) | `lsnrctl status` — nunca `stop`/`reload`/`set` | todas |
| `os-network-collector` (Fase 4) | equivalentes semánticos de sólo lectura por plataforma (`ip`/`ss`/`getent`/`nslookup`) — `get_interfaces`/`get_routes`/`get_socket_summary`/`get_name_resolution`/`get_host_identity`; nunca cambia bonding/VLAN/route/MTU/firewall/sysctl | Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server |
| `os-platform-collector` (Fase 9) | ~25 collectors semánticos allowlisted (`get_os_identity`, `get_cpu_topology`, `get_memory_summary`, `get_swap_summary`, `get_hugepages_status`, `get_thp_status`, `get_process_limits`, `get_open_files_limits`, `get_ipc_limits`, `get_aio_limits`, `get_ephemeral_port_range`, `get_filesystem_usage`, `get_inode_usage`, `get_mount_summary`, `get_block_device_summary`, `get_multipath_summary`, `get_bonding_summary`, `get_vlan_summary`, `get_mtu_summary`, `get_time_sync_status`, `get_oracle_process_summary`, `get_grid_process_summary`, `get_cgroup_summary`, más los Windows/Solaris equivalentes) — nunca `sysctl -w`/`multipathd reconfigure`/edición de `limits.conf`/systemd units/red/storage/SSH/Windows Registry/servicios. Reutiliza `get_interfaces`/`get_routes`/`get_socket_summary`/`get_name_resolution`/`get_host_identity` (Fase 4, sin duplicar `collector_id`). Ver `docs/OS_READONLY_COLLECTOR_MODEL.md`, propiedad de `os-platform-analyst` | Oracle Linux, RHEL, SUSE, LinuxONE, Solaris, Windows Server |

Ver `docs/GI_READONLY_COLLECTORS.md` para el Collector Contract completo (schema, catálogo GI/Clusterware/ASM/Network, GI Identity Model) de los collectors de Fase 4, y `docs/OS_READONLY_COLLECTOR_MODEL.md` para el catálogo completo de Fase 9.

## Certificación

Un collector nuevo o modificado sigue el mismo flujo `/change query` (para las queries que ejecuta) + `/change compatibility` (si introduce una plataforma nueva), con SECURITY VALIDATION obligatoria antes de HUMAN REVIEW.

## Límites obligatorios (todo collector)

Timeout, max rows/output, cancelación, clasificación de costo — heredados de la entrada de `queries/REGISTRY.md` que ejecuta. Ver `policies/rate-limiting-policy.md`.

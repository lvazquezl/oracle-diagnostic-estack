# OS Read-Only Collector Model — Fase 9 (OS Platform Diagnostics & Hardening)

Extiende el modelo de collectors de `collectors/README.md` (Fase 1/2) y `docs/GI_READONLY_COLLECTORS.md`
(Fase 4) con el Collector Contract específico del dominio OS — mismo principio: *OS diagnosis can
be performed with certified read-only semantic collectors without granting the e-stack
administrative execution capabilities* (`# 87` del prompt de Fase 9: "COLLECTORS MUST BE SEMANTIC
AND ALLOWLISTED").

## Principio

Ningún collector de este dominio es `execute_shell(command)`/`run_command(command)`/
`powershell(command)`/`read_file(path)`/`cat(path)` genérico (`# 7` del prompt: "No crear...").
Cada uno mapea **exclusivamente** a un comando/API allowlisted específico, sin concatenación de
parámetros no validados.

## Collector Contract (extendido, `# 8` del prompt)

```yaml
collector_id: string
purpose: string
platforms: [string]              # plataformas donde este collector aplica
supported_versions: [string]     # versiones/kernels donde está certificado
required_identity: string        # identidad diagnóstica de sólo lectura, nunca root/sudo/Administrator
required_privileges: [string]
command_family: string           # comando/API allowlisted exacto, sin flags de cambio
allowlist: [string]              # subcomandos/claves específicas permitidas
timeout_seconds: number
max_output_bytes: number
sanitizer: string                # referencia a sanitizers/data-classification-policy.md
cost: LOW|MEDIUM|HIGH|BLOCKED
side_effect_class: READ_ONLY|BLOCKED   # BLOCKED si no puede garantizarse READ_ONLY
validation_status: DOCUMENTATION_VALIDATED|FIXTURE_VALIDATED|LAB_VALIDATED|RUNTIME_VALIDATED
parser: string|null
fallback: string
```

`side_effect_class` es siempre `READ_ONLY` para todo collector habilitado — si no puede
garantizarse, el collector queda `BLOCKED`, nunca se habilita "por ahora".

## Catálogo — Linux

| collector_id | comando allowlisted | cost | validation_status |
|---|---|---|---|
| `get_os_identity` | `uname -a`, `/etc/os-release` (lectura acotada) | LOW | FIXTURE_VALIDATED |
| `get_cpu_topology` | `lscpu` | LOW | FIXTURE_VALIDATED |
| `get_memory_summary` | `/proc/meminfo`, `free` | LOW | FIXTURE_VALIDATED |
| `get_swap_summary` | `/proc/swaps`, `vmstat` (campos `si`/`so`) | LOW | FIXTURE_VALIDATED |
| `get_hugepages_status` | `/proc/meminfo` (`HugePages_*`, `Hugepagesize`) | LOW | FIXTURE_VALIDATED |
| `get_thp_status` | `/sys/kernel/mm/transparent_hugepage/enabled` | LOW | FIXTURE_VALIDATED |
| `get_process_limits` | `ulimit`/`prlimit` de sólo lectura del usuario/sesión de diagnóstico (`# 9`: "ulimit read-only via controlled shell wrapper", "prlimit read-only where certified"), `/proc/sys/kernel/pid_max` — awareness de nivel host, nunca evidencia del proceso Oracle/Grid | LOW | FIXTURE_VALIDATED |
| `get_process_effective_limits` | `/proc/<pid>/limits` **PID-scoped** — PID debe provenir de `get_oracle_process_summary`/`get_grid_process_summary`, nunca aceptado como input arbitrario (`# 12`/`# 271`-`# 352` del prompt PHASE 9 — EFFECTIVE PROCESS LIMITS & SYSTEMD/PAM SOURCE-OF-TRUTH HARDENING); `INSUFFICIENT_PRIVILEGES` si no accesible, nunca `sudo`/`su`/escalamiento | LOW | FIXTURE_VALIDATED |
| `get_service_limit_configuration` | `systemctl show <unit> --property=LimitNOFILE,LimitNPROC,TasksMax` — unit allowlisted/validada contra el PID objetivo, nunca `systemctl show <arbitrary user input>` sin validación | LOW | FIXTURE_VALIDATED |
| `get_pam_limits_applicability` | inspecciona la pila PAM efectiva de un `service` allowlisted/validado (sigue `include`/`substack` con `max_depth`/`visited set`, nunca el archivo completo) para confirmar si `pam_limits.so` está realmente cargado — nunca infiere applicability de la sola presencia de `PAMName=` (`# 152`-`# 320` del prompt PHASE 9 — PAM LIMITS APPLICABILITY & PROCESS CONSTRAINT SCOPE MICRO-HARDENING) | LOW | FIXTURE_VALIDATED |
| `get_pam_limits_policy_source` | dado un `service` con `pam_limits.applicability == APPLICABLE`, parsea los argumentos de la(s) invocación(es) real(es) de `pam_limits.so` en la pila efectiva (`conf=`, `debug`, `set_all`, `utmp_early`) — determina `DEFAULT` (sin `conf=`, awareness de `limits.conf`/`limits.d`) vs. `CUSTOM_CONF` (con `conf=<path>`, path tokenizado, `limits.conf`/`limits.d` NUNCA asumidos concurrentes); preserva cada invocación por separado si hay más de una, nunca colapsadas (`# 169`-`# 392` del prompt PHASE 9 — PAM LIMITS POLICY SOURCE & PID CONTROLLER IDENTITY MICRO-HARDENING) | LOW | FIXTURE_VALIDATED |
| `get_pam_limit_configuration` | lectura acotada de `/etc/security/limits.conf`/`limits.d/*` **o** del `conf=<path>` custom confirmado por `get_pam_limits_policy_source` — claves específicas del usuario Oracle/Grid vía collector semántico, nunca el archivo completo; sólo se correlaciona cuando `get_pam_limits_applicability` confirme `APPLICABLE` **y** la fuente (default o custom) esté determinada (ver `os/ulimits`) | LOW | FIXTURE_VALIDATED |
| `get_unit_cgroup_path` | resuelve `systemd unit → control group path` vía collector semántico (`systemctl show <unit> --property=ControlGroup` o equivalente) — nunca adivinado por convención de nombre del servicio (`# 414`-`# 427` del prompt de micro-hardening) | LOW | FIXTURE_VALIDATED |
| `get_open_files_limits` | `/proc/sys/fs/file-max`, `ulimit -n` de sólo lectura (configuración del usuario, no PID-scoped — el valor efectivo del proceso viene de `get_process_effective_limits`) | LOW | FIXTURE_VALIDATED |
| `get_ipc_limits` | `sysctl -n kernel.shmmax/shmall/shmmni/sem` (claves allowlisted específicas, nunca `sysctl -a`) | LOW | FIXTURE_VALIDATED |
| `get_aio_limits` | `sysctl -n fs.aio-max-nr`, `/proc/sys/fs/aio-nr` | LOW | FIXTURE_VALIDATED |
| `get_ephemeral_port_range` | `sysctl -n net.ipv4.ip_local_port_range` | LOW | FIXTURE_VALIDATED |
| `get_socket_summary` | `ss` (ya certificado desde Fase 4) | MEDIUM | FIXTURE_VALIDATED |
| `get_filesystem_usage` | `df` | LOW | FIXTURE_VALIDATED |
| `get_inode_usage` | `df -i` | LOW | FIXTURE_VALIDATED |
| `get_mount_summary` | `/proc/mounts`, `mount` (lectura) | LOW | FIXTURE_VALIDATED |
| `get_block_device_summary` | `lsblk` | LOW | FIXTURE_VALIDATED |
| `get_multipath_summary` | `multipath -ll` (`# 9`/`# 33`: "read-only when permitted", nunca `multipathd reconfigure`) | MEDIUM | FIXTURE_VALIDATED |
| `get_interfaces` | `ip addr` (ya certificado desde Fase 4) | LOW | FIXTURE_VALIDATED |
| `get_routes` | `ip route` (ya certificado desde Fase 4) | LOW | FIXTURE_VALIDATED |
| `get_bonding_summary` | `/proc/net/bonding/<bond>`, `ip link` | LOW | FIXTURE_VALIDATED |
| `get_vlan_summary` | `ip -d link show` | LOW | FIXTURE_VALIDATED |
| `get_mtu_summary` | derivado de `get_interfaces`/`get_bonding_summary`/`get_vlan_summary` | LOW | FIXTURE_VALIDATED |
| `get_name_resolution` | `getent hosts`/`nslookup` (ya certificado desde Fase 4) | LOW | FIXTURE_VALIDATED |
| `get_time_sync_status` | `chronyc tracking`/`sources`, `timedatectl` | LOW | FIXTURE_VALIDATED |
| `get_host_identity` | lectura de `/etc/hostname` (ya certificado desde Fase 4) | LOW | FIXTURE_VALIDATED |
| `get_oracle_process_summary` | `ps` filtrado por owner/familia (nunca dump completo) | MEDIUM | FIXTURE_VALIDATED |
| `get_grid_process_summary` | `ps` filtrado por familia GI | MEDIUM | FIXTURE_VALIDATED |
| `get_cgroup_summary` | lectura de `cpu.max`/`memory.max`/`pids.max` (cgroup v2) o equivalentes v1, con `cgroup_path_token`/`parent_path_token`/`relation` (`UNIT`/`PARENT`/`CHILD`/`DELEGATED`/`OTHER`) para el modelo de jerarquía de cgroups | LOW | FIXTURE_VALIDATED |

## Catálogo — Windows (`# 10` del prompt)

| collector_id | API/comando allowlisted | cost | validation_status |
|---|---|---|---|
| `get_windows_os_identity` | WMI `Win32_OperatingSystem` (sólo lectura) | LOW | DOCUMENTATION_VALIDATED |
| `get_windows_cpu_topology` | WMI `Win32_Processor` | LOW | DOCUMENTATION_VALIDATED |
| `get_windows_memory_summary` | WMI `Win32_OperatingSystem`/`Win32_PhysicalMemory` | LOW | DOCUMENTATION_VALIDATED |
| `get_windows_pagefile_summary` | WMI `Win32_PageFileUsage` | LOW | DOCUMENTATION_VALIDATED |
| `get_windows_network_summary` | WMI `Win32_NetworkAdapterConfiguration` (sólo lectura) | LOW | DOCUMENTATION_VALIDATED |
| `get_windows_service_status` | consulta de estado de servicio (sólo lectura — nunca start/stop) | LOW | DOCUMENTATION_VALIDATED |
| `get_windows_time_sync_status` | W32Time query (sólo lectura) | LOW | DOCUMENTATION_VALIDATED |

**Ningún collector Windows ejecuta PowerShell arbitrario** (`# 10`: "No exponer PowerShell
arbitrario") — cada uno mapea a una consulta WMI/API específica, sin parámetros de script
concatenados.

## Catálogo — Solaris (`# 11` del prompt)

| collector_id | comando allowlisted | cost | validation_status |
|---|---|---|---|
| `get_os_identity` (Solaris) | `uname -a`, `prtdiag` (header) | LOW | DOCUMENTATION_VALIDATED |
| `get_cpu_topology` (Solaris) | `psrinfo -pv` | LOW | DOCUMENTATION_VALIDATED |
| `get_memory_summary` (Solaris) | `prtconf`, `kstat` | LOW | DOCUMENTATION_VALIDATED |
| `get_swap_summary` (Solaris) | `swap -s` | LOW | DOCUMENTATION_VALIDATED |
| `get_filesystem_usage` (Solaris) | `df -h` | LOW | DOCUMENTATION_VALIDATED |
| `get_interfaces`/`get_routes` (Solaris) | `ipadm`, `netstat -rn` | LOW | DOCUMENTATION_VALIDATED |
| `get_bonding_summary` (Solaris, terminología "aggregation") | `dladm show-aggr` | LOW | DOCUMENTATION_VALIDATED |

**Nunca se asume sintaxis Linux en Solaris** (`# 11`: "No asumir sintaxis Linux") — cada
collector Solaris mapea a su propio comando nativo, nunca una traducción automática de la
sintaxis Linux equivalente.

## Effective vs. configured process limits (PHASE 9 hardening)

`get_process_effective_limits(pid)` es la evidencia **primaria** de lo que realmente aplica a un
proceso Oracle/Grid — `get_process_limits` (sesión de diagnóstico), `get_service_limit_configuration`
(systemd) y `get_pam_limit_configuration` (PAM) son fuentes **configuradas** que explican la
política, nunca sustituyen al valor leído directamente del PID cuando está disponible. El PID
objetivo siempre proviene de `get_oracle_process_summary`/`get_grid_process_summary` (ya
certificados), nunca de un input de usuario sin validar — ver `docs/PHASE_9_EFFECTIVE_PROCESS_LIMITS_SYSTEMD_PAM_HARDENING.md`.

`get_service_limit_configuration` y `get_pam_limit_configuration` **nunca se combinan mediante una
regla universal de mínimo** — un proceso lanzado directamente por systemd normalmente no pasa por
PAM, así que `get_pam_limit_configuration` sólo se correlaciona cuando exista evidencia explícita
de que la unit systemd declara `PAMName=`. Ver `os/process-limits`, `os/systemd-limits`,
`os/ulimits`.

Solaris: sin mecanismo certificado equivalente a `/proc/<pid>/limits` en esta fase →
`PARTIALLY_SUPPORTED` para `get_process_effective_limits`, nunca se simula paridad con Linux.
Windows: límites/recursos de proceso y job objects → `PARTIALLY_SUPPORTED`, sólo si existe una API
certificada equivalente; de lo contrario `PARTIALLY_SUPPORTED` sin collector dedicado.

## PAM applicability vs. PAM session (PHASE 9 micro-hardening)

`PAMName=<service>` en una unit systemd prueba únicamente que se **solicita** una sesión PAM para
ese servicio — nunca que `pam_limits.so` esté realmente cargado en la pila PAM efectiva de ese
servicio. `get_pam_limits_applicability(service)` es el único collector autorizado para confirmar
esa presencia; sin él (o sin resultado legible), la applicability es siempre
`INSUFFICIENT_EVIDENCE`, nunca `APPLICABLE` por inferencia de `PAMName=`. Ningún collector de este
dominio es un lector de archivo PAM genérico (`read_pam_file(path)`/`read_file(path)`/
`cat_file(path)`/`grep_file(path, pattern)`) — el collector sólo inspecciona servicios PAM
previamente validados/allowlisted.

`get_pam_limits_applicability` sigue el grafo de `include`/`substack` de la configuración PAM de
forma controlada (`pam_limits.so` puede estar declarado en un archivo incluido, nunca se asume que
debe aparecer literalmente en el archivo principal del servicio) — protegido contra include loops
recursivos, includes duplicados y explosión de profundidad mediante `max_depth`/`visited set` o
equivalente. Nunca se envía el contenido completo de archivos PAM al modelo — sólo `service`,
`module`, `control`, la relación de includes y la presencia/ausencia de `pam_limits.so`.

## Process constraint scopes (PHASE 9 micro-hardening)

`RLIMIT_NPROC` (scope `USER`), `TasksMax` (scope `UNIT`), `pids.max` (scope `CGROUP`) y `pid_max`
(scope `HOST`) son constraints paralelos con contadores y scopes distintos — ningún collector ni
skill de este dominio calcula un "límite efectivo" como el mínimo numérico entre ellos. La
restricción realmente vinculante (`binding_constraint`) se determina en
`os/process-limits#binding-constraint-model` usando scope + membership del proceso + uso actual +
headroom de cada constraint, nunca comparando sólo los valores configurados.

## PAM limits policy source: DEFAULT vs. CUSTOM_CONF (PHASE 9 micro-hardening)

`pam_limits.so` confirmado activo (`applicability: APPLICABLE`) no implica por sí solo que
`/etc/security/limits.conf`/`limits.d/*` sean la fuente de policy efectiva — el módulo acepta
argumentos, y `conf=<path>` reemplaza la fuente por defecto para esa invocación específica.
`get_pam_limits_policy_source` parsea esos argumentos y determina `mode: DEFAULT|CUSTOM_CONF|
INSUFFICIENT_EVIDENCE|NOT_APPLICABLE` — con `conf=` presente, `limits.conf`/`limits.d` **nunca**
se agregan como si fueran fuentes concurrentes. Una pila PAM con más de una invocación de
`pam_limits.so` (ej. una con `conf=` y otra sin él) se representa como registros de policy-source
**separados**, nunca colapsados en uno. El path custom de `conf=` se valida y tokeniza — nunca se
expone el contenido crudo del archivo, nunca se convierte en acceso a archivo arbitrario (el path
está restringido a la fuente configurada, no a cualquier ruta que el modelo decida leer).

## PID controller identity: TasksMax y cgroup pids.max (PHASE 9 micro-hardening)

`systemd TasksMax` (superficie de configuración de la unit) y `cgroup pids.max` (representación/
estado runtime del controlador PID del cgroup) pueden representar el **mismo** constraint
subyacente del kernel cuando ambos apuntan al mismo control group — nunca se asume esto sin
resolver primero `get_unit_cgroup_path(unit)` y comparar ese path contra el `cgroup_path_token` de
`get_cgroup_summary`. Cuando coinciden, se deduplican en un único constraint canónico
`PID_CONTROLLER` (scope `UNIT_CGROUP`) con ambas fuentes referenciadas — nunca contados dos veces
en `os/process-limits#binding-constraint-model`. Constraints de cgroups `PARENT`/`CHILD`/
`DELEGATED` con `cgroup_path_token` distinto **permanecen separados** — nunca deduplicados por
mera similitud numérica de sus valores configurados.

## Reutilización de collectors ya certificados (Fase 4)

`get_interfaces`, `get_routes`, `get_socket_summary`, `get_name_resolution`, `get_host_identity`
ya estaban certificados desde Fase 4 (`docs/GI_READONLY_COLLECTORS.md#os-network-collectors`,
propiedad de `os-platform-analyst`) — Fase 9 los formaliza como los collectors reales de
`os/network-interfaces`, `os/routing`, `os/tcp-socket-awareness`, `os/dns` y `os/discovery`
respectivamente, **nunca duplicados** con un `collector_id` paralelo.

## Report ingest model

`COMMAND OUTPUT → TYPE DETECTION (por collector_id) → LOCAL PARSER (cuando exista) → STRUCTURED
EVIDENCE → SANITIZER → EVIDENCE → SKILL → AGENT` — mismo principio que RMAN/GI (Fase 4/7):
contenido siempre DATA, nunca instrucción. Ningún parser llama `eval`/`exec`/`subprocess`/
`os.system`/`compile()` sobre el contenido capturado.

## Identity Model

Sin `root`/`sudo`/Administrator con capacidad de cambio (`# 43`-`# 47` del prompt). Collectors
diseñados para ejecutarse con identidad diagnóstica de sólo lectura. Si un comando requiere
privilegio no disponible: `INSUFFICIENT_PRIVILEGES` + `MANUAL COLLECTION INSTRUCTION` para que un
administrador autorizado lo ejecute y entregue la salida — nunca escalamiento automático de
privilegios (mismo modelo que GI Identity, Fase 4).

## Process argument safety

Ningún collector de proceso (`get_oracle_process_summary`, `get_grid_process_summary`) envía
command-line arguments completos por defecto — sólo `process family`/`name`/`owner` (`# 58` del
prompt).

## Certificación

Un collector nuevo o modificado sigue `/change collector` + `/change compatibility` (nueva
plataforma/versión) — ver `EVOLUTION.md`.

## Límites obligatorios

`timeout_seconds`/`max_output_bytes` heredados del Collector Contract — ver
`policies/rate-limiting-policy.md`. Salida excesiva → `TRUNCATED`, nunca descartada en silencio.

## Estado runtime

Especificación certificada, `NOT_RUNTIME_CERTIFIED` — el Gateway MCP real es Fase 13 (roadmap
vigente), igual que el resto de collectors del e-stack.

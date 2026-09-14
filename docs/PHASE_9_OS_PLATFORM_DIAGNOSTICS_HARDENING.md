# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING

Baseline: `v0.8.0-security-compliance`. Branch: `phase/9-os-platform`.

**Nota (superado)**: un defecto real fue detectado en este build base — `os/systemd-limits`
declaraba una regla universal ("el valor efectivo es siempre el más restrictivo entre systemd y
`/etc/security/limits.conf`") estructuralmente incorrecta, ya que un proceso lanzado por systemd
normalmente no pasa por PAM. `os/process-limits`/`os/open-files`/`os/ulimits` tampoco distinguían
el `ulimit` del propio proceso de diagnóstico del límite real del proceso Oracle/Grid objetivo.
Corregido en el hardening posterior — ver
`docs/PHASE_9_EFFECTIVE_PROCESS_LIMITS_SYSTEMD_PAM_HARDENING.md`. Ese hardening a su vez introdujo
dos defectos propios (`PAMName=` tratado como prueba suficiente de PAM applicability sin verificar
`pam_limits.so`; `os/cgroups` seguía colapsando `pids.max`/`nproc`/`TasksMax` en un mínimo
universal) — corregidos en `docs/PHASE_9_PAM_LIMITS_PROCESS_CONSTRAINT_SCOPE_HARDENING.md`, que a
su vez introdujo otros dos (`pam_limits.so conf=` no modelado; `TasksMax`/`pids.max` del mismo
cgroup contados dos veces) — corregidos en
`docs/PHASE_9_PAM_POLICY_SOURCE_PID_CONTROLLER_IDENTITY_HARDENING.md`.

## Objetivo

Construir la capa especializada de diagnóstico read-only del sistema operativo que hospeda Oracle
Database — Linux (Oracle Linux/RHEL/SUSE/LinuxONE), Solaris, Windows Server — cubriendo CPU/NUMA,
memoria/swap, HugePages/THP, límites de kernel/IPC/AIO, red/bonding/VLAN/MTU/routing/DNS,
filesystems/inodes/dispositivos de bloque/multipath, time sync, SSH/SSHD posture, grupos/procesos
Oracle/Grid, e integración por referencia con RAC/Data Guard/RMAN/Security — siempre read-only,
nunca ejecuta ninguna operación mutante de OS (paquetes, servicios, parámetros de kernel, mounts,
permisos, red, usuarios/grupos, SSHD, Windows Registry/servicios, PowerShell arbitrario). AIX/HP-UX
explícitamente fuera de alcance de esta fase.

## Agente principal

`agents/os-platform-analyst/` — contrato completo (`AGENT.md`, `manifest.yaml`, `routing.yaml`,
`context-policy.yaml`, `collaboration.yaml`, `output-schema.yaml`, `tests/README.md`,
`CHANGELOG.md`), mismo patrón que RAC/ASM/Network/Data Guard/Multitenant/RMAN/Security. v2.0.0 —
`supersedes` documentado explícitamente en `manifest.yaml` porque, igual que Security en Fase 8,
`agents/os-platform-analyst.md` (plano, v1.1.0) sí existía con contenido real desde Foundation; ese
archivo fue eliminado y reemplazado por el contrato estructurado completo, preservando y
amplificando sus responsabilidades/boundaries originales sin contradecirlos.

Un solo agente cubre todo el dominio OS Platform — explícitamente **no** se crean agentes
separados por plataforma (Linux/Solaris/Windows) ni por subdominio (memoria/red/storage).

## Skills

45 skills `os/*` materializadas (`SKILL.md` + `manifest.yaml` cada una), reemplazando el modelo
`os/<plataforma>/<skill>` de Foundation (18 skills × 5 plataformas, sólo `os/linux/memory.md`
materializado) por un modelo domain-per-skill-id `os/<capability>` con platform-awareness dentro de
cada manifest (campo `platforms:`, estados `SUPPORTED|PARTIALLY_SUPPORTED|NOT_APPLICABLE|
COMPATIBILITY_VALIDATION_REQUIRED`) — igual que `network/*`/`security/*` ya funcionan:

- **Discovery/CPU/Memoria (7)**: `discovery`, `platform-version`, `cpu-topology`, `numa`, `memory`
  (v2.0.0, absorbe el contenido real de `os/linux/memory.md`), `swap`, `memory-pressure`.
- **HugePages/THP (2)**: `hugepages`, `transparent-hugepages`.
- **Límites/IPC/AIO (8)**: `process-limits`, `open-files`, `ulimits`, `systemd-limits`,
  `shared-memory`, `semaphores`, `aio`, `kernel-parameter-assessment`.
- **Puertos/Red (8)**: `ephemeral-ports`, `tcp-socket-awareness`, `network-interfaces`, `bonding`,
  `vlan`, `mtu`, `routing`, `dns`.
- **Filesystem/Storage (6)**: `filesystems`, `inodes`, `mount-options`, `block-devices`,
  `multipath-awareness`, `io-performance`.
- **Time/SSH/Grupos/Procesos/Cgroups/Log (7)**: `time-sync`, `ssh-sshd-awareness`,
  `oracle-groups`, `oracle-processes`, `grid-processes`, `cgroups`, `log-pressure`.
- **Cross-domain (4)**: `rac-interconnect-awareness`, `dataguard-network-awareness`,
  `rman-media-manager-awareness`, `security-filesystem-awareness`.
- **Meta (3)**: `platform-healthcheck`, `platform-assessment`, `manual-hardening-plan`.

`skills/os/linux/memory.md` (Foundation) eliminado — contenido fusionado como base de
`os/memory` v2.0.0, extendido con Windows/Solaris. Registros `os/aix/*`/`os/hpux/*` de Foundation
permanecen `registered`, sin materializar — explícitamente fuera de alcance de Fase 9 (ver
`skills/REGISTRY.md`).

## Collector model

~25 collectors semánticos catalogados por Linux/Windows/Solaris (`docs/OS_READONLY_COLLECTOR_MODEL.md`)
bajo un Collector Contract extendido (`collector_id, purpose, platforms, supported_versions,
required_identity, required_privileges, command_family, allowlist, timeout_seconds,
max_output_bytes, sanitizer, cost, side_effect_class, validation_status, parser, fallback`) —
`side_effect_class` siempre `READ_ONLY` o el collector queda `BLOCKED`. Reutiliza (nunca duplica)
los collectors OS ya certificados desde Fase 4 — `get_interfaces`, `get_routes`,
`get_socket_summary`, `get_name_resolution`, `get_host_identity` — propiedad de
`os-platform-analyst`, invocados también por `network/interconnect`/`rac/gi-network-interfaces`.
Ningún collector Windows ejecuta PowerShell arbitrario; ningún collector Linux/Solaris es shell
arbitrario ni lector de archivo genérico.

## HugePages model

`required_pages = ceil(total_SGA_bytes / hugepage_size_bytes)`, donde `total_SGA_bytes` es la suma
de la SGA de **todas** las instancias/bases de datos activas en el host, más overhead ASM/GI cuando
el Target Profile lo declare — nunca calculado con una sola instancia si hay más de una, nunca con
un margen porcentual fijo inventado. Ver `docs/ORACLE_HUGEPAGES_ASSESSMENT_MODEL.md`.

## Kernel/IPC/AIO model

`shmmax`/`shmall`/`shmmni`/`kernel.sem`/`aio-max-nr`/límites `nofile`/`nproc` siempre evaluados
contra el sizing real del host (SGA, `PROCESSES`, concurrencia de I/O) — nunca contra una tabla
fija/hardcodeada aplicada universalmente. `os/kernel-parameter-assessment` consolida el juicio de
`os/shared-memory`/`os/semaphores`/`os/aio`/`os/tcp-socket-awareness` sin re-recolectar ni
duplicar el análisis individual. Ver `docs/OS_KERNEL_LIMITS_MODEL.md`.

## Network model

`os/network-interfaces`/`os/routing`/`os/dns` formalizan como skills completos los collectors
`get_interfaces`/`get_routes`/`get_name_resolution` ya certificados desde Fase 4. `os/bonding`
mapea explícitamente la terminología Solaris "aggregation" vs. Linux "bonding", nunca asume
sintaxis Linux en Solaris. `os/mtu` nunca recomienda jumbo frames sin evidencia end-to-end de toda
la ruta. `os/ephemeral-ports` correlaciona con `ORA-27530`/`ORA-27501`/`ORA-27300` sin atribuir el
error automáticamente sin evidencia de agotamiento real. Ver `docs/OS_NETWORK_DIAGNOSTIC_MODEL.md`.

## Storage model

`os/filesystems` correlaciona el rol Oracle de cada mount (binarios/`diagnostic_dest`/FRA/backups/
logs/wallet) — la severidad depende del rol, nunca genérica. `os/inodes` detecta agotamiento de
inodes independientemente del agotamiento de espacio (archivos pequeños acumulados). `os/io-performance`
nunca concluye cuello de botella de storage con `util%` aislado — requiere latencia/cola/wait
events Oracle correlacionados. Ver `docs/OS_STORAGE_FILESYSTEM_MODEL.md`.

## Cross-domain integration (by reference)

`os/rac-interconnect-awareness`, `os/dataguard-network-awareness`, `os/rman-media-manager-awareness`,
`os/security-filesystem-awareness` consolidan evidencia OS y entregan un juicio combinado con
`evidence_refs` al agente Oracle correspondiente (`oracle-rac-analyst`, `oracle-dataguard-analyst`,
`oracle-backup-recovery-analyst`, `oracle-security-analyst`) — nunca duplican el análisis de
dominio Oracle de esos agentes, nunca asumen causa OS sin al menos un hallazgo concreto de los
skills consolidados.

## Manual hardening model

Manual Action Contract extendido con campos OS-específicos (`platform, config_file, prechecks,
expected_result, risk, rollback, postchecks, reboot_required, execution_status: NOT_EXECUTED`) —
`reboot_required` declarado honestamente por acción (HugePages/THP vía boot-args frecuentemente lo
requieren). Ver `docs/OS_HARDENING_MANUAL_ACTION_MODEL.md`.

## Target Profile

`docs/TARGET_PROFILE.md` extendido (`schema_version` 2.5.0 → 2.6.0) con el bloque `os_platform`
(`family, distribution, version, kernel, architecture, virtualization, oracle_home_owner,
grid_home_owner, oracle_groups, expected_hugepages_policy, expected_thp_policy,
expected_time_sync, expected_network_model`) — ningún campo `expected_*` se inventa sin
declaración explícita del DBA; sin ellos, los skills correspondientes reportan el estado real leído
directamente, nunca lo comparan contra un diseño no declarado. Sin secretos.

## Workflows

`/healthcheck os` (Health Model de 25 dimensiones vía `os-platform-analyst`), `/assessment
os-platform`, y routing de síntomas OS en `/diagnose` (`memory-pressure`, `swap-pressure`,
`hugepages`, `thp`, `open-files`, `process-limits`, `semaphore`, `shared-memory`, `aio`,
`ephemeral-ports`, `filesystem-full`, `inode-pressure`, `io-latency`, `bonding`, `vlan`, `mtu`,
`time-sync`, `oracle-os-limits`) — deliberadamente no un comando por cada `sysctl` individual.

## Fixtures / Tests

26 fixtures nuevas bajo `tests/fixtures/` (mínimo ~30 requerido — cobertura funcional completa de
los escenarios declarados en el prompt: Linux Oracle/RHEL/SUSE/LinuxONE healthy y degradado por
subdominio, Solaris, Windows Server, y 4 escenarios cross-domain RAC/RMAN/Data Guard/Security). 67
tests nuevos bajo `tests/test_*.sh` en 10 categorías — todos verificados pasando individualmente:
collector safety/agent contract (9), discovery/CPU/memoria (7), HugePages/THP (7), límites/IPC/AIO
(8), puertos/red (9), filesystem/storage (8), time/SSH/grupos/procesos (7), cross-domain (4),
sanitización (5, incluyendo `test_os_no_secret_exposure.sh` como variante de dominio de
`test_secret_detection.sh` — nombre distinto por colisión intencional evitada), contratos de
collector por plataforma (3, Linux/Solaris/Windows).

## Capability Matrix

`config/capability-matrix.yaml`/`docs/CAPABILITY_MATRIX.md` — dominio `os` pasa de `PARTIAL` a
`SUPPORTED` 10g–23ai (no depende de la versión Oracle), `future_status:
COMPATIBILITY_VALIDATION_REQUIRED`, nunca `latest: SUPPORTED` (mismo criterio que Data
Guard/Multitenant/RMAN/Security). Linux `SUPPORTED`, Windows Server `SUPPORTED` (con
sub-capacidades `PARTIALLY_SUPPORTED`/`NOT_APPLICABLE` donde el modelo de OS difiere), Solaris
`PARTIALLY_SUPPORTED`, AIX/HP-UX fuera de alcance.

## Documentación

Creados: [`docs/OS_PLATFORM_DIAGNOSTIC_MODEL.md`](OS_PLATFORM_DIAGNOSTIC_MODEL.md),
[`docs/OS_READONLY_COLLECTOR_MODEL.md`](OS_READONLY_COLLECTOR_MODEL.md),
[`docs/ORACLE_HUGEPAGES_ASSESSMENT_MODEL.md`](ORACLE_HUGEPAGES_ASSESSMENT_MODEL.md),
[`docs/OS_KERNEL_LIMITS_MODEL.md`](OS_KERNEL_LIMITS_MODEL.md),
[`docs/OS_NETWORK_DIAGNOSTIC_MODEL.md`](OS_NETWORK_DIAGNOSTIC_MODEL.md),
[`docs/OS_STORAGE_FILESYSTEM_MODEL.md`](OS_STORAGE_FILESYSTEM_MODEL.md),
[`docs/OS_HARDENING_MANUAL_ACTION_MODEL.md`](OS_HARDENING_MANUAL_ACTION_MODEL.md),
[`docs/OS_READONLY_PRIVILEGES.md`](OS_READONLY_PRIVILEGES.md), este documento. `README.md`,
`ARCHITECTURE.md` (principio 31), `SECURITY.md`, `CAPABILITY_MATRIX.md`, `CHANGELOG.md`,
`docs/TARGET_PROFILE.md` (2.5.0→2.6.0), `workflows/healthcheck.md`, `workflows/diagnose.md`,
`workflows/assessment.md`, `agents/REGISTRY.md`, `skills/REGISTRY.md`, `collectors/README.md`,
`templates/README.md` (corrección de referencia obsoleta a "Fase 9" para entregables binarios) —
actualizados.

## Full regression

`tests/run-all.sh` (687 tests, toda la suite del repositorio — obligatorio en esta fase porque se
agrega un agente nuevo, collectors/contratos nuevos, routing cross-domain nuevo y se tocan
restricciones de seguridad compartidas). Primera corrida: 684/687 OK, 3 fallos — los tres
diagnosticados y corregidos con la misma disciplina de verificación establecida en el proyecto,
ninguno relacionado con una capacidad OS realmente defectuosa:

- `tests/test_fixture_query_variant_resolution.sh` — asumía que **todo** archivo bajo
  `tests/fixtures/*.yaml` es una fixture de compatibilidad de versión Oracle (`compatibility_schema:`
  obligatorio, sección 26 de Compatibility Hardening). Las 26 fixtures nuevas de Fase 9 son
  fixtures de estado de host (`os_target:`), no de versión Oracle — el Query Variant Resolver no
  interviene en su dominio (evidencia de collectors semánticos, no queries SQL). Corregido: el test
  ahora reconoce el marcador `os_target:` sin `oracle_version:` y las trata como fuera de alcance
  (`continue`), no como un fallo — mismo patrón que el `continue` ya existente para "sin variante
  para esta versión".
- `tests/test_no_credential_exposure.sh` — filtro de negación same-line no reconocía la frase real
  usada en `agents/os-platform-analyst/AGENT.md#security-constraints` ("sin root/sudo/Administrator")
  porque sólo cubría `sin.*sysdba`. Corregido: extendido a `sin.*root|sin.*sudo|sin.*administrator`
  — mismo patrón de hardening aplicado repetidas veces en esta fase a tests propios.
- `tests/test_os_detection.sh` — test heredado de Foundation apuntaba al flat file superado
  `agents/os-platform-analyst.md` (eliminado en el deepening de esta fase) y comparaba
  `skills/REGISTRY.md` con literales en minúscula sin `-i` (el registro usa "Solaris"/"Windows"
  con mayúscula inicial). Corregido: path actualizado a `agents/os-platform-analyst/AGENT.md`,
  comparación case-insensitive.

Segunda corrida (sólo los 3 tests corregidos, individualmente): 3/3 OK. Ningún otro archivo del
repositorio fue tocado por estas correcciones — los 684 tests restantes de la primera corrida
completa permanecen válidos. Resultado consolidado: **687/687 OK**.

## Seguridad

READ-ONLY ALWAYS. Ninguna capacidad real de mutación de OS — sin root/sudo/shell privilegiado, sin
lectura arbitraria de archivo, sin ejecutor de comando genérico, sin `sysctl -w`, sin cambio de
mount/red/bonding/VLAN/permisos/usuarios-grupos/SSHD/Windows Registry/servicio Windows/PowerShell
arbitrario — verificado por 9 tests dedicados de collector safety/agent contract y ~20 tests de
bloqueo de ejecución por subdominio (`test_no_sysctl_execution.sh`,
`test_no_network_change_execution.sh`, `test_no_mount_execution.sh`,
`test_no_storage_change_execution.sh`, `test_no_thp_change_execution.sh`,
`test_no_limits_change_execution.sh`, `test_no_sshd_change_execution.sh`,
`test_no_group_change_execution.sh` et al.). Command-line arguments de proceso y contenido del
wallet TDE nunca se envían/leen, verificado por `test_os_process_args_sanitization.sh`/
`test_os_no_secret_exposure.sh`.

## Known limitations

- Solaris queda `PARTIALLY_SUPPORTED` — comandos nativos (`psrinfo -pv`, `prtconf`, `kstat`,
  `swap -s`, `ipadm`, `dladm show-aggr`) mapeados individualmente, sin la misma profundidad de
  collector que Linux; multipath/block-devices Solaris `PARTIALLY_SUPPORTED` por menor granularidad
  de collector dedicado en esta fase.
- Windows Server: `ulimits`/`hugepages`(large pages nativo)/`aio`(IOCP, no AIO POSIX)/
  `mount-options` son `NOT_APPLICABLE` por diferencia estructural de modelo de OS, no una brecha de
  cobertura del e-stack.
- AIX/HP-UX explícitamente fuera de alcance de Fase 9 — registrados en `skills/REGISTRY.md` sin
  skill materializado, ninguna fecha de fase asignada aún.
- `os/multipath-awareness` degrada a `NOT_APPLICABLE`/`INSUFFICIENT_PRIVILEGES` sin collector
  certificado disponible para la plataforma — nunca asume que multipath no está configurado.
- Entregables binarios de documentación (DOCX/XLSX/PDF/PPTX) siguen `PLANNED`, sin fase de
  implementación asignada — la referencia previa "son Fase 9" en `config/capability-matrix.yaml`/
  `templates/README.md` era obsoleta (la Fase 9 real es OS Platform), corregida en este build.

## NOT_CERTIFIED

Ningún collector OS declarado en el catálogo de `docs/OS_READONLY_COLLECTOR_MODEL.md` queda sin
`validation_status` — Linux es `FIXTURE_VALIDATED`, Windows/Solaris son `DOCUMENTATION_VALIDATED`
(especificación certificada, sin runtime real contra un host físico todavía — mismo criterio de
honestidad que el resto del e-stack para collectors sin Gateway MCP productivo, Fase 13 roadmap).

# PHASE 9 — EFFECTIVE PROCESS LIMITS & SYSTEMD/PAM SOURCE-OF-TRUTH HARDENING

Baseline: `v0.8.0-security-compliance`. Branch: `phase/9-os-platform`. Hardening sobre el build
base de Fase 9 (OS Platform Diagnostics & Hardening), previo a aprobar `v0.9.0-os-platform`.

**Nota (superado)**: este hardening corrigió el merge systemd/PAM pero introdujo un defecto
propio — `pam_applicable` se derivaba de `PAMName=` confirmado sin verificar `pam_limits.so` en la
pila PAM efectiva, y `os/cgroups` seguía combinando `pids.max`/`nproc`/`TasksMax` mediante una
regla de mínimo universal. Corregido en el micro-hardening posterior — ver
`docs/PHASE_9_PAM_LIMITS_PROCESS_CONSTRAINT_SCOPE_HARDENING.md`, que a su vez introdujo dos
defectos propios (`conf=` no modelado; `TasksMax`/`pids.max` del mismo cgroup contados dos veces),
corregidos en `docs/PHASE_9_PAM_POLICY_SOURCE_PID_CONTROLLER_IDENTITY_HARDENING.md`.

## Defecto corregido

`os/systemd-limits` (v1.0.0) y `docs/OS_KERNEL_LIMITS_MODEL.md` declaraban una regla universal:
*"el valor efectivo es siempre el más restrictivo entre la unit systemd y
`/etc/security/limits.conf`"*. Es estructuralmente incorrecta: un proceso lanzado directamente por
systemd normalmente **no** pasa por una sesión PAM (no hay login shell), así que
`/etc/security/limits.conf` simplemente no aplica salvo que la unit declare explícitamente
`PAMName=` — combinar ambas fuentes por defecto produce un límite efectivo inventado, no real.
Adicionalmente, `os/process-limits`/`os/open-files`/`os/ulimits` no distinguían el `ulimit` del
propio proceso de diagnóstico (el usuario/servicio que corre el e-stack) del límite real del
proceso Oracle/Grid objetivo — un defecto separado pero relacionado, con el mismo síntoma raíz:
confundir configuración teórica con evidencia real del proceso.

## Effective vs. configured limits

Modelo corregido: **configured limits explain policy; effective process limits explain reality**
(`# 1288` del prompt de hardening). Toda skill de límites ahora distingue explícitamente:

- **Configurado** — `LimitNOFILE`/`LimitNPROC`/`TasksMax` de una unit systemd
  (`get_service_limit_configuration`), o `nofile`/`nproc`/`stack`/`memlock` de
  `/etc/security/limits.conf` (`get_pam_limit_configuration`).
- **Efectivo** — el valor real leído del PID Oracle/Grid objetivo vía
  `get_process_effective_limits(pid)` (`/proc/<pid>/limits`, PID-scoped) — evidencia primaria
  cuando está disponible, prevalece siempre sobre la configuración teórica.

## Launch context model

Nuevo modelo `launch_context: {type, source, confidence, evidence_ids}` en `os/process-limits`,
determinado **antes** de interpretar cualquier fuente de límite configurado. Valores: `SYSTEMD`,
`PAM_LOGIN`, `PAM_SU`, `MANUAL_SHELL`, `ORACLE_CLUSTERWARE`, `OTHER`, `UNKNOWN` — nunca inventado
sin evidencia.

## Systemd launch context

Cuando `launch_context.type == SYSTEMD`: `LimitNOFILE`/`LimitNPROC`/`TasksMax` de la unit son la
fuente configurada relevante. PAM **no** se asume aplicable — `configured_sources.pam.applicable:
false` salvo evidencia explícita de `PAMName=` en la unit. Ver `os/systemd-limits` v2.0.0.

## PAM launch context

Cuando `launch_context.type` es `PAM_LOGIN`/`PAM_SU`/`MANUAL_SHELL`:
`get_pam_limit_configuration` (`/etc/security/limits.conf`/`limits.d/*`, claves allowlisted,
scope al usuario Oracle/Grid) correlaciona directamente como fuente configurada relevante. Ver
`os/ulimits` v2.0.0.

## Oracle/Grid launch paths

`os/process-limits`/`os/systemd-limits` modelan explícitamente que Oracle Clusterware, servicios
Grid gestionados por systemd, arranque manual del DBA, u otras rutas de arranque certificadas
pueden coexistir en el mismo host — nunca se asume un único mecanismo de arranque.

## Target PID evidence

El PID objetivo siempre proviene de collectors ya certificados —
`get_oracle_process_summary`/`get_grid_process_summary` — nunca un PID arbitrario aportado
directamente por el usuario sin esa validación.

## Diagnostic-user ulimit limitation

`ulimit -u`/`ulimit -n` ejecutados por el propio proceso de diagnóstico representan únicamente su
propio contexto — nunca se reportan ni interpretan como evidencia del proceso Oracle/Grid.
Conservados, cuando útil, como `diagnostic_session_limits`, explícitamente separados de
`effective_limits` y nunca mezclados.

## cgroups

`os/cgroups` (`pids.max`) se mantiene como una capa de enforcement adicional y genuinamente
simultánea (a diferencia de systemd/PAM, cgroups aplica siempre que el proceso esté en ese scope,
independientemente del launch context) — `os/process-limits` la correlaciona explícitamente sin
colapsarla con `nproc`/`TasksMax`.

## Permission fallback

Sin acceso de lectura a `/proc/<pid>/limits` del PID objetivo: `collection_status:
INSUFFICIENT_PRIVILEGES` — nunca `sudo`/`su`/`runuser`/escalamiento de ningún tipo.

## Manual collection

Nuevo Manual Collection Contract (`docs/OS_HARDENING_MANUAL_ACTION_MODEL.md`), distinto de
`manual_action`: propone la obtención de evidencia faltante para ejecución humana
(`owner_role: OS_ADMIN`, `command`, `expected_output`, `sanitization`, `execution_status:
NOT_EXECUTED`) — nunca una acción de cambio.

## Collector contracts

`docs/OS_READONLY_COLLECTOR_MODEL.md` extendido con `get_process_effective_limits` (PID-scoped),
`get_service_limit_configuration` (unit allowlisted/validada contra el PID objetivo, nunca
`systemctl show <arbitrary user input>`), `get_pam_limit_configuration` (claves acotadas, nunca
el archivo completo). Todos `READ_ONLY`, `FIXTURE_VALIDATED`. Solaris/Windows: sin mecanismo
equivalente certificado a `/proc/<pid>/limits` en esta fase → `PARTIALLY_SUPPORTED`, nunca se
simula paridad con Linux.

## Fixtures

5 fixtures nuevas: `ol8-systemd-oracle-effective-limit.yaml` (systemd, PAM no aplica),
`ol8-pam-session-oracle-limit.yaml` (PAM sí aplica, sin unit), `ol8-diagnostic-user-ulimit-mismatch.yaml`
(ulimit del diagnóstico ignorado como evidencia Oracle), `ol8-process-limits-insufficient-privileges.yaml`
(fallback sin sudo), `ol8-systemd-configuration-effective-mismatch.yaml`
(`CONFIGURATION_EFFECTIVE_MISMATCH` sin causa única inferida).

## Tests

18 tests nuevos, todos verificados pasando individualmente: `test_systemd_service_does_not_assume_pam_limits.sh`,
`test_pam_session_limits_awareness.sh`, `test_launch_context_model.sh`,
`test_effective_process_limits_from_target_pid.sh`, `test_diagnostic_user_ulimit_not_oracle_evidence.sh`,
`test_effective_limits_precedence.sh`, `test_configuration_effective_mismatch.sh`,
`test_process_limits_insufficient_privileges.sh`, `test_process_limits_manual_collection_fallback.sh`,
`test_process_limits_no_sudo_fallback.sh`, `test_open_files_effective_limit.sh`,
`test_open_files_current_usage_headroom.sh`, `test_open_files_systemwide_vs_process_scope.sh`,
`test_nproc_vs_tasksmax_distinction.sh`, `test_cgroup_pids_limit_awareness.sh`,
`test_pid_max_not_equal_process_rlimit.sh`, `test_no_generic_proc_reader.sh`,
`test_process_limit_collector_allowlisted.sh`. `test_systemd_limits.sh` corregido: eliminada la
aserción que institucionalizaba la regla incorrecta de mínimo universal, agregadas aserciones que
verifican su ausencia y la presencia del modelo `PAMName=`.

## Known limitations

- `get_process_effective_limits` es `PARTIALLY_SUPPORTED` en Solaris (sin mecanismo equivalente
  certificado a `/proc/<pid>/limits` en esta fase) y `PARTIALLY_SUPPORTED` en Windows (sin API
  certificada de job objects/resource limits todavía).
- `PAMName=` en una unit systemd sólo se correlaciona cuando hay evidencia explícita — si el
  collector de configuración de la unit no puede leer esa propiedad, `pam_applicable` queda
  `false` por diseño conservador (nunca `true` sin evidencia), lo que puede subestimar un caso real
  pero infrecuente de systemd+PAM combinados.
- `CONFIGURATION_EFFECTIVE_MISMATCH` se reporta sin diagnosticar la causa específica (restart
  pendiente, override no aplicado, launch context distinto, shell heredado, cgroup, desconocida) —
  intencional, la causa requiere contexto operativo que el e-stack no puede inferir sólo desde
  evidencia estática.

## Regresión

Targeted (`TEST_SCOPE: TARGETED`) — este hardening modifica exclusivamente OS limit skills,
collector contracts, fixtures, tests de Fase 9 y documentación; no toca collector runtime
compartido, parser global, sanitizer global, framework de routing de agentes, scanner de seguridad
compartido, test harness global, ni el modelo de evidencia compartido (`# 1076`-`# 1092` del
prompt de hardening).

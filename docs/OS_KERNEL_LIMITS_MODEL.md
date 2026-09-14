# OS Kernel/Resource Limits Model — Fase 9

## Principio

Ningún parámetro de kernel/límite de recurso se evalúa contra una cifra universal — siempre
contra el sizing real del host (memoria física, page size, SGA total, `PROCESSES` configurado,
procesos Oracle/Grid esperados). Ver `# 20`-`# 26` del prompt de Fase 9.

## Parámetros cubiertos

```text
fs.aio-max-nr              os/aio
fs.file-max                 os/open-files
kernel.shmmax/shmall/shmmni  os/shared-memory
kernel.sem                    os/semaphores
net.ipv4.ip_local_port_range   os/ephemeral-ports
net.core.rmem/wmem_*             os/tcp-socket-awareness
nproc/pid_max/TasksMax             os/process-limits, os/systemd-limits
nofile/nproc/stack/memlock            os/ulimits
```

## shmmax/shmall

Evaluados con page size, memoria física real y requisitos de SGA — nunca una fórmula obsoleta
("50% de RAM física") aplicada ciegamente (`# 21` del prompt). En releases modernos, HugePages
puede reducir la dependencia de `shmmax`/`shmall` tradicional — correlacionado antes de emitir
severidad alta.

## Semáforos

`SEMMSL` >= `PROCESSES` + margen documentado por Oracle; `SEMMNS` cubre la suma de todas las
instancias; `SEMMNI` relevante sólo con múltiples instancias por host. Nunca valores sin ese
contexto (`# 22`).

## AIO

`aio-max-nr` evaluado contra `aio-nr` actual (uso real), nunca un valor fijo (`# 23`).

## Open files / Process limits

`nofile`/`nproc` **por usuario** distinguidos explícitamente de `file-max`/`pid_max`
**globales** — nunca confundidos (`# 24`, `# 25`).

## Systemd limits (corregido — PHASE 9 EFFECTIVE PROCESS LIMITS & SYSTEMD/PAM SOURCE-OF-TRUTH
HARDENING)

`LimitNOFILE`/`LimitNPROC`/`TasksMax` de una unit systemd son la fuente **configurada** relevante
cuando el proceso Oracle/Grid corre bajo esa unit (`launch_context.type == SYSTEMD`). **Ya no se
asume que `/etc/security/limits.conf` (PAM) participa automáticamente** — un proceso lanzado
directamente por systemd normalmente no pasa por una sesión PAM (no hay login shell). La versión
1.0.0 de este documento declaraba una regla universal "el valor efectivo es siempre el más
restrictivo de ambos" — corregida por ser estructuralmente incorrecta cuando no hay evidencia de
que PAM realmente participe. El valor **efectivo** real se obtiene, cuando sea posible,
directamente del PID objetivo (`get_process_effective_limits`, ver `os/process-limits`) — nunca
inferido calculando el mínimo entre fuentes configuradas. Ver
`docs/PHASE_9_EFFECTIVE_PROCESS_LIMITS_SYSTEMD_PAM_HARDENING.md`.

## PAMName vs. pam_limits.so (corregido — PHASE 9 PAM LIMITS APPLICABILITY & PROCESS CONSTRAINT
SCOPE MICRO-HARDENING)

La versión 2.0.0 de este documento (y de `os/systemd-limits`) corrigió el merge systemd/PAM pero
introdujo un segundo defecto: trataba `PAMName=` confirmado como prueba suficiente de que
`limits.conf` aplica. **`PAMName` sólo prueba que se solicita una sesión PAM — nunca que
`pam_limits.so` esté cargado en la pila PAM efectiva de ese servicio.** La applicability real
(`APPLICABLE`/`NOT_APPLICABLE`/`INSUFFICIENT_EVIDENCE`/`NOT_ASSESSED`) requiere confirmar
`pam_limits.so` vía `get_pam_limits_applicability(service)` — sin esa evidencia, el estado es
siempre `INSUFFICIENT_EVIDENCE`, nunca `true` ni `false` por defecto. Ver
`docs/PHASE_9_PAM_LIMITS_PROCESS_CONSTRAINT_SCOPE_HARDENING.md`.

## Process constraint scopes (corregido — mismo micro-hardening)

`RLIMIT_NPROC` (scope `USER`), `TasksMax` (scope `UNIT`), `pids.max` de cgroup (scope `CGROUP`) y
`pid_max` (scope `HOST`) son constraints paralelos, con contadores y scopes distintos — la versión
1.0.0 de `os/cgroups` declaraba que "el valor efectivo es el más restrictivo entre cgroup, nproc y
TasksMax systemd", una regla de mínimo universal que ignora el scope y la membership de cada
constraint. Corregido: la restricción vinculante (`binding_constraint`) se calcula en
`os/process-limits` a partir de `applicability` + `scope` + `current_usage` + `headroom` de cada
constraint — nunca por comparación directa de valores configurados.

## PAM limits policy source: DEFAULT vs. CUSTOM_CONF (corregido — PHASE 9 PAM LIMITS POLICY SOURCE
& PID CONTROLLER IDENTITY MICRO-HARDENING)

La versión 3.0.0 de `os/systemd-limits` corrigió `PAMName` vs. `pam_limits.so`, pero seguía
tratando `applicability == APPLICABLE` como prueba de que `limits.conf`/`limits.d` eran la fuente
efectiva — sin parsear los argumentos reales de la invocación de `pam_limits.so`. `conf=<path>`
reemplaza esa fuente por defecto para esa invocación específica; `limits.conf`/`limits.d` **nunca**
se agregan como fuente concurrente cuando `conf=` está presente. Corregido vía
`get_pam_limits_policy_source(service)` — `mode: DEFAULT|CUSTOM_CONF|INSUFFICIENT_EVIDENCE|
NOT_APPLICABLE`. Ver `docs/PHASE_9_PAM_POLICY_SOURCE_PID_CONTROLLER_IDENTITY_HARDENING.md`.

## PID controller identity: TasksMax y pids.max del mismo nodo (corregido — mismo micro-hardening)

`TasksMax` (superficie de configuración de la unit) y `pids.max` (estado runtime del controlador
PID del cgroup) pueden representar el **mismo** constraint subyacente del kernel cuando ambos
apuntan al mismo control group — la versión 3.0.0 del Binding Constraint Model seguía contándolos
siempre como dos constraints independientes. Corregido: `os/process-limits` resuelve
`unit_cgroup_path_token` (`get_unit_cgroup_path`) contra el `cgroup_path_token` del nodo `UNIT` de
`os/cgroups` — si coinciden, deduplica en un único constraint canónico `PID_CONTROLLER`; nodos
`PARENT`/`CHILD`/`DELEGATED` con `cgroup_path_token` distinto permanecen separados, nunca
deduplicados por similitud numérica.

## Consolidación

`os/kernel-parameter-assessment` consolida `os/shared-memory`, `os/semaphores`, `os/aio`,
`os/tcp-socket-awareness` en una vista única de "kernel readiness para Oracle" — cada parámetro
mantiene su estado individual, nunca colapsado en un score agregado.

## Manual remediation

Toda recomendación de `sysctl -w`/edición de `limits.conf`/systemd override queda bajo "MANUAL OS
ADMIN ACTION", siempre `NOT_EXECUTED` (`# 62`, `# 63` del prompt).

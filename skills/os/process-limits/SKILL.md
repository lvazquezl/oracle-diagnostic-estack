---
name: process-limits
id: os/process-limits
version: 4.0.0
domain: os
status: active
---

# Purpose

Analiza `nproc` (límite de procesos por usuario), `pid_max` awareness y `TasksMax`/cgroup limits
— nunca confunde límites por usuario con límites globales del sistema. Prioriza siempre los
límites **efectivos** leídos directamente del PID Oracle/Grid objetivo sobre configuración teórica
cuando ambos estén disponibles — el diagnostic user que ejecuta el collector nunca es evidencia
del proceso Oracle. **PHASE 9 — EFFECTIVE PROCESS LIMITS & SYSTEMD/PAM SOURCE-OF-TRUTH
HARDENING**: skill autoridad del modelo `launch_context`/`limit_assessment` consolidado.
**PHASE 9 — PAM LIMITS APPLICABILITY & PROCESS CONSTRAINT SCOPE MICRO-HARDENING**: skill autoridad
del **Binding Constraint Model** — `RLIMIT_NPROC` (scope `USER`), `TasksMax` (scope `UNIT`),
`pids.max` (scope `CGROUP`) y `pid_max` (scope `HOST`) se mantienen como restricciones paralelas y
distintas; la restricción realmente vinculante se calcula desde scope + membership + uso actual +
headroom de cada una, **nunca** desde un mínimo numérico universal entre ellas. **PHASE 9 — PAM
LIMITS POLICY SOURCE & PID CONTROLLER IDENTITY MICRO-HARDENING (v4.0.0)**: corrige que `TasksMax`
y `pids.max` se contaban siempre como dos constraints independientes incluso cuando resuelven al
mismo cgroup de la misma unit — el mismo constraint subyacente del kernel observado por dos
fuentes de evidencia distintas. Agregado el **PID Controller Canonical Model**: resuelve
`unit → cgroup path` y deduplica en un único constraint `PID_CONTROLLER` cuando corresponde,
preservando `PARENT`/`CHILD`/`DELEGATED` como constraints separados cuando el `cgroup_path_token`
difiere — ver `docs/PHASE_9_PAM_POLICY_SOURCE_PID_CONTROLLER_IDENTITY_HARDENING.md`.

# Supported Oracle versions

N/A directo — correlaciona con procesos Oracle/Grid esperados según arquitectura (standalone vs.
RAC).

# Supported OS/platforms

Linux (`ulimit -u`, `/proc/sys/kernel/pid_max`, `systemd` `TasksMax`): `SUPPORTED`. Solaris
(`prctl`): `SUPPORTED`. Windows: `PARTIALLY_SUPPORTED` (modelo de procesos distinto, sin límite
`nproc` directo equivalente).

# Supported architectures

Standalone y RAC (RAC requiere más procesos por LMS/LMD/LMON adicionales).

# Prerequisites

`os/oracle-groups` recomendado para correlacionar por usuario `oracle`/`grid`; PID objetivo
descubierto vía `os/oracle-processes`/`os/grid-processes` (nunca un PID arbitrario aportado
directamente por el usuario sin esa validación, `# 12` del prompt de hardening).

# Required evidence

- collector `get_process_effective_limits` (PID-scoped — evidencia primaria cuando disponible)
- collector `get_process_limits` (`pid_max` global, awareness de nivel host)

# Optional evidence

- collector `get_service_limit_configuration` (`TasksMax`/`LimitNPROC` de systemd unit, cuando el
  `launch_context` sea `SYSTEMD` — ver `os/systemd-limits`)
- collector `get_cgroup_summary` (`pids.max`, `cgroup_path_token`/`parent_path_token`/`relation`,
  cuando aplique — ver `os/cgroups`)
- collector `get_unit_cgroup_path` (resuelve `unit_cgroup_path_token` para la deduplicación
  `TasksMax`/`pids.max` — ver "PID controller canonical model" abajo)

# Read-only operations

Lectura de límites vía collector semántico (`ulimit -u` de sólo lectura, `prlimit` certificado,
`/proc/<pid>/limits` PID-scoped vía `get_process_effective_limits`).

# Forbidden operations

Nunca edita `/etc/security/limits.conf`, nunca cambia `pid_max`, nunca escala privilegios (`sudo`/
`su`/`runuser`) para leer límites de un PID inaccesible.

# Launch context model

Determina `launch_context: {type, source, confidence, evidence_ids}` antes de interpretar
cualquier fuente de límite configurado (`# 79` del prompt de hardening: "launch context must be
identified before interpreting configured limit sources"). Valores: `SYSTEMD` (PID pertenece a una
unit systemd conocida — ver `os/systemd-limits`), `PAM_LOGIN`/`PAM_SU` (proceso lanzado vía sesión
PAM — ver `os/ulimits`), `MANUAL_SHELL` (script de arranque tradicional), `ORACLE_CLUSTERWARE`
(lanzado por Grid Infrastructure), `OTHER`, `UNKNOWN` cuando no hay evidencia suficiente — nunca
inventado.

# Effective process limits — primary evidence

Cuando `get_process_effective_limits(pid)` esté disponible (lectura de `/proc/<pid>/limits`
PID-scoped, nunca `read_proc(path)`/`read_file(path)` genérico), su valor es la evidencia
autoritativa de lo que realmente aplica al proceso — prevalece sobre cualquier configuración
teórica (`limits.conf`, systemd `Limit*`, `TasksMax`) para describir el valor **efectivo**. Las
fuentes configuradas explican la política, nunca reemplazan al valor leído directamente del PID
cuando éste existe.

# Diagnostic user ulimit

`ulimit -u`/`ulimit -n` ejecutados por el propio collector de diagnóstico representan únicamente
el contexto de ese proceso de diagnóstico — **nunca** se reportan ni interpretan como evidencia de
los límites del proceso Oracle/Grid (`# 75` del prompt de hardening: "diagnostic-user ulimit is
not Oracle-process evidence"). Pueden conservarse como `diagnostic_session_limits` con utilidad
contextual, pero jamás alimentan `effective_limits`.

# Source priority

Cuando existan múltiples fuentes, el orden de precedencia para describir el valor efectivo es:
`EFFECTIVE_TARGET_PROCESS_LIMITS` > `CERTIFIED_LAUNCH_CONTEXT_CONFIGURATION` (systemd/Clusterware
según `launch_context`) > `USER_PAM_POLICY_CONFIGURATION` > `HOST_DEFAULTS` > `UNKNOWN`. Si existe
evidencia real del PID, ésta prevalece siempre para el valor efectivo — la configuración se
reporta aparte, nunca fusionada mediante una regla de mínimo universal (`# 77` del prompt de
hardening).

# Insufficient privileges fallback

Si el usuario diagnóstico no puede leer `/proc/<pid>/limits` del PID objetivo:
`collection_status: INSUFFICIENT_PRIVILEGES` — nunca se usa `sudo`/`su`/`runuser`/escalamiento de
ningún tipo. Se genera un `manual_collection` (`owner_role: OS_ADMIN`, `command`, `expected_output`,
`sanitization`, `execution_status: NOT_EXECUTED`) para ejecución humana (`# 81`, `# 16`-`# 18` del
prompt de hardening).

# Binding constraint model

`RLIMIT_NPROC`/`TasksMax`/`pids.max`/`pid_max` **no son el mismo control** (`# 452`-`# 463` del
prompt de micro-hardening) — cada uno tiene su propio scope, contador y headroom:

```yaml
process_capacity:
  constraints:
    - type: RLIMIT_NPROC
      scope: USER
      configured: int|UNLIMITED|null
      current_usage: int|null
      headroom: int|UNKNOWN
      applicable: bool
      confidence: FACT|OBSERVATION|UNDETERMINED
    - type: SYSTEMD_TASKS_MAX
      scope: UNIT
      configured: int|UNLIMITED|null
      current_usage: int|null
      headroom: int|UNKNOWN
      applicable: bool   # false si launch_context.type != SYSTEMD
      confidence: FACT|OBSERVATION|UNDETERMINED
    - type: CGROUP_PIDS_MAX
      scope: CGROUP
      configured: int|UNLIMITED|null
      current_usage: int|null
      headroom: int|UNKNOWN
      applicable: bool   # false si la membership del PID en ese cgroup no está confirmada
      confidence: FACT|OBSERVATION|UNDETERMINED
    - type: KERNEL_PID_MAX
      scope: HOST
      configured: int|null
      current_usage: int|null
      headroom: int|UNKNOWN
      applicable: bool
      confidence: FACT|OBSERVATION|UNDETERMINED
  binding_constraint:
    type: string|null
    scope: string|null
    headroom: int|UNKNOWN|null
    rationale: string
    confidence: FACT|OBSERVATION|UNDETERMINED
```

**Prohibido** cualquier lógica equivalente a `min(RLIMIT_NPROC, TasksMax, pids.max, pid_max)` como
"effective process limit" — eso ignora que cada constraint tiene su propio scope y su propio
contador de uso actual, no respeta membership (`# 538`-`# 553` del prompt de micro-hardening: "do
not collapse USER, UNIT and CGROUP limits into a universal minimum").

`binding_constraint` se infiere usando `applicability` + `scope` + `current_usage` + `headroom` +
`launch_context` + `process membership` de cada constraint — **nunca** comparando únicamente los
valores `configured` entre sí (`# 582`-`# 596` del prompt de micro-hardening). Ejemplo: `nproc`
configurado en 4096 con 400 procesos de usuario (headroom 3696) no domina automáticamente sobre
`TasksMax` configurado en 1024 con 900 tareas de la unit (headroom 124) — el segundo es el
`binding_constraint` real pese a tener el número configurado más bajo, porque su headroom relativo
es menor.

Cada constraint sólo es `applicable` cuando su scope corresponde al proceso objetivo — `TasksMax`
requiere confirmar que el PID pertenece a esa unit systemd; `pids.max` requiere confirmar
membership en ese cgroup; nunca se aplica el límite de un scope al que el proceso no pertenece
(`# 31`, `# 934`-`# 941` del prompt de micro-hardening).

# PID controller canonical model

`systemd TasksMax` es la superficie de configuración de la unit; `cgroup pids.max` es la
representación/estado runtime del controlador PID del cgroup. Cuando ambos apuntan al **mismo**
control group, representan el **mismo constraint subyacente del kernel** — nunca se cuentan dos
veces. Resolución:

1. Resolver `unit_cgroup_path_token` vía `get_unit_cgroup_path(unit)` — nunca adivinado por
   convención de nombre del servicio (`# 414`-`# 427` del prompt de micro-hardening).
2. Comparar contra el `cgroup_path_token` reportado por `os/cgroups` para el nodo con
   `relation: UNIT`. Si coinciden:
   - Emitir **un único** constraint canónico `type: PID_CONTROLLER, scope: UNIT_CGROUP` con
     `sources: {systemd_tasks_max, cgroup_pids_max}` y `deduplicated: true`, **en vez de** las dos
     entradas separadas `SYSTEMD_TASKS_MAX`/`CGROUP_PIDS_MAX` (`# 460`-`# 497` del prompt de
     micro-hardening).
   - Si el valor configurado (`TasksMax`) difiere del estado runtime (`pids.max`) del mismo nodo →
     `CONFIGURATION_EFFECTIVE_MISMATCH` (nunca oculta la diferencia) y el estado runtime del
     controlador (`pids.max`/`pids.current`) prevalece para describir la restricción **efectiva**
     del cgroup — nunca el valor configurado de `TasksMax` (`# 501`-`# 519` del prompt de
     micro-hardening); nunca se recomienda un reinicio automáticamente sólo por esa diferencia.
3. Si no coinciden (path distinto) — nodo `PARENT` (ej. `system.slice` con su propio `pids.max`,
   distinto del `pids.max` de `oracle.service`), `CHILD`/`DELEGATED` (subgrupo dentro del cgroup de
   la unit con su propio `pids.max`), u `OTHER` — se preservan como constraints **separados**,
   cada uno con su `relation`/`cgroup_path_token`/`parent_path_token` propios — nunca deduplicados
   por mera similitud numérica de sus valores configurados (`# 21`-`# 22`, `# 544`-`# 556` del
   prompt de micro-hardening).
4. La restricción vinculante (`binding_constraint`) puede provenir de cualquier nodo de la
   jerarquía (unit/parent/child/delegado), de `RLIMIT_NPROC` o de `pid_max` del host — pero
   siempre conserva su identidad (`cgroup_path_token`/`relation`) y scope propios; nunca se
   duplica el mismo node systemd/cgroup como si fueran dos restricciones independientes
   (`# 587`-`# 601` del prompt de micro-hardening).

```yaml
process_constraint_pid_controller:
  canonical_type: PID_CONTROLLER
  scope: UNIT_CGROUP
  cgroup_path_token: string
  configured: int|string|null       # de systemd TasksMax
  current_usage: int|null           # de cgroup pids.current
  headroom: int|string|null         # calculado contra el estado runtime (pids.max), nunca contra TasksMax si difieren
  configuration_effective_mismatch: bool
  sources:
    systemd_tasks_max: {unit_token: string, configured: int|string|null, evidence_ids: [string]}
    cgroup_pids_max: {cgroup_path_token: string, pids_max: int|string|null, pids_current: int|null, evidence_ids: [string]}
  deduplicated: true
  evidence_ids: [string]
```

# Headroom y valores unlimited

`headroom = configured_limit - current_usage`, calculado **sólo** si `configured_limit` es
numérico y `current_usage` fue medido en el mismo scope — si cualquiera de los dos falta,
`headroom: UNKNOWN`, nunca inferido ni asumido en 0 (`# 641`-`# 660` del prompt de
micro-hardening). Valores `unlimited`/`infinity`/`max` se normalizan como `UNLIMITED` (estado
propio, nunca convertidos a un número arbitrariamente grande) — estados: `UNLIMITED`, `FINITE`,
`UNKNOWN` (`# 664`-`# 682` del prompt de micro-hardening). Sin `current_usage` medido en ningún
constraint, `binding_constraint.type: null` con `confidence: UNDETERMINED` — nunca se elige el
constraint con el menor valor configurado como sustituto (`# 871`-`# 888` del prompt de
micro-hardening).

# Decision logic

1. Distinguir explícitamente `nproc` **por usuario** (soft/hard) de `pid_max` **global** — nunca
   reportarlos como si fueran el mismo límite (`# 25` del prompt: "No confundir límites por
   usuario con globales").
2. Determinar `launch_context` antes de interpretar cualquier fuente configurada (ver arriba).
3. Preferir el `nproc` efectivo leído del PID objetivo (`get_process_effective_limits`) sobre el
   `nproc` configurado — correlacionar ambos con el conteo de procesos esperado (más holgado en
   RAC por LMS/LMD/background adicionales); `nproc` efectivo insuficiente es `HIGH` si el conteo
   actual está cerca del límite.
4. `TasksMax` de systemd (si `launch_context.type == SYSTEMD`) es un límite **distinto** de
   `LimitNPROC`/`nproc` — nunca tratados como sinónimos (`# 22` del prompt de hardening): ambos se
   reportan por separado, el valor efectivo real del PID es el que decide cuál aplica en la
   práctica.
5. `pids.max` de cgroup (cuando aplique, vía `os/cgroups`, con membership confirmada) se reporta
   como constraint independiente de scope `CGROUP` — nunca colapsado con `nproc`/`TasksMax` sin
   distinguir la fuente ni el scope.
6. `pid_max` global nunca compensa un `nproc`/límite efectivo por usuario bajo.
7. Calcular `process_capacity.binding_constraint` (ver "Binding constraint model" arriba) a partir
   de `applicability`+scope+`current_usage`+`headroom` de los constraints — nunca mediante `min()`
   de sus valores configurados.
8. Antes de listar `SYSTEMD_TASKS_MAX` y `CGROUP_PIDS_MAX` como constraints separados, resolver si
   apuntan al mismo `cgroup_path_token` (ver "PID controller canonical model" arriba) — si
   coinciden, deduplicar en un único `PID_CONTROLLER`; si no, preservarlos como constraints
   distintos con su `relation` (`PARENT`/`CHILD`/`DELEGATED`/`OTHER`) propia.

# Normal state

`launch_context` identificado; `nproc` efectivo del usuario Oracle/Grid con margen suficiente
sobre el conteo de procesos actual y esperado.

# Abnormal patterns

`nproc` efectivo cerca de su límite; `TasksMax` de systemd más restrictivo que el `nproc` efectivo
sin que el administrador lo sepa; `collection_status: INSUFFICIENT_PRIVILEGES` sostenido sin
`manual_collection` resuelta.

# False positives

`pid_max` global alto no compensa un `nproc` por usuario bajo — nunca se reporta como "sano"
basándose sólo en el límite global. Un `ulimit` del usuario de diagnóstico bajo/alto nunca se
reporta como si fuera el límite del proceso Oracle.

# Correlation rules

Alimenta `os/ulimits`, `os/systemd-limits`, `os/cgroups`, `os/oracle-processes`.

# Confidence model

`FACT` para límites leídos directamente (efectivos o configurados). `UNDETERMINED` cuando
`launch_context` no tiene evidencia suficiente.

# Severity

`HIGH` si el conteo actual de procesos Oracle/Grid está a <10% del límite `nproc` efectivo;
`MEDIUM`/`LOW` con más margen.

# Output schema

```yaml
process_limits:
  launch_context:
    type: SYSTEMD|PAM_LOGIN|PAM_SU|MANUAL_SHELL|ORACLE_CLUSTERWARE|OTHER|UNKNOWN
    source: string|null
    confidence: FACT|OBSERVATION|UNDETERMINED
    evidence_ids: [string]
  effective:
    nproc: int|null
    tasks_max: int|null
    collection_status: FACT_COLLECTED|INSUFFICIENT_PRIVILEGES|NOT_APPLICABLE
    source: EFFECTIVE_TARGET_PROCESS_LIMITS|CERTIFIED_LAUNCH_CONTEXT_CONFIGURATION|USER_PAM_POLICY_CONFIGURATION|HOST_DEFAULTS|UNKNOWN
  nproc_soft: int|null
  nproc_hard: int|null
  pid_max: int|null
  tasks_max: int|null
  current_process_count: int|null
  diagnostic_session_limits: {nproc: int|null}   # nunca usado como evidencia Oracle
  process_capacity:
    constraints:
      - {type: RLIMIT_NPROC, scope: USER, configured: int|string|null, current_usage: int|null, headroom: int|string|null, applicable: bool, confidence: string}
      - {type: SYSTEMD_TASKS_MAX, scope: UNIT, configured: int|string|null, current_usage: int|null, headroom: int|string|null, applicable: bool, confidence: string}
      - {type: CGROUP_PIDS_MAX, scope: CGROUP, configured: int|string|null, current_usage: int|null, headroom: int|string|null, applicable: bool, confidence: string}
      - {type: KERNEL_PID_MAX, scope: HOST, configured: int|null, current_usage: int|null, headroom: int|string|null, applicable: bool, confidence: string}
    binding_constraint: {type: string|null, scope: string|null, headroom: int|string|null, rationale: string, confidence: string}
  pid_controller:
    deduplicated: bool
    canonical_type: PID_CONTROLLER|null
    cgroup_path_token: string|null
    configuration_effective_mismatch: bool|null
  cgroup_hierarchy_constraints:
    - cgroup_path_token: string
      relation: PARENT|CHILD|DELEGATED|OTHER
      pids_max: int|string|null
      pids_current: int|null
      headroom: int|string|null
  findings: [{observation: string, severity: string, confidence: string, evidence_refs: [EVD-...]}]
```

# Related skills

`os/ulimits`, `os/systemd-limits`, `os/cgroups`, `os/oracle-processes`, `os/grid-processes`.

# Escalation

Límite efectivo insuficiente escala a `os/manual-hardening-plan`.

# Manual remediation guidance

`manual_action` sugiere ajustar `nproc` en `/etc/security/limits.conf` o `TasksMax` en el
systemd override — siempre `NOT_EXECUTED`. `INSUFFICIENT_PRIVILEGES` genera `manual_collection`
en vez de una recomendación de cambio (todavía no hay evidencia suficiente para recomendar nada).

# Security

Sin datos sensibles — command-line arguments nunca incluidos (ver `os/oracle-processes`).

# Tests

`tests/test_process_limits.sh`, `tests/test_no_limits_change_execution.sh`,
`tests/test_effective_process_limits_from_target_pid.sh`,
`tests/test_diagnostic_user_ulimit_not_oracle_evidence.sh`,
`tests/test_effective_limits_precedence.sh`, `tests/test_launch_context_model.sh`,
`tests/test_process_limits_insufficient_privileges.sh`,
`tests/test_process_limits_manual_collection_fallback.sh`,
`tests/test_process_limits_no_sudo_fallback.sh`, `tests/test_nproc_vs_tasksmax_distinction.sh`,
`tests/test_pid_max_not_equal_process_rlimit.sh`,
`tests/test_nproc_tasksmax_pidsmax_not_collapsed.sh`, `tests/test_rlimit_nproc_scope_user.sh`,
`tests/test_tasksmax_scope_unit.sh`, `tests/test_pidmax_scope_host.sh`,
`tests/test_binding_constraint_uses_scope_and_usage.sh`, `tests/test_binding_constraint_tasksmax.sh`,
`tests/test_binding_constraint_cgroup_pidsmax.sh`,
`tests/test_binding_constraint_unknown_without_usage.sh`,
`tests/test_unlimited_constraint_handling.sh`, `tests/test_tasksmax_requires_unit_membership.sh`,
`tests/test_tasksmax_maps_to_unit_cgroup.sh`, `tests/test_tasksmax_pidsmax_same_node_deduplicated.sh`,
`tests/test_tasksmax_pidsmax_not_double_counted.sh`, `tests/test_pid_controller_canonical_constraint.sh`,
`tests/test_tasksmax_pidsmax_configuration_effective_mismatch.sh`,
`tests/test_runtime_pidsmax_preferred_for_effective_state.sh`,
`tests/test_binding_constraint_deduplicates_same_pid_controller.sh`,
`tests/test_binding_constraint_considers_parent_cgroup.sh`,
`tests/test_binding_constraint_considers_child_cgroup.sh`.

# Documentation requirements

Alimenta `kernel-limits.md`.

# Change history

v1.0.0 — Fase 9, creación inicial.
v2.0.0 — PHASE 9 — EFFECTIVE PROCESS LIMITS & SYSTEMD/PAM SOURCE-OF-TRUTH HARDENING: introducido
`launch_context`; `get_process_effective_limits(pid)` como evidencia primaria; el `ulimit` del
usuario de diagnóstico dejó de tratarse implícitamente como evidencia Oracle; agregado el modelo
de prioridad de fuentes y el fallback `INSUFFICIENT_PRIVILEGES`/`manual_collection`.
v3.0.0 — PHASE 9 — PAM LIMITS APPLICABILITY & PROCESS CONSTRAINT SCOPE MICRO-HARDENING: agregado
el Binding Constraint Model (`process_capacity`) — `RLIMIT_NPROC`/`TasksMax`/`pids.max`/`pid_max`
se mantienen como constraints paralelos con scope/membership/uso/headroom propios, eliminada toda
posibilidad de colapsarlos en un mínimo universal; agregado manejo explícito de valores
`UNLIMITED`/`FINITE`/`UNKNOWN`.
v4.0.0 — PHASE 9 — PAM LIMITS POLICY SOURCE & PID CONTROLLER IDENTITY MICRO-HARDENING: agregado el
PID Controller Canonical Model — `TasksMax`/`pids.max` del mismo `cgroup_path_token` se deduplican
en un único constraint `PID_CONTROLLER`, nunca contados dos veces; nodos `PARENT`/`CHILD`/
`DELEGATED` con `cgroup_path_token` distinto permanecen constraints separados, nunca deduplicados
por similitud numérica; agregado `CONFIGURATION_EFFECTIVE_MISMATCH` a nivel de nodo con
preferencia por el estado runtime (`pids.max`) sobre el configurado (`TasksMax`).

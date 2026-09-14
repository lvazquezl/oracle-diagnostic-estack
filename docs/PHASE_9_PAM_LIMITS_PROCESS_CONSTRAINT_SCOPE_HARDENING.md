# PHASE 9 — PAM LIMITS APPLICABILITY & PROCESS CONSTRAINT SCOPE MICRO-HARDENING

Baseline: `v0.8.0-security-compliance`. Branch: `phase/9-os-platform`. Micro-hardening sobre el
build de Fase 9 + `docs/PHASE_9_EFFECTIVE_PROCESS_LIMITS_SYSTEMD_PAM_HARDENING.md`, previo a
aprobar `v0.9.0-os-platform`.

**Nota (superado)**: este micro-hardening introdujo dos defectos propios — `pam_limits.applicability
== APPLICABLE` se trataba como prueba de que `limits.conf`/`limits.d` eran la fuente efectiva sin
parsear los argumentos reales de `pam_limits.so` (`conf=` no modelado), y `TasksMax`/`pids.max` del
mismo cgroup se contaban siempre como dos constraints independientes. Corregidos en el
micro-hardening posterior — ver `docs/PHASE_9_PAM_POLICY_SOURCE_PID_CONTROLLER_IDENTITY_HARDENING.md`.

## Defectos corregidos

Dos defectos semánticos, ambos consecuencia directa de simplificaciones introducidas por el
hardening anterior:

1. **`PAMName= implica limits.conf applicability`**: `os/systemd-limits` v2.0.0 trataba `PAMName=`
   confirmado en una unit systemd como prueba suficiente de que `/etc/security/limits.conf`
   aplicaba (`pam_applicable: true`). `PAMName=` sólo prueba que se **solicita** una sesión PAM
   para ese servicio — nunca que el módulo `pam_limits.so` esté realmente cargado en la pila PAM
   efectiva de ese servicio. El mismo tipo de inferencia no evidenciada que el hardening anterior
   ya había corregido para "systemd vs. PAM en general", reaparecida un nivel más abajo.
2. **`min(RLIMIT_NPROC, TasksMax, pids.max, pid_max)` como "límite efectivo"**: `os/cgroups` v1.0.0
   seguía declarando "el valor efectivo es el más restrictivo entre cgroup, `nproc` y `TasksMax`
   systemd" — una regla de mínimo universal que ignora que cada constraint tiene su propio scope
   (`USER`/`UNIT`/`CGROUP`/`HOST`), su propio contador de uso actual, y requiere confirmar
   membership del proceso en esa unit/cgroup antes de aplicarse.

## PAMName model

`PAMName=<service>` en una unit systemd se interpreta únicamente como "sesión PAM solicitada para
ese servicio" (`pam_session_present: true`) — nunca como "limits.conf aplica".

## PAM session model

Distingue explícitamente `PAM SESSION PRESENT` de `pam_limits.so ACTIVE` — no son equivalentes.

## pam_limits.so detection

`get_pam_limits_applicability(service)` — collector semántico, `READ_ONLY`, `ALLOWLISTED`,
service-scoped, sin lectura de archivo arbitraria, sin root — confirma la presencia real de
`pam_limits.so` en la pila PAM efectiva del servicio.

## PAM include resolution

Sigue `include`/`substack` de forma controlada (`max_depth`/`visited set` o equivalente, protegido
contra loops recursivos, includes duplicados y explosión de profundidad) — `pam_limits.so` puede
estar declarado en un archivo incluido, nunca se asume que debe aparecer literalmente en el archivo
principal del servicio.

## PAM limits applicability

Árbol de decisión: sin `PAMName` → `NOT_APPLICABLE`. Con `PAMName` pero pila PAM no legible →
`INSUFFICIENT_EVIDENCE`. Con pila PAM legible: `pam_limits.so` presente → `APPLICABLE`; ausente →
`NOT_APPLICABLE`. Ninguna heurística convierte `PAMName` por sí sola en `APPLICABLE`.

## PAM insufficient evidence

`PAM_LIMITS_APPLICABILITY: INSUFFICIENT_EVIDENCE` cuando no puede confirmarse `PAMName`/pila PAM
efectiva/`pam_limits.so` — nunca `true` por defecto, nunca `false` sin evidencia.

## RLIMIT_NPROC / TasksMax / pids.max / pid_max model

Modelados como constraints paralelos con scope propio (`USER`/`UNIT`/`CGROUP`/`HOST`),
`configured`, `current_usage`, `headroom` propios — nunca tratados como el mismo control.

## Process membership model

`TasksMax` requiere confirmar que el PID pertenece a esa unit systemd; `pids.max` requiere
confirmar membership en ese cgroup — nunca se aplica la limitación de un scope al que el proceso
no pertenece.

## Current usage / headroom model

`headroom = configured - current_usage`, calculado sólo si ambos son numéricos y medidos en el
mismo scope; si falta cualquiera, `headroom: UNKNOWN`. Valores `unlimited`/`infinity`/`max`
normalizados como `UNLIMITED` (nunca convertidos a un número arbitrario) — estados: `UNLIMITED`,
`FINITE`, `UNKNOWN`.

## Binding constraint model

`os/process-limits#binding-constraint-model` calcula el constraint realmente vinculante usando
`applicability`+`scope`+`current_usage`+`headroom`+`launch_context`+`process membership` de cada
uno — nunca comparando sólo valores configurados. Ejemplo: `RLIMIT_NPROC` con el valor configurado
más alto puede no ser el vinculante si su headroom relativo es mayor que el de `TasksMax`/
`pids.max`. Sin uso medido en ningún scope, `binding_constraint: UNKNOWN` — nunca se elige el
constraint con el menor valor configurado como sustituto.

## Collector contracts

`get_pam_limits_applicability(service)` agregado a `docs/OS_READONLY_COLLECTOR_MODEL.md` —
`READ_ONLY`, `FIXTURE_VALIDATED`. Ningún collector de este dominio es un lector de archivo PAM
genérico (`read_pam_file`/`read_file`/`cat_file`/`grep_file`).

## Fixtures

7 nuevas: `ol8-pamname-without-pam-limits.yaml`, `ol8-pamname-with-pam-limits.yaml`,
`ol8-pamname-unknown-stack.yaml`, `ol8-pam-include-chain.yaml`,
`ol8-binding-constraint-tasksmax.yaml`, `ol8-binding-constraint-cgroup.yaml`,
`ol8-binding-constraint-unknown-usage.yaml`.

## Tests

19 tests nuevos, todos verificados pasando individualmente: 5 de PAM applicability
(`test_pamname_does_not_imply_pam_limits.sh` et al.), 5 de constraint scopes
(`test_nproc_tasksmax_pidsmax_not_collapsed.sh` et al.), 5 de binding constraint
(`test_binding_constraint_uses_scope_and_usage.sh` et al.), 2 de membership
(`test_tasksmax_requires_unit_membership.sh`, `test_pidsmax_requires_cgroup_membership.sh`), 2 de
collector safety (`test_no_generic_pam_file_reader.sh`, `test_pam_collector_allowlisted.sh`).
`test_systemd_limits.sh`, `test_systemd_service_does_not_assume_pam_limits.sh`,
`test_cgroup_pids_limit_awareness.sh` corregidos: eliminadas las aserciones que verificaban
`pam_applicable`/`pids_max` (campos ya reemplazados por `pam_limits:`/`pids_constraint:`).

## Known limitations

- `get_pam_limits_applicability` no puede confirmar `pam_limits.so` cuando la pila PAM efectiva
  del servicio depende de resolución dinámica (ej. `pam_selinux`/módulos condicionales por
  contexto de ejecución no estático) — en esos casos queda `INSUFFICIENT_EVIDENCE`, nunca se
  asume.
- El resolver de `include`/`substack` tiene un `max_depth` configurable pero finito — una cadena
  de includes más profunda que ese límite se reporta como `INSUFFICIENT_EVIDENCE`, nunca se
  extiende indefinidamente.
- `binding_constraint` requiere `current_usage` medido en al menos dos scopes distintos para ser
  informativo; con un solo scope medido, el resultado sigue siendo `UNKNOWN` si los demás quedan
  sin evidencia comparable.

## Regresión

`TEST_SCOPE: TARGETED` — este micro-hardening modifica exclusivamente skills de Fase 9
(`os/systemd-limits`, `os/process-limits`, `os/ulimits`, `os/cgroups`), collector contracts,
fixtures, tests y documentación — no toca collector runtime compartido, framework de acceso a
archivos compartido, sanitizer global, framework de routing de agentes, modelo de evidencia
compartido, ni el test harness global.

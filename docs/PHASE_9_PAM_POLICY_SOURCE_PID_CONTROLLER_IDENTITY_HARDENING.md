# PHASE 9 — PAM LIMITS POLICY SOURCE & PID CONTROLLER IDENTITY MICRO-HARDENING

Baseline: `v0.8.0-security-compliance`. Branch: `phase/9-os-platform`. Micro-hardening sobre el
build de Fase 9 + `docs/PHASE_9_EFFECTIVE_PROCESS_LIMITS_SYSTEMD_PAM_HARDENING.md` +
`docs/PHASE_9_PAM_LIMITS_PROCESS_CONSTRAINT_SCOPE_HARDENING.md`, previo a aprobar
`v0.9.0-os-platform`.

## Defectos corregidos

1. **`pam_limits.so` custom `conf=` source no modelado**: `pam_limits.applicability ==
   APPLICABLE` (confirmado en el micro-hardening anterior) se trataba como prueba de que
   `/etc/security/limits.conf`/`limits.d/*` eran la fuente de policy efectiva — sin parsear los
   argumentos reales de la invocación de `pam_limits.so`. `conf=<path>` reemplaza la fuente por
   defecto para esa invocación específica; asumir `limits.conf`/`limits.d` de todas formas es el
   mismo tipo de inferencia no evidenciada que los dos hardenings anteriores ya habían corregido
   en otras capas del mismo problema.
2. **`TasksMax`/`pids.max` del mismo nodo contados dos veces**: el Binding Constraint Model
   siempre listaba `SYSTEMD_TASKS_MAX` (scope `UNIT`) y `CGROUP_PIDS_MAX` (scope `CGROUP`) como
   constraints independientes, incluso cuando ambos resuelven al mismo control group — el mismo
   constraint del kernel observado por dos fuentes de evidencia distintas (la configuración de la
   unit vs. el estado runtime del cgroup).

## `pam_limits.so` module argument model

`get_pam_limits_policy_source(service)` parsea al menos `conf=`, `debug=`, `set_all=`,
`utmp_early=` de la(s) invocación(es) real(es) de `pam_limits.so` en la pila PAM efectiva —
aplicando los argumentos al punto exacto donde aparece el módulo, nunca atribuyendo argumentos del
servicio padre a un módulo encontrado en un `include`.

## PAM custom `conf=` detection

Detectado explícitamente — su presencia determina `mode: CUSTOM_CONF` en vez de `DEFAULT`.

## DEFAULT policy source

Sin `conf=`: `mode: DEFAULT`, awareness de `/etc/security/limits.conf`/`limits.d/*` según la
plataforma certificada.

## CUSTOM policy source

Con `conf=<path>`: `mode: CUSTOM_CONF`, `source_token` (path validado y tokenizado) — `limits.conf`/
`limits.d` **nunca** se agregan como fuente concurrente para esa invocación.

## Multiple `pam_limits.so` invocations

Cada invocación con argumentos distintos se representa en `policy_sources[]` como un registro
separado — nunca colapsadas en un único resultado.

## PAM custom path safety

`get_pam_limits_policy_source` es `READ_ONLY`, `ALLOWLISTED`, service-scoped, path-validated, sin
root — el path custom se tokeniza, nunca se expone su contenido crudo, nunca se convierte en
acceso a archivo arbitrario.

## Systemd unit → cgroup mapping

`get_unit_cgroup_path(unit)` resuelve `unit_cgroup_path_token` vía collector semántico — nunca
adivinado por convención de nombre del servicio.

## TasksMax model / cgroup pids.max model

`TasksMax` sigue siendo la superficie de configuración de la unit (scope `UNIT`); `pids.max` sigue
siendo la representación/estado runtime del controlador PID del cgroup (scope `CGROUP`) — modelos
paralelos que ahora se correlacionan por `cgroup_path_token` antes de decidir si son el mismo
constraint.

## PID controller canonical model / deduplication

Cuando `unit_cgroup_path_token == cgroup_path_token` del nodo `UNIT`, se emite un único constraint
`PID_CONTROLLER` (scope `UNIT_CGROUP`) con `sources: {systemd_tasks_max, cgroup_pids_max}` y
`deduplicated: true`, reemplazando las dos entradas separadas. Nodos `PARENT`/`CHILD`/`DELEGATED`
con `cgroup_path_token` distinto permanecen constraints separados — nunca deduplicados por mera
similitud numérica.

## Configuration/effective mismatch

Cuando `TasksMax` configurado difiere del `pids.max` runtime del **mismo** nodo canónico →
`CONFIGURATION_EFFECTIVE_MISMATCH`, sin ocultar la diferencia — el estado runtime del controlador
prevalece para describir la restricción efectiva, nunca el valor configurado; ninguna
recomendación de reinicio automática.

## Binding constraint update

`os/process-limits#binding-constraint-model` ahora resuelve primero la identidad PID-controller
antes de listar constraints — puede provenir de cualquier nodo de la jerarquía (unit/parent/
child/delegado), `RLIMIT_NPROC` o `pid_max` del host, conservando siempre su identidad/scope
propios; nunca duplica el mismo nodo systemd/cgroup.

## Collector contracts

`get_pam_limits_policy_source(service)` y `get_unit_cgroup_path(unit)` agregados a
`docs/OS_READONLY_COLLECTOR_MODEL.md` — ambos `READ_ONLY`, `FIXTURE_VALIDATED`.

## Fixtures

7 nuevas: `ol8-pam-default-policy-source.yaml`, `ol8-pam-custom-conf-policy-source.yaml`,
`ol8-pam-limits-multiple-invocations.yaml`, `ol8-tasksmax-pidsmax-same-node.yaml`,
`ol8-tasksmax-pidsmax-configuration-mismatch.yaml`, `ol8-parent-cgroup-constraint.yaml`,
`ol8-child-delegated-cgroup-constraint.yaml`.

## Tests

21 tests nuevos, todos verificados pasando individualmente: 5 de policy source
(`test_pam_limits_default_policy_source.sh` et al.), 3 de custom path safety
(`test_pam_custom_conf_path_validated.sh` et al.), 4 de identidad PID-controller
(`test_tasksmax_maps_to_unit_cgroup.sh` et al.), 4 de jerarquía de cgroups
(`test_parent_cgroup_constraint_preserved.sh` et al.), 2 de mismatch
(`test_tasksmax_pidsmax_configuration_effective_mismatch.sh`,
`test_runtime_pidsmax_preferred_for_effective_state.sh`), 3 de binding constraint update
(`test_binding_constraint_deduplicates_same_pid_controller.sh` et al.).

## Correcciones adicionales

Se detectó y corrigió durante este pase un defecto de edición pre-existente en
`skills/os/cgroups/SKILL.md` (v2.0.0 de la micro-hardening anterior): las secciones "Documentation
requirements"/"Change history" estaban duplicadas al final del archivo, con la segunda copia
truncada en v1.0.0 — corregido a una única copia consistente con el historial completo.

## Known limitations

- `get_pam_limits_policy_source` no puede distinguir múltiples invocaciones de `pam_limits.so`
  dentro del mismo archivo si el orden de evaluación PAM real depende de lógica condicional no
  estática (ej. `pam_succeed_if` previo) — en ese caso cada invocación se reporta con su
  `confidence` degradada, nunca colapsada arbitrariamente.
- La deduplicación `PID_CONTROLLER` requiere que tanto `get_unit_cgroup_path` como
  `get_cgroup_summary` sean legibles con la identidad diagnóstica — sin uno de los dos, ambos
  constraints (`SYSTEMD_TASKS_MAX`/`CGROUP_PIDS_MAX`) se reportan por separado con
  `confidence: UNDETERMINED`, nunca se asume que son el mismo nodo sin esa confirmación.

## Regresión

`TEST_SCOPE: TARGETED` — este micro-hardening modifica exclusivamente skills de Fase 9
(`os/systemd-limits`, `os/process-limits`, `os/ulimits`, `os/cgroups`), collector contracts,
fixtures, tests y documentación — no toca collector runtime compartido, framework de acceso a
archivos compartido, sanitizer global, framework de routing de agentes, modelo de evidencia
compartido, parser framework global, ni el test harness global.

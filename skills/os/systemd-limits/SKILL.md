---
name: systemd-limits
id: os/systemd-limits
version: 4.0.0
domain: os
status: active
---

# Purpose

Detecta `LimitNOFILE`/`LimitNPROC`/`TasksMax` cuando el proceso Oracle/Grid corre bajo una unit
systemd, y determina con evidencia real — nunca por inferencia de una sola propiedad — si
`/etc/security/limits.conf` (PAM) participa en ese launch context, y con qué fuente de policy
específica. Nunca edita units. **PHASE 9 — EFFECTIVE PROCESS LIMITS & SYSTEMD/PAM SOURCE-OF-TRUTH
HARDENING**: corrige el defecto de v1.0.0 que combinaba systemd y PAM mediante una regla universal
de mínimo. **PHASE 9 — PAM LIMITS APPLICABILITY & PROCESS CONSTRAINT SCOPE MICRO-HARDENING
(v3.0.0)**: corrige un segundo defecto introducido por la propia v2.0.0 — `PAMName=` en la unit
sólo prueba que se **solicita** una sesión PAM para ese servicio, nunca que `pam_limits.so` esté
realmente cargado. **PHASE 9 — PAM LIMITS POLICY SOURCE & PID CONTROLLER IDENTITY
MICRO-HARDENING (v4.0.0)**: corrige un tercer defecto — `pam_limits.applicability == APPLICABLE`
se trataba como prueba de que `/etc/security/limits.conf`/`limits.d/*` eran la fuente efectiva,
sin parsear los argumentos reales de la invocación de `pam_limits.so` — un `conf=<path>` custom
reemplaza esa fuente por defecto para esa invocación específica, nunca se asume concurrente con
ella — ver `docs/PHASE_9_PAM_POLICY_SOURCE_PID_CONTROLLER_IDENTITY_HARDENING.md`.

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Linux con systemd (Oracle Linux 7+, RHEL 7+, SUSE 12+): `SUPPORTED`. Solaris/Windows:
`NOT_APPLICABLE`.

# Supported architectures

Standalone y RAC.

# Prerequisites

Confirmar que el proceso Oracle/Grid corre bajo systemd (no siempre es el caso — muchas
instalaciones usan scripts de arranque tradicionales); PID objetivo ya descubierto vía
`os/oracle-processes`/`os/grid-processes`.

# Required evidence

- collector `get_service_limit_configuration` (Limit*/TasksMax de la unit systemd, `PAMName=`
  cuando esté declarado, cuando aplique)
- collector `get_process_effective_limits` (límites efectivos del PID objetivo — evidencia
  primaria del valor real, ver `os/process-limits`)

# Optional evidence

- collector `get_pam_limits_applicability(service)` — **sólo** cuando `PAMName=<service>` esté
  declarado en la unit; determina si `pam_limits.so` está realmente presente en la pila PAM
  efectiva de ese `service` (ver "PAM applicability model" abajo). Sin este collector (o sin
  resultado legible), la applicability nunca se asume `APPLICABLE`.
- evidencia de `os/ulimits` (valores de policy `limits.conf`) **sólo** cuando
  `pam_limits.applicability == APPLICABLE`.

# PAM applicability model

`PAMName SESSION PRESENT` (la unit solicita una sesión PAM para ese servicio) y
`pam_limits.so ACTIVE` (ese módulo está realmente cargado en la pila PAM efectiva de ese
servicio) **no son equivalentes** — confundirlos es el defecto que corrige esta versión (`# 74`,
`# 164`-`# 178` del prompt de micro-hardening: "PAMName does not by itself prove that
pam_limits.so is active"). Árbol de decisión:

```text
unit systemd
  ↓
PAMName configurado?
  ├── NO  → pam_limits.applicability = NOT_APPLICABLE
  └── SÍ  → pam_session_present = true
             ↓
          pila PAM efectiva del servicio conocida (get_pam_limits_applicability)?
             ├── NO  → pam_limits.applicability = INSUFFICIENT_EVIDENCE
             └── SÍ  → pam_limits.so presente en esa pila (incluyendo include/substack)?
                          ├── SÍ → pam_limits.applicability = APPLICABLE
                          └── NO → pam_limits.applicability = NOT_APPLICABLE
```

Nunca se usa una heurística que convierta `PAMName` por sí solo en `APPLICABLE` — ni `true` ni
`false` se afirman sin la evidencia correspondiente; sin pila PAM legible, el estado es siempre
`INSUFFICIENT_EVIDENCE`, nunca inferido de forma optimista ni pesimista.

# PAM limits policy source model

`applicability == APPLICABLE` confirma que `pam_limits.so` está cargado — **no** confirma cuál es
su fuente de policy efectiva. El módulo acepta argumentos (`conf=`, `debug`, `set_all`,
`utmp_early`); `get_pam_limits_policy_source(service)` parsea la(s) invocación(es) real(es) en la
pila efectiva (aplicando los argumentos al punto exacto donde aparece `pam_limits.so`, nunca
atribuyendo argumentos del servicio padre a un módulo encontrado en un `include`) y determina:

- **`DEFAULT`** — `pam_limits.so` sin `conf=`: awareness de `/etc/security/limits.conf`/
  `limits.d/*` según la plataforma certificada.
- **`CUSTOM_CONF`** — `pam_limits.so conf=<path>`: la fuente efectiva para esa invocación es
  `<path>` (validado, tokenizado) — `limits.conf`/`limits.d` **nunca** se asumen concurrentes ni
  se agregan como fuente adicional para esa invocación específica.
- **`INSUFFICIENT_EVIDENCE`** — argumentos no legibles con la identidad diagnóstica.
- **`NOT_APPLICABLE`** — `pam_limits.applicability != APPLICABLE`.

Si la pila PAM contiene más de una invocación de `pam_limits.so` con argumentos distintos (ej. una
`DEFAULT` y otra `CUSTOM_CONF` en distintos puntos de la pila), cada una se representa como un
registro de `policy_sources[]` separado — nunca colapsadas en un único resultado.

# Read-only operations

Lectura de propiedades de unit systemd (`systemctl show <unit> --property=LimitNOFILE,...`) de
sólo lectura.

# Forbidden operations

Nunca edita units ni overrides, nunca ejecuta `systemctl daemon-reload`/`restart`.

# Decision logic

1. Si el proceso Oracle/Grid NO corre bajo systemd → `NOT_APPLICABLE`, nunca se asume que sí.
2. Si corre bajo systemd, `launch_context.type = SYSTEMD` con `source` = nombre de la unit —
   `LimitNOFILE`/`LimitNPROC`/`TasksMax` de esa unit son la fuente **configurada** relevante para
   ese proceso (scope `UNIT`, ver `os/process-limits#binding-constraint-model`).
3. Aplicar el árbol de decisión de "PAM applicability model" arriba — `pam_limits.applicability`
   nunca es `APPLICABLE`/`NOT_APPLICABLE` por la sola presencia/ausencia de `PAMName=`; requiere
   confirmar `pam_limits.so` en la pila PAM efectiva del servicio (`# 77`, `# 97`-`# 104` del
   prompt de micro-hardening).
4. El valor **efectivo** que realmente aplica al proceso se obtiene, cuando sea posible, del PID
   real vía `get_process_effective_limits` (`os/process-limits`) — nunca inferido calculando el
   mínimo entre fuentes configuradas. Los valores de la unit systemd explican la **política**, el
   valor leído del PID explica la **realidad**.
5. Si el límite efectivo del PID difiere del `Limit*`/`TasksMax` configurado en la unit →
   `CONFIGURATION_EFFECTIVE_MISMATCH` — nunca se asume una causa única automáticamente (posibles:
   restart pendiente, override no aplicado, launch context distinto al esperado, shell heredado,
   restricción de cgroup, desconocida) — reportado como observación a investigar, no como error.
6. `TasksMax` restrictivo (default de systemd puede ser bajo en algunas distribuciones) sin
   override explícito para el usuario Oracle → `MEDIUM`/`HIGH` según margen, evaluado contra el
   valor efectivo cuando esté disponible y correlacionado en `os/process-limits` como constraint
   de scope `UNIT` — nunca colapsado con `nproc` (scope `USER`) o `pids.max` (scope `CGROUP`) en
   un único "valor efectivo" (`# 78`, `# 80`, `# 538`-`# 553` del prompt de micro-hardening: "do
   not collapse USER, UNIT and CGROUP limits into a universal minimum").

# Normal state

`launch_context` identificado con evidencia; límites configurados de la unit systemd alineados con
el límite efectivo real del PID cuando ambos están disponibles; `pam_limits.applicability`
determinado con evidencia (`APPLICABLE`/`NOT_APPLICABLE`/`INSUFFICIENT_EVIDENCE`), nunca inferido
de la sola presencia de `PAMName=`.

# Abnormal patterns

`CONFIGURATION_EFFECTIVE_MISMATCH` sin explicación conocida; `TasksMax`/`LimitNOFILE`/`LimitNPROC`
restrictivo confirmado por el valor efectivo del PID; `pam_limits.applicability:
INSUFFICIENT_EVIDENCE` sostenido sin resolución.

# False positives

Proceso Oracle que no corre bajo systemd — este skill se declara `NOT_APPLICABLE`, nunca fuerza
un hallazgo. Tratar `PAMName=` confirmado como prueba suficiente de que `limits.conf` aplica —
sin verificar `pam_limits.so` en la pila efectiva — es en sí mismo el falso positivo que corrige
esta versión (v3.0.0); nunca se repite.

# Correlation rules

Alimenta `os/process-limits` (constraint scope `UNIT`), `os/open-files`, `os/cgroups`, `os/ulimits`
(sólo cuando `pam_limits.applicability == APPLICABLE`, nunca por `PAMName=` aislado).

# Confidence model

`FACT` para propiedades leídas directamente (unit y PID efectivo) y para `pam_limits.applicability`
cuando la pila PAM efectiva fue confirmada. `UNDETERMINED`/`INSUFFICIENT_EVIDENCE` cuando la pila
PAM no es legible. `OBSERVATION` para `CONFIGURATION_EFFECTIVE_MISMATCH` sin causa confirmada.

# Severity

`HIGH` si el límite efectivo confirmado del PID es significativamente más restrictivo que el
esperado.

# Output schema

```yaml
systemd_limits:
  applicable: bool
  launch_context:
    type: SYSTEMD|UNKNOWN
    source: string|null            # nombre de la unit
    confidence: FACT|OBSERVATION|UNDETERMINED
    evidence_ids: [string]
  configured:
    limit_nofile: int|null
    limit_nproc: int|null
    tasks_max: int|null
  effective:
    nofile: int|null               # de get_process_effective_limits, cuando disponible
    nproc: int|null
    collection_status: FACT_COLLECTED|INSUFFICIENT_PRIVILEGES|NOT_APPLICABLE
  pam_limits:
    pam_session_present: bool|null       # PAMName= declarado en la unit -- sólo eso, nada más
    pam_service: string|null
    pam_limits_module_present: bool|null # confirmado en la pila PAM efectiva, nunca inferido de pam_session_present
    limits_policy_source_available: bool|null
    applicability: APPLICABLE|NOT_APPLICABLE|INSUFFICIENT_EVIDENCE|NOT_ASSESSED
    confidence: FACT|OBSERVATION|UNDETERMINED
    evidence_ids: [string]
    policy_sources:
      - mode: DEFAULT|CUSTOM_CONF|INSUFFICIENT_EVIDENCE|NOT_APPLICABLE
        source_token: string|null            # tokenizado; ruta custom nunca expuesta cruda
        default_limits_conf: bool            # true sólo si mode == DEFAULT
        limits_d_enabled: bool|null
        module_arguments: {conf: string|null, debug: bool|null, set_all: bool|null, utmp_early: bool|null}
        confidence: FACT|OBSERVATION|UNDETERMINED
        evidence_ids: [string]
  configuration_effective_mismatch: bool|null
  findings: [{observation: string, severity: string, confidence: string, evidence_refs: [EVD-...]}]
```

# Related skills

`os/process-limits`, `os/open-files`, `os/ulimits`, `os/cgroups`.

# Escalation

`CONFIGURATION_EFFECTIVE_MISMATCH`/límite efectivo restrictivo confirmado escala a
`os/manual-hardening-plan`.

# Manual remediation guidance

`manual_action` sugiere crear un systemd override (`systemctl edit`) — nunca ejecutado, siempre
`NOT_EXECUTED`. Nunca recomienda reiniciar el servicio Oracle/systemd automáticamente sólo porque
configurado != efectivo — la acción es manual, con change control (`# 92` del prompt de
hardening).

# Security

Sin datos sensibles.

# Tests

`tests/test_systemd_limits.sh`, `tests/test_no_limits_change_execution.sh`,
`tests/test_systemd_service_does_not_assume_pam_limits.sh`, `tests/test_launch_context_model.sh`,
`tests/test_configuration_effective_mismatch.sh`, `tests/test_pamname_does_not_imply_pam_limits.sh`,
`tests/test_pam_limits_requires_pam_limits_module.sh`,
`tests/test_pam_limits_not_applicable_without_module.sh`,
`tests/test_pam_limits_insufficient_evidence.sh`, `tests/test_pam_limits_include_chain.sh`,
`tests/test_pam_limits_default_policy_source.sh`, `tests/test_pam_limits_custom_conf_source.sh`,
`tests/test_pam_limits_custom_conf_disables_default_assumption.sh`,
`tests/test_pam_limits_multiple_invocations.sh`,
`tests/test_pam_limits_module_arguments_preserved.sh`.

# Documentation requirements

Alimenta `kernel-limits.md`.

# Change history

v1.0.0 — Fase 9, creación inicial.
v2.0.0 — PHASE 9 — EFFECTIVE PROCESS LIMITS & SYSTEMD/PAM SOURCE-OF-TRUTH HARDENING: eliminada la
regla universal "effective = most restrictive of limits.conf and systemd"; introducido el modelo
`launch_context`; PAM ya no se asume aplicable a procesos lanzados por systemd sin evidencia de
`PAMName=`; el valor efectivo ahora se prioriza desde el PID real (`get_process_effective_limits`)
sobre la configuración teórica; agregado `CONFIGURATION_EFFECTIVE_MISMATCH`.
v3.0.0 — PHASE 9 — PAM LIMITS APPLICABILITY & PROCESS CONSTRAINT SCOPE MICRO-HARDENING: corregido
el defecto introducido por v2.0.0 que trataba `PAMName=` confirmado como prueba suficiente de
applicability — ahora requiere confirmar `pam_limits.so` en la pila PAM efectiva del servicio
(`get_pam_limits_applicability`) antes de declarar `APPLICABLE`; agregado el estado
`INSUFFICIENT_EVIDENCE` explícito; `TasksMax` reforzado como constraint de scope `UNIT`, nunca
colapsado con `nproc`/`pids.max` de otros scopes.
v4.0.0 — PHASE 9 — PAM LIMITS POLICY SOURCE & PID CONTROLLER IDENTITY MICRO-HARDENING: agregado el
modelo de policy source (`policy_sources[]`) — `applicability == APPLICABLE` ya no implica que
`limits.conf`/`limits.d` sean la fuente efectiva; parsea argumentos reales de `pam_limits.so`
(`conf=`/`debug`/`set_all`/`utmp_early`) vía `get_pam_limits_policy_source`; múltiples invocaciones
preservadas por separado, nunca colapsadas.

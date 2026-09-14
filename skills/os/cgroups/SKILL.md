---
name: cgroups
id: os/cgroups
version: 3.0.0
domain: os
status: active
---

# Purpose

Analiza CPU quota, límites de memoria y límites de PIDs impuestos por cgroups (v1/v2) sobre el
scope del proceso/servicio Oracle — cuando aplique. Nunca modifica límites de cgroup.
**PHASE 9 — PAM LIMITS APPLICABILITY & PROCESS CONSTRAINT SCOPE MICRO-HARDENING**: `pids.max` es
un constraint de scope `CGROUP`, distinto y paralelo a `RLIMIT_NPROC` (scope `USER`) y `TasksMax`
(scope `UNIT`) — nunca colapsado con ellos en un único "valor efectivo" mediante un mínimo
universal; la restricción vinculante real la calcula `os/process-limits#binding-constraint-model`
a partir de scope + membership + uso actual + headroom de cada uno. **PHASE 9 — PAM LIMITS POLICY
SOURCE & PID CONTROLLER IDENTITY MICRO-HARDENING (v3.0.0)**: modela la jerarquía completa de
cgroups (`UNIT`/`PARENT`/`CHILD`/`DELEGATED`) — nodos distintos permanecen constraints separados,
nunca deduplicados por similitud numérica; cuando el `pids.max` del cgroup de la unit y el
`TasksMax` de esa misma unit resuelven al mismo `cgroup_path_token`, la deduplicación en un
constraint canónico único la realiza `os/process-limits`, nunca este skill. Ver
`docs/PHASE_9_PAM_POLICY_SOURCE_PID_CONTROLLER_IDENTITY_HARDENING.md`.

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Linux con cgroups (Oracle Linux 7+, RHEL 7+, SUSE 12+): `SUPPORTED`. Solaris (zones/resource
pools, mecanismo distinto): `PARTIALLY_SUPPORTED`, awareness únicamente. Windows: `NOT_APPLICABLE`.

# Supported architectures

Standalone y RAC.

# Prerequisites

Confirmar si el proceso Oracle corre dentro de un scope de cgroup restrictivo (no siempre es el
caso); membership del PID objetivo en ese cgroup confirmada vía `get_cgroup_summary` scoped al
PID (nunca asumida sólo porque el host tiene cgroups habilitados — un cgroup puede existir sin que
el proceso Oracle pertenezca a él).

# Required evidence

- collector `get_cgroup_summary`

# Optional evidence

Ninguna.

# Read-only operations

Lectura de `cpu.max`/`memory.max`/`pids.max` (cgroup v2) o equivalentes v1, de sólo lectura.

# Forbidden operations

Nunca modifica ningún límite de cgroup.

# Decision logic

1. Si el proceso Oracle NO corre dentro de un scope cgroup restrictivo más allá del default del
   sistema → `NOT_APPLICABLE`, nunca se asume restricción sin evidencia.
2. `memory.max` de cgroup más restrictivo que la SGA+PGA+overhead esperado → `HIGH`, correlación
   directa con `os/memory-pressure` (el proceso puede ser OOM-killed por el cgroup, no por el
   kernel global).
3. `pids.max` se reporta como constraint independiente de scope `CGROUP` (`current_usage` = tareas
   actuales del cgroup, `headroom = pids.max - current_usage` cuando ambos son numéricos) — **nunca
   colapsado con `nproc` (scope `USER`) o `TasksMax` (scope `UNIT`) mediante un mínimo universal**
   (`# 80`, `# 504`-`# 553` del prompt de micro-hardening: "do not collapse USER, UNIT and CGROUP
   limits into a universal minimum"). `os/process-limits#binding-constraint-model` es el único
   lugar donde se determina cuál de los tres constraints es el vinculante, usando scope +
   membership + uso + headroom de cada uno — este skill nunca calcula ese resultado combinado.
4. `pids.max` sólo se correlaciona con un proceso Oracle/Grid específico cuando existe evidencia de
   que ese PID pertenece al cgroup en cuestión (`# 31`, `# 686`-`# 690` del prompt de
   micro-hardening) — nunca se asume que el cgroup coincide exactamente con una systemd unit sin
   esa confirmación.
5. Modelar la jerarquía completa: `cgroup_path_token`/`parent_path_token`/`relation`
   (`UNIT`/`PARENT`/`CHILD`/`DELEGATED`/`OTHER`) por cada nodo relevante — un `parent slice`
   `pids.max` (ej. `system.slice`) y el `pids.max` de la unit del proceso Oracle son **dos
   constraints distintos**, ambos preservados; lo mismo aplica a un cgroup hijo/delegado dentro del
   cgroup de la unit (`# 523`-`# 556` del prompt de micro-hardening). Nunca se deduplican dos nodos
   por tener el mismo valor numérico — sólo por compartir el mismo `cgroup_path_token`.

# Normal state

Sin restricción de cgroup relevante, o límites con margen suficiente sobre el uso esperado.

# Abnormal patterns

`memory.max` de cgroup menor a la SGA+PGA esperada — riesgo real de OOM-kill por el cgroup.

# False positives

Presencia de un cgroup por sí sola no es un hallazgo — sólo cuando el límite configurado es más
restrictivo que el uso esperado. Aplicar `pids.max` de un cgroup a un proceso sin confirmar su
membership es el falso positivo que corrige esta versión (v2.0.0) — nunca se repite.

# Correlation rules

Alimenta `os/memory-pressure`, `os/process-limits` (constraint scope `CGROUP`, nunca fusionado),
`os/systemd-limits`.

# Confidence model

`FACT` para límites leídos directamente. `UNDETERMINED` cuando la membership del PID en el cgroup
no puede confirmarse.

# Severity

`HIGH` si `memory.max` es más restrictivo que el uso esperado de Oracle. `pids.max` no tiene
severidad propia aquí — su severidad se determina en `os/process-limits#binding-constraint-model`
sólo si resulta ser el `binding_constraint`.

# Output schema

```yaml
cgroups:
  applicable: bool
  membership_confirmed: bool|null
  cpu_quota: string|null
  memory_max_bytes: int|null
  pids_constraint:
    type: CGROUP_PIDS_MAX
    scope: CGROUP
    configured: int|null|UNLIMITED
    current_usage: int|null
    headroom: int|null|UNKNOWN
  cgroup_hierarchy:
    - cgroup_path_token: string
      parent_path_token: string|null
      relation: UNIT|PARENT|CHILD|DELEGATED|OTHER
      pids_max: int|null|UNLIMITED
      pids_current: int|null
      scope: string
      applicable: bool
      evidence_ids: [string]
  findings: [{observation: string, severity: string, evidence_refs: [EVD-...]}]
```

# Related skills

`os/process-limits`, `os/memory-pressure`, `os/systemd-limits`.

# Escalation

`memory.max` restrictivo escala a `oracle-performance-analyst`/`os/manual-hardening-plan`.

# Manual remediation guidance

`manual_action` sugiere ajustar el cgroup/systemd slice correspondiente — siempre `NOT_EXECUTED`.

# Security

Sin datos sensibles.

# Tests

`tests/test_no_limits_change_execution.sh`, `tests/test_pidsmax_scope_cgroup.sh`,
`tests/test_pidsmax_requires_cgroup_membership.sh`, `tests/test_parent_cgroup_constraint_preserved.sh`,
`tests/test_child_cgroup_constraint_preserved.sh`, `tests/test_delegated_cgroup_constraint_preserved.sh`,
`tests/test_same_numeric_value_not_automatically_deduplicated.sh`.

# Documentation requirements

Alimenta `kernel-limits.md`.

# Change history

v1.0.0 — Fase 9, creación inicial.
v2.0.0 — PHASE 9 — PAM LIMITS APPLICABILITY & PROCESS CONSTRAINT SCOPE MICRO-HARDENING: eliminada
la regla "el valor efectivo es el más restrictivo entre cgroup, nproc y TasksMax systemd" —
`pids.max` ahora se reporta como constraint independiente de scope `CGROUP` con `current_usage`/
`headroom` propios; agregado el requisito de confirmar membership del PID en el cgroup antes de
aplicar su límite.
v3.0.0 — PHASE 9 — PAM LIMITS POLICY SOURCE & PID CONTROLLER IDENTITY MICRO-HARDENING: agregado el
modelo de jerarquía de cgroups (`cgroup_constraint`, `relation: UNIT|PARENT|CHILD|DELEGATED|OTHER`)
— constraints de nodos de cgroup distintos permanecen separados, nunca deduplicados por mera
similitud numérica; cuando `pids.max` del cgroup de la unit coincide con el `TasksMax` de esa misma
unit (mismo `cgroup_path_token`), la deduplicación en un constraint canónico `PID_CONTROLLER` la
realiza `os/process-limits#binding-constraint-model`, nunca este skill.

---
name: ulimits
id: os/ulimits
version: 4.0.0
domain: os
status: active
---

# Purpose

Consolida el conjunto completo de límites **efectivos** (`nofile`, `nproc`, `stack`, `memlock`)
del **proceso Oracle/Grid real** — nunca del usuario/sesión de diagnóstico — en una única vista, y
correlaciona con la fuente de policy PAM real (`DEFAULT` = `/etc/security/limits.conf`/`limits.d`,
o `CUSTOM_CONF` = el `conf=<path>` declarado en la invocación real de `pam_limits.so`) **sólo**
cuando `pam_limits.applicability == APPLICABLE` esté confirmado (ver
`os/systemd-limits#pam-limits-policy-source-model` para `launch_context SYSTEMD`; determinado
directamente aquí para `PAM_LOGIN`/`PAM_SU`/`MANUAL_SHELL`). Evita que `os/process-limits` y
`os/open-files` reporten hallazgos fragmentados sin contexto conjunto. **PHASE 9 — EFFECTIVE
PROCESS LIMITS & SYSTEMD/PAM SOURCE-OF-TRUTH HARDENING**: aclara explícitamente que el `ulimit -a`
del propio proceso de diagnóstico nunca es evidencia del proceso Oracle. **PHASE 9 — PAM LIMITS
APPLICABILITY & PROCESS CONSTRAINT SCOPE MICRO-HARDENING**: corrige que la correlación PAM
dependía sólo de `PAMName=` confirmado — ahora requiere `pam_limits.so` confirmado en la pila PAM
efectiva. **PHASE 9 — PAM LIMITS POLICY SOURCE & PID CONTROLLER IDENTITY MICRO-HARDENING
(v4.0.0)**: corrige que `applicability == APPLICABLE` se trataba como prueba de que
`limits.conf`/`limits.d` eran la fuente efectiva — ahora requiere parsear los argumentos reales de
`pam_limits.so` (`conf=`) antes de asumir la fuente por defecto — ver
`docs/PHASE_9_PAM_POLICY_SOURCE_PID_CONTROLLER_IDENTITY_HARDENING.md`.

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Linux (`ulimit -a` de sólo lectura vía collector, `prlimit` certificado): `SUPPORTED`. Solaris
(`ulimit -a`): `SUPPORTED`. Windows: `NOT_APPLICABLE` (sin equivalente directo de `ulimit`).

# Supported architectures

Standalone y RAC.

# Prerequisites

`os/process-limits` y `os/open-files` ya ejecutados (`launch_context` ya determinado).

# Required evidence

- evidencia efectiva de `os/process-limits` y `os/open-files` (PID-scoped, nunca del proceso de
  diagnóstico)
- `memlock` (relevante para HugePages/Locked SGA)

# Optional evidence

- collector `get_pam_limits_applicability(service)` — cuando `launch_context.type` sea
  `PAM_LOGIN`/`PAM_SU`/`MANUAL_SHELL`, determina si `pam_limits.so` está presente en la pila PAM
  efectiva del servicio de login relevante; para `launch_context.type == SYSTEMD`, este skill
  consume directamente `pam_limits.applicability` ya calculado por `os/systemd-limits`, nunca lo
  recalcula de forma distinta.
- collector `get_pam_limits_policy_source(service)` — cuando `applicability == APPLICABLE`,
  parsea los argumentos reales de la(s) invocación(es) de `pam_limits.so` y determina `mode:
  DEFAULT|CUSTOM_CONF|INSUFFICIENT_EVIDENCE`; para `launch_context.type == SYSTEMD` consume
  directamente `policy_sources[]` ya calculado por `os/systemd-limits`, nunca lo recalcula de
  forma distinta.
- collector `get_pam_limit_configuration` (`/etc/security/limits.conf`/`limits.d/*` cuando
  `mode == DEFAULT`, **o** el `conf=<path>` tokenizado cuando `mode == CUSTOM_CONF` — nunca ambas
  fuentes a la vez para la misma invocación) — consultada **sólo** cuando `pam_limits.applicability
  == APPLICABLE` **y** el `mode` de policy source esté determinado; nunca por la sola presencia de
  `PAMName=`/sesión PAM genérica, ni asumiendo `limits.conf`/`limits.d` cuando `conf=` los
  reemplaza.

# Read-only operations

`ulimit -a`/`prlimit` de sólo lectura vía collector allowlisted — nunca vía shell interactivo
libre (`# 9` del prompt: "ulimit read-only via controlled shell wrapper if architecture permits").
Lectura de `get_pam_limit_configuration` acotada a claves específicas, nunca el archivo completo.

# Forbidden operations

Nunca edita `/etc/security/limits.conf`, nunca ejecuta `ulimit -S`/`-H` de escritura.

# Diagnostic user ulimit is not Oracle evidence

El `ulimit -a`/`prlimit` ejecutado por el propio proceso de diagnóstico (el usuario/servicio que
corre el e-stack) representa únicamente su propio contexto — **nunca** se consolida ni reporta como
si fuera el límite del proceso Oracle/Grid (`# 75`, `# 13` del prompt de hardening). Este skill
consolida exclusivamente los límites **efectivos** ya obtenidos por `os/process-limits`/
`os/open-files` desde el PID Oracle/Grid real (`get_process_effective_limits`); si ese collector
no está disponible, el campo queda `INSUFFICIENT_PRIVILEGES`, nunca sustituido silenciosamente por
el `ulimit` del diagnóstico. Puede conservarse un campo separado `diagnostic_session_limits` con
valor puramente contextual, nunca mezclado en `effective`.

# Decision logic

1. Consolidar `nofile`, `nproc`, `stack`, `memlock` **efectivos** del proceso Oracle/Grid (nunca
   del usuario de diagnóstico) contra los valores recomendados por Oracle Database Installation
   Guide (citados explícitamente por versión, nunca una tabla genérica sin fuente).
2. `memlock` insuficiente cuando HugePages están habilitadas y la instancia usa `LOCK_SGA` →
   `HIGH` (la SGA no podría bloquearse en memoria, fallback silencioso a comportamiento no
   deseado).
3. Correlacionar con `get_pam_limit_configuration` **únicamente** cuando
   `pam_limits.applicability == APPLICABLE` (evidencia de `pam_limits.so` en la pila PAM efectiva,
   nunca `PAMName=` aislado). Sin pila PAM legible → `pam_limits.applicability:
   INSUFFICIENT_EVIDENCE`, nunca `APPLICABLE` ni `NOT_APPLICABLE` por defecto.
4. Antes de leer `get_pam_limit_configuration`, determinar el `mode` de policy source
   (`get_pam_limits_policy_source`) — con `mode: CUSTOM_CONF`, la fuente consultada es el
   `source_token` custom, **nunca** `/etc/security/limits.conf`/`limits.d` por defecto; con
   `mode: DEFAULT`, la fuente es `limits.conf`/`limits.d` según la plataforma. Con más de una
   invocación de `pam_limits.so` en la pila, cada `policy_sources[]` se correlaciona por
   separado — nunca fusionadas en una sola consulta.
5. Reportar cada límite individualmente — nunca un único score agregado que oculte cuál límite
   específico está fuera de rango.

# Normal state

`launch_context` conocido; todos los límites efectivos relevantes dentro o por encima de los
valores recomendados citados.

# Abnormal patterns

`memlock` efectivo insuficiente con `LOCK_SGA` habilitado; `stack` efectivo por debajo del mínimo
recomendado; `INSUFFICIENT_PRIVILEGES` sostenido sin `manual_collection` generada.

# False positives

Ninguno conocido cuando la fuente de la recomendación está correctamente citada. Reportar el
`ulimit` del usuario de diagnóstico como si fuera el límite Oracle es el falso positivo que este
hardening elimina — nunca se repite. Correlacionar PAM con un proceso a partir de `PAMName=`
aislado, sin confirmar `pam_limits.so` en la pila efectiva, es igualmente un falso positivo
eliminado (v3.0.0). Asumir `limits.conf`/`limits.d` como fuente efectiva cuando la invocación real
de `pam_limits.so` declara `conf=<path>` es el falso positivo que corrige v4.0.0 — nunca se
repite.

# Correlation rules

Consolida `os/process-limits`, `os/open-files`. Alimenta `os/hugepages` (memlock).

# Confidence model

`FACT` para límites efectivos leídos directamente del PID. `INSUFFICIENT_PRIVILEGES` cuando no
son accesibles.

# Severity

`HIGH` para `memlock` insuficiente con `LOCK_SGA`; `MEDIUM`/`LOW` para el resto.

# Output schema

```yaml
ulimits:
  launch_context_ref: string   # evidence_id de os/process-limits#launch_context
  effective:
    nofile: {soft: int|null, hard: int|null}
    nproc: {soft: int|null, hard: int|null}
    stack: {soft: int|null, hard: int|null}
    memlock: {soft: int|null, hard: int|null}
    collection_status: FACT_COLLECTED|INSUFFICIENT_PRIVILEGES|NOT_APPLICABLE
  pam_limits:
    applicability: APPLICABLE|NOT_APPLICABLE|INSUFFICIENT_EVIDENCE|NOT_ASSESSED
    confidence: FACT|OBSERVATION|UNDETERMINED
    policy_sources:
      - mode: DEFAULT|CUSTOM_CONF|INSUFFICIENT_EVIDENCE|NOT_APPLICABLE
        source_token: string|null
        default_limits_conf: bool
        limits_d_enabled: bool|null
        module_arguments: {conf: string|null, debug: bool|null, set_all: bool|null, utmp_early: bool|null}
  pam:
    nofile_soft: int|null    # sólo poblado si mode == DEFAULT|CUSTOM_CONF con source resuelta
    nproc_soft: int|null
    stack_soft: int|null
    memlock_soft: int|null
    source_mode: DEFAULT|CUSTOM_CONF|null   # nunca poblado sin policy_sources[] correspondiente
  diagnostic_session_limits: {nofile: int|null, nproc: int|null}   # nunca usado como evidencia Oracle
  findings: [{limit: string, observation: string, severity: string, evidence_refs: [EVD-...]}]
```

# Related skills

`os/process-limits`, `os/open-files`, `os/systemd-limits`, `os/hugepages`.

# Escalation

`memlock` insuficiente con `LOCK_SGA` escala a `os/manual-hardening-plan`.

# Manual remediation guidance

`manual_action` sugiere ajustar `/etc/security/limits.conf` (`nofile`/`nproc`/`stack`/`memlock`
del usuario oracle/grid) — siempre `NOT_EXECUTED`, sólo cuando `pam_limits.applicability ==
APPLICABLE`; para `SYSTEMD` sin `pam_limits.so` confirmado, la sugerencia apunta al override de la
unit, nunca a `limits.conf`.

# Security

Sin datos sensibles.

# Tests

`tests/test_process_limits.sh`, `tests/test_no_limits_change_execution.sh`,
`tests/test_diagnostic_user_ulimit_not_oracle_evidence.sh`,
`tests/test_pam_session_limits_awareness.sh`, `tests/test_pam_limits_requires_pam_limits_module.sh`,
`tests/test_pam_limits_insufficient_evidence.sh`,
`tests/test_pam_limits_custom_conf_disables_default_assumption.sh`,
`tests/test_pam_custom_conf_path_tokenized.sh`.

# Documentation requirements

Alimenta `kernel-limits.md`.

# Change history

v1.0.0 — Fase 9, creación inicial.
v2.0.0 — PHASE 9 — EFFECTIVE PROCESS LIMITS & SYSTEMD/PAM SOURCE-OF-TRUTH HARDENING: consolida
ahora explícitamente límites efectivos del PID Oracle/Grid, nunca del usuario de diagnóstico;
correlación PAM condicionada al `launch_context`, nunca asumida por defecto.
v3.0.0 — PHASE 9 — PAM LIMITS APPLICABILITY & PROCESS CONSTRAINT SCOPE MICRO-HARDENING: la
correlación PAM ahora depende de `pam_limits.applicability == APPLICABLE` (evidencia de
`pam_limits.so`), nunca de `PAMName=` aislado; agregado `INSUFFICIENT_EVIDENCE` explícito.
v4.0.0 — PHASE 9 — PAM LIMITS POLICY SOURCE & PID CONTROLLER IDENTITY MICRO-HARDENING: agregado
`policy_sources[]`/`mode` — `applicability == APPLICABLE` ya no implica `limits.conf`/`limits.d`
como fuente efectiva; `conf=<path>` custom detectado y usado en su lugar, nunca agregado como
fuente concurrente.

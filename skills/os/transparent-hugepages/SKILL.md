---
name: transparent-hugepages
id: os/transparent-hugepages
version: 1.0.0
domain: os
status: active
---

# Purpose

Analiza el estado de Transparent HugePages (THP: `always|madvise|never`) y su alineación con la
recomendación aplicable por versión/plataforma — nunca modifica kernel boot args.

# Supported Oracle versions

N/A directo — la recomendación de THP (`disabled` vs. `madvise`) varía por versión Oracle y
release de Linux; este skill reporta el estado real, la recomendación aplicable se documenta por
separado y se cita, nunca inventada por versión no verificada.

# Supported OS/platforms

Linux (`/sys/kernel/mm/transparent_hugepage/enabled`): `SUPPORTED`. Solaris/Windows: `NOT_APPLICABLE`
(THP es un mecanismo específico del kernel Linux).

# Supported architectures

Standalone y RAC (por nodo).

# Prerequisites

`os/discovery` ya ejecutado.

# Required evidence

- collector `get_thp_status`

# Optional evidence

Ninguna.

# Read-only operations

Lectura de `/sys/kernel/mm/transparent_hugepage/enabled` vía collector semántico.

# Forbidden operations

Nunca modifica kernel boot args (`transparent_hugepage=never`), nunca escribe en `/sys/kernel/
mm/transparent_hugepage/enabled`.

# Decision logic

1. Reportar el estado real (`always`/`madvise`/`never`) — nunca inferido, siempre leído
   directamente.
2. Comparar contra la recomendación aplicable citada explícitamente por versión/plataforma (nunca
   una regla universal sin fuente) — un mismatch se reporta como `MEDIUM`/`HIGH` según el
   historial de incidentes documentado para esa combinación versión/THP.
3. `always` es la configuración con mayor riesgo documentado históricamente para muchas cargas
   Oracle (fragmentación, latencia de compactación) — pero el skill nunca degrada
   automáticamente sin declarar la fuente de la recomendación aplicable.

# Normal state

THP en el estado recomendado para la versión/plataforma detectada, según la fuente citada.

# Abnormal patterns

`always` en una combinación donde la guidance documentada recomienda `never`/`madvise`.

# False positives

Ninguno conocido cuando la recomendación está correctamente citada — el riesgo de falso positivo
está en aplicar una regla genérica sin verificar la versión específica, por eso este skill nunca
lo hace sin fuente.

# Correlation rules

Alimenta `os/hugepages` (mecanismos relacionados pero distintos — nunca confundidos), `os/memory`.

# Confidence model

`FACT` para el estado leído directamente. `OBSERVATION` para el mismatch contra recomendación.

# Severity

`MEDIUM`/`HIGH` según el mismatch y el historial documentado para esa combinación.

# Output schema

```yaml
thp:
  status: always|madvise|never|unknown
  recommended_status: string|null
  recommendation_source: string|null
  findings: [{observation: string, severity: string, evidence_refs: [EVD-...]}]
```

# Related skills

`os/hugepages`, `os/manual-hardening-plan`.

# Escalation

Mismatch documentado escala a `os/manual-hardening-plan`.

# Manual remediation guidance

`manual_action` sugiere el procedimiento de cambio de THP vía kernel boot args (GRUB) —
`reboot_required: true`, siempre `NOT_EXECUTED`. No modifica en caliente sin reinicio salvo que
la plataforma lo soporte explícitamente y se documente en el `manual_action`.

# Security

Sin datos sensibles.

# Tests

`tests/test_thp_status.sh`, `tests/test_thp_policy_awareness.sh`, `tests/test_no_thp_change_execution.sh`.

# Documentation requirements

Alimenta `hugepages-thp.md`.

# Change history

v1.0.0 — Fase 9, creación inicial.

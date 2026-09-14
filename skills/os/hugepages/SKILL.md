---
name: hugepages
id: os/hugepages
version: 1.0.0
domain: os
status: active
---

# Purpose

Calcula si HugePages están correctamente dimensionadas para la SGA total del host (todas las
bases de datos + overhead ASM/GI cuando aplique), no sólo la base de datos principal. Ver
`docs/ORACLE_HUGEPAGES_ASSESSMENT_MODEL.md` para el modelo completo.

# Supported Oracle versions

N/A directo — aplica a cualquier versión Oracle con SGA configurada.

# Supported OS/platforms

Linux (`/proc/meminfo`: `HugePages_Total/Free/Rsvd`, `Hugepagesize`): `SUPPORTED`. Solaris
(large pages, mecanismo distinto — awareness, no cálculo idéntico): `PARTIALLY_SUPPORTED`.
Windows: `NOT_APPLICABLE` (Large Pages de Windows es un mecanismo distinto, fuera de este skill
— ver nota en `os/transparent-hugepages`).

# Supported architectures

Standalone y RAC (por nodo — múltiples instancias por nodo suman SGA).

# Prerequisites

`os/memory` ya ejecutado; requiere SGA de todas las bases de datos del host (vía
`oracle-performance-analyst`/`oracle-dba-analyst`, nunca re-determinada por este skill).

# Required evidence

- collector `get_hugepages_status` (`MemTotal`, `HugePages_Total`, `HugePages_Free`,
  `HugePages_Rsvd`, `Hugepagesize`)
- SGA total de **todas** las bases de datos/instancias del host (`# 18` del prompt: "Soportar
  múltiples SGAs por host")

# Optional evidence

- overhead ASM/GI conocido (cuando el Target Profile lo declare)

# Read-only operations

Lectura de `/proc/meminfo` vía collector semántico.

# Forbidden operations

Nunca ejecuta `sysctl -w vm.nr_hugepages=...`, nunca edita `/etc/sysctl.conf`.

# Decision logic

1. **Fórmula certificada** (`# 17` del prompt, sin margen inventado):
   `required_pages = ceil(total_SGA_bytes / hugepage_size_bytes)`. `total_SGA_bytes` es la **suma**
   de la SGA de cada instancia/base de datos activa en el host, más overhead ASM/GI cuando el
   Target Profile lo declare explícitamente — nunca calculado con una sola instancia si hay más
   de una (`# 18`).
2. Ningún margen porcentual fijo se agrega salvo que una policy explícita del Target Profile lo
   especifique (`# 17`: "No inventar porcentaje fijo") — sin policy, `required_pages` es
   exactamente la fórmula.
3. `configured_hugepages = HugePages_Total`, `unused_hugepages = HugePages_Free -
   HugePages_Rsvd` (páginas libres no reservadas por ninguna instancia), `shortfall =
   max(0, required_pages - configured_hugepages)`.
4. `shortfall > 0` → `HIGH` (riesgo real de fallback a small pages o `ORA-27102`/degradación de
   memoria). `configured_hugepages > 0` pero `HugePages_Free`/`HugePages_Rsvd` indican que la
   instancia no las está usando efectivamente (mismatch con `USE_LARGE_PAGES`) → `MEDIUM`,
   configuración inconsistente.
5. Sin SGA total conocida (múltiples DBs, alguna sin evidencia) → `INSUFFICIENT_EVIDENCE`, nunca
   se calcula con una SGA parcial disfrazada de total.

# Normal state

`configured_hugepages >= required_pages`, `HugePages_Free`/`Rsvd` consistentes con
`USE_LARGE_PAGES` de cada instancia.

# Abnormal patterns

`shortfall > 0`; HugePages configuradas pero no usadas efectivamente por una instancia con
`USE_LARGE_PAGES=ONLY`/`TRUE`.

# False positives

`HugePages_Free > 0` sin `Rsvd` correspondiente durante el arranque de una instancia (ventana
transitoria) no es necesariamente un hallazgo — se correlaciona con el estado de la instancia
antes de reportar `MEDIUM`+.

# Correlation rules

Alimenta `os/transparent-hugepages`, `os/memory`, `performance` (SGA/PGA sizing),
`os/manual-hardening-plan`.

# Confidence model

`FACT` para métricas leídas de `/proc/meminfo`. `INSUFFICIENT_EVIDENCE` cuando la SGA total del
host no es completamente conocida.

# Severity

`HIGH` si `shortfall > 0`; `MEDIUM` si configuración inconsistente; `LOW`/`INFO` si correcto.

# Output schema

```yaml
hugepages:
  hugepage_size_bytes: int
  total_sga_bytes: int|null
  required_pages: int|null
  configured_pages: int
  free_pages: int
  reserved_pages: int
  unused_pages: int|null
  shortfall_pages: int|null
  multiple_databases_considered: bool
  findings: [{observation: string, severity: string, confidence: string, evidence_refs: [EVD-...]}]
```

# Related skills

`os/transparent-hugepages`, `os/memory`, `os/manual-hardening-plan`.

# Escalation

`shortfall > 0` con SGA grande escala a `oracle-performance-analyst` (impacto) y a
`os/manual-hardening-plan` (procedimiento de configuración).

# Manual remediation guidance

`manual_action` sugiere `vm.nr_hugepages=<required_pages>` vía `sysctl`/`/etc/sysctl.conf` —
siempre `NOT_EXECUTED`, `reboot_required: false` (aplica en caliente si hay memoria contigua
disponible, aunque frecuentemente requiere reinicio en producción para garantizar contigüidad —
declarado explícitamente en el `manual_action`, nunca asumido).

# Security

Sin datos sensibles — sólo contadores de memoria.

# Tests

`tests/test_hugepages_calculation.sh`, `tests/test_hugepages_multiple_sgas.sh`,
`tests/test_hugepages_shortfall.sh`, `tests/test_hugepages_no_fixed_margin.sh`.

# Documentation requirements

Alimenta `hugepages-thp.md`.

# Change history

v1.0.0 — Fase 9, creación inicial.

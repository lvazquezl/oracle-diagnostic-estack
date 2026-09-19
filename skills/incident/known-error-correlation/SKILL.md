---
name: known-error-correlation
id: incident/known-error-correlation
version: 1.0.0
domain: incident
status: active
---

# Purpose

Mapea errores del incidente contra `knowledge/errors/{ora,tns,crs,rman}/` local (ORA/TNS/RMAN/CRS/
OS errors, `# 919`-`# 931` del prompt de Fase 11) — un "known error match" nunca se considera
causa confirmada automáticamente.

# Supported Oracle versions

N/A directo — el mapeo hereda el alcance de versión de cada entrada en `knowledge/errors/`.

# Supported OS/platforms

Todas.

# Supported architectures

Todas.

# Prerequisites

`incident/timeline` ejecutado (para tener `error_signatures` extraídos).

# Required evidence

- `error_signatures` extraídos por los parsers locales o evidencia estructurada de dominio.

# Optional evidence

Ninguna adicional.

# Read-only operations

Búsqueda local en `knowledge/errors/` — nunca modifica esa base de conocimiento.

# Forbidden operations

Nunca marca `confirmed_as_cause: true` únicamente por el match — ese campo requiere evidencia
adicional específica del incidente (`# 931` del prompt: "no considerar match como causa
confirmada automáticamente").

# Decision logic

1. Normalizar cada error observado a un `error_signature` (`code`, `domain`, `timestamp`,
   `source`, `count`, `first_seen`, `last_seen`, `evidence_ids` — `# 935`-`# 949` del prompt).
2. Buscar coincidencia contra `knowledge/errors/{ora,tns,crs,rman}/*.md` — cada artículo ya
   documenta notas de contexto (ver `knowledge/errors/ora/ORA-01653-tablespace-full.md` como
   ejemplo semilla).
3. `known_error_matches` registra el `match_confidence` (`HIGH|MEDIUM|LOW`) y siempre
   `confirmed_as_cause: false` por defecto — sólo pasa a `true` si `incident/hypothesis-testing`
   confirma esa hipótesis con evidencia adicional específica del incidente actual.

# Normal state

Errores mapeados contra el knowledge base local con `confirmed_as_cause: false` salvo
confirmación explícita posterior.

# Abnormal patterns

Un error sin ningún artículo local coincidente — reportado como gap de knowledge base (candidato
para `incident/lessons-learned` → `docs/PHASE_12` futuro, nunca bloqueante).

# False positives

Tratar "el código de error coincide con un artículo conocido" como si fuera automáticamente la
causa confirmada de este incidente específico es el falso positivo central que este skill evita.

# Correlation rules

Consume `incident/timeline`. Alimenta `incident/classification`, `incident/hypothesis-generation`.

# Confidence model

`match_confidence: HIGH|MEDIUM|LOW` para la calidad del match textual; `confirmed_as_cause` es un
booleano separado, siempre `false` hasta confirmación explícita por evidencia adicional.

# Severity

N/A directa.

# Output schema

```yaml
error_signature:
  code: string
  domain: string
  timestamp: string
  source: string
  count: int
  first_seen: string
  last_seen: string
  evidence_ids: [EVD-...]
known_error_matches:
  - code: string
    domain: string
    knowledge_ref: string|null
    match_confidence: HIGH|MEDIUM|LOW
    confirmed_as_cause: bool
```

# Related skills

`incident/classification`, `incident/hypothesis-generation`, `incident/recurrence-awareness`.

# Escalation

Ninguna directa.

# Manual remediation guidance

Si `knowledge/errors/` ya documenta una remediación manual para ese código, se referencia en
`incident/manual-remediation-plan` — siempre `NOT_EXECUTED`.

# Security

Sin datos sensibles adicionales.

# Tests

Cubierto transversalmente por los tests de root cause (sección 94) — sin test dedicado adicional
en el alcance MVP de Fase 11.

# Documentation requirements

Alimenta `incident-findings.md`.

# Change history

v1.0.0 — Fase 11, creación inicial.

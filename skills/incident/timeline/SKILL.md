---
name: timeline
id: incident/timeline
version: 1.0.0
domain: incident
status: active
---

# Purpose

Construye el timeline unificado del incidente a partir de eventos extraídos de evidencia
cross-domain — normaliza timezone/offset/UTC, detecta clock skew, ordena por timestamp normalizado
preservando el timestamp de origen para auditoría, y deduplica eventos repetidos
(`docs/INCIDENT_TIMELINE_MODEL.md`).

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Todas.

# Supported architectures

Todas.

# Prerequisites

`incident/evidence-plan` ejecutado; al menos un `evidence_ref` disponible con eventos extraíbles.

# Required evidence

- Eventos extraídos por los parsers locales (`docs/INCIDENT_EVIDENCE_MODEL.md`) o por evidencia
  estructurada ya certificada de los especialistas de dominio.

# Optional evidence

- `incident.timeline_granularity` del Target Profile, cuando declarado.

# Read-only operations

Cálculo local — normalización de tiempo, ordenamiento, deduplicación.

# Forbidden operations

Nunca correlaciona eventos sin resolver timezone primero (`# 463`-`# 464` del prompt de Fase 11).

# Decision logic

1. Normalizar cada evento con `timezone`/`offset`/`UTC equivalent`/`source timestamp` preservado
   (`# 452`-`# 461` del prompt) — el `timestamp` normalizado es siempre UTC, `source_timestamp`
   nunca se descarta.
2. Detectar clock skew: NTP drift, host clock skew, source timestamp delay, monitoring ingestion
   delay (`# 467`-`# 476` del prompt) — ver `incident/timeline#clock-skew`.
3. Si se detecta skew significativo, marcar `timeline_confidence: TIMELINE_CONFIDENCE_DEGRADED`
   explícitamente (`# 478`-`# 482` del prompt) — nunca oculto.
4. Ordenar por `timestamp` normalizado (`# 486`-`# 492` del prompt); `source timestamp` se
   preserva en cada evento para auditoría.
5. Deduplicar eventos repetidos conservando `count`/`first_seen`/`last_seen`/`sources`
   (`# 480`-`# 1489` del prompt) — nunca colapsa a un solo evento sin ese detalle agregado.
6. Clasificar cada evento con `event_type`: `ALERT|ERROR|WARNING|STATE_CHANGE|CONFIG_CHANGE|
   RESOURCE_PRESSURE|FAILURE|RECOVERY|RESTART|FAILOVER|BACKUP_EVENT|NETWORK_EVENT|SECURITY_EVENT|
   CAPACITY_EVENT` (`# 504`-`# 523` del prompt) — nunca un tipo genérico cuando hay evidencia para
   una clasificación específica.

## Clock skew

Fuentes de skew consideradas: `NTP drift`, `host clock skew`, `source timestamp delay`,
`monitoring ingestion delay`. Detectado vía comparación cruzada de timestamps de la misma
transacción/evento reportado por múltiples fuentes (ej. alert.log vs. monitoring) — cuando la
discrepancia excede un umbral configurable, se degrada la confianza del timeline, nunca se
"corrige" silenciosamente el timestamp.

# Normal state

Timeline ordenado, deduplicado, con `timeline_confidence: NORMAL` y sin skew detectado.

# Abnormal patterns

`TIMELINE_CONFIDENCE_DEGRADED` por clock skew — correlación de eventos en esa ventana se trata con
cautela adicional, declarada explícitamente en `limitations`.

# False positives

Tratar dos eventos con timestamps cercanos pero de fuentes con skew conocido como "simultáneos" es
el falso positivo que este skill evita explícitamente.

# Correlation rules

Consume evidencia de todos los especialistas de dominio activados. Alimenta
`incident/event-correlation` (vía `incident/evidence-correlation`), `incident/hypothesis-generation`,
`incident/change-correlation`.

# Confidence model

`FACT` para eventos con timestamp de fuente confiable y sin skew; `OBSERVATION` degradada cuando
hay skew detectado.

# Severity

N/A directa.

# Output schema

Ver `docs/INCIDENT_TIMELINE_MODEL.md#schema` — lista de `timeline_event`.

# Related skills

`incident/evidence-plan`, `incident/evidence-correlation`, `incident/change-correlation`,
`incident/hypothesis-generation`.

# Escalation

Skew severo y sostenido escala como `observability_gap` (`CLOCK_SKEW`) explícito en el RCA final.

# Manual remediation guidance

N/A directa — corregir NTP/clock drift es una acción manual fuera de alcance de este skill (ver
`incident/manual-remediation-plan` si se recomienda como preventiva).

# Security

Timestamps y metadata de evento — sin contenido de log crudo expuesto más allá de lo ya sanitizado
por el parser de origen.

# Tests

`tests/test_incident_timeline_ordering.sh`, `tests/test_incident_timezone_normalization.sh`,
`tests/test_incident_clock_skew.sh`, `tests/test_incident_duplicate_events.sh`.

# Documentation requirements

Produce `incident-timeline.md`.

# Change history

v1.0.0 — Fase 11, creación inicial.

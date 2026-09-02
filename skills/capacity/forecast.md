---
name: forecast
id: capacity/forecast
version: 1.0.0
domain: capacity
status: active
---

# Purpose

Proyectar headroom de un recurso (tablespace, filesystem, disk group ASM, CPU, memoria) a horizontes de 1/3/6 meses a partir de tendencia histórica, declarando explícitamente el nivel de confianza según la cantidad de histórico disponible.

# Supported Oracle versions

N/A directo — opera sobre series de tiempo ya recolectadas por los skills de dominio (tablespaces, ASM, OS), agnóstico de versión Oracle específica.

# Supported OS/platforms

Todas — el forecast es un cálculo sobre series numéricas, no depende del OS.

# Supported architectures

Todas (Standalone/RAC, NON-CDB/CDB, ASM/Filesystem, Primary/Standby) — hereda el alcance del recurso que está proyectando.

# Prerequisites

Requiere `evidence_refs` de al menos dos puntos en el tiempo del mismo recurso (idealmente una serie histórica de AWR/snapshots retenidos); si sólo hay un punto, el skill lo declara y no proyecta.

# Required evidence

- query_id: `Q-CAP-TIMESERIES-001` (serie histórica del recurso solicitado, ventana acotada al histórico disponible)

# Optional evidence

Ninguna adicional — reutiliza `evidence_refs` ya recolectada por `oracle/tablespaces`, `asm/capacity`, `os/*/memory`, etc., en la misma sesión de análisis cuando está disponible, evitando duplicar recolección.

# Read-only operations

Lectura de series históricas ya recolectadas; ningún acceso adicional de escritura.

# Forbidden operations

No modifica ningún recurso; no genera ni recomienda una ampliación automática — sólo el número proyectado y el riesgo asociado.

# Decision logic

1. Ajustar una tendencia lineal simple sobre los puntos históricos disponibles (regresión lineal sobre `used_pct` vs. tiempo).
2. Proyectar `used_pct` al horizonte solicitado (1/3/6 meses).
3. Calcular `headroom = 100% - used_pct_proyectado`.
4. Clasificar riesgo: `CRITICAL` si el headroom proyectado es negativo o cero antes del horizonte solicitado; `HIGH` si `< 10%` al horizonte; `MEDIUM` si `< 25%`; `LOW` en otro caso.
5. Si el histórico disponible cubre menos del 20% del horizonte solicitado (ej. 2 semanas de datos para proyectar 6 meses), degradar la confianza del forecast a `HYPOTHESIS` como máximo y declararlo explícitamente.

# Confidence model

El uso actual es `FACT` (heredado). El forecast en sí nunca pasa de `HYPOTHESIS`/`PROBABLE_CAUSE` — nunca `CONFIRMED_ROOT_CAUSE` (una proyección no es una causa). `UNDETERMINED` si hay menos de dos puntos históricos.

# Output schema

```yaml
findings:
  - resource: string
    current_used_pct: number
    horizon_months: 1|3|6
    projected_used_pct: number
    headroom_pct: number
    risk: LOW|MEDIUM|HIGH|CRITICAL
    confidence: HYPOTHESIS|PROBABLE_CAUSE|UNDETERMINED
    evidence_refs: [EVD-...]
```

# Related skills

`capacity/trending`, `capacity/growth`, `capacity/headroom`, `capacity/risk`, `oracle/tablespaces`, `asm/capacity`.

# Escalation

Riesgo `HIGH`/`CRITICAL` escala a `change-advisor` para una propuesta de ampliación con plazo, y se documenta explícitamente el supuesto de tendencia lineal (no válido para crecimiento no lineal, ej. eventos estacionales) en `recommendations.md`.

# Data sensitivity

Baja: son series numéricas de utilización, sin datos de negocio.

# Context budget

Bajo: opera sobre evidencia ya agregada, no series crudas extensas.

# Tests

`tests/test_evidence_traceability.sh`, `tests/test_no_duplicate_evidence_collection.sh`.

# Documentation requirements

Alimenta `recommendations.md` con la tabla de headroom/riesgo por recurso y horizonte, y declara el método (regresión lineal) y sus límites.

# Evolution via `/change`

Método de proyección (ej. incorporar estacionalidad) vía `/change skill`; umbrales de riesgo vía `/change policy`.

# Template — Findings / Inventory / Risk Matrix (XLSX)

Estructura que `documentation/excel-generator` debe producir. Fase 1: especificación; Fase 9: generador real.

## Hoja "Findings"

Columnas: `finding_id, area, observation, severity, confidence, evidence_refs, related_recommendation_id`.

## Hoja "Recommendations"

Columnas: `rec_id, summary, severity, license_check_required, related_finding_ids`.

## Hoja "Capacity" (si el análisis incluyó `capacity-analyst`)

Columnas: `resource, current_used_pct, horizon_months, projected_used_pct, headroom_pct, risk`.

## Hoja "Evidence Register"

Columnas: `evidence_id, query_id, collector, classification, sensitivity, timestamp` — nunca contenido raw.

## Hoja "Risk Matrix"

Filas = findings `MEDIUM`/`HIGH`; columnas = probabilidad estimada × impacto, coloreada por severidad.

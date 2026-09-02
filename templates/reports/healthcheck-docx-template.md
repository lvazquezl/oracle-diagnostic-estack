# Template — Health check / Assessment (DOCX)

Estructura que `documentation/word-generator` debe producir a partir de `analysis/ANA-*/*.md`. Fase 1: especificación; Fase 9: generador real.

1. Portada — target enmascarado, fecha, tipo de análisis, `analysis_id`.
2. Resumen ejecutivo — de `analysis.md`.
3. Identidad del ambiente — de `context.md`.
4. Hallazgos por severidad — tabla de `findings.md`, con columna de `evidence_refs` (como notas al pie, no como link externo).
5. Recomendaciones — de `recommendations.md`, marcando `LICENSE_CHECK_REQUIRED` donde aplique.
6. Propuestas de cambio (si existen) — resumen de `proposed-changes.md` (Problem/Proposed change/Risk/Rollback, sin los comandos exactos completos en la vista ejecutiva — el detalle técnico completo va en un anexo).
7. Anexo técnico — `proposed-changes.md` completo.
8. Anexo de evidencia — `evidence-manifest.json` resumido (IDs, clasificación, sensibilidad — nunca el contenido raw).

Branding corporativo (logo/colores) se aplica vía un archivo de estilo local del cliente, fuera de este repositorio (no se distribuye branding de terceros).

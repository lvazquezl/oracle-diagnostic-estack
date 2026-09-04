# oracle-performance-analyst — Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Fase 1 (Foundation) | Manifest plano inicial (`agents/oracle-performance-analyst.md`), sin skills materializados salvo `performance/wait-events`. |
| 3.0.0 | Fase 3 (Oracle Performance) | Reestructurado a `agents/oracle-performance-analyst/AGENT.md`. 31 skills Performance completamente materializados. Licensing Gate formalizado (AWR/ASH/ADDM detrás de Diagnostics Pack; Statspack primera clase; ruta estándar sin licencia). Correlation model con ejemplos certificados OBSERVATION→HYPOTHESIS→PROBABLE_CAUSE. SQL text policy explícita (nunca por defecto). Manual command generation (nunca `KILL SESSION`/`ALTER SYSTEM` ejecutado). Catálogo `queries/performance/**` (21 queries, Query Contract v2 + Query Variant Contract). |
| 4.0.0 | Fase 3 Completion & Portability Hardening | Contrato estructurado materializado completamente: `manifest.yaml`, `routing.yaml`, `context-policy.yaml`, `collaboration.yaml`, `output-schema.yaml` como source-of-truth YAML separado de `AGENT.md` (antes concentrado en un único archivo). `AGENT.md` reescrito como documento narrativo que referencia los YAML, sin duplicar contenido estructurado. Evidence policy extendida para incluir reportes de archivo (AWR/Statspack/ADDM/plan) parseados localmente vía `parsers/performance/`. |

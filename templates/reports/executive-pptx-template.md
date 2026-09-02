# Template — Executive Assessment / Incident Review (PPTX)

Estructura que `documentation/presentation-generator` debe producir. Fase 1: especificación; Fase 9: generador real.

1. Portada — target enmascarado, tipo (`assessment executive`/`incident review`/`capacity review`), fecha.
2. Resumen en 3 bullets — de `analysis.md`.
3. Estado general — semáforo por dominio (dba/performance/rac/asm/dataguard/security/capacity), derivado de la severidad máxima de `findings.md` por área.
4. Top 3-5 hallazgos — sólo `HIGH`/`MEDIUM`, sin detalle técnico profundo (eso queda en el DOCX técnico).
5. Recomendaciones priorizadas — de `recommendations.md`, máximo 5, con `LICENSE_CHECK_REQUIRED` señalado.
6. Capacity outlook (si aplica) — gráfico de headroom a 1/3/6 meses de `capacity-analyst`.
7. Próximos pasos — referencia a `proposed-changes.md` (sin comandos, sólo el resumen de la acción propuesta y quién la ejecuta: el DBA).

Nunca incluye evidencia raw, SQL text completo, ni hostnames/IPs sin enmascarar salvo autorización explícita del DBA para esa sesión.

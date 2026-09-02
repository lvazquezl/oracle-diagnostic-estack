# Commands

Especificación conceptual de los 13 slash commands (sección 18 del prompt maestro). La implementación real, ejecutable en Claude Code, vive en [`.claude/commands/`](../.claude/commands/) — cada uno resuelve al Workflow Contract correspondiente en [`workflows/`](../workflows/).

| comando | workflow | propósito |
|---|---|---|
| `/diagnose` | [workflows/diagnose.md](../workflows/diagnose.md) | Síntoma puntual, dominio no conocido de antemano |
| `/healthcheck` | [workflows/healthcheck.md](../workflows/healthcheck.md) | Salud general de un target |
| `/assessment` | [workflows/assessment.md](../workflows/assessment.md) | Evaluación integral, cobertura completa |
| `/analyze` | [workflows/analyze.md](../workflows/analyze.md) | Análisis dirigido a un dominio/objeto conocido |
| `/awr` | [workflows/awr.md](../workflows/awr.md) | Performance sobre una ventana AWR/ASH |
| `/rac` | [workflows/rac.md](../workflows/rac.md) | Topología/servicios/Cache Fusion RAC |
| `/dataguard` | [workflows/dataguard.md](../workflows/dataguard.md) | Rol/lag/gaps/readiness Data Guard |
| `/capacity` | [workflows/capacity.md](../workflows/capacity.md) | Forecast de headroom/riesgo |
| `/incident` | [workflows/incident.md](../workflows/incident.md) | Incidente activo declarado explícitamente |
| `/rca` | [workflows/rca.md](../workflows/rca.md) | RCA formal, post-mortem o en curso |
| `/recommend` | [workflows/recommend.md](../workflows/recommend.md) | Convertir una recomendación en propuesta de cambio |
| `/document` | [workflows/document.md](../workflows/document.md) | Generar entregable binario bajo demanda |
| `/change` | [workflows/change.md](../workflows/change.md) | Crecimiento gobernado del e-stack |

No se agregan comandos más allá de esta lista sin pasar por `/change workflow` (evitar proliferación innecesaria, sección 18 del prompt maestro).

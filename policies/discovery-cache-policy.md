# Discovery Cache Policy (Phase 2)

## Principio

No toda la información de un Target Profile tiene la misma volatilidad. Cachear indiscriminadamente arriesga diagnosticar sobre un estado stale (ej. `open_mode` cambió, un failover ocurrió). Cachear nada desperdicia contexto y tiempo re-descubriendo lo que no cambia.

## Clasificación de volatilidad

| Campo | Volatilidad | TTL por defecto | Notas |
|---|---|---|---|
| `oracle_version` | Estable | 24h (sesión completa) | Sólo cambia con un upgrade — evento raro y disruptivo |
| `database.dbid` | Estable | 24h | Inmutable salvo `nid`/recreación de la base |
| `database.unique_name` | Estable | 24h | Cambia sólo con reconfiguración explícita |
| `architecture.cluster_mode` (RAC flag) | Estable | 24h | Cambia sólo con reconfiguración de Grid Infrastructure |
| `architecture.multitenant_mode` (CDB flag) | Estable | 24h | Cambia sólo con conversión NON-CDB↔CDB (evento raro) |
| `architecture.storage_mode` | Estable | 24h | Cambia sólo con migración ASM↔Filesystem |
| `platform.database_platform` | Estable | 24h | No cambia sin migración de plataforma |
| `database_role` | **Volátil** | 5 min | Puede cambiar por switchover/failover en cualquier momento |
| `open_mode` | **Volátil** | 5 min | Puede cambiar por mount/open/close manual o automatizado |
| `instance` (estado, no identidad) | **Volátil** | 5 min | La instancia puede caer/reiniciar entre invocaciones |
| Servicios activos | **Volátil** | 5 min | Relocate/failover de servicios (relevante para RAC en fases futuras) |
| `cluster.instance_count` | Semi-estable | 30 min | Cambia con adición/remoción de nodos (infrecuente pero no raro) |

## Regla

- Los campos **Estables** se sirven desde cache dentro del TTL sin re-verificar.
- Los campos **Volátiles** se re-verifican si el análisis actual los necesita explícitamente (ej. `/dataguard` en fases futuras siempre re-confirma `database_role`/`open_mode` antes de evaluar readiness), incluso si el resto del Target Profile viene de cache.
- Un Target Profile servido parcialmente desde cache lo declara explícitamente en `discovery.evidence_refs` (qué partes son nuevas vs. reutilizadas) — nunca se presenta como 100% fresco si no lo es.
- **No reutilizar información stale cuando pueda comprometer el diagnóstico.** Ante duda (ej. el análisis es un `/incident` — ver `workflows/incident.md#gates`), el discovery se re-ejecuta completo sin importar el TTL.

## Configuración

`config/estack.config.example.yaml#discovery_cache` declara el TTL por defecto (actualmente el valor único de Foundation, 60 min); Fase 2 lo refina por campo según la tabla anterior — ver `config/estack.config.example.yaml` actualizado.

## Referencia

`docs/TARGET_PROFILE.md`, `skills/core/context-discovery.md`, `agents/oracle-discovery-analyst/AGENT.md#discovery-cache`.

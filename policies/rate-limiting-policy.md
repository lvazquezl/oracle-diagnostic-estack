# Rate Limiting & Impact Protection Policy

Read-only no es zero-risk. Toda query/collector certificado respeta estos límites por defecto (una entrada de `queries/REGISTRY.md` puede ser más estricta, nunca más laxa).

## Límites por defecto

| Control | Default | Notas |
|---|---|---|
| Timeout por query | 30s (`cost_class LOW`/`MEDIUM`), 60s (`cost_class HIGH`) | Cancelación automática al vencer |
| Max rows | 1000 (genérico), ver overrides por query en `queries/REGISTRY.md` | Nunca `SELECT *` sin límite |
| Max output size | 2 MB (`max_output_bytes` por defecto) por evidencia cruda antes de sanitizar | Evidencia mayor se trunca y se declara truncada |
| Max AWR/ASH window | 24h por invocación (`ASH`), 7 días (`AWR` agregado) | Ventanas mayores requieren múltiples invocaciones explícitas, no una sola ilimitada |
| Concurrencia por identidad `ESTACK_DIAG_*` | 3 queries simultáneas | Evita saturar el ambiente objetivo |
| Rate limit | 30 queries/minuto por identidad | Configurable a la baja por `config/estack.config.example.yaml` |
| Cancelación | Todo collector debe soportar cancelación cooperativa al vencer el timeout | Sin excepción |

## Clasificación de costo (`cost_class`)

La clasificación LOW/MEDIUM/HIGH/BLOCKED y sus condiciones reforzadas (ventana de tiempo obligatoria, `max_rows`/`timeout` más estrictos para `HIGH`, evaluación por `environment`/RAC/número de nodos/workflow actual) viven en [`policies/query-cost-policy.md`](query-cost-policy.md) — no se duplican aquí. Esta política cubre los límites **por defecto** que aplican independientemente de la clase; `query-cost-policy.md` cubre cómo se refuerzan según la clase de cada query. `cost_class` es distinto de `risk_class` (seguridad) — ver `docs/CONTRACTS.md#query-contract-v2-foundation-hardening`.

## GV$ y RAC — límites especiales

- Las queries sobre `GV$*` se ejecutan con `max_rows` proporcional al número de instancias conocido por discovery, nunca fijo e independiente del tamaño del cluster.
- Nunca se lanza una query `GV$*` de alto costo simultáneamente contra todas las instancias sin ventana de tiempo acotada.

## Bloqueo de application tables

Ninguna query certificada puede apuntar a un esquema fuera de `SYS`/`SYSTEM`/diccionario/`DBA_HIST_*`/vistas diagnósticas propias (`ESTACK_V_*`). `tests/test_application_data_blocked.*` lo valida estáticamente sobre `queries/REGISTRY.md`.

## Referencia

Ver `docs/CONTRACTS.md#query-contract-v2-foundation-hardening` (campos `risk_class`, `cost_class`, `timeout_seconds`, `max_rows`, `max_output_bytes` obligatorios por entrada), `policies/query-cost-policy.md` y `SECURITY.md#protección-contra-impacto-read-only`.

# Query Cost Policy

## Principio

`cost_class` mide **impacto operacional** de ejecutar una query certificada contra el ambiente objetivo — nunca seguridad. El costo no debe confundirse con seguridad: una query puede ser perfectamente segura (`risk_class: R0` — read-only, mínimo privilegio, sin datos de aplicación) y aun así costosa (`cost_class: HIGH`), por ejemplo ASH sobre una ventana amplia en un cluster grande. Ver `docs/CONTRACTS.md#query-contract-v2-foundation-hardening`.

## Clases

| `cost_class` | Significado | Ejecución |
|---|---|---|
| `LOW` | Costo despreciable — vistas de diccionario pequeñas, sin joins costosos, alcance de una sola fila/instancia | Automática, dentro de los límites de `policies/rate-limiting-policy.md` |
| `MEDIUM` | Costo moderado — vistas históricas, joins acotados, o agregación sobre `GV$*` en clusters de tamaño típico | Automática, con límites reforzados (ver abajo) |
| `HIGH` | Costo significativo — escala con el tamaño del ambiente (ASH en ventana amplia, `GV$SESSION` sin agregación en un cluster grande, históricos multi-día) | Requiere condiciones adicionales explícitas — nunca automática sin ellas |
| `BLOCKED` | Costo o alcance inaceptable para ejecución por este e-stack (ej. full scan de tabla de aplicación) | Nunca se ejecuta automáticamente; de hecho, una query `BLOCKED` no puede certificarse en el catálogo — esta clase describe *por qué* algo se rechaza (ver `policies/forbidden-operations.md`, `tests/test_application_data_blocked.sh`), no un modo de ejecución permitido |

## Ejemplos conceptuales

```text
V$INSTANCE                    → LOW
GV$INSTANCE                   → LOW
GV$SESSION aggregation        → MEDIUM
ASH sobre ventana amplia      → HIGH
Application table full scan   → BLOCKED
```

## Condiciones reforzadas por clase

- **`LOW`**: límites estándar de `policies/rate-limiting-policy.md` (timeout/max_rows por defecto).
- **`MEDIUM`**: `max_rows` reducido respecto al default genérico cuando el objeto escala con el ambiente (ej. `GV$SESSION`); ventana de tiempo obligatoria si el objeto es histórico.
- **`HIGH`**: antes de ejecutar automáticamente, el workflow evalúa explícitamente:
  - `environment` — ¿es producción? (mayor precaución)
  - `rac` / `number of nodes` — el costo escala con nodos en `GV$*`
  - `time range` — ventana obligatoria y acotada (nunca "todo el histórico disponible")
  - `row/output limits` — `max_rows`/`max_output_bytes` obligatorios y más estrictos que el default
  - `timeout` — más corto que el default genérico de su `risk_class`
  - `current workflow` — un `HIGH` puede ser aceptable en `/assessment` (ventana amplia esperada) y no razonable dentro de `/diagnose` (exploración inicial de bajo costo)

  Si estas condiciones no se cumplen, el gate `cost` del workflow (`docs/CONTRACTS.md#workflow-contract`) produce `capability_status: POLICY_BLOCKED` para esa query específica — **no** se solicita aprobación humana para una query read-only certificada; en su lugar, el skill/agente prefiere limitar la consulta (ventana más corta, `max_rows` menor) o solicitar evidencia alternativa de menor costo antes de renunciar al hallazgo.
- **`BLOCKED`**: no aplica ejecución — es una clasificación de rechazo, no un modo con condiciones.

## Relación con `risk_class`

`risk_class` (ver Query Contract v2) es ortogonal: mide si la query, de ejecutarse, podría exponer algo sensible o exceder privilegio — no cuánto cuesta ejecutarla. En Fase 1/Hardening, todo el catálogo certificado es `risk_class: R0` porque todas las queries son read-only con `ESTACK_DIAGNOSTIC_ROLE` de mínimo privilegio; `cost_class` es la dimensión que sí varía query a query.

## Referencia cruzada

`docs/CONTRACTS.md#query-contract-v2-foundation-hardening`, `policies/rate-limiting-policy.md`, `docs/CONTRACTS.md#capability-status-model` (estado `POLICY_BLOCKED`), `queries/REGISTRY.md` (columna `cost_class`).

# Query Variants — Oracle Core Compatibility Hardening

## Principio

> A query is not certified because its metadata says it supports an Oracle version. It is certified because the Query Resolver can select an executable SQL variant whose views and columns are valid for that target version, architecture, container, role and open mode, and the variant has passed safety and compatibility tests.

Antes de este hardening, un query certificado declaraba `supported_oracle_versions: [10g...23ai]` como metadata suelta, sin garantía de que la sentencia SQL única funcionara en todo ese rango — ver `docs/PHASE_2_COMPATIBILITY_HARDENING.md#problem-detected` para 4 casos reales encontrados. Esta regla cierra esa brecha estructuralmente.

## Logical query vs. physical SQL variant

- **Logical query** (`query_id`, ej. `Q-DISC-IDENTITY-001`): la pregunta diagnóstica y su Query Contract (scope, sensibilidad, costo, licenciamiento). Es lo que un skill referencia — nunca un archivo `.sql` concreto.
- **Physical SQL variant** (`variant_id`, ej. `Q-DISC-IDENTITY-001-V1`): una sentencia SQL concreta, ejecutable, válida sólo dentro de un rango de versión/arquitectura declarado explícitamente.

Un query certificado declara `variants: []` en su frontmatter cuando su SQL difiere por versión. Si no lo declara, tiene **un variante implícito** que cubre exactamente su `supported_oracle_versions` — válido únicamente si se verificó (inventario de este hardening, `docs/PHASE_2_COMPATIBILITY_HARDENING.md#queries-reviewed`) que su SQL no usa ninguna columna/vista fuera de esa cobertura.

## Query Variant Contract

```yaml
query_id: Q-DISC-IDENTITY-001        # logical query — sin cambios de Query Contract v2
version: 3.0.0

variants:
  - variant_id: Q-DISC-IDENTITY-001-V1
    label: legacy_10g_11g
    oracle_versions: {min: "10.2", max: "11.2"}
    architecture: {multitenant: false}
    container_scope: NON_CDB
    sql_block: "Variant V1 (legacy_10g_11g)"   # ancla al heading del bloque ```sql en el mismo archivo

  - variant_id: Q-DISC-IDENTITY-001-V2
    label: multitenant_12c
    oracle_versions: {min: "12.1", max: "12.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (multitenant_12c)"

  - variant_id: Q-DISC-IDENTITY-001-V3
    label: modern_18plus
    oracle_versions: {min: "18.0", max: "latest"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V3 (modern_18plus)"
```

Cada `sql_block` referencia un heading `# Statement / procedure (read-only) — Variant <ID> (<label>, <rango>)` en el mismo archivo Markdown del query — **no se crean archivos `.sql` separados ni sub-carpetas por variante**: mantener todo en un único Markdown por logical query evita duplicar Query Contract/metadata y sigue el principio de Fuente Única de Verdad (`docs/CONTRACTS.md`). Esto es la adaptación explícitamente permitida por la sección 5 del prompt de hardening ("la estructura exacta puede adaptarse al repositorio existente").

## Query Variant Resolver

Componente lógico (documentado aquí; sin runtime ejecutable — el Gateway MCP real es Fase 7, igual que el resto de collectors):

```text
Target Profile
  → oracle_version (normalizado, docs/TARGET_PROFILE.md)
  → architecture (cluster_mode, multitenant_mode, storage_mode)
  → container (type)
  → database_role
  → platform
      ↓
Logical Query ID
      ↓
[para cada variant declarado, en orden]
  ¿oracle_version dentro de [min, max]?
  ¿architecture/container/role compatibles con las restricciones del variant?
      ↓
Primera variante compatible → Certified SQL (ese bloque exacto)
Ninguna variante compatible → status: UNSUPPORTED (nunca "closest version", nunca fallback silencioso)
```

**El modelo/Claude nunca elige manualmente el archivo/bloque SQL** — el agente/skill solicita la evidencia por `query_id` (logical), y es el Resolver (hoy: la lógica documentada aquí, ejecutada por el propio agente al preparar el Task Package de un collector — Fase 7 la automatiza en el Gateway) quien determina la variante. Ver `agents/oracle-discovery-analyst/AGENT.md#evidence-policy` y `agents/oracle-dba-analyst/AGENT.md#evidence-policy`, ambos actualizados para referenciar únicamente `query_id` lógicos.

### Entrada/salida conceptual

```yaml
# Entrada
query_id: Q-DISC-IDENTITY-001
target: {oracle_version: "11.2.0.4", multitenant: false, database_role: PRIMARY}

# Salida (match)
logical_query_id: Q-DISC-IDENTITY-001
variant_id: Q-DISC-IDENTITY-001-V1
status: SUPPORTED

# Salida (no match)
logical_query_id: Q-ALGUNA-QUERY-FUTURA
variant_id: null
status: UNSUPPORTED
reason: "Ninguna variante cubre Oracle 9.2 — mínimo certificado es 10.2"
alternative: null
```

## No variant match

Si ninguna variante es compatible con el Target Profile:

```yaml
status: UNSUPPORTED
reason: string
alternative: string|null
```

Nunca "ejecutar la versión más cercana". Nunca fallback silencioso — cualquier fallback debe estar explícitamente declarado y certificado como una variante propia (ver `docs/PHASE_2_COMPATIBILITY_HARDENING.md` sección de fallback declarado, ej. TEMP en 10g).

## Estados de evaluación (inventario, sección 4 del prompt de hardening)

Todo query del catálogo se clasifica, durante este hardening y en cada `/change query` futuro, como uno de:

| Estado | Significado |
|---|---|
| `COMPATIBLE` | El/los variant(s) declarados cubren correctamente su `supported_oracle_versions`, validado contra `compatibility/oracle-dictionary/`. |
| `VARIANT_REQUIRED` | La query tenía una única sentencia SQL usando construcciones fuera de rango — requiere split en variantes (los 4 casos corregidos en este hardening). |
| `UNSUPPORTED` | La vista/columna requerida no existe en ninguna versión del rango declarado — la query no puede certificarse para ese rango. |
| `INCORRECT_VERSION_RANGE` | El rango declarado no coincide con la disponibilidad real de la vista/columna (ej. declarar 10g cuando la vista es 11g+). |
| `INCORRECT_COST_CLASS` | El `cost_class` no refleja el impacto operacional real (ej. `Q-DISC-ASM-001`, corregido en este hardening). |
| `INCORRECT_CONTAINER_SCOPE` | `container_scope` no coincide con el comportamiento real de la vista. |
| `INCORRECT_ROLE_SCOPE` | `database_role_scope` no coincide con el comportamiento real en standby. |

Ver el inventario completo con la clasificación aplicada a las 26 queries en `docs/PHASE_2_COMPATIBILITY_HARDENING.md#queries-reviewed`.

## Quality Gate por logical query

```text
Metadata                 PASS
Variant coverage         PASS
Version compatibility    PASS
View compatibility       PASS
Column compatibility     PASS
Container compatibility  PASS
Role compatibility       PASS
Open-mode compatibility  PASS
Cost classification      PASS
Security                 PASS
Privilege mapping        PASS
Tests                    PASS
```

Si alguna dimensión falla: `QUERY STATUS = NOT_CERTIFIED`. Una query `NOT_CERTIFIED` no puede ser referenciada por `mcp/tool-manifest.md` como `CERTIFIED` (ver sección "MCP Query Certification" en `mcp/tool-manifest.md`).

## Future-proof version policy

### `latest` no es un alias permanente de 23ai

`latest` en un `oracle_versions.max` (ej. `{min: "18.0", max: "latest"}`) significa **"sin límite superior conocido dentro de las versiones validadas por este catálogo"**, evaluado dinámicamente contra `known_supported` (abajo) — nunca se resuelve en build/documentación como un número fijo ("23ai" hoy, otro mañana). Cuando Oracle libere una major version posterior a 23ai, esa versión entra en `unknown_future` (no en el rango `latest` automáticamente) hasta integrarse vía `/change compatibility`.

### Clasificación de toda versión Oracle evaluada por el Resolver

| Clase | Significado | Comportamiento del Resolver |
|---|---|---|
| `known_supported` | Versión validada explícitamente contra `compatibility/oracle-dictionary/` — hoy: 10g, 11g, 12c, 18c, 19c, 21c, 23ai. | Resuelve variante normalmente (flujo estándar de `docs/QUERY_VARIANTS.md#query-variant-resolver`). |
| `known_unsupported` | Versión anterior al mínimo certificado del catálogo (hoy: < 10.2) o feature inexistente en esa versión (ej. Multitenant en 10g/11g). | `status: UNSUPPORTED` con `reason` explícito — nunca se intenta ejecutar. |
| `unknown_future` | Versión Oracle mayor a la más alta en `known_supported` (hoy: > 23.0) que el catálogo aún no ha validado. | **Nunca** se asume compatible por ser numéricamente mayor. `status: PARTIALLY_SUPPORTED` o `COMPATIBILITY_VALIDATION_REQUIRED` (nunca `SUPPORTED` ni ejecución automática de la variante `max: latest`) hasta que `/change compatibility` integre esa versión (dictionary delta + variants + matrix + fixtures + tests, ver `EVOLUTION.md#change-compatibility--checklist-obligatorio-oracle-core-compatibility-hardening`). |

Esto evita el error de "una variante declara `max: latest`, por lo tanto sirve para cualquier versión futura sin validar" — la variante `max: latest` cubre `known_supported` hasta el techo actual, no `unknown_future`.

## Referencia cruzada

`config/query-compatibility-matrix.yaml` (fuente estructurada por logical query), `compatibility/oracle-dictionary/` (disponibilidad de vistas/columnas por versión), `docs/CONTRACTS.md#query-contract-v2-foundation-hardening` (Query Contract base, sin cambios — este documento lo extiende), `EVOLUTION.md#13-change-compatibility` (toda nueva variante sigue `/change query`/`/change compatibility`).

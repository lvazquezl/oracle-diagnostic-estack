# Version-Awareness Policy

## Principio

Ninguna capability compara versiones Oracle como strings (`"19.0.0.0.0" > "12.1.0.2.0"` como comparación léxica es incorrecta y frágil). Toda evaluación de versión usa la representación normalizada.

## Representación normalizada

```yaml
oracle_version:
  major:      # ej. 19
  minor:      # ej. 0
  release:    # ej. 0 (release update dentro del major, cuando aplica)
  ru:         # ej. "RU 19.21" — Release Update, cuando el ambiente lo expone; null si no aplica/no se pudo determinar
  raw:        # string original tal como lo reportó V$INSTANCE.VERSION_FULL / VERSION — nunca se descarta
```

Ejemplos de mapeo `raw → normalizado` (no exhaustivo, ver `skills/core/version-awareness.md` para la lógica completa):

| raw | major | minor | notas |
|---|---|---|---|
| `10.2.0.5.0` | 10 | 2 | "10g" |
| `11.2.0.4.0` | 11 | 2 | "11g" (R2) |
| `12.1.0.2.0` | 12 | 1 | "12c" (12.1) |
| `12.2.0.1.0` | 12 | 2 | "12c" (12.2) |
| `18.0.0.0.0` | 18 | 0 | "18c" |
| `19.21.0.0.0` (`VERSION_FULL`) | 19 | 0 | "19c", `ru: "19.21"` |
| `23.4.0.24.05` | 23 | 4 | "23ai" |

`core/context-discovery` (`skills/core/context-discovery.md`) produce este bloque como parte de su `findings`, no sólo el string `product_version`.

## Dimensiones evaluadas (no sólo versión)

Toda capability que declare soporte condicionado evalúa, en este orden, antes de ejecutarse:

```text
Oracle version (normalizado)
Database architecture (Standalone/RAC/RAC One Node)
RAC/Standalone
CDB/NON-CDB/PDB (container_scope)
Database role (PRIMARY/STANDBY — database_role_scope)
GI version (si RAC)
OS/platform
```

Esto es lo que evalúa el gate `version`/`architecture` del Workflow Contract (`docs/CONTRACTS.md#workflow-contract`) antes de activar un agente/skill/query.

## Degradación explícita — ejemplos obligatorios

```text
Oracle 10g          → multitenant/*     → UNSUPPORTED (la feature no existe antes de 12c)
NON-CDB              → multitenant/pdb  → UNSUPPORTED (no hay PDB fuera de CDB)
Standalone            → rac/*            → UNSUPPORTED (no hay cluster que analizar)
Physical Standby       → algunas queries de dataguard/apply son válidas; otras
                          (ej. las que asumen actividad de escritura de usuario)
                          se degradan según open_mode — ver database_role_scope por query
```

Cada uno de estos casos produce `capability_status: UNSUPPORTED` (ver `policies/capability-degradation-policy.md`), nunca un error genérico ni un intento silencioso de ejecutar la query igual.

## Fuente de verdad

`config/capability-matrix.yaml` / `docs/CAPABILITY_MATRIX.md` son la fuente consultada por el gate `version` de cada workflow para decidir, por dominio × versión, si una capability es `SUPPORTED|PARTIAL|FOUNDATION_ONLY|PLANNED|UNSUPPORTED|LICENSE_DEPENDENT` antes incluso de mirar el catálogo de queries específico.

## Referencia cruzada

`docs/CONTRACTS.md#context-token-model` (pipeline DISCOVERY → CAPABILITY FILTER), `skills/core/version-awareness.md`, `docs/CAPABILITY_MATRIX.md`.

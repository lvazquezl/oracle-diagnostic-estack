# Data Guard Broker Read-Only Collectors — Fase 5

Reutiliza el Collector Contract de Fase 4 (`docs/GI_READONLY_COLLECTORS.md#collector-contract-schema`) — mismo schema, mismo principio: *ningún collector es `execute_dgmgrl(command)` genérico* (`# 23` del prompt de Fase 5). Cada uno mapea exclusivamente a un subcomando `SHOW` allowlisted, read-only.

## Catálogo de collectors Broker

| collector_id | comando | parser | cost | validation_status |
|---|---|---|---|---|
| `get_dataguard_configuration` | `SHOW CONFIGURATION` | `parsers/dataguard/broker_parser.py::parse_show_configuration` | LOW | FIXTURE_VALIDATED |
| `get_dataguard_database_status` | `SHOW DATABASE <tokenized-db>` | `parsers/dataguard/broker_parser.py::parse_show_database` | LOW | FIXTURE_VALIDATED |
| `get_dataguard_verbose_status` | `SHOW DATABASE VERBOSE <tokenized-db>` | `parsers/dataguard/broker_parser.py::parse_show_database_verbose` | MEDIUM | FIXTURE_VALIDATED |
| `get_fsfo_status` | `SHOW FAST_START FAILOVER` | `parsers/dataguard/broker_parser.py::parse_show_fsfo` | LOW | FIXTURE_VALIDATED |
| `get_relevant_alertlog_excerpt` | lectura acotada de `alert.log` (reutiliza `oracle-diag-collector` de Fase 2), filtrado a términos MRP/RFS/LNS/gap/transport/apply/broker | `parsers/dataguard/alertlog_filter.py` | MEDIUM | FIXTURE_VALIDATED |

Ninguno alcanza `RUNTIME_VALIDATED` en esta fase — ejecución real contra ambiente vivo es Fase 7 (Gateway MCP), igual que el resto del catálogo de collectors.

## `<tokenized-db>` — nunca un nombre real interpolado sin pasar por el sanitizer

Todo `db_unique_name` usado para construir `SHOW DATABASE [VERBOSE] <db>` proviene de `dataguard/topology` (ya tokenizado como `DB_UNIQUE_NAME_TOKEN_NNN` para presentación) — el collector real, en la capa de ejecución (Fase 7), resuelve el token al nombre real internamente antes de invocar DGMGRL; el modelo nunca ve ni construye el nombre real directamente. Esto es consistente con el resto del stack: el modelo trabaja siempre sobre datos ya sanitizados.

## Allowlist de comandos DGMGRL (`# 23`)

Únicamente:

```text
SHOW CONFIGURATION
SHOW DATABASE <tokenized-db>
SHOW DATABASE VERBOSE <tokenized-db>
SHOW FAST_START FAILOVER
```

Ningún otro subcomando `SHOW` ni ningún otro verbo DGMGRL está permitido en esta fase.

## Bloqueados explícitamente (`# 24`)

```text
EDIT DATABASE
EDIT CONFIGURATION
ENABLE CONFIGURATION
DISABLE CONFIGURATION
SWITCHOVER TO
FAILOVER TO
REINSTATE DATABASE
CONVERT DATABASE
REMOVE DATABASE
ADD DATABASE
```

Bloqueados incluso si aparecen como ejemplos manuales en documentación — `tests/test_no_arbitrary_dgmgrl.sh` verifica estáticamente que ninguno de estos verbos aparece en un contexto ejecutable (fuera de prosa de prohibición) en `parsers/dataguard/`, `docs/DATAGUARD_BROKER_READONLY_COLLECTORS.md`, o `mcp/tool-manifest.md`.

## Report ingest model

`DGMGRL SHOW output → TYPE DETECTION (por collector_id) → LOCAL PARSER (parsers/dataguard/broker_parser.py) → STRUCTURED EVIDENCE → SANITIZER → EVIDENCE → SKILL → AGENT` — mismo principio que `parsers/rac/` (Fase 4) y `parsers/performance/` (Fase 3): Python 3 stdlib-only, ningún parser llama `eval`/`exec`/`subprocess`/`os.system`/`compile()` sobre el contenido capturado. La salida completa de `SHOW DATABASE VERBOSE` (que puede ser extensa) nunca se propaga cruda — el parser extrae únicamente: configuration status, database role, intended state, transport lag, apply lag, errors, warnings, properties relevantes, FSFO, observer (`# 25`).

## GI/OS Identity Model reutilizado

Identidad diagnóstica Broker separada de `ESTACK_DIAGNOSTIC_ROLE` (SQL) — nunca `SYSDBA` permanente (`# 77`). Si un comando requiere privilegio no disponible: `INSUFFICIENT_PRIVILEGES` + `MANUAL_COLLECTION_REQUIRED`, nunca escalamiento automático — mismo modelo que `docs/GI_READONLY_COLLECTORS.md#gi-identity-model`.

## Certificación

Un collector Broker nuevo o modificado sigue `/change parser` + `/change compatibility` (nuevas versiones/propiedades DGMGRL), con SECURITY VALIDATION obligatoria antes de HUMAN REVIEW — mismo flujo que Fase 4.

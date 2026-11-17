# Modelo de cobertura por dominio del assessment

`CHG-ESTACK-D-COMPLETE-WITHIN-POLICY-001`. Fuente: `config/assessment-coverage-model.json`. Evaluador: `scripts/assessment_coverage/evaluate.py`. Documento: sección `domain_coverage` de `document_assessment` (`change_documentation_knowledge/documents.py`). Pruebas: `tests/test_assessment_coverage.sh` (P20).

## Para qué

En `ANA-20261020-001` la cobertura por dominio se armó a mano y mezclaba dos cosas distintas bajo `PARTIAL`:
- lo que **falta y se puede obtener**: un collector que no existe o no se ejecutó, un privilegio, un adaptador, un target conectado a la PDB;
- lo que **nunca se va a obtener a propósito**: el texto SQL, los bind values, los valores de texto de los parámetros. La política lo excluye.

Con eso, F (SQL) o B (parámetros) iban a quedar `PARTIAL` para siempre, y `PARTIAL` dejaba de decir si había trabajo pendiente. El modelo separa las dos cosas y las calcula sin criterio manual.

## Estados de un dominio

| Estado | Significa | Lo asigna |
|---|---|---|
| `COMPLETE` | Se obtuvo cada ítem que aplica a la topología | El evaluador |
| `COMPLETE_WITHIN_POLICY` | Se obtuvo todo lo obtenible; el resto está excluido por una política nombrada en el modelo | El evaluador |
| `PARTIAL` | Falta algo que se puede obtener; el informe dice qué y cómo | El evaluador |
| `NOT_ASSESSED` | No se obtuvo ningún ítem del dominio | El evaluador |
| `NOT_APPLICABLE` | La topología no tiene el dominio (RAC en single instance, Data Guard sin standby) o ningún ítem aplica | El evaluador |
| `INSUFFICIENT_EVIDENCE` | Hay evidencia, pero no alcanza para juzgar (por ejemplo, AWR con un solo intervalo) | Solo la revisión de especialistas, bajando un estado calculado con motivo |

**Regla de oro:** una revisión puede bajar un estado, nunca subirlo. `NOT_APPLICABLE` no cambia. El documento de assessment rechaza lo contrario (`E_INPUT_INVALID`) y marca toda baja con `DOMAIN_STATUS_LOWERED_BY_REVIEW`.

## Estados de un ítem

Cada dominio se compone de ítems. Cada ítem lista los collectors certificados que lo cubren; con cualquiera de ellos alcanza.
- `OBTAINED`: algún collector devolvió evidencia saneada (`OBSERVED`, también con cero filas). Si el gateway la devolvió con limitaciones (`DEGRADED`, por ejemplo `ROWS_TRUNCATED_TO_LIMIT`), el ítem cuenta como obtenido, la lista `degraded` lo dice y la tabla lo marca "con limitaciones". La revisión de especialistas decide si eso baja el dominio.
- `EXCLUDED_BY_POLICY`: el modelo lo declara excluido con una categoría, o sus collectors requieren un pack que el humano declaró `NOT_LICENSED`.
- `NOT_APPLICABLE`: su condición de topología no se cumple, o el gateway declara `NOT_APPLICABLE` todos sus collectors.
- `MISSING`: cualquier otro caso: no se ejecutó, falló, no está habilitado, falta un privilegio, licencia sin confirmar, no existe un collector certificado (`gap`) o falta el adaptador. El motivo dice cuál y cómo obtenerlo.

**Una topología desconocida nunca se asume.** Si el ítem depende de un flag (`cdb`, `rac`, `asm`, `dataguard`, `standby`) que no se observó, queda `MISSING`, no `NOT_APPLICABLE`.

## Categorías de exclusión

Toda exclusión cita una política del repo. El evaluador rechaza un modelo con una categoría desconocida o una política inexistente.

| Categoría | Política | Ítems |
|---|---|---|
| `DATA_CLASSIFICATION` | `sanitizers/data-classification-policy.md` | B4 valores de texto de parámetros; F4 texto SQL; F5 bind values; O12 passwords y hashes; P4 detalle de registros de auditoría; Q6 ruta del keystore |
| `FORBIDDEN_OPERATION` | `policies/forbidden-operations.md` | N7 `RESTORE ... VALIDATE` y `RESTORE PREVIEW` (el e-stack no ejecuta RMAN) |
| `LICENSE_ENTITLEMENT_NOT_ASSERTED` | `policies/licensing-awareness-policy.md` | Z3 derecho de uso según el contrato |
| `LICENSE_NOT_ENTITLED` | `policies/licensing-awareness-policy.md` | Dinámica: un ítem cuyos collectors quedan `LICENSE_RESTRICTED` y el target declara el pack `NOT_LICENSED` en `license_status` |

**Una licencia sin confirmar no es una exclusión.** Con `UNKNOWN` o sin declarar, el ítem queda `MISSING` con `LICENSE_CHECK_REQUIRED`: se puede obtener confirmando la licencia. Solo un `NOT_LICENSED` explícito del humano convierte el hueco en exclusión. El gateway no cambia: cualquier valor distinto de `CONFIRMED` sigue siendo `LICENSE_RESTRICTED`.

**Un hueco nunca se disfraza de política.** Lo que se puede obtener sigue `MISSING`:
- los adaptadores del lote E: alert log, listener y SO;
- lo que desde `CDB$ROOT` no se ve de una PDB: UNDO, credenciales por defecto, proxy y políticas de auditoría;
- las vistas sin collector certificado: result cache, latches, cursores hijos, BIGFILE, standby redo logs, RAC, rebalance ASM, broker, ACL y Resource Manager fuera de una CDB.

P20 verifica que ninguna exclusión tenga `gap`.

## Dominios

28 dominios y 127 ítems: los 26 de `ANA-20261020-001` (A–Z), "Red visible desde la base" (`NET`) y "Sistema operativo" (`OS`). Cada collector del catálogo tiene al menos un ítem, salvo las sondas `Q-DICT-VERIFY-*`, que verifican el diccionario y no son evidencia de un dominio. P20 exige las dos cosas.

## Cómo se usa

1. El orquestador arma las observaciones del assessment: el estado de cada collector en el gateway (`OBSERVED`, `DEGRADED`, `FAILED` o su `capability_status`), la topología observada en el discovery y el `license_status` del target.
2. `python3 -m scripts.assessment_coverage.evaluate --observations obs.json --format md` entrega la tabla. `--format json` entrega el detalle por ítem con `model_sha256`.
3. La revisión de especialistas puede bajar un estado, con `review_note`.
   - El evaluador no juzga el contenido. Cero filas cuentan como obtenidas, porque "ninguna sesión bloqueada" es un dato.
   - Un collector de historia con cero filas, como AWR de 24 h sin snapshots porque el ambiente estuvo detenido, no alcanza para juzgar la carga. El especialista baja ese dominio a `INSUFFICIENT_EVIDENCE` (ocurrió en el lab con D, E y F; ver `docs/D_COMPLETE_WITHIN_POLICY.md`).
4. `document --kind assessment` recibe `domain_coverage` y valida:
   - `COMPLETE_WITHIN_POLICY` con al menos una exclusión;
   - `PARTIAL` y `NOT_ASSESSED` con lo que falta;
   - `COMPLETE` sin faltantes ni exclusiones;
   - solo bajas.

Stdlib, determinista, sin acceso a Oracle; igual en Windows, macOS y Linux.

## Evolución

El modelo cambia por `/change` (`compatibility`/`documentation`). Al certificar un collector nuevo:
- se agrega a un ítem existente, o
- reemplaza el `gap` de uno.

Al aprobar el lote E, los ítems `D4`, `H3`, `NET3` y `OS1`–`OS4` pasan a depender de los adaptadores reales.

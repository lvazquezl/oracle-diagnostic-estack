# PHASE 11 — RCA STRUCTURED EVIDENCE SANITIZATION & OUTPUT LEAK PREVENTION HARDENING

Hardening acotado sobre `docs/PHASE_11_RCA_EXECUTION_EVIDENCE_VALIDATION_HARDENING.md` (misma
rama `phase/11-incident-rca`, baseline `v0.10.0-capacity-forecasting`), exclusivamente sobre
sanitización de evidencia estructurada y prevención de fugas de salida en `rca_engine/`. No
reconstruye Phase 11 ni avanza a Phase 12.

## Diagnóstico inicial (fuga reproducida)

El sanitizador previo (`rca_engine/sanitize.py`, Fase de ejecución RCA) sólo aplicaba patrones de
redacción a `evidence.summary`/`incident.symptom_description` — su propio docstring lo admitía
explícitamente: *"Structured `attributes` dict values are never sanitized here"*. Reproducido con
el marcador sintético `SYNTHETIC_SECRET_DO_NOT_USE_8f2c`:

1. Colocado en `incident.target_id`, `evidence.signature`, `evidence.source_id`, una clave de
   `evidence.attributes`, un valor de `evidence.attributes` y un valor anidado dentro de
   `attributes` → **5 apariciones crudas en `result.json`, 2 en `report.md`** tras una corrida
   exitosa (`cli_exit=0`).
2. Colocado en `evidence.event_type` (valor inválido, forzando el rechazo de intake) →
   **el mensaje de error de `IntakeError` ecoaba el valor crudo completo hacia stderr**.
3. Un `evidence.evidence_id` duplicado también ecoaba el valor crudo en el mensaje de error.

Causa raíz: el sanitizador nunca tocaba campos estructurados (`target_id`, `signature`,
`source_id`, `attributes`), y los mensajes de validación interpolaban directamente el valor
ofensivo en el string de error.

## Files created

- `rca_engine/tokenization.py` — tokens opacos, deterministas, namespaced por incidente.
- 9 fixtures nuevos bajo `tests/fixtures/rca_engine/` (`marker_combined_all_fields.json`,
  `marker_bare_no_key_hint.json`, `malformed_multi_error.json`, `malformed_bad_event_type.json`,
  `malformed_duplicate_evidence_id.json`, `malformed_secret_shaped_evidence_id.json`,
  `invalid_typed_attribute.json`, `numeric_boolean_types.json`, `signature_clustering.json`) + 4
  fixtures de tokenización (`target_token_same_incident_a/b.json`,
  `target_token_different_target.json`, `target_token_different_incident.json`).
- 12 tests nuevos bajo `tests/test_rca_*.sh` (lista exacta del prompt de hardening, ver abajo).

## Files modified

- `rca_engine/sanitize.py` — reescrito: `deep_sanitize()` recursivo con guards de
  profundidad/tamaño/ciclo, `sanitize_attributes()` con allowlist, `normalize_signature()`,
  `_key_contains_narrow_secret_pattern()`.
- `rca_engine/intake.py` — reescrito: sanitiza/tokeniza cada campo (target_id, source_id,
  signature, attributes, evidence_id, domain, symptom_description, summary) antes de que
  cualquier estructura salga de esta función; mensajes de error sin eco de valor crudo.
- `rca_engine/rules.py` — agrega `collect_allowed_attribute_keys()`.
- `rca_engine/common.py` — agrega `ALLOWED_DOMAINS`, `SAFE_IDENTIFIER_SHAPE`.
- `rca_engine/engine.py` — reordena: reglas se cargan **antes** que intake (el allowlist de
  atributos depende del catálogo); `run_rca()` ahora retorna `(result, token_map)`.
- `rca_engine/cli.py` — agrega `--token-map` (salida separada, nunca fusionada); captura
  `SanitizationError`.
- `tests/lib/rca_engine_e2e_helpers.sh` — `rca_engine_run()` acepta un 8º parámetro `token_map_rel`.
- `docs/INCIDENT_READONLY_SECURITY_MODEL.md` — sección nueva de sanitización estructurada.
- `tests/test_secret_detection.sh` — sin cambios de lógica; 2 falsos positivos del propio escáner
  de secretos del repo contra prosa/código de este mismo hardening corregidos en los archivos que
  los disparaban (ver Known limitations).

## Root cause

Sanitización incompleta por diseño (cobertura de campo parcial) + mensajes de error que
interpolaban el valor crudo directamente. Ninguna de las dos causas estaba relacionada con la
lógica causal del motor (RCA gates), que permanece intacta y fue re-verificada explícitamente.

## Input sanitization policy

`intake.py#validate_and_sanitize()` es el único punto de entrada de datos al motor — **antes**
de timeline/hipótesis/RCA/reportes. Política por campo:

| Campo | Tratamiento |
|---|---|
| `incident.id` | Validado contra `SAFE_IDENTIFIER_SHAPE`, nunca tokenizado (preserva `INC-...` literal para trazabilidad) |
| `incident.target_id` | **Tokenizado** (`TGT-...`), namespaced por `incident_id` |
| `incident.symptom_description` | `sanitize_text()` + sustitución literal del `target_id` crudo por su token |
| `incident.declared_evidence_refs` | Validado por forma + `contains_secret_pattern`; referencia inválida se excluye silenciosamente (degrada a "missing", nunca se eco) |
| `evidence.evidence_id` | Validado contra `SAFE_IDENTIFIER_SHAPE` + `contains_secret_pattern`; nunca tokenizado (preserva trazabilidad `EVD-...`) |
| `evidence.domain` | Validado contra `ALLOWED_DOMAINS` (allowlist fija de 11 dominios) — rechazado si no coincide |
| `evidence.event_type` | Validado contra el enum fijo existente (ya existía; el mensaje de error se corrigió para no ecoar) |
| `evidence.source_id` | **Tokenizado** (`SRC-...`), namespaced por `incident_id` |
| `evidence.signature` | `normalize_signature()` — forma segura conocida o `UNRECOGNIZED_SIGNATURE` |
| `evidence.summary` | `sanitize_text()` + sustitución literal de `target_id`/`source_id` crudos |
| `evidence.attributes` | `sanitize_attributes()` — allowlist derivado del catálogo de reglas + validación de tipo |

## Recursive schema coverage

`deep_sanitize()` — profundidad máxima 6, máx. 200 claves por objeto, máx. 200 elementos por
lista, máx. 2000 caracteres por string, presupuesto total de 5000 nodos. Ciclos de referencia
Python (nunca representables en JSON puro, pero alcanzables si un llamador interno pasa un objeto
crudo) detectados vía seguimiento de `id()` por rama de recursión. Tipos no soportados (objetos
custom, bytes, etc.) rechazados — nunca convertidos a string silenciosamente. Verificado con
`test_rca_sanitizer_depth_size_cycle_guards.sh` (5 sub-casos: profundidad, longitud de lista,
número de claves, ciclo, tipo no soportado).

## Target_id tokenization

`tokenization.derive_target_token(incident_id, raw_target_id)` — HMAC-SHA256 truncado (16 hex),
prefijo `TGT-`. Determinista dentro de un incidente (mismo crudo → mismo token), namespaced por
`incident_id` (mismo crudo bajo incidente distinto → token distinto, sin correlación
cross-incident no autorizada). El pepper de namespacing es una constante fija **en el código
fuente, pública** — explícitamente documentado como NO un mecanismo de confidencialidad
criptográfica por sí solo, sino de estabilidad/namespacing (ver limitaciones). Verificado con
`test_rca_target_token_correlation.sh` (4 fixtures: mismo incidente+mismo target → mismo token;
mismo incidente+target distinto → token distinto; incidente distinto+mismo target crudo → token
distinto).

## Signature safe normalization

`normalize_signature()` — preserva verbatim sólo `^(ORA|TNS|RMAN|CRS|LSNR|PLS)-\d{3,6}$` o
`^[A-Z][A-Z0-9_]{2,63}$` (plantilla estructural); cualquier otra forma → literal fijo
`UNRECOGNIZED_SIGNATURE`. Dos evidencias con la misma signature segura siguen correlacionando
idénticamente (clustering preservado) — verificado con `test_rca_signature_safe_clustering.sh`.

## Nested attributes / keys

`sanitize_attributes()` aplica `deep_sanitize()` primero (guards estructurales/texto), luego
descarta cualquier clave fuera del allowlist derivado de `rules.collect_allowed_attribute_keys()`
— una clave desconocida (incluida una con forma de marcador/secreto) se descarta por completo,
clave y valor, nunca ecoada. Una estructura anidada bajo una clave desconocida se descarta en
bloque sin necesidad de inspeccionar su interior. Verificado con
`test_rca_sanitize_nested_keys_and_values.sh` (vía el pipeline CLI real + `deep_sanitize()` a
nivel unitario).

## Numeric / boolean preservation

Enteros/flotantes/booleanos en atributos permitidos permanecen tipados — nunca convertidos a
string, nunca enmascarados. Verificado end-to-end (fixture con `int 96`, `bool true`, `bool
false` produce el resultado causal correcto, `CONFIRMED`) y a nivel unitario
(`sanitize_attributes()` invocado directamente, verificando `isinstance` exacto) en
`test_rca_preserves_numeric_boolean_causal_fields.sh`.

## Invalid-input fail-closed

Un valor string sospechoso inyectado en un campo tipado (`nproc_utilization_percent`) se
descarta silenciosamente — nunca coaccionado a número, nunca ecoado — degradando correctamente la
hipótesis a no-confirmada por falta de esa evidencia específica. Verificado con
`test_rca_invalid_typed_input_fails_closed.sh`.

## Output surfaces covered

JSON (`--out`), Markdown (`--markdown`), evidence manifest (`--manifest`), stdout (payload sin
`--out`), stderr (todos los mensajes de error/excepción), y el nuevo `--token-map` (que
legítimamente contiene el valor crudo, pero **aislado en su propio archivo**, nunca fusionado con
las demás salidas). No existen archivos temporales/cache/trazas de diagnóstico adicionales en
`rca_engine/` — el único artefacto "crudo" posible es exactamente ese `--token-map` opcional,
explícitamente documentado como material sensible local.

## JSON / Markdown / manifest

`test_rca_no_secret_in_json_markdown_manifest.sh` verifica los tres simultáneamente sobre el
fixture combinado (marcador en los 6 campos de riesgo a la vez). `test_rca_cli_e2e_no_secret_leak.sh`
añade stderr y la verificación de idempotencia (re-ejecución del mismo fixture ya saneado produce
salida estable, sin re-fuga, mismo mapa de tokens).

## Stdout / stderr / logs / errors

`test_rca_no_secret_in_stdout_stderr_logs_errors.sh` induce 5 errores distintos (dominio
inválido, `event_type` inválido, `evidence_id` duplicado, `evidence_id` con forma de secreto,
JSON sintácticamente roto) y verifica ausencia del marcador en cada mensaje de stderr — ningún
caso produce un archivo de salida pese al rechazo.

## Traceability / correlation regression

La cadena `INC → EVD → FND → HYP → RCA → REC → CHG` permanece intacta: `evidence_id` nunca se
tokeniza (se valida por forma en su lugar), preservando las referencias literales
`supporting_evidence_ids`/`contradicting_evidence_ids`/`declared_evidence_refs` ya verificadas por
los 20 tests de la fase de ejecución previa — re-ejecutados sin modificación y todos en verde tras
este hardening. `test_rca_no_false_root_cause_after_sanitization.sh` re-verifica explícitamente 4
escenarios de causalidad (contradicción crítica, proximidad temporal, evidencia insuficiente,
referencia de evidencia faltante) contra el motor rediseñado.

## No remediation execution

`test_rca_no_automatic_remediation.sh` — `rca_engine/tokenization.py` y el `sanitize.py`/
`intake.py` reescritos no importan `subprocess`, no llaman `os.system`, no definen
`execute_sql`/`execute_shell`/`read_file`. Toda recomendación permanece `execution_status:
"NOT_EXECUTED"` (default fijo del dataclass, sin cambios).

## Regresión de un defecto propio de este hardening

Al implementar la heurística de "token desnudo" (cadena aislada ≥20 caracteres alfanumérico/`_+/=-`)
para detectar secretos sin prefijo `key=`, se aplicó inicialmente también a **nombres de clave**
en `deep_sanitize()` — lo cual descartaba erróneamente atributos legítimos del catálogo de reglas
(ej. `nproc_utilization_percent`, `fork_failures_stopped_after_limit_increase`, ambos ≥20
caracteres de snake_case legítimo), causando que el fixture positivo ya verificado en el hardening
anterior dejara de confirmar (`CONFIRMED` → `INSUFFICIENT_EVIDENCE`). Detectado inmediatamente
por la re-ejecución de los 20 tests preexistentes tras el rediseño (disciplina de este proyecto:
nunca declarar un rediseño terminado sin re-correr la regresión existente). Corregido introduciendo
`_key_contains_narrow_secret_pattern()` — una verificación estrecha (sólo patrones estructurados
prefijo-anclados) exclusiva para nombres de clave, dejando la heurística de token desnudo completa
para valores de texto libre, donde sí es el comportamiento previsto.

## Known limitations / residual risks

- **Ninguna heurística de texto prueba ausencia total de secretos.** `sanitize_text()`/
  `_looks_like_bare_secret()` son deliberadamente amplias (sesgadas hacia sobre-redactar, el modo
  de falla más seguro para un control de seguridad) pero no exhaustivas — un secreto formateado de
  forma suficientemente inusual podría evadirlas. La defensa real y estructural (no heurística)
  para `attributes` es el allowlist de claves conocidas; para `target_id`/`source_id` es la
  tokenización obligatoria; para `signature` es la validación de forma seleccionada.
- **El pepper de tokenización es una constante pública en el código fuente**, no un secreto
  criptográfico — el propósito es namespacing/estabilidad determinista, no confidencialidad
  irreversible. Un atacante con una lista de candidatos plausibles de `incident_id`+`target_id`/
  `source_id` podría en principio verificar coincidencias por fuerza bruta. Documentado
  explícitamente en `rca_engine/tokenization.py`, nunca presentado como cifrado.
  Mitigación disponible pero fuera de alcance de este hardening: rotar el pepper a un secreto real
  gestionado externamente si el modelo de amenaza lo requiere.
- **La sustitución literal del `target_id`/`source_id` crudo en texto libre es exacta, no
  heurística** — cubre la repetición verbatim del identificador, pero no detecta una referencia
  parafraseada o parcial (ej. sólo el sufijo numérico del hostname). Un detector genérico de
  "cualquier hostname" es indecidible sin un allowlist externo — deliberadamente no se afirma
  cobertura ahí.
- **`declared_evidence_refs`/`evidence_id` no se tokenizan** (se validan por forma en su lugar)
  para preservar la trazabilidad literal `EVD-...` ya usada extensivamente por los 20 tests de
  ejecución previos y por las salidas orientadas al DBA — un `evidence_id` que evade
  `contains_secret_pattern` (por no tener forma de token largo ni patrón estructurado) podría en
  principio contener información sensible de baja entropía; el riesgo se juzgó bajo dado que
  `evidence_id` es típicamente asignado por el pipeline de evidencia certificado, no por texto
  libre de usuario.
- **Falsos positivos del escáner de secretos del propio repositorio** (`tests/test_secret_detection.sh`)
  contra prosa/código de este mismo hardening que menciona, como ejemplo, un patrón `password`
  seguido de `=` —
  corregidos en los 2 archivos afectados (ver Files modified), sin relajar el escáner ni el
  sanitizador real.

## Targeted tests

`bash tests/test_rca_*.sh` (32 archivos, 20 preexistentes + 12 nuevos de esta hardening) +
`tests/test_incident_*.sh` (~63) + 13 extensiones de safety + `test_capability_matrix_schema.sh`/
`test_capability_matrix_registry_consistency.sh` + `test_secret_detection.sh`/`test_no_secrets.sh`
— resultado exacto en la sección **Salida final obligatoria** de este mismo reporte.

## Full regression

`tests/run-all.sh` — obligatorio dado que este hardening modifica una frontera de seguridad
transversal (sanitización de evidencia) del flujo RCA. Resultado exacto, comando, exit code y
reconciliación triple-independiente en la sección **Salida final obligatoria**.

## Portability / git diff --check

`git diff --check` limpio (exit 0) sobre el repositorio completo, incluyendo todos los archivos
nuevos/modificados de este hardening. Sin CRLF (verificado explícitamente, excluyendo
`__pycache__/*.pyc` binarios, gitignorados e irrelevantes).

## Referencias

`rca_engine/sanitize.py`, `rca_engine/tokenization.py`, `rca_engine/intake.py`,
`tests/test_rca_sanitize_*.sh`, `tests/test_rca_no_secret_*.sh`, `tests/test_rca_target_token_correlation.sh`,
`tests/test_rca_signature_safe_clustering.sh`, `docs/INCIDENT_READONLY_SECURITY_MODEL.md`,
`docs/PHASE_11_RCA_EXECUTION_EVIDENCE_VALIDATION_HARDENING.md`,
`sanitizers/data-classification-policy.md`.

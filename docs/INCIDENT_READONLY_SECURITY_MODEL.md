# Incident Read-Only Security Model — Fase 11

## Non-negotiables (verbatim del prompt de Fase 11)

READ-ONLY ALWAYS · HUMAN-EXECUTED REMEDIATION ONLY · EVIDENCE FIRST · NO ROOT · NO SUDO ·
NO ARBITRARY SQL · NO ARBITRARY SHELL · NO AUTOMATIC SERVICE/DATABASE RESTART ·
NO PARAMETER CHANGE · NO FAILOVER/SWITCHOVER EXECUTION · NO SESSION/PROCESS KILL ·
NO STORAGE/NETWORK/SECURITY CHANGE · NO RMAN EXECUTION · NO INCIDENT ACTION MAY MUTATE PROD ·
ROOT CAUSE MUST BE EVIDENCE-BASED · CORRELATION IS NOT CAUSATION ·
CAUSE/CONTRIBUTING-FACTOR/SYMPTOM MUST REMAIN DISTINCT · UNCERTAINTY MUST BE EXPLICIT ·
TIMELINE MUST BE TRACEABLE · RCA MUST BE REPRODUCIBLE · MULTI-AGENT DOES NOT MEAN MULTI-CONTEXT ·
AGENTS FOR DOMAINS/SKILLS FOR TASKS · ANALYZE ONCE DOCUMENT MANY.

## security_mode

`security_mode: READ_ONLY_ALWAYS` — declarado en
`agents/incident-root-cause-analyst/manifest.yaml`, mismo campo/valor que el resto de agentes de
dominio del e-stack.

## forbidden_capabilities (agente)

Restart/relocate de servicio, `KILL SESSION`, kill de proceso OS, failover/switchover, cambio de
parámetro, cambio de storage/red/seguridad, ejecución de RMAN, SQL/shell arbitrario, escalamiento
de privilegios — las 12 prohibiciones explícitas de `agents/incident-root-cause-analyst/manifest.yaml#forbidden_capabilities`.

## Evidence policy

Hereda `sanitizers/data-classification-policy.md` (KEEP/MASK/HASH/TOKENIZE/DROP) — nunca
passwords, hashes, wallet secrets, private keys, SQL text sensible completo, bind values, datos
de negocio, identificadores crudos de clientes en ningún artefacto generado (timeline, findings,
reportes).

## Structured evidence sanitization (rca_engine — Fase 11, RCA Structured Evidence Sanitization & Output Leak Prevention Hardening)

Extiende la política declarativa de arriba con una implementación ejecutable propia del motor
RCA local (`rca_engine/`), que corre íntegramente **antes** de timeline/hipótesis/RCA/reportes —
ver `docs/PHASE_11_RCA_STRUCTURED_EVIDENCE_SANITIZATION_HARDENING.md` para el reporte de cierre
completo. Reemplaza el sanitizador estrecho anterior (que sólo cubría `summary`/
`symptom_description` con patrones fijos y dejaba `attributes`/`target_id`/`signature`/
`source_id` completamente sin sanitizar — brecha real, reproducida y cerrada en este hardening).

- **`rca_engine/sanitize.py`** — `deep_sanitize()` recorre recursivamente cualquier estructura
  (dict/list/escalar) con límites de profundidad (6), claves por objeto (200), longitud de lista
  (200) y presupuesto total de nodos (5000); rechaza (fail-closed, nunca eco) referencias
  cíclicas, claves no-string y tipos no soportados. `sanitize_text()` combina patrones
  estructurados de ejemplo (`password` seguido de `=`, AKIA, bloques PEM, hashes hex 32+, `Bearer`, connection strings) con
  una heurística de "token desnudo" (palabra aislada ≥20 caracteres) para texto libre — nunca se
  afirma que esto detecta el 100% de los secretos posibles (heurística documentada, no
  exhaustiva).
- **`sanitize_attributes()`** — política de allowlist: sólo las claves que el catálogo de reglas
  (`rules.collect_allowed_attribute_keys()`) realmente consume sobreviven; cualquier clave
  desconocida se descarta por completo (clave y valor, nunca ecoados); una clave permitida con un
  tipo distinto al esperado (bool/int/float) se descarta como `INVALID_INPUT` sin eco — nunca
  coaccionada a string.
- **`rca_engine/tokenization.py`** — `target_id`/`source_id` nunca se propagan crudos: se
  reemplazan por un token opaco derivado (`TGT-`/`SRC-` + HMAC-SHA256 truncado), estable dentro
  del mismo incidente (mismo valor crudo → mismo token) pero namespaced por `incident_id` (mismo
  valor crudo bajo un incidente distinto → token distinto — sin correlación cross-incident sin
  autorización explícita, que no existe hoy). El mapa token→crudo sólo se escribe si se pide
  explícitamente (`--token-map`, CLI), en un archivo separado, nunca fusionado con `--out`/
  `--markdown`/`--manifest`.
- **`classify_signature()`** (Fase 11, RCA Signature Allowlist & Output Leak Prevention
  Micro-Hardening — reemplaza el `normalize_signature()` original, que aceptaba verbatim
  *cualquier* cadena con forma `UPPER_SNAKE_CASE` de 3-64 caracteres: una regex genérica nunca
  prueba que el contenido sea seguro, y un marcador como `SYNTHETIC_SECRET_DO_NOT_USE` coincidía
  con esa forma y se filtraba literal a JSON/Markdown — defecto real, reproducido y cerrado en
  este micro-hardening). Certificación por **dos vías independientes y acotadas**, nunca por
  forma genérica sola: (1) un código numérico tipado bajo un prefijo conocido y fijo
  (`^(ORA|TNS|RMAN|CRS|LSNR|PLS)-\d{3,6}$` — seguro porque el espacio de valores es un código
  numérico acotado, no texto libre elegido por la fuente); (2) membresía **exacta** en el
  conjunto versionado de nombres de plantilla que el catálogo de reglas cargado realmente declara
  (`rules.collect_certified_signatures()`) — coincidir con la forma `UPPER_SNAKE_CASE` nunca basta
  por sí solo. Devuelve tres campos separados, nunca un único string ambiguo:
  `signature_status` (`CERTIFIED|UNRECOGNIZED_SIGNATURE|INSUFFICIENT_EVIDENCE`),
  `canonical_signature` (sólo si `CERTIFIED`, seguro para reportar) y `signature_token` (opaco,
  no reversible, namespaced por incidente vía `tokenization.derive_signature_token()`, presente
  sólo si NO es `CERTIFIED`) — el token nunca filtra longitud/prefijo/sufijo de la firma original
  (longitud fija de 16 hex). El valor crudo (`raw_signature`) es estrictamente transitorio dentro
  de `intake.py` y nunca llega a `NormalizedEvidence`/`TimelineEvent`/`RcaResult`; sólo se
  conserva en el mapa `--token-map` local y separado (mismo aislamiento que `target_id`/
  `source_id`). Agrupación/dedup/correlación de timeline usan exclusivamente
  `canonical_signature` (si `CERTIFIED`) o `signature_token` (si no) como clave — nunca el texto
  crudo como clave serializable. El motor de reglas (`rules._symptom_matches()`) sólo puede
  emparejar una hipótesis contra una firma `CERTIFIED`, nunca contra una `UNRECOGNIZED_SIGNATURE`.
- **`ALLOWED_DOMAINS`** (`common.py`) — `domain` es un campo estructural de vocabulario fijo (11
  dominios conocidos); cualquier valor fuera de ese conjunto se rechaza (`INVALID_INPUT`, fail
  closed) antes de tocar el motor de reglas.
- **Mensajes de error nunca ecoan el valor crudo** — `intake.py` reporta únicamente el nombre/
  índice del campo y, cuando aplica, el conjunto de valores permitidos (un enum fijo no es un
  secreto); un `event_type`/`domain` inválido, un `evidence_id` duplicado o con forma de secreto,
  nunca aparecen en el mensaje de excepción ni en stderr.
- **Preservación de tipos causales** — enteros/booleanos en atributos permitidos permanecen
  tipados (nunca convertidos a string, nunca enmascarados indiscriminadamente); un valor
  sospechoso en un campo tipado se descarta sin eco, nunca se fuerza una conversión.
- **Idempotencia** — re-ejecutar el mismo fixture ya saneado produce salida estable (excepto
  `generated_at`) y el mismo mapa de tokens — verificado explícitamente.
- **Riesgo residual documentado, nunca minimizado**: ningún conjunto de patrones/heurísticas
  prueba la ausencia de todo secreto posible; ver
  `docs/PHASE_11_RCA_STRUCTURED_EVIDENCE_SANITIZATION_HARDENING.md#known-limitations--residual-risks`.

## Verificación (13 tests de safety)

`tests/test_incident_read_only.sh`, `test_no_session_kill.sh`, `test_no_process_kill.sh`,
`test_no_restart_execution.sh`, `test_no_failover_execution.sh`,
`test_no_switchover_execution.sh`, `test_no_parameter_change.sh`, `test_no_storage_change.sh`,
`test_no_network_change.sh`, `test_no_security_change.sh`, `test_no_rman_execution.sh`,
`test_no_arbitrary_sql.sh` (extendido, nunca sobrescrito — ya extendido dos veces en Fase 9/10),
`test_no_arbitrary_shell.sh` (extendido, nunca sobrescrito).

## Verificación (41 tests de rca_engine)

20 tests de ejecución RCA (`tests/test_rca_e2e_*.sh` y afines, Fase 11 RCA Execution & Evidence
Validation Hardening) + 12 tests dedicados de sanitización estructurada (Fase 11 RCA Structured
Evidence Sanitization & Output Leak Prevention Hardening): `test_rca_sanitize_all_structured_fields.sh`,
`test_rca_sanitize_nested_keys_and_values.sh`, `test_rca_no_secret_in_json_markdown_manifest.sh`,
`test_rca_no_secret_in_stdout_stderr_logs_errors.sh`, `test_rca_target_token_correlation.sh`,
`test_rca_signature_safe_clustering.sh`, `test_rca_preserves_numeric_boolean_causal_fields.sh`,
`test_rca_invalid_typed_input_fails_closed.sh`, `test_rca_sanitizer_depth_size_cycle_guards.sh`,
`test_rca_cli_e2e_no_secret_leak.sh`, `test_rca_no_false_root_cause_after_sanitization.sh`,
`test_rca_no_automatic_remediation.sh` + 9 tests dedicados de allowlist de firmas (Fase 11 RCA
Signature Allowlist & Output Leak Prevention Micro-Hardening):
`test_rca_signature_marker_not_certified_no_leak.sh`, `test_rca_unknown_signature_shapes_no_leak.sh`,
`test_rca_signature_no_alternate_leak_path.sh`, `test_rca_certified_signature_regression.sh`,
`test_rca_unknown_signature_token_correlation.sh`, `test_rca_signature_error_paths_no_leak.sh`,
`test_rca_signature_all_surfaces_no_leak.sh`, `test_rca_signature_arbitrary_regex_not_certified.sh`,
`test_rca_signature_generic_regex_regression_guard.sh`.

## Referencias

`agents/incident-root-cause-analyst/manifest.yaml`, `policies/forbidden-operations.md`,
`sanitizers/data-classification-policy.md`, `docs/INCIDENT_MANUAL_REMEDIATION_MODEL.md`,
`docs/PHASE_11_RCA_EXECUTION_EVIDENCE_VALIDATION_HARDENING.md`,
`docs/PHASE_11_RCA_STRUCTURED_EVIDENCE_SANITIZATION_HARDENING.md`,
`docs/PHASE_11_RCA_SIGNATURE_ALLOWLIST_LEAK_PREVENTION_MICRO_HARDENING.md`.

# Phase 3 — Performance Completion & Portability Hardening

Branch: `phase/3-performance`. Baseline: `v0.2.0-oracle-core` + Fase 3 (Oracle Performance, no tagueada aún). Objetivo del baseline resultante: `v0.3.0-performance`. Esta fase **no es un rebuild de Fase 3** — cierra 4 gaps explícitos sobre el mismo trabajo ya construido, sin reconstruir los 31 skills existentes salvo donde genuinamente lo requería un gap.

## Scope

Cuatro gaps cerrados: (1) Statspack como capability multi-sección real, no sólo wait events; (2) arquitectura genérica de ingesta/parseo local de reportes de performance (AWR/Statspack/ADDM/Execution Plan); (3) materialización del contrato de `oracle-performance-analyst` en archivos estructurados; (4) hardening de portabilidad cross-platform (line endings, test runner, documentación Windows/Git Bash/WSL/CI). Explícitamente fuera de alcance: reconstrucción de los 31 skills existentes, nuevos agentes, RAC/ASM/GI deep diagnostics, auto-remediación, generación de documentos binarios, un Execution Plane.

## Gap 1 — Statspack completion

`skills/performance/statspack-analysis` (`v2.0.0`) ya no se limita a wait events. Cobertura real, validada contra un fixture 11g completo (`tests/fixtures/reports/statspack-11g.txt`): Load Profile, Instance Efficiency, Top Wait Events, SQL ordered by CPU/elapsed/executions/gets/reads, Instance Activity, Buffer Cache/Library Cache/Shared Pool (Cache Sizes), Latch Activity, Enqueue Activity, File I/O (incluyendo paths ASM `+DATA/...`), Redo/Commit y Parsing (derivados de Load Profile + Instance Efficiency, ya que Statspack no tiene headers dedicados para estos dos). Cada sección reporta su propio `completeness`: `SUPPORTED` (header presente + filas), `PARTIALLY_SUPPORTED` (header presente, sin filas), `UNSUPPORTED` (header ausente en el reporte concreto) — nunca se finge una sección que el reporte fuente no contiene. El `statspack_capabilities:` map en el propio `SKILL.md` declara explícitamente qué NO cubre Statspack frente a AWR (`ash_sampling`, `awr_specific_metrics`: `unsupported`, con `reason`).

## Gap 2 — Report ingest architecture

Pipeline nuevo, genérico y local: `FILE → TYPE DETECTOR → LOCAL PARSER → STRUCTURED REPORT → SANITIZER → EVIDENCE → SKILL → AGENT`, implementado en `parsers/performance/` — el primer código fuente no Markdown/YAML/Bash del repositorio (Python 3, sólo librería estándar).

- **`common.py`**: envelope `ParsedReport` (`report_id, source_type, parser_version, detection_confidence, status, metadata, sections, warnings, completeness, sensitivity, sanitization_status, evidence_refs, source_file_hash, parse_timestamp, sections_extracted, sections_missing`), `ParseStatus` (`SUCCESS/PARTIAL/UNSUPPORTED_FORMAT/UNKNOWN_REPORT_TYPE/MALFORMED_REPORT/EMPTY_REPORT/SANITIZATION_FAILED`), `SizeLimitPolicy` (`max_report_size_bytes=20MB, max_section_size_bytes=2MB, max_sql_entries=200, max_wait_entries=100, max_plan_rows=500`, configurable, nunca hardcoded en silencio), `Sanitizer` (tokenización determinista de hostname/db_name/service_name/schema/object_name, scrub de IPs, `drop_sql_text()` — SQL text es siempre DROP por política, nunca KEEP/MASK/HASH), `apply_size_limits()` como único punto de enforcement de truncamiento (con warning explícito cuando trunca).
- **`type_detector.py`**: `detect_report_type(text) -> (ReportSourceType, confidence)`, basado en firmas de contenido — nunca confía en la extensión del archivo. Devuelve `UNKNOWN`/confianza `LOW` cuando nada coincide; los llamadores no deben adivinar un parser para `UNKNOWN`.
- **`statspack_parser.py`**, **`awr_parser.py`**, **`addm_parser.py`**, **`execution_plan_parser.py`**: un parser por tipo de reporte, cada uno devolviendo el mismo envelope.
- **`ingest.py`**: orquestador único (`ingest_report`) — detecta tipo primero, despacha al parser correspondiente, `UNKNOWN_REPORT_TYPE` sin invocar ningún parser si la detección falla.

**Seguridad del parser** (verificada, no sólo declarada): ningún módulo llama `eval`/`exec`/`subprocess`/`os.system`/`compile()` sobre contenido de reporte — el contenido es siempre DATA, nunca instrucción. Probado con `tests/fixtures/reports/addm-injection-attempt.txt` (contiene texto tipo "IGNORE ALL PREVIOUS INSTRUCTIONS"/`rm -rf /`/`ALTER SYSTEM KILL SESSION`) y `tests/test_parser_does_not_execute_embedded_instructions.sh` (grep estático sobre el código fuente real de los parsers, no sobre su documentación). SQL text/bind values nunca se extraen de ningún reporte, en ningún parser.

## Gap 3 — Agent contract materialization

`agents/oracle-performance-analyst/` (`v4.0.0`) pasa de un único `AGENT.md` a un contrato estructurado en 8 archivos, YAML como fuente de verdad, sin duplicar contenido:

- **`manifest.yaml`**: `id/version/domain/status/mission`, `supported_versions`, `supported_architectures`, `allowed_skills` (31, exactamente), `forbidden_capabilities` (`ALTER SESSION/SYSTEM`, `KILL SESSION`, ejecución de SQL Tuning/Access Advisor, creación de SQL Profile/Patch, escritura de SQL Plan Baseline, cambios de parámetro, `DBMS_ADVISOR.EXECUTE_TASK`, cualquier escritura, cualquier llamada MCP no certificada), `required_gates` (secuencia version→architecture→license→privilege→cost), `input_contract`, `output_contract`, `security_mode: READ_ONLY_ALWAYS`, `evidence_policy`, `evolution_policy`.
- **`routing.yaml`**: `activation_conditions`, `deactivation_rule`, `delegates_to` (6 agentes con `when:`), `receives_from`, `must_not_delegate_to: [oracle-dba-analyst, oracle-discovery-analyst]` (previene loops).
- **`context-policy.yaml`**: `minimum_context`, `evidence_by_reference`, `top_n` (default 10, configurable), `no_full_report`/`no_full_history`/`no_sql_text_default`/`no_bind_values`, `context_budget`.
- **`collaboration.yaml`**: `may_delegate_to`, `may_receive_from`, `must_not_delegate_to`, `escalation_conditions` (7), `no_delegation_loop_rule`, `manual_command_rule`.
- **`output-schema.yaml`**: schema completo de `performance_result:` (summary/workload/bottlenecks/findings/hypotheses/evidence_refs/recommendations/manual_actions/limitations/confidence/next_skill_or_agent/capability_status) — `confidence` nunca `CONFIRMED_ROOT_CAUSE`.
- **`AGENT.md`**: reescrito como documento narrativo — cada bloque estructurado que antes vivía inline ahora dice "Ver `manifest.yaml#...`"/`routing.yaml`/etc. en vez de repetir el dato. Retiene únicamente lo genuinamente narrativo: Responsibilities, Explicit boundaries, Performance workflow (con la nueva rama "File report path"), Licensing rules + ejemplos, SQL text policy, Evidence policy + AWR/Report ingest model, Correlation model (con los 2 patrones nuevos de Statspack/AWR), Multi-instance/Multitenant awareness, Confidence rules, Manual command generation, Security constraints, Tests (pointer), Evolution policy (pointer).
- **`tests/README.md`**: nota de diseño explícita — los tests reales viven en el `tests/` plano de nivel repositorio (convención de glob de `run-all.sh`), este archivo sólo referencia los 7 tests de contrato de agente.
- **`CHANGELOG.md`**: Change History movido fuera de `AGENT.md` a este archivo dedicado.

Excepción deliberada a la convención de Fase 2/3 (un único `AGENT.md` para agentes profundizados) — aplicada sólo a `oracle-performance-analyst` por instrucción explícita de esta fase, no retroactiva a otros agentes sin justificación equivalente (ver `ARCHITECTURE.md#19`).

## Gap 4 — Cross-platform / CRLF hardening

`.gitattributes` en la raíz del repositorio fuerza `eol=lf` en `*.sh/*.bash/*.py/*.yaml/*.yml/*.json/*.md`, `binary` en tipos de imagen/PDF. `tests/test_no_crlf_in_shell_scripts.sh` falla el build si cualquier `*.sh`/`*.bash` contiene CRLF, o si algún `*.sh` carece de un shebang bash válido (`#!/usr/bin/env bash`/`#!/bin/bash`), y confirma que `.gitattributes` existe y fuerza `eol=lf` para `*.sh`.

**Hallazgo real durante la construcción de este test** (no un falso positivo del test, ver `# Line ending policy` abajo): 85 archivos `tests/test_*.sh` pre-existentes (de Foundation Hardening, Fase 2 Oracle Core, y Oracle Core Compatibility Hardening) contenían CRLF real, sin detectar hasta esta fase porque el chequeo original usado en fases anteriores no incluía la flag `-U`/`--binary` de grep — en Git Bash/MSYS, grep descarta por defecto el CR de fin de línea antes de matchear, aunque el archivo sí lo tenga. Verificado byte a byte con `od -c` antes de tocar ningún archivo (dos ejemplos confirmados con CR real en offset del salto de línea), y normalizados a LF con `sed -i 's/\r$//'` — contenido verificado idéntico byte a byte tras la normalización (`diff` vacío entre el original con `tr -d '\r'` aplicado manualmente y el resultado de `sed`). Ningún contenido semántico fue modificado, sólo el terminador de línea.

`tests/run-all.sh` extendido (sin cambiar su contrato: sigue sin fail-fast, sigue preservando el exit code agregado) para reportar totales (`N/M tests OK`) y la lista de nombres de tests fallidos en el resumen final. `tests/run_all.py` añadido como runner portable opcional en Python 3 stdlib-only — coherente con `run-all.sh` (mismo criterio pass/fail por script, mismo resumen), no lo reemplaza; requiere `bash` en PATH igual que el original, ya que los tests en sí son scripts bash, no Python.

**Ejecución en Windows**: la vía soportada es Git Bash (incluido en Git for Windows) o WSL — nunca PowerShell/cmd.exe directamente, ya que todos los tests son `#!/usr/bin/env bash`. En CI, cualquier runner Linux ejecuta el mismo `tests/run-all.sh` sin cambios. Recomendación de configuración de estación Windows: `git config --global core.autocrlf input` (o `false`) es opcional — `.gitattributes` ya fuerza `eol=lf` en el checkout independientemente del `core.autocrlf` local, por lo que ningún ajuste de configuración global es estrictamente necesario para que el repositorio se comporte correctamente; se documenta como recomendación, no como prerrequisito bloqueante.

## Line ending policy

Ver Gap 4 arriba. Resumen operativo: `.gitattributes` es la fuente de verdad; `tests/test_no_crlf_in_shell_scripts.sh` es el quality gate que lo hace cumplir en cada regresión; ningún archivo `*.sh`/`*.bash` puede fusionarse a `main` con CRLF real.

## Security validation

Todos los tests de seguridad de fases anteriores (Foundation, Foundation Hardening, Oracle Core, Compatibility Hardening, Fase 3) siguen pasando sin modificación de su lógica. Nuevos: `tests/test_parser_does_not_execute_embedded_instructions.sh`, `tests/test_parser_sanitization.sh`, `tests/test_parser_size_limit.sh`, `tests/test_statspack_no_sql_text_by_default.sh`, `tests/test_performance_agent_no_execution_capability.sh`, `tests/test_performance_agent_no_delegation_loop.sh` — todos `PASS`.

## Test results

Nuevos en esta fase: 12 tests de Statspack multi-sección, 16 tests generales de parser (detección de tipo ×6, parsers AWR/ADDM/execution-plan ×4, secciones faltantes/malformadas/vacías ×3, seguridad/límites/sanitización ×3), 7 tests de contrato de agente, 1 test de portabilidad (`test_no_crlf_in_shell_scripts.sh`) — 36 tests nuevos en total, todos `PASS` tras corregir los bugs propios de diseño de test documentados abajo.

Bugs de test autoinfligidos encontrados y corregidos durante esta fase (ninguno afectó el catálogo certificado en sí): 2 falsos positivos de "mención en prosa" tratada como llamada real (`re.compile(` interpretado como el builtin peligroso `compile()`; un docstring citando "never calls eval()..." interpretado como código real), 2 falsos positivos de negación textual (`grep` matcheando un comentario `# nunca "CONFIRMED_ROOT_CAUSE"` como si fuera el valor asignado), 1 test con deriva semántica (aserción de que SQL metrics vía Statspack eran un gap documentado, ya no cierto tras construir el parser), 1 regex de extracción sobre-amplia (`test_performance_agent_no_delegation_loop.sh` extrayendo palabras sueltas de prosa/comentarios en vez de nombres de agente reales, y matcheando `"agent: X"` en cualquier sección del YAML en vez de sólo en `delegates_to`), 2 bugs de propagación de warning/límite de tamaño en el parser de Statspack (truncamiento silencioso sin warning; warning de truncamiento descartado en el path de retorno temprano por headers no encontrados), 2 bugs reales de extracción del parser (nombres de archivo ASM `+DATA/...` rechazados por la regex genérica de tabla; formato "Cache Sizes" de dos pares label:valor por línea no reconocido por el extractor de tabla genérico), y el propio bug de detección de CRLF documentado en el Gap 4 (dos capas: un patrón bash `\r'` perdiendo su byte CR literal al guardarse en un archivo de script, y `grep` en Git Bash/MSYS descartando CR de fin de línea por defecto sin la flag `-U`).

## Regression results

Ver el reporte de cierre final para el resultado agregado de `tests/run-all.sh` sobre el árbol completo (Foundation + Foundation Hardening + Oracle Core + Oracle Core Compatibility Hardening + Fase 3 Oracle Performance + esta fase), ejecutado después de la normalización de line endings.

## Known limitations

- `awr_parser.py` es una primera versión funcional, no una cobertura perfecta de todos los formatos históricos de AWR HTML/texto — alineación de columnas numéricas imperfecta en algunas filas de wait events. Documentado como tal, no fingido como completo.
- El parser de execution plan requiere la firma exacta de tabla `"| Id  | Operation"`; salidas de `DBMS_XPLAN` en formatos no tabulares devuelven `UNSUPPORTED_FORMAT`, nunca un intento de mejor esfuerzo que podría malinterpretar la estructura.
- Ningún parser genera evidencia si el DBA no adjunta un reporte — sigue siendo una ruta adicional a la evidencia por query en vivo, no un reemplazo.
- `run_all.py` requiere `bash` en PATH — no reimplementa los tests en Python puro, sólo los orquesta; no es una vía de ejecución independiente de bash.

## Next phase

Fase 4 — RAC/GI/ASM deep diagnostics (`oracle-rac-analyst`, `oracle-asm-storage-analyst`), sin cambios respecto a lo ya declarado en `docs/PHASE_3_ORACLE_PERFORMANCE.md#next-phase` — explícitamente fuera de alcance de esta fase de hardening.

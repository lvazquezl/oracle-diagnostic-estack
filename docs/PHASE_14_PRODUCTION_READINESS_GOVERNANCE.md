# PHASE 14 — Production Readiness, Governance & E-Stack Evolution

Baseline: `v0.13.0-mcp-diagnostic-gateway` (`22929bc`, integrado en `main`) · Rama: `phase/14-production-readiness-governance` · Tag objetivo (NO creado por el agente): `v0.14.0-production-readiness-governance`.

Esta fase **no** certifica Oracle productivo ni habilita adaptadores reales. Entrega la capa que permite *decidir con evidencia* qué puede operar y dónde: un registro de capacidades ejecutable, un gate de release que ejecuta código, un empaquetador de evidencias con identidad de árbol verificable, gobierno de cambios/conocimiento y runbooks. Todo lo que sigue `CONTRACT_ONLY`/`DISABLED` se informa como tal. Documentos de la fase: [`PRODUCTION_READINESS.md`](PRODUCTION_READINESS.md), [`OPERATIONS_RUNBOOK.md`](OPERATIONS_RUNBOOK.md), [`SECURITY_AND_PRIVACY.md`](SECURITY_AND_PRIVACY.md), [`RELEASE_AND_ROLLBACK.md`](RELEASE_AND_ROLLBACK.md), [`GOVERNANCE_AND_EVOLUTION.md`](GOVERNANCE_AND_EVOLUTION.md), [`PILOT_ACCEPTANCE_CHECKLIST.md`](PILOT_ACCEPTANCE_CHECKLIST.md).

## 1. Descubrimiento (estado real al inicio de la fase)

| Área | Estado real verificado |
|---|---|
| Git | rama `phase/14-…` creada desde `main` = `22929bc` (merge de Phase 13, tag `v0.13.0-mcp-diagnostic-gateway`); árbol limpio; sin cambios ajenos |
| Runner | `tests/run-all.sh` (43 líneas): itera `tests/test_*.sh`, imprime `=== name ===`, `--- PASS/FAIL: name` y `RESUMEN: N/M tests OK`; **950 scripts**; no captura snapshot, ni exit code por archivo, ni timestamps → no prueba identidad del árbol |
| Paquetes Python (stdlib) | `rca_engine` (Ph. 11), `change_documentation_knowledge` (Ph. 12), `mcp_gateway` (Ph. 13), `capacity_engine` (Ph. 10) |
| Gateway MCP | 5 tools estáticas por stdio; adaptador `fixture` = `VERIFIED_FIXTURE`; `oracle_sql` = `DISABLED`; `oracle_diag_file`/`os_readonly` = `CONTRACT_ONLY`; 7 colectores; 6 destinos sintéticos; límites como constantes de módulo (no configurables) |
| Registros existentes | `config/capability-matrix.yaml` (20 dominios × versiones), `agents/REGISTRY.md` (18 agentes), `skills/REGISTRY.md`, `queries/REGISTRY.md` (fuente humana; sin registro por herramienta/adaptador/estado de certificación real) |
| Gobierno | `EVOLUTION.md` + plano B de Phase 12 (`build_estack_change`); aprobación local `STRUCTURAL_ONLY_IDENTITY_NOT_VERIFIED` |
| Documentación de operación | inexistente: sin runbook, sin política de logging/retención, sin checklist de piloto, sin guía de release/rollback |

## 2. Matriz de brechas

| # | Requisito | Componente al inicio | Estado | Riesgo | Acción mínima | Prueba de aceptación | Cierre |
|---|---|---|---|---|---|---|---|
| G1 | Inventario machine-readable, fuente única | tres registros humanos sin estado de certificación por herramienta/adaptador | PARCIAL | Alto: declaraciones divergen del código | `config/production-readiness-registry.json` + verificador contra el código | `test_p14_inventory_registry.sh` | Cerrada (75 componentes verificados) |
| G2 | Estados con definición verificable | sólo `VERIFIED_FIXTURE/…` en el gateway | PARCIAL | Alto: `CERTIFIED` sin evidencia | definiciones ejecutables; `PILOT_VALIDATED`/`CERTIFIED` exigen registro de piloto válido | ídem | Cerrada (ningún componente los reclama) |
| G3 | Compatibilidad numérica, sin «latest», fail closed | pertenencia a conjunto; **metadatos ausentes = todas las versiones** | **DEFECTO** | Alto: fail-open | normalizador numérico; metadatos ausentes ⇒ cero versiones; colector de alert log restringido a 11g+ (ADR); `missing_privileges` produce `INSUFFICIENT_PRIVILEGES` | inventario, operabilidad | Cerrada |
| G4 | Gate de release ejecutable, JSON+MD sanitizados, exit ≠ 0 | no existía | AUSENTE | Alto | `release_readiness gate` con 10 comprobaciones que ejecutan código | `test_p14_release_gate.sh` | Cerrada |
| G5 | Paquete de evidencias con fingerprint antes/después | paquetes manuales | MANUAL | Alto: identidad sólo indirecta (mtimes) | `release_readiness run/verify` | `test_p14_evidence_packager.sh` | Cerrada |
| G6 | INCONCLUSIVE/FAIL ante timeout, sin exit code, log truncado, alteración, árbol cambiado, omisiones | no verificado | AUSENTE | Alto | veredictos fail-closed + verificador independiente | `test_p14_release_gate.sh` | Cerrada |
| G7 | Threat model de producción y pruebas | Phase 13 cubría stdio/inyección/traversal | PARCIAL | Medio | escaneo AST, sockets bloqueados en runtime, TOCTOU, entorno, fugas en informes | `test_p14_security_threat_model.sh` | Cerrada (límite TOCTOU documentado) |
| G8 | Operabilidad: límites configurables y acotados, cancelación, recuperación | límites fijos; cancelación ignorada sin prueba | PARCIAL | Medio | banderas que **sólo reducen** límites; pruebas de cancelación, caída/reinicio, shutdown, degradación | `test_p14_operability.sh` | Cerrada (sin cancelación en vuelo: plazos duros) |
| G9 | Gobierno: normal/urgente/excepción, riesgos, ciclo de vida, segregación | plano B de Phase 12 sin ciclo de vida | PARCIAL | Medio | validadores + registro de riesgos + integración documental con los agentes existentes | `test_p14_governance.sh` | Cerrada |
| G10 | Runbooks, políticas, checklist | no existían | AUSENTE | Alto | 6 documentos + política de logging y retención | `test_p14_docs_consistency.sh` | Cerrada |
| G11 | Empaquetado reproducible sin importaciones ocultas ni red | no verificado | AUSENTE | Medio | prueba en copia limpia, sin `site-packages`, con sockets bloqueados | `test_p14_packaging_reproducibility.sh` | Cerrada |
| G12 | Piloto real | adaptadores reales `DISABLED`/`CONTRACT_ONLY` | **FUERA DE ALCANCE** | — | declarado `NO` con causas y plan | `test_p14_integration_chain.sh` | **Abierta por diseño** |

## 3. Arquitectura de `release_readiness/` (stdlib)

| Módulo | Responsabilidad |
|---|---|
| `runner.py` | **único** módulo que arranca procesos: `git` de sólo lectura (lista permitida), el runner del repositorio y la sonda del gateway; sin shell, entorno depurado, plazo con fin de todo el árbol de procesos |
| `fingerprint.py` | identidad del árbol: SHA-256 por archivo (tracked + untracked no ignorados), agregado reproducible independiente de HEAD |
| `runlog.py` | parser independiente del log del runner (conteo de scripts **únicos**) y juicio fail-closed |
| `evidence.py` | `run_and_package` (fingerprint antes/después, `git diff --check`, redacción, veredicto) y `verify_package` (re-deriva todo) |
| `redact.py` | rutas personales → `<REPO_ROOT>`/`<USER_HOME>` + escaneo residual |
| `registry.py` | registro de capacidades, definiciones de madurez, registros de piloto y verificación contra el código |
| `governance.py` | ciclo de vida, segregación, urgencia, excepciones, registro de riesgos |
| `gate.py` | 10 comprobaciones ejecutables, derivación de las tres decisiones de preparación, informes JSON/Markdown sanitizados |
| `cli.py` | `snapshot`, `run`, `verify`, `gate`, `registry-check`, `governance-check` |

Comprobaciones del gate: `C01` estado Git · `C02` registro↔código · `C03` superficie MCP real por stdio · `C04` adaptadores reales no habilitados · `C05` escaneo AST (sin red, subprocess fuera de `runner.py`, eval/exec, importación dinámica, lectura de entorno, escrituras del gateway) · `C06` compatibilidad y licencias (17 casos de versión, 5 de comparación, 11 de capacidad) · `C07` documentación (secciones, enlaces, comandos documentados parseados con los CLIs reales, tests referenciados) · `C08` gobierno · `C09` `git diff --check` + equivalente para archivos sin trackear · `C10` paquete de evidencias verificado.

Veredicto (fail closed): `FAIL` si falla cualquier comprobación; `INCONCLUSIVE` si algo no pudo establecerse (p. ej. sin paquete de evidencias o identidad de árbol no verificada); `PASS` sólo con todo en `PASS` **y** árbol `VERIFIED`. Código de salida 0/1/2 respectivamente.

## 4. Cambios en el gateway MCP (Fase 13 → 14)

| Cambio | Motivo | Superficie de seguridad |
|---|---|---|
| `mcp_gateway/versions.py`: resolución numérica (`19.0.0.0.0`→`19c`, `latest`→desconocida; dígitos ASCII y anclaje `\Z`) | G3; una prueba encontró que `\d` aceptaba dígitos Unicode de ancho completo | más estricta |
| Metadatos de versión ausentes ⇒ cero versiones soportadas (antes: todas); colector OS debe declarar `oracle_version_scope` | G3, fail-open | más estricta |
| Colector de alert log restringido a 11g+ (ADR), según la matriz de capacidades | consistencia con Phase 2 | más estricta |
| Destinos aceptan versiones completas (normalizadas a familia) y rechazan `latest`/mayores no soportados | versión efectiva | neutra |
| `missing_privileges` en destinos ⇒ `INSUFFICIENT_PRIVILEGES` (estado que existía pero nunca se producía) | degradación segura | más estricta |
| Banderas `--operation-timeout`, `--max-session-calls`, `--max-rows`, `--max-message-bytes`: **sólo bajan** el límite; fuera de rango ⇒ no arranca | G8 | neutra (no amplían nada) |
| `build_parser()` extraído del CLI | validar comandos documentados | ninguna |

La prueba `check_security` de Phase 13 se ajustó en un caso (`19.3.0` ahora se resuelve a `19c`; el caso hostil pasó a ser `latest`).

## 5. Pruebas

Diez suites nuevas, todas con datos sintéticos, sobre el código real (subprocesos reales, repositorios Git temporales, copias limpias):

| Suite | Cubre |
|---|---|
| `tests/test_p14_inventory_registry.sh` | registro vs código, evidencia de madurez, registros de piloto, versiones numéricas y fail-closed |
| `tests/test_p14_evidence_packager.sh` | fingerprint, parser de log, paquete, redacción, timeout, árbol cambiado, omitidos, skips, secretos, allowlist de Git |
| `tests/test_p14_release_gate.sh` | verificador (hash, timestamps, exit code, log, fingerprint, veredicto forjado, otro árbol), veredicto/readiness del gate, comprobaciones sobre copias mutadas |
| `tests/test_p14_security_threat_model.sh` | stdio hostil, prompt injection, rutas/enlaces, entorno, agotamiento, descubrimiento de tools, escaneo estático, red bloqueada en runtime, fugas en informes |
| `tests/test_p14_operability.sh` | límites acotados, cancelación, orden secuencial, shutdown, caída y recuperación, degradación por estado, adaptadores defectuosos |
| `tests/test_p14_governance.sh` | ciclo de vida, segregación, aprobación estructural, urgencia, excepciones, riesgos, plano B de Phase 12 |
| `tests/test_p14_packaging_reproducibility.sh` | copia limpia sin `site-packages`, sin importaciones del checkout, sin dependencias opcionales, sin red ni archivos residuales |
| `tests/test_p14_integration_chain.sh` | Fase 13→11→12 con referencias e incertidumbre preservadas, cadena de sólo lectura, readiness |
| `tests/test_p14_mutation_controls.sh` | 18 defensas desactivadas una a una; cada prueba protectora debe fallar |
| `tests/test_p14_docs_consistency.sh` | documentos vs código: estados, conteos, banderas, rangos, subcomandos, riesgos, tests |

Los conteos y resultados de la regresión completa **no** se escriben en este documento: hacerlo cambiaría el árbol y anularía la evidencia que describe. Están en el paquete de evidencias (`manifest.md`) y en el informe de entrega.

## 6. Procedimiento del gate final

1. `python -m release_readiness run --out <EVIDENCE_DIR_OUTSIDE_REPO>` (regresión completa con fingerprint antes/después; no tocar el repositorio mientras corre).
2. `python -m release_readiness verify --package <EVIDENCE_DIR_OUTSIDE_REPO> --root .`
3. `python -m release_readiness gate --evidence <EVIDENCE_DIR_OUTSIDE_REPO> --format markdown`
4. Revisión humana; cualquier cambio posterior al paso 1 invalida la evidencia. Detalle: [`RELEASE_AND_ROLLBACK.md`](RELEASE_AND_ROLLBACK.md).

## 7. Decisiones de diseño y límites

- **Ejecutar en vez de declarar:** cada comprobación del gate ejecuta el gateway real, el catálogo, el AST o los validadores; los documentos se validan contra los parsers reales.
- **Integridad, no autenticidad:** hashes y fingerprints detectan alteración; no identifican a quien generó el paquete (RSK-006). La identidad del árbol se establece comparando fingerprint inicial y final, no en cada instante intermedio.
- **Aprobaciones estructurales:** ninguna herramienta crea una aprobación; el registro de ciclo de vida de esta fase queda en `PROPOSED`.
- **Sin cancelación en vuelo:** el servidor es secuencial (concurrencia 1) y los adaptadores tienen plazo duro; las notificaciones de cancelación son idempotentes y no rompen la sesión.
- **TOCTOU:** cada lectura de fixture se confina y verifica en el momento del acceso; la ventana entre verificación y apertura se mitiga no compartiendo el directorio (RSK-002).
- **Plataforma:** validado sólo en Windows con Git Bash y Python 3.13 (RSK-007).

## 8. Fuera de alcance por diseño

Habilitar `oracle_sql`, `oracle_diag_file` u `os_readonly`; solicitar o almacenar credenciales; acceso a Oracle real; red, telemetría o dependencias externas; commit, merge, push, tag, instalación productiva o despliegue. `READY_FOR_REAL_ENVIRONMENT_PILOT` permanece en `NO` con las causas y el plan de [`PILOT_ACCEPTANCE_CHECKLIST.md`](PILOT_ACCEPTANCE_CHECKLIST.md).

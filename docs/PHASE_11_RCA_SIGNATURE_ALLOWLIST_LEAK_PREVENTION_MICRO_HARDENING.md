# PHASE 11 — RCA SIGNATURE ALLOWLIST & OUTPUT LEAK PREVENTION MICRO-HARDENING

Micro-hardening acotado sobre `docs/PHASE_11_RCA_STRUCTURED_EVIDENCE_SANITIZATION_HARDENING.md`
(misma rama `phase/11-incident-rca`, baseline `v0.10.0-capacity-forecasting`), exclusivamente
sobre la ruta de fuga en `evidence.signature` y sus dependencias directas (timeline, dedup,
correlación de reglas, reporte). No reconstruye Phase 11 ni avanza a Phase 12.

## Defecto confirmado y reproducido

`normalize_signature()` (el sanitizador de firmas del hardening anterior) aceptaba **verbatim**
cualquier cadena que coincidiera con la forma genérica `^[A-Z][A-Z0-9_]{2,63}$` — mayúsculas,
dígitos y guiones bajos, 3-64 caracteres. Un marcador sintético como `SYNTHETIC_SECRET_DO_NOT_USE`
(27 caracteres, sólo mayúsculas y guiones bajos) coincide exactamente con esa forma.

Reproducido antes de tocar código:

```
>>> normalize_signature("SYNTHETIC_SECRET_DO_NOT_USE")
"SYNTHETIC_SECRET_DO_NOT_USE"   # LEAKED: True
```

Y de punta a punta vía CLI, sobre un fixture con esa firma: `cli_exit=0`, **2 apariciones crudas
en `result.json`, 1 en `report.md`**. Que una firma cumpla una expresión regular nunca demuestra
que su contenido sea seguro — exactamente el defecto que este micro-hardening corrige.

## Files created

- 6 fixtures nuevos bajo `tests/fixtures/rca_engine/` (`signature_pure_uppercase_marker.json`,
  `signature_various_unknown_shapes.json`, `signature_marker_nested_paths.json`,
  `signature_certified_regression.json`, `signature_token_correlation.json`,
  `signature_malformed_error_case.json`).
- 9 tests nuevos bajo `tests/test_rca_signature_*.sh` / `test_rca_unknown_signature_*.sh` /
  `test_rca_certified_signature_regression.sh` (lista exacta abajo).
- `docs/PHASE_11_RCA_SIGNATURE_ALLOWLIST_LEAK_PREVENTION_MICRO_HARDENING.md` (este documento).

## Files modified

- `rca_engine/sanitize.py` — `normalize_signature()` reemplazado por `classify_signature()`;
  elimina la constante `_SAFE_TEMPLATE_SIGNATURE` (aceptación genérica por forma).
- `rca_engine/tokenization.py` — agrega `derive_signature_token()`.
- `rca_engine/rules.py` — agrega `collect_certified_signatures()`; `_symptom_matches()` ahora
  exige `signature_status == CERTIFIED` antes de comparar `canonical_signature`.
- `rca_engine/common.py` — agrega `SignatureStatus`; `NormalizedEvidence`/`TimelineEvent`
  reemplazan el campo único `signature` por `signature_status`/`canonical_signature`/
  `signature_token` (cambio de schema deliberado y documentado, ver Compatibilidad abajo).
- `rca_engine/intake.py` — usa `classify_signature()`; registra el token de firma no reconocida
  en el mapa `--token-map` local (mismo aislamiento que `target_id`/`source_id`).
- `rca_engine/timeline.py` — `_dedup_key()`/agrupación usan `canonical_signature` (si
  `CERTIFIED`) o `signature_token` (si no) — nunca el texto crudo como clave.
- `rca_engine/report.py` — tabla de timeline en Markdown muestra las 3 columnas nuevas en vez del
  campo único anterior.
- `tests/test_rca_signature_safe_clustering.sh` — adaptado al nuevo schema (extendido, no
  sustituido — sigue verificando exactamente lo mismo que antes más las columnas nuevas).
- `docs/INCIDENT_READONLY_SECURITY_MODEL.md` — sección de `signature` reescrita.

## Root cause of leak

Un patrón de "forma segura" (`UPPER_SNAKE_CASE`, 3-64 caracteres) se usaba como sustituto de
certificación real. La forma no acota el **origen** ni el **contenido** — es texto libre elegido
por quien produce la evidencia, exactamente lo que el modelo de amenaza de este dominio (evidencia
no confiable hasta ser sanitizada) debe rechazar por defecto.

## Reproduced before fix: YES

Ver sección "Defecto confirmado y reproducido" arriba — ejecutado contra el código real antes de
cualquier cambio, con salida capturada.

## Signature policy

Certificación por **dos vías independientes y acotadas**, nunca por forma genérica sola
(`classify_signature()`, `rca_engine/sanitize.py`):

1. **Código numérico tipado** bajo un prefijo fijo y conocido:
   `^(ORA|TNS|RMAN|CRS|LSNR|PLS)-\d{3,6}$`. Seguro porque el espacio de valores es un código
   numérico acotado (3-6 dígitos) bajo un vocabulario de prefijos fijo — no texto libre elegido
   por la fuente. Una gramática de código público conocido certifica *un código tipado*, nunca
   texto libre.
2. **Membresía exacta** en el conjunto versionado de nombres de plantilla que el catálogo de
   reglas *cargado* realmente declara (`rules.collect_certified_signatures()`, derivado de
   `symptom_match.signature_any` en `rca_engine/rules/default_rules.json`, `rules_version`
   `"1.0.0"`). Coincidir con la forma `UPPER_SNAKE_CASE` nunca basta por sí solo — sólo la
   pertenencia literal a este catálogo, revisable y versionado.

Cualquier firma que no certifique por ninguna de las dos vías → `UNRECOGNIZED_SIGNATURE`.

## Certified signature categories

| Categoría | Gramática/origen | Ejemplo certificado |
|---|---|---|
| Oracle error code | `ORA-\d{3,6}` | `ORA-27300`, `ORA-12537`, `ORA-01652` |
| TNS error code | `TNS-\d{3,6}` | (ninguno usado hoy en el catálogo, gramática disponible) |
| RMAN error code | `RMAN-\d{3,6}` | (ninguno usado hoy) |
| Clusterware (CRS) event | `CRS-\d{3,6}` | `CRS-1607`, `CRS-1632` |
| Listener (LSNR) code | `LSNR-\d{3,6}` | (ninguno usado hoy) |
| PL/SQL (PLS) code | `PLS-\d{3,6}` | (ninguno usado hoy) |
| Plantilla estructural certificada | Membresía exacta en el catálogo | `HIGH_DB_FILE_SEQUENTIAL_READ` |

No se declara una allowlist universal de "todos los códigos Oracle conocidos" — sólo los
prefijos/categorías que este catálogo de reglas versionado realmente certifica y sobre los que
existen parsers/reglas certificados en este repositorio.

## Unknown signature handling

`UNRECOGNIZED_SIGNATURE` — `canonical_signature: null`, `signature_token`: token opaco no
reversible (`tokenization.derive_signature_token()`, HMAC-SHA256 truncado a 16 hex, prefijo
`SIG-`), namespaced por `incident_id`. Nunca contribuye a `symptom_match` de ninguna regla
(`rules._symptom_matches()` exige `signature_status == CERTIFIED` explícitamente). El valor crudo
nunca se persiste fuera del perímetro local de `intake.py`, salvo en el mapa `--token-map`
opcional, aislado, gated por flag explícito del CLI.

## Tokenization and correlation

Reutiliza el mecanismo HMAC ya existente (`tokenization.py`, mismo patrón que `target_id`/
`source_id`) — no se introdujo un nuevo almacén de credenciales ni una nueva clave. El pepper de
namespacing es una constante pública en el código fuente (documentado explícitamente como no
criptográfico en `docs/PHASE_11_RCA_STRUCTURED_EVIDENCE_SANITIZATION_HARDENING.md#known-limitations`
y heredado sin cambios aquí) — no existe en este repositorio una solución de tokenización
certificada con clave externa. Consistente con la instrucción del prompt ("si no existe una
solución de tokenización segura certificada, desactiva la correlación entre incidentes"): el
namespacing por `incident_id` ya implementado desactiva estructuralmente la correlación
cross-incident para firmas no reconocidas — dos incidentes distintos con la misma firma cruda
producen tokens distintos, por diseño. Dos eventos con la **misma** firma no reconocida **dentro
del mismo incidente** sí correlacionan (mismo token), verificado con
`test_rca_unknown_signature_token_correlation.sh`. Firmas legítimas certificadas conservan
exactamente la misma clasificación/agrupación/correlación semántica que antes, verificado con
`test_rca_certified_signature_regression.sh`.

## Compatibilidad (cambio de schema documentado)

`NormalizedEvidence`/`TimelineEvent`/la tabla de timeline en Markdown reemplazan el campo único
`signature` (que en el hardening anterior ya era un string post-procesado, nunca el crudo) por
tres campos: `signature_status`, `canonical_signature`, `signature_token`. Cambio deliberado,
necesario y documentado (§6 del prompt de este micro-hardening lo autoriza explícitamente cuando
es imprescindible) — el único consumidor externo del campo anterior era
`tests/test_rca_signature_safe_clustering.sh`, extendido (no reescrito desde cero) para cubrir el
nuevo schema. Ningún otro contrato de fases anteriores, parser ni runtime compartido fue tocado.

## Resultados de pruebas (nombres exactos)

```
test_rca_signature_marker_not_certified_no_leak.sh    — PASS (repro + regresión permanente)
test_rca_unknown_signature_shapes_no_leak.sh           — PASS (8 formas: mixed/Unicode/espacios/\n/comillas/\/muy larga)
test_rca_signature_no_alternate_leak_path.sh           — PASS (marcador anidado en attributes/summary simultáneo)
test_rca_certified_signature_regression.sh              — PASS (2 categorías certificadas, CONFIRMED preservado)
test_rca_unknown_signature_token_correlation.sh          — PASS (mismo token / sin colisión)
test_rca_signature_error_paths_no_leak.sh                 — PASS (error de validación no relacionado, sin eco)
test_rca_signature_all_surfaces_no_leak.sh                 — PASS (JSON/Markdown/manifest/stdout/stderr)
test_rca_signature_arbitrary_regex_not_certified.sh         — PASS (9 strings regex-válidos, ninguno CERTIFIED)
test_rca_signature_generic_regex_regression_guard.sh          — PASS (guard estático + funcional)
```

## Known limitations

- El pepper de tokenización sigue siendo una constante pública en el código fuente (heredado del
  hardening anterior, sin cambio) — namespacing/estabilidad, no confidencialidad criptográfica
  irreversible.
- El catálogo de firmas certificadas (6 prefijos numéricos + 1 plantilla) es un MVP acotado al
  catálogo de reglas actual (`rules_version 1.0.0`) — ampliarlo es un cambio gobernado vía
  `/change skill`, nunca una aceptación genérica ad hoc.
- No se certifica ningún código Oracle/Red/OS que no esté ya referenciado por una regla real del
  catálogo — una firma legítima pero aún no cubierta por ninguna regla se clasifica
  `UNRECOGNIZED_SIGNATURE` (comportamiento correcto y conservador, no un defecto).

## Referencias

`rca_engine/sanitize.py#classify_signature`, `rca_engine/tokenization.py#derive_signature_token`,
`rca_engine/rules.py#collect_certified_signatures`, `docs/INCIDENT_READONLY_SECURITY_MODEL.md`,
`docs/PHASE_11_RCA_STRUCTURED_EVIDENCE_SANITIZATION_HARDENING.md`.

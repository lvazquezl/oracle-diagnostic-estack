# PHASE 8 — FINAL DBA_USERS 12.1.0.2 SOURCE-OF-TRUTH CORRECTION

Baseline: `v0.7.0-backup-recovery-rman`. Branch: `phase/8-security-compliance`.

## Official source of truth

`docs.oracle.com/database/121/REFRN/GUID-309FCCB2-2E8D-4371-9FC5-7F3B10E2A8C0.htm` (Oracle
Database 12.1 Reference, `DBA_USERS`). Verificado directamente contra el **HTML crudo** de la
página (`curl`, sin ningún resumen de modelo intermedio — la vía usada en las dos verificaciones
anteriores, que sí pasaban por un modelo resumidor y no detectaron esta nota):

```html
<a onclick='footdisplay(1,"This column is available starting with Oracle Database 12c
Release 1 (12.1.0.2).")'><sup>Foot&nbsp;1</sup></a>
```

Esta nota al pie ("Footnote 1") está adjunta explícitamente a **cuatro** columnas de `DBA_USERS`
en la tabla de referencia oficial: `PROXY_ONLY_CONNECT`, `COMMON`, `LAST_LOGIN`,
`ORACLE_MAINTAINED` — verificado por línea exacta en el HTML crudo:

```text
línea 370: PROXY_ONLY_CONNECT ... Footref 1
línea 383: COMMON ... Footref 1
línea 403: LAST_LOGIN ... Footref 1
línea 415: ORACLE_MAINTAINED ... Footref 1
```

## Prior incorrect assumption

El hardening `PHASE 8 — DBA_USERS 12.1.0.2 BOUNDARY CERTIFICATION MICRO-HARDENING`
(`docs/PHASE_8_DBA_USERS_12102_BOUNDARY_CERTIFICATION_HARDENING.md`) certificó `COMMON`/
`ORACLE_MAINTAINED` en `12.1.0.1` basándose en:

1. El *Oracle Database Security Guide*, "Changes in This Release", que atribuye a 12.1.0.1 el
   soporte de *"Common Users and Local Users"* como concepto arquitectónico del Multitenant
   Option.
2. Un blog datado 2013-07-17 (~3 semanas post-GA de 12.1.0.1, un año antes de que existiera
   12.1.0.2) discutiendo `ORACLE_MAINTAINED`.
3. Dos intentos de fetch de la página oficial de referencia de `DBA_USERS` pidiendo el texto
   "verbatim" de la descripción de cada columna — ninguno de los dos surface la nota al pie,
   porque el marcador de nota (`<sup>Foot 1</sup>`) no forma parte del texto de descripción de la
   columna en sí; es un elemento HTML separado (ancla + superíndice) que el resumen de un modelo
   intermedio omitió en ambas ocasiones.

Esta evidencia era genuina y verificable, pero **incompleta**: confundía la disponibilidad de la
**feature arquitectónica** (Multitenant, common/local users como concepto — sí GA en 12.1.0.1)
con la disponibilidad de la **columna de diccionario específica** que expone esa información vía
SQL (`DBA_USERS.COMMON` — 12.1.0.2, según la nota al pie oficial). Son dos cosas relacionadas pero
distintas, y sólo la nota al pie oficial resuelve cuál aplica a la columna.

## COMMON correction

`compatibility/oracle-dictionary/views.yaml` → `DBA_USERS.common.min_version`: `"12.1"` (leído
como 12.1.0.1) → **`"12.1.0.2"`**.

## ORACLE_MAINTAINED correction

`compatibility/oracle-dictionary/views.yaml` → `DBA_USERS.oracle_maintained.min_version`: `"12.1"`
(leído como 12.1.0.1) → **`"12.1.0.2"`**.

## LAST_LOGIN confirmation

Sin cambio — ya certificada correctamente en `"12.1.0.2"` desde
`PHASE 8 — SECURITY QUERY COMPATIBILITY, ORACLE NET EVIDENCE & STATIC VALIDATOR HARDENING`. El
mismo footnote oficial confirma este boundary, ahora con evidencia primaria directa en vez de
fuentes secundarias (My Oracle Support + blogs, usadas en aquel hardening).

## Query variant corrections

### Q-SEC-DEFAULT-ACCOUNTS-001

- `V1` (`legacy_pre12102`): `min: "11.0"` → `max: "11.2"` cambiado a `max: "12.1.0.1"` — cubre
  ahora 11g **y** 12.1.0.1 (antes sólo cubría 11g, dejando un gap real: 12.1-12.1.0.1 no tenía
  ninguna variante que lo certificara). Nunca selecciona `ORACLE_MAINTAINED`.
- `V2` (`modern_12102plus`): `min: "12.1"` → `min: "12.1.0.2"`. Selecciona `ORACLE_MAINTAINED`.

### Q-SEC-ACCOUNT-INVENTORY-001

- `V1` (`legacy_pre12c`, 10.2-11.2): sin cambios.
- `V2` (`multitenant_pre12102`, 12.1-12.1.0.1): columnas seleccionadas reducidas de
  `authentication_type, common, oracle_maintained` a **sólo `authentication_type`** —
  `COMMON`/`ORACLE_MAINTAINED` ya no se seleccionan en esta variante (ambas requieren 12.1.0.2).
  `AUTHENTICATION_TYPE` se mantiene porque está certificada de forma independiente (11.2+, sin
  relación con el footnote de las otras tres columnas — `# 12` del prompt de esta corrección:
  "No asumir que AUTHENTICATION_TYPE comparte automáticamente el mismo boundary").
- `V3` (`modern_12102plus`, 12.1.0.2-23.0): sin cambios estructurales — ya seleccionaba las tres
  columnas correctamente desde el hardening anterior (el error estaba únicamente en `V2`).

## AUTHENTICATION_TYPE boundary status

Certificada independientemente en `11.2` — no comparte el footnote de `COMMON`/
`ORACLE_MAINTAINED`/`LAST_LOGIN`/`PROXY_ONLY_CONNECT`. Verificado que la página oficial de
`DBA_USERS` no adjunta la nota al pie 1 a `AUTHENTICATION_TYPE`. Permanece disponible en
`Q-SEC-ACCOUNT-INVENTORY-001-V2` (12.1-12.1.0.1), a diferencia de las tres columnas patch-level
2-gated.

## Incorrect tests removed/renamed

`tests/test_dba_users_common_12101_valid.sh` y `tests/test_dba_users_oracle_maintained_12101_valid.sh`
— **eliminados** (no renombrados con contenido preservado, porque su aserción era factualmente
incorrecta, no sólo mal nombrada). Reemplazados por:

## 12.1.0.1 negative tests

`tests/test_dba_users_common_12101_invalid.sh` (nuevo), `tests/test_dba_users_oracle_maintained_12101_invalid.sh`
(nuevo), `tests/test_dba_users_last_login_12101_invalid.sh` (ya existente, sin cambios) — los tres
verifican `NOT_CERTIFIED` en 12.1.0.1 vía `scripts/lib/version.sh`.

## 12.1.0.2 positive tests

`tests/test_dba_users_common_12102_valid.sh`, `tests/test_dba_users_oracle_maintained_12102_valid.sh`
(ambos creados en el micro-hardening previo, contenido ya correcto — sin cambios necesarios),
`tests/test_dba_users_last_login_12102_valid.sh` (ya existente, sin cambios).

## Query-specific tests

`tests/test_security_default_accounts.sh` y `tests/test_security_account_inventory.sh`
actualizados para verificar los nuevos boundaries (12.1.0.1 → legacy variant sin las columnas
gated; 12.1.0.2 → modern variant con ellas; ninguna columna no soportada en la variante legacy;
outputs normalizados sin cambios estructurales).

## Static Validator / Shared Version Resolver

Sin cambios de implementación. Confirmado end-to-end (delegado al validador real, no
reimplementado):

```text
DBA_USERS.COMMON @ 12.1.0.1              → NOT_CERTIFIED (rejected)
DBA_USERS.COMMON @ 12.1.0.2              → CERTIFIED (accepted)
DBA_USERS.ORACLE_MAINTAINED @ 12.1.0.1   → NOT_CERTIFIED (rejected)
DBA_USERS.ORACLE_MAINTAINED @ 12.1.0.2   → CERTIFIED (accepted)
DBA_USERS.LAST_LOGIN @ 12.1.0.1          → NOT_CERTIFIED (rejected, sin cambio)
DBA_USERS.LAST_LOGIN @ 12.1.0.2          → CERTIFIED (accepted, sin cambio)
```

`scripts/lib/version.sh` sin modificar — sigue siendo el único comparador de versión, usado
exclusivamente por todos los tests de boundary nuevos y actualizados.

## Documentation corrected

- `compatibility/oracle-dictionary/views.yaml` — comentarios inline actualizados con la cita
  verbatim del footnote oficial y explicación de la corrección.
- `queries/security/Q-SEC-DEFAULT-ACCOUNTS-001.md`, `queries/security/Q-SEC-ACCOUNT-INVENTORY-001.md`
  — variantes y prosa actualizadas.
- `config/query-compatibility-matrix.yaml` — entradas de ambas queries actualizadas.
- `docs/PHASE_8_DBA_USERS_12102_BOUNDARY_CERTIFICATION_HARDENING.md` — nota "(superado)" agregada
  al inicio, apuntando a este documento; el contenido histórico se conserva sin reescribirse
  (registro de lo que se investigó y concluyó entonces, con su causa raíz ya identificada arriba).
- `docs/PHASE_8_SECURITY_QUERY_ORACLE_NET_STATIC_VALIDATOR_HARDENING.md`,
  `docs/PHASE_8_ORACLE_SECURITY_COMPLIANCE.md`, `docs/ORACLE_SECURITY_READONLY_QUERY_MODEL.md`,
  `queries/REGISTRY.md`, `CHANGELOG.md` — referencias a los boundaries corregidas donde
  afirmaban `COMMON`/`ORACLE_MAINTAINED` disponibles desde `12.1.0.1`.

No se conservó ninguna conclusión que tratara la fuente secundaria (blog, inferencia cronológica)
como equivalente o superior a la documentación oficial — la nota "prior assumption rejected" en
`docs/PHASE_8_DBA_USERS_12102_BOUNDARY_CERTIFICATION_HARDENING.md` es histórica, no vigente.

## TEST_SCOPE

`TARGETED` — no se modificó Static Validator, Shared Version Resolver, Query Variant Resolver,
dictionary parser, query parser ni test harness. Cambios de contenido: `views.yaml` (2 valores de
`min_version`), 2 archivos de query (rangos de variantes + prosa), `config/query-compatibility-matrix.yaml`,
2 tests eliminados + 2 tests nuevos + 4 tests actualizados, documentación.

## Targeted regression rationale

Mismo razonamiento que el micro-hardening anterior: ningún cambio toca infraestructura
compartida (Static Validator, Shared Version Resolver, Query Variant Resolver, parsers). El
riesgo de regresión está acotado a: (a) las dos queries de Security modificadas, (b) los tests
que dependen directamente de los valores de `min_version` de `DBA_USERS.common`/
`.oracle_maintained` — ambos verificados exhaustivamente vía regresión dirigida.

## Known limitations

- El boundary de las cuatro columnas (`COMMON`, `ORACLE_MAINTAINED`, `LAST_LOGIN`,
  `PROXY_ONLY_CONNECT`) queda anclado a una única nota al pie oficial compartida — si Oracle
  publicara una corrección posterior a esa documentación, este e-stack debería re-verificarse.
  `PROXY_ONLY_CONNECT` no está registrada en el dictionary (no usada por ninguna query del
  catálogo) — fuera de alcance de esta corrección, documentado por completitud.

# Lote D: cobertura por dominio con `COMPLETE_WITHIN_POLICY`

`/change compatibility|documentation|skill|workflow` — `CHG-ESTACK-D-COMPLETE-WITHIN-POLICY-001`. Rama `change/d-complete-within-policy` sobre `main` (`09ab88d`).

Origen: el plan de lotes acordado con el DBA (D: estado `COMPLETE_WITHIN_POLICY` en el modelo de cobertura). En `ANA-20261020-001`:
- la tabla de cobertura por dominio se armó a mano, sin un modelo en el repo;
- `PARTIAL` mezclaba lo que falta y se puede obtener con lo que la política excluye para siempre (texto SQL, bind values, valores de texto de parámetros);
- F y B no iban a poder salir nunca de `PARTIAL`.

## Qué cambia

- **`config/assessment-coverage-model.json`:** el modelo, con 28 dominios y 127 ítems.
  - Cada ítem nombra los collectors certificados que lo cubren, la topología a la que aplica y, si corresponde, la exclusión por política con su categoría.
  - Si no hay collector, el ítem dice por qué (`gap`).
- **`scripts/assessment_coverage/evaluate.py`:** el evaluador, determinista y solo con stdlib. Calcula el estado de cada dominio desde:
  - el estado de cada collector en el gateway;
  - la topología observada;
  - el `license_status` del target.
- **`change_documentation_knowledge/documents.py`:** el documento de assessment acepta `domain_coverage` y rechaza la cobertura no ganada:
  - `COMPLETE_WITHIN_POLICY` sin exclusión;
  - `PARTIAL` sin lo que falta;
  - una revisión que sube un estado;
  - `INSUFFICIENT_EVIDENCE` sin revisión.
- **`workflows/assessment.md` 1.2.0:**
  - La tabla de cobertura por dominio es un paso fijo.
  - Un dominio sin acceso queda `PARTIAL` o `NOT_ASSESSED` con lo que falta, en lugar de `UNDETERMINED`, que no estaba definido.
- **`documentation/assessment-report` 1.1.0:** documenta la entrada y las reglas.
- **Referencias:** `docs/CONTRACTS.md` (referencia) y `docs/ASSESSMENT_COVERAGE_MODEL.md` (el modelo completo).

Sin SQL nuevo, sin collectors nuevos, sin cambios al gateway ni al guard de solo lectura. No requiere nada en la base ni en el SO.

## Decisiones de diseño

- **Una exclusión solo cita una política existente.** Hay cuatro categorías:
  - `DATA_CLASSIFICATION`;
  - `FORBIDDEN_OPERATION`;
  - `LICENSE_NOT_ENTITLED`;
  - `LICENSE_ENTITLEMENT_NOT_ASSERTED`.

  El cargador rechaza una categoría desconocida o una política inexistente. P20 compara los 8 ítems excluidos con el texto de las políticas.
- **Lo obtenible nunca se excluye.** Siguen `MISSING`:
  - los adaptadores del lote E (alert log, listener, SO);
  - lo que no se ve de una PDB desde el root (UNDO, credenciales por defecto, proxy, políticas de auditoría);
  - las vistas sin collector certificado.

  Así `PARTIAL` vuelve a significar "hay trabajo pendiente".
- **Licencia.** Un pack sin confirmar queda `MISSING` con `LICENSE_CHECK_REQUIRED`. Solo un `NOT_LICENSED` declarado por el humano lo convierte en exclusión (`LICENSE_NOT_ENTITLED`). El gateway no cambia: todo lo que no sea `CONFIRMED` sigue `LICENSE_RESTRICTED`. **Decisión para la revisión humana:** el valor `NOT_LICENSED` es una convención nueva del `license_status` del target, solo leída por el evaluador.
- **`INSUFFICIENT_EVIDENCE` es de la revisión.** El evaluador no juzga la calidad del dato (por ejemplo, un solo intervalo AWR). Los especialistas pueden bajar un estado con motivo, nunca subirlo.
- **Topología desconocida no es "no aplica".** Un flag sin observar deja el ítem `MISSING`.
- **Las sondas `Q-DICT-VERIFY-*` no cuentan como evidencia de un dominio.** El resto del catálogo, los 107 collectors restantes, tiene dominio, y P20 lo exige.

## Pruebas

- **P20** (`tests/test_assessment_coverage.sh`), 13 casos:
  - modelo, cargador y reglas del evaluador;
  - CLI;
  - documento de assessment.
- **P12** (`tests/test_p12_documentation_factory.sh`): sin cambios, 16/16.
- **Seguridad:** 15/15 mutaciones detectadas (13 iniciales y 2 agregadas tras el lab).
  - Huecos disfrazados de exclusión:
    - UNDO de la PDB como política;
    - una exclusión junto a collectors;
    - una categoría sin política.
  - Cobertura inflada:
    - un faltante contado como dentro de política;
    - un collector fallido contado como obtenido;
    - una licencia sin confirmar tratada como exclusión;
    - una topología desconocida tratada como no aplicable.
  - Documento permisivo:
    - una revisión que sube un estado;
    - `COMPLETE_WITHIN_POLICY` sin exclusión;
    - `PARTIAL` sin lo que falta;
    - `INSUFFICIENT_EVIDENCE` sin revisión.
  - Integridad del modelo y del evaluador:
    - un collector que desaparece del modelo;
    - el evaluador asignando `INSUFFICIENT_EVIDENCE`.
  - Agregadas tras el lab:
    - evidencia `DEGRADED` sin marcar;
    - una baja a `PARTIAL` sin decir qué falta.
- **Regresión:** 976/976 en macOS (bash 5.3).

## Validación en el lab

`lab-ol8-19c`, contexto `LAB-OL8-19C-CDBROOT-ASM` (19.32, `CDB$ROOT`, ASM), 2026-11-17, con la cuenta de diagnóstico. El recorrido ejecutó una vez cada uno de los 114 collectors del catálogo con el gateway del lab, por el mismo camino de código que el servidor MCP y en solo lectura, y registró solo el estado de cada uno:
- **Observados:** 108, todos `FIELD_VALIDATED`.
- **`DEGRADED`:** 1, `Q-ORA-OBJECTS-INVENTORY-001`, truncado a 100 filas.
- **`UNSUPPORTED`:** 5, los esperados:
  - `Q-DG-STATS-001` (solo standby);
  - el alert log y los dos collectors del SO (adaptadores del lote E);
  - `Q-ORA-PROCESSES-SUMMARY-001` (no implementado en el adaptador del lab).

Topología observada: CDB, ASM, sin RAC ni Data Guard, primario. `license_status`: Diagnostics y Tuning Pack `CONFIRMED`. Modelo `074afc79ee9f…`.

**El lab encontró dos defectos, corregidos en este cambio:**
1. **`DEGRADED` no existía como estado.** El gateway devuelve `DEGRADED` cuando hay evidencia con limitaciones, y el primer recorrido lo contó como falla. Ahora es un estado de collector: cuenta como obtenido, el ítem lo lista en `degraded` y la tabla lo marca "con limitaciones".
2. **Una baja de `COMPLETE` a `PARTIAL` era imposible.** El documento validaba el contenido solo contra el estado calculado y rechazaba los faltantes de un dominio calculado `COMPLETE`. Ahora valida el estado final y el calculado. P20 agrega los dos casos y una mutación para cada uno.

**Cobertura calculada frente a `ANA-20261020-001`:**

| | `ANA-20261020-001` (a mano) | Evaluador | Tras la revisión |
|---|---|---|---|
| `COMPLETE` | 1 | 10 | 9 |
| `COMPLETE_WITHIN_POLICY` | — | 4 (B, N, Q, Z) | 4 |
| `PARTIAL` | 21 | 11 | 9 |
| `INSUFFICIENT_EVIDENCE` | 1 | 0 | 3 (D, E, F) |
| `NOT_ASSESSED` | 3 | 1 (OS) | 1 |
| `NOT_APPLICABLE` | 2 | 2 (S, U) | 2 |

La mejora frente a `ANA-20261020-001` viene de los lotes B7, B8 y C. Este lote agrega el criterio con que se cuentan.

Los 9 `PARTIAL` dicen qué falta, y todo se puede obtener:
- **Sin collector certificado:** C6 result cache, I4 BIGFILE, T3 rebalance, NET4 ACL.
- **No visible desde el root:** K3, O11 y P3 (PDB desde el root).
- **Adaptadores del lote E:** H3 alert log y NET3 listener. D4 CPU del host también depende del lote E, pero D quedó `INSUFFICIENT_EVIDENCE` tras la revisión.
- **W2:** inventario truncado (tras la revisión).

Con la revisión aplicada, el documento de assessment (`DOC-20261117-001`, digest `677be63b…`) acepta las 28 filas y marca `DOMAIN_STATUS_LOWERED_BY_REVIEW`.

**Revisión de los especialistas:**
1. **`oracle-performance-analyst`:** baja D, E y F a `INSUFFICIENT_EVIDENCE`.
   - Los tres collectors AWR de 24 h devolvieron 0 filas porque la VM estuvo detenida y no hay snapshots en el último día. El ASH tiene 24 filas, de la última hora.
   - El evaluador los cuenta como obtenidos, y es correcto: cero filas es un dato válido, como "ninguna sesión bloqueada". Pero no alcanza para juzgar la carga histórica.
   - Es el caso para el que existe la baja por revisión. Deja la recomendación operativa de siempre: antes de un assessment, el lab debe llevar al menos 24 a 48 h arriba.
2. **`oracle-dba-analyst`:** baja W de `COMPLETE` a `PARTIAL`.
   - El inventario de objetos llegó truncado a 100 filas: 2 contenedores × dueños × tipos × estados.
   - Se puede obtener ampliando el límite o agregando más en la base; queda como mejora para un lote de queries.
   - Confirma que K3 (UNDO de la PDB) y la cobertura de G con `Q-ORA-RESOURCE-LIMITS-001` coinciden con lo observado en el lote C.
3. **`oracle-security-analyst`:**
   - Las exclusiones de O12, P4, Q6 y Z3 corresponden a lo que las políticas declaran.
   - O11 y P3 siguen como faltantes y no se esconden como política.
   - Z queda `COMPLETE_WITHIN_POLICY`: el uso de features se obtuvo, y el derecho de licencia nunca lo afirma el e-stack.
4. **`technical-documentation-manager`:**
   - Las 28 filas cuadran con el modelo.
   - Cada `PARTIAL` dice qué falta y cada `COMPLETE_WITHIN_POLICY` nombra su exclusión.
   - Las 4 bajas llevan motivo.

## Registro del cambio

| Fase | Resultado |
|---|---|
| DETECT GAP | `ANA-20261020-001`: cobertura por dominio armada a mano; `PARTIAL` no distinguía lo obtenible de lo excluido por política |
| CHANGE REQUEST | `CHG-ESTACK-D-COMPLETE-WITHIN-POLICY-001`, tipos `compatibility`, `documentation`, `skill` y `workflow` |
| GAP ANALYSIS | No existía un modelo de cobertura en el repo; el documento de assessment solo conocía `SUPPORTED/UNSUPPORTED/UNKNOWN` por área |
| IMPACT ANALYSIS | Sin SQL, collectors, privilegios, licencias ni tools nuevos; gateway y guard sin cambios; el documento de assessment agrega una sección opcional y compatible (`NOT_PROVIDED_BY_SOURCE` si no se entrega) |
| PROPOSAL | Este documento y `docs/ASSESSMENT_COVERAGE_MODEL.md` |
| IMPLEMENT | Modelo (28 dominios, 127 ítems), evaluador, sección `domain_coverage`, workflow 1.2.0, skill 1.1.0, contratos |
| TEST | P20 13/13 (incluye los casos agregados tras el lab); P12 16/16 |
| SECURITY | 15/15 mutaciones detectadas |
| REGRESSION | 976/976 en macOS (bash 5.3), también después de las correcciones del lab; 15/15 mutaciones sobre el árbol final |
| LAB | Recorrido de los 114 collectors (108 observados, 1 `DEGRADED`, 5 `UNSUPPORTED` esperados); el lab encontró dos defectos (estado `DEGRADED` y baja a `PARTIAL`), corregidos; cobertura del lab calculada y revisada por 4 especialistas (4 bajas con motivo) |
| HUMAN REVIEW | Aprobado: `AUTH-D-COMPLETE-WITHIN-POLICY-001`, revisor `REV-DBAMANAGER`, `2026-11-17T17:33:43Z`, contra el digest `44d86c2c…34b7e0ba5ff` (`STRUCTURAL_ONLY_IDENTITY_NOT_VERIFIED`), incluida la convención `NOT_LICENSED`. PROMOTE: pendiente (push, PR y merge, acciones humanas) |

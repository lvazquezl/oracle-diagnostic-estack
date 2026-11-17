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
- **Seguridad:** 13/13 mutaciones detectadas.
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
- **Regresión:** 976/976 en macOS (bash 5.3).

## Registro del cambio

| Fase | Resultado |
|---|---|
| DETECT GAP | `ANA-20261020-001`: cobertura por dominio armada a mano; `PARTIAL` no distinguía lo obtenible de lo excluido por política |
| CHANGE REQUEST | `CHG-ESTACK-D-COMPLETE-WITHIN-POLICY-001`, tipos `compatibility`, `documentation`, `skill` y `workflow` |
| GAP ANALYSIS | No existía un modelo de cobertura en el repo; el documento de assessment solo conocía `SUPPORTED/UNSUPPORTED/UNKNOWN` por área |
| IMPACT ANALYSIS | Sin SQL, collectors, privilegios, licencias ni tools nuevos; gateway y guard sin cambios; el documento de assessment agrega una sección opcional y compatible (`NOT_PROVIDED_BY_SOURCE` si no se entrega) |
| PROPOSAL | Este documento y `docs/ASSESSMENT_COVERAGE_MODEL.md` |
| IMPLEMENT | Modelo (28 dominios, 127 ítems), evaluador, sección `domain_coverage`, workflow 1.2.0, skill 1.1.0, contratos |
| TEST | P20 13/13; P12 16/16 |
| SECURITY | 13/13 mutaciones detectadas |
| REGRESSION | 976/976 en macOS (bash 5.3) |
| LAB | pendiente: cobertura real del lab con el evaluador |
| HUMAN REVIEW | pendiente |

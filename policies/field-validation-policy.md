# Field Validation Policy

`CHG-ESTACK-VALIDATION-MATRIX-001`. Registro: [`config/field-validation-registry.json`](../config/field-validation-registry.json). Evaluador: `mcp_gateway/field_validation.py`.

## Principio

Una query certificada **no está validada en campo** hasta que su SQL exacto (`query_sha256`) corrió contra un Oracle real en un contexto registrado, con evidencia (`EVR-*`) en un registro de cambio aprobado. Certificación por documentación, fixtures sintéticos o `DOCUMENTATION_VALIDATED` en el diccionario **no** son validación en campo: `CHG-ESTACK-ORA19C-LAB-006` encontró columnas marcadas `DOCUMENTATION_VALIDATED` que no existían.

## Niveles

| Nivel | Significado |
|---|---|
| `FIELD_VALIDATED` | El mismo SQL corrió en un contexto que coincide con el target en todas las dimensiones comparables |
| `FIELD_VALIDATED_OTHER_CONTEXT` | El mismo SQL corrió en real, pero alguna dimensión difiere. Las diferencias se listan, nunca se ocultan |
| `DOCUMENTATION_ONLY` | Nunca corrió en real para ese SQL, o el SQL cambió desde que corrió (`SQL_CHANGED_SINCE_FIELD_VALIDATION`) |
| `HUMAN_REPORTED` | El DBA ejecutó a mano el SQL certificado (`python -m human_evidence`, `CHG-ESTACK-HUMAN-EVIDENCE-001`) y entregó el CSV, que se saneó localmente. Es una observación real, pero **el e-stack no la observó**: no se pudo verificar el target, el usuario ni que el SQL fuera exactamente el entregado. Nivel propio de la evidencia `EVD-HR-*`, independiente de la validación en campo de la query |

Orden de "más débil" para combinar evidencias: `FIELD_VALIDATED` > `FIELD_VALIDATED_OTHER_CONTEXT` > `HUMAN_REPORTED` > `DOCUMENTATION_ONLY`.

## Dimensiones del contexto

| Dimensión | Regla |
|---|---|
| Versión | Familia (`19c`) debe coincidir |
| Release Update | Se registra el RU validado (`19.32`). Un target con RU **menor** al validado difiere (un RU puede agregar vistas/columnas, casi nunca quita). El RU del target es el **observado** por `Q-DISC-IDENTITY-001` en la sesión (18c+; la versión `YY.RU.x.x.x` lo incluye), o el declarado si aún no se observó; desconocido → `not_compared`. Si el observado difiere del declarado: `DECLARED_RELEASE_UPDATE_MISMATCH` (`CHG-ESTACK-VALIDATION-RU-001`) |
| Contenedor | `CDB_ROOT` / `PDB` / `NON_CDB` |
| Rol | `PRIMARY` / `STANDBY` |
| RAC, ASM, Data Guard | Booleanos de `architecture` |
| Sistema operativo | Familia y distribución (`LINUX`/`OL`); la versión se registra |

Una dimensión no declarada en el target se reporta en `not_compared` y **nunca** convierte una diferencia en coincidencia.

**Observado sobre declarado** (`CHG-ESTACK-DISC-ARCHITECTURE-001`, `CHG-ESTACK-VALIDATION-RU-001`): con datos REAL, RAC/ASM/Data Guard/rol/familia de SO observados por `Q-DISC-ARCHITECTURE-001` y el RU observado por `Q-DISC-IDENTITY-001` reemplazan a lo declarado para la validación en campo en esa sesión. Toda diferencia con lo declarado se reporta; los fixtures nunca reemplazan una declaración.

## Reglas para agentes y resultados

1. Todo hallazgo del Result Package declara `validation_level` de la evidencia en que se apoya: el **más débil** de sus evidencias.
2. Un hallazgo con `validation_level` distinto de `FIELD_VALIDATED` debe decir explícitamente **"no validado en campo"**, e indicar las dimensiones que difieren (p. ej. "validado en 19c single-instance; el target es RAC").
3. **Tope de confianza:** con evidencia que no es `FIELD_VALIDATED`, `confidence` no puede superar `PROBABLE_CAUSE`. Nunca `CONFIRMED_ROOT_CAUSE`. `diagnostics.analyze_incident` lo expone como `field_validation.confidence_ceiling`, y el orquestador lo aplica.
4. Un recurso sin validación en campo sigue siendo utilizable: orienta el análisis, y el DBA confirma.
5. **Evidencia reportada por humano** (`EVD-HR-*`): el hallazgo la cita como "reportada por `<reporter_id>` (ejecución manual de `<query_id>`)", con techo `PROBABLE_CAUSE`. Sus columnas `DROP` y los valores descartados (`SENSITIVE_VALUES_DROPPED`, `COLUMNS_DROPPED`) son limitaciones que el hallazgo declara. Ver [docs/HUMAN_EVIDENCE.md](../docs/HUMAN_EVIDENCE.md).

## Cómo se agrega una validación

Sólo por `/change`, después de una ejecución humana en el lab (o en un piloto aprobado) registrada en un documento de cambio con sus `EVR-*`:
- el contexto completo, incluidos RU y SO observados;
- el `query_sha256` del SQL que corrió;
- el `change_id`.

`tests/test_field_validation_registry.sh` verifica que cada entrada apunte a una query existente con su hash vigente y que sus `EVR-*` consten en el registro citado. Si una query cambia, ese test falla hasta que se revalide o se retire la entrada; mientras tanto, el gateway ya la trata como `DOCUMENTATION_ONLY`.

Resultados que no son representativos (p. ej. 0 filas por ejecutarse en un contenedor donde la vista no aplica, o columnas nulas por un defecto del SQL) **no** se registran como validación.

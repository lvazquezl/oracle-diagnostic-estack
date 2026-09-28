# CHG-ESTACK-VALIDATION-MATRIX-001 — Validación en campo por query y contexto

**Tipo:** `/change compatibility|documentation|security` (plano B, `ESTACK_DEVELOPMENT`) · **Rama:** `change/validation-matrix` (desde `main` `3e8f8e0`, `v0.20.0-dictionary-19c-fixes`)
**Origen:** `CHG-REQ-VALIDATION-MATRIX`
**Estado:** aprobado por revisión humana (§11). Pendiente: `PROMOTE` (acción humana). `PROMOTE`, commit, merge, tag y push son acciones humanas.

READ-ONLY ALWAYS · HUMAN-EXECUTED REMEDIATION ONLY. No se agregan queries, collectors ni accesos.

## 1. DETECT GAP

Nada en la salida del stack distinguía una query probada contra Oracle real de una certificada sólo por documentación:
- `provenance` (`REAL`/`FIXTURE`) dice de dónde vienen los **datos**, no si la **query** se validó en un ambiente como el consultado.
- El diccionario usa `DOCUMENTATION_VALIDATED`. `CHG-ESTACK-ORA19C-LAB-006` mostró que esa marca no basta: 4 columnas así marcadas no existían.
- El registro de readiness mide madurez por componente, no por query × versión × arquitectura.

Un hallazgo sobre RAC, Data Guard u otra versión podía presentarse con la misma confianza que uno probado en el lab.

## 2. CHANGE REQUEST — alcance

| Artefacto | Cambio |
|---|---|
| `config/field-validation-registry.json` (nuevo) | Contextos validados y, por query, el `query_sha256` exacto que corrió en real, con `EVR`/`REQ`, fecha, registro de cambio y `change_id` |
| `mcp_gateway/field_validation.py` (nuevo) | Evaluador de 3 niveles para un target; falla cerrado a `DOCUMENTATION_ONLY` |
| `mcp_gateway/gateway.py` | `field_validation` en `collect`, `get_evidence`, `describe_collector`; techo `PROBABLE_CAUSE` y limitaciones en `analyze_incident` |
| `mcp_gateway/catalog.py` | Target: campos opcionales `os` (`family`/`distribution`/`version`) y `release_update` |
| `policies/field-validation-policy.md` (nuevo) | Niveles, dimensiones, reglas para agentes (tope de confianza) y cómo se agrega una validación |
| `docs/CONTRACTS.md`, `agents/oracle-operations-orchestrator.md`, `CLAUDE.md` | `validation_level` en el Result Package; "no validado en campo"; `confidence ≤ PROBABLE_CAUSE` |
| `docs/PHASE_13_MCP_DIAGNOSTIC_GATEWAY.md` | Campo nuevo del sobre |
| `tests/p16/check_field_validation.py`, `tests/test_field_validation.sh` (nuevos) | 9 casos |

## 3. GAP ANALYSIS — decisiones

1. **Decisiones del DBA (2026-09-28):**
   - (a) el tope de `confidence` en `PROBABLE_CAUSE` con evidencia no validada en campo;
   - (b) las dimensiones: versión (familia, con RU registrado), contenedor, rol, RAC, ASM, Data Guard y **sistema operativo**.
2. **Release Update:**
   - la familia debe coincidir;
   - un target con RU **menor** al validado difiere, porque un RU puede agregar vistas o columnas;
   - un RU mayor no difiere;
   - un RU no declarado se reporta como `not_compared`.

   Hoy el target sólo declara la familia: usar el RU **observado** por la query de identidad en tiempo de ejecución queda para `CHG-REQ-VALIDATION-RU`.
3. **Sistema operativo:** se compara familia y distribución; la versión se registra.
4. **Validación atada al SQL:** si la query cambia, deja de contar sola (`SQL_CHANGED_SINCE_FIELD_VALIDATION`), y el test del registro falla hasta revalidar o retirar la entrada.
5. **Dimensión desconocida:** nunca convierte una diferencia en coincidencia. Se reporta en `not_compared`.
6. **RCA:** los estados del `rca_engine` no se reescriben. El techo se expone (`confidence_ceiling`) y lo aplica el orquestador según la política.
7. **Carga inicial:** sólo lo que tiene evidencia en un registro aprobado. Son 11 queries en `lab-ol8-19c`, en el contexto 19c RU 19.32, `CDB_ROOT`, PRIMARY, sin RAC, con ASM, sin Data Guard, Oracle Linux 8.10:

   | Queries | Registro |
   |---|---|
   | `Q-DISC-IDENTITY-001`, `Q-ORA-RESOURCE-LIMITS-001` | LAB-002 |
   | `Q-CDB-TABLESPACES-001`, `Q-RMAN-FRA-USAGE-001` | LAB-003 |
   | `Q-RMAN-BACKUP-FRESHNESS-001`, `Q-RMAN-JOB-SUMMARY-001` | LAB-004 |
   | `Q-DICT-VERIFY-001` … `-005` | LAB-007 |

   **No** se registran:
   - `Q-CDB-TEMP-001`, que corrió pero devolvió nulos por un defecto del `JOIN` (`CHG-REQ-QUERY-CDB-TEMP-USAGE`);
   - `Q-ORA-RESOURCE-LIMITS-001` desde la PDB, que devolvió 0 filas, un resultado no representativo;
   - las 5 queries corregidas en LAB-007, que nunca corrieron con su SQL nuevo.

## 4. IMPACT ANALYSIS

| Dimensión | Impacto |
|---|---|
| Contrato de salida del gateway | Campo nuevo `field_validation` (aditivo); limitaciones nuevas en `analyze_incident` |
| Agentes | `validation_level` obligatorio por hallazgo y tope de confianza |
| Queries / diccionario / collectors / lab | Sin cambios |
| Targets | Campos opcionales `os`, `release_update`: los archivos existentes siguen válidos |
| Capability matrix | Sin cambios: cobertura del marco ≠ validación en campo |
| Licencia / costo | Sin cambios |

## 5. TEST

- `check_field_validation`, 9/9 casos:
  - coherencia del registro: query existente, hash vigente, `EVR`/`REQ`/`change_id` en el registro citado;
  - contexto exacto, y dimensiones desconocidas reportadas;
  - cada dimensión distinta, incluidos RU menor y SO distinto;
  - un RU mayor no difiere;
  - SQL cambiado, query sin validar y collector no-SQL;
  - registro inválido o ausente, que falla cerrado;
  - el sobre de `collect`/`get_evidence`/`describe_collector`;
  - el techo en `analyze_incident`;
  - la política y los contratos.
- Mutaciones, 8/8 detectadas:
  - RU sin comparar;
  - SO desconocido dado por coincidente;
  - `EVR` mal formado aceptado;
  - SQL cambiado que sigue validado;
  - techo removido;
  - hash viejo en el registro;
  - `EVR` ausente del registro de cambio;
  - dimensión `rac` ignorada.

## 6. SECURITY VALIDATION

- El registro es de solo lectura para el gateway.
- Un registro inválido nunca produce una afirmación de validación: todo cae a `DOCUMENTATION_ONLY`.
- No hay datos nuevos de Oracle ni accesos nuevos.
- El sobre sólo agrega metadatos del propio e-stack: contexto declarado, ids de cambio y de evidencia.
- Veredicto: **PASS**.

## 7. REGRESSION VALIDATION

macOS (bash 5.3.20): 966/966 antes y **967/967** después.

## 8. Uso en el lab (opcional, acción humana)

El targets file privado del lab puede declarar `"release_update": "19.32"` y `"os": {"family": "LINUX", "distribution": "OL", "version": "8.10"}`. Si no los declara, el nivel es igual (`FIELD_VALIDATED`) y RU y SO aparecen en `not_compared`.

## 9–10. Registros relacionados

- Cierra `CHG-REQ-VALIDATION-MATRIX`.
- Abre `CHG-REQ-VALIDATION-RU` (RU observado en tiempo de ejecución).
- Siguientes validaciones naturales: las 5 queries corregidas en LAB-007, para las que se necesitan un RAC/ASM/DG de lab (`CHG-REQ-LAB-MULTIVERSION`, `CHG-REQ-LAB-DISC-STORAGE`).

## 11. HUMAN REVIEW — aprobado

`AUTH-VALIDATION-MATRIX-001`, revisor `REV-DBAMANAGER` (distinto del proponente `REV-CLAUDEAGENT`), `2026-09-28T19:10:11Z`, contra el digest `7252a507…d5c6201`. El motor informa `review_status: APPROVED_BY_HUMAN` con verificación `STRUCTURAL_ONLY_IDENTITY_NOT_VERIFIED`: comprueba la estructura y el digest, no la identidad del firmante. `PROMOTE` (merge, tag) sigue siendo acción humana.

## 12. Motor de gobernanza

`advise --mode estack` (2026-09-28T19:02:55Z): `governance_state: PENDING_HUMAN_REVIEW`, `blockers: []`, `promote_status: HUMAN_ACTION_REQUIRED`, `content_digest: 7252a507e9561457627d762551a6e575f2b47169b2689def2b12ac9f3d5c6201`. La salida queda fuera del repo, en `~/.local/share/oracle-diagnostic-estack/change-evidence/CHG-ESTACK-VALIDATION-MATRIX-001/`.

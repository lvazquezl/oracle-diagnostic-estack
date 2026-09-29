# CHG-ESTACK-VALIDATION-RU-001 — Release Update observado para la validación en campo

**Tipo:** `/change compatibility|documentation` (plano B, `ESTACK_DEVELOPMENT`) · **Rama:** `change/validation-ru` (desde `change/disc-architecture`, `c2d8a36`, PR #21)
**Origen:** `CHG-REQ-VALIDATION-RU`
**Estado:** propuesto. Pendiente: validación en el lab (§8) y HUMAN REVIEW.

READ-ONLY ALWAYS · HUMAN-EXECUTED REMEDIATION ONLY. Sin queries ni accesos nuevos.

## 1. DETECT GAP

La validación en campo compara el RU del target con el RU validado, pero el target sólo lo **declara** (`release_update` en el targets file). Si se aplica un parche y no se actualiza el archivo, el nivel sale con un RU falso. `Q-DISC-IDENTITY-001` ya observa la versión completa (`19.32.0.0.0`).

## 2. CHANGE REQUEST — alcance

| Artefacto | Cambio |
|---|---|
| `mcp_gateway/architecture.py` | `release_update_from_identity`: RU `YY.RU` desde la versión observada, sólo 18c+. `ObservedTarget` aplica el RU observado |
| `mcp_gateway/gateway.py` | `collect` de `Q-DISC-IDENTITY-001` agrega `release_update_check` (observado, declarado, diferencia) y `DECLARED_RELEASE_UPDATE_MISMATCH`. Con REAL, el RU observado queda en la sesión, y un `collect` posterior de la arquitectura ya no lo pisa |
| `policies/field-validation-policy.md`, `docs/PHASE_13_MCP_DIAGNOSTIC_GATEWAY.md` | Regla "observado sobre declarado" para RU y arquitectura |
| Tests | P15 +1, P16 +3 |

## 3. GAP ANALYSIS

- **Antes de 18c** (`12.2.0.1.0`) la versión no contiene el RU: queda `not_compared` y no se infiere de otra fuente (el RU real estaría en `DBA_REGISTRY_SQLPATCH`, fuera de alcance).
- **Fixtures:** reportan el RU pero nunca reemplazan la declaración.
- **Coherencia con la arquitectura:** el estado observado de la sesión se **combina**. Antes, recoger la arquitectura reemplazaba todo el estado observado; ahora se conserva el RU.

## 4. IMPACT ANALYSIS

Campo nuevo `release_update_check` en el `collect` de la identidad. Queries, diccionario, lab, licencia y costo sin cambios.

## 5. TEST

- P15: RU observado (19.27) frente al declarado (19.40), con la diferencia reportada; después de recoger la arquitectura, la validación sigue usando 19.27 y marca `release_update` frente a 19.32.
- P16: extracción sólo desde 18c; un RU observado más viejo que el validado difiere; los fixtures no reemplazan.
- Mutaciones, 5/5 detectadas:
  - un fixture que reemplaza el RU declarado;
  - un RU "extraído" antes de 18c;
  - la arquitectura que pisa el RU observado (el caso se reforzó tras sobrevivir la primera vez);
  - una diferencia sin limitación;
  - el RU observado ignorado por la vista del target.

## 6. SECURITY VALIDATION

Sin datos nuevos: la versión ya se devolvía. Veredicto: **PASS**.

## 7. REGRESSION VALIDATION

macOS (bash 5.3.20): ver §12.

## 8. Validación en el lab (pendiente)

Con esta rama en el workspace principal y el lab reconectado, `Q-DISC-IDENTITY-001` debe reportar `release_update_check: {observed: "19.32", declared: "19.32", mismatch: false}` y seguir `FIELD_VALIDATED`.

## 9–10. Registros relacionados

Cierra `CHG-REQ-VALIDATION-RU`.

## 11. HUMAN REVIEW (pendiente)

## 12. Motor de gobernanza (pendiente, después de §8)

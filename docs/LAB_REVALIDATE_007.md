# CHG-ESTACK-LAB-REVALIDATE-007 — Revalidación en el lab de las queries corregidas en LAB-007

**Tipo:** `/change query|security` (plano B, `ESTACK_DEVELOPMENT`) · **Rama:** `change/lab-revalidate-007` (desde `change/validation-ru`, `1c41e31`)
**Origen:** pendiente de `CHG-ESTACK-ORA19C-LAB-007` (5 queries corregidas, todas `DOCUMENTATION_ONLY`)
**Estado:** propuesto. Pendiente: validación en el lab (§8) y HUMAN REVIEW.

READ-ONLY ALWAYS · HUMAN-EXECUTED REMEDIATION ONLY.

## 1. DETECT GAP

LAB-007 corrigió 5 queries que fallaban en Oracle real, pero su SQL nuevo nunca corrió: siguen `DOCUMENTATION_ONLY`.

## 2. CHANGE REQUEST — alcance

| Query | En este cambio | Motivo |
|---|---|---|
| `Q-RMAN-BACKUP-DEVICE-001` | **Sí** | `V$BACKUP_DEVICE` lista los tipos soportados; siempre hay datos |
| `Q-SEC-PROXY-AUTHENTICATION-001` | **Sí** | Datos de prueba creados por el DBA en `CDB$ROOT`: dos relaciones proxy con `FLAGS` distintos (opción B) |
| `Q-ASM-TOPOLOGY-001` | **Sí** | El lab usa ASM |
| `Q-SEC-DATA-REDACTION-POLICIES-001` | No | Requiere Advanced Security (licencia) y datos, y tiene **dos** sentencias: un collector del lab ejecuta una. `CHG-REQ-LAB-REDACTION` |
| `Q-RAC-GES-GCS-001` | No | Requiere RAC (`CHG-REQ-LAB-MULTIVERSION`) |

Cambios:
- **Collectors:** 3 en `mcp_gateway/catalog/collectors.json`, sin `DATE` ni texto libre.
  - Nombres de dispositivo, usuario, instancia, base y disk group → `identifier` MASK.
  - Tipos y estados → enums KEEP.
  - Capacidades → enteros KEEP (`usable_file_mb` admite negativos).
- **Adaptador lab:** `mcp_gateway_lab` 0.7.0 con los 3 collectors.
- **Sanitizador** (`mcp_gateway/evidence.py`): `identifier` admite un `+` **inicial**, la convención de ASM (`+ASM`, `+ASM1`). El valor sigue saliendo enmascarado.
- **`Q-ASM-TOPOLOGY-001`:** `supported_oracle_versions` pasa de `11gR2` a la familia canónica `11g`, que exige el catálogo del gateway. El piso 11.2 sigue en la matriz y el SQL (y su hash) no cambia.
- **Fixtures y registros:** fixtures sintéticos en `fixture-primary-19c`; readiness con 89 componentes y privilegios copiados de la query; docs.
- **Tests:** P15 +1 (driver falso: los 3 corren su bloque certificado, sin nombres en claro; en 19c la de proxy resuelve la variante V2 con `FLAGS`).

## 3. GAP ANALYSIS

- **Sin datos no hay validación de comportamiento.** Proxy se valida con los datos de prueba que creó el DBA; redacción queda fuera hasta que haya licencia y datos.
- **Contenedor:** `PROXY_USERS` sólo ve el contenedor actual. Los datos de prueba se crearon en `CDB$ROOT` porque el lab se conecta ahí.
- **`FLAGS` en 10.2** sigue sin verificar (variante V1). El lab sólo valida la V2.

## 4. IMPACT ANALYSIS

| Dimensión | Impacto |
|---|---|
| Queries | Sin cambios de SQL; `Q-ASM-TOPOLOGY-001` sólo cambia la familia declarada |
| Sanitizador | Un `+` inicial permitido en identificadores (valor enmascarado de todas formas) |
| Lab | 0.6.0 → 0.7.0; hay que agregar los 3 collectors al targets file privado |
| Privilegios | `SELECT_CATALOG_ROLE` (ya otorgado); si alguno falta, `MISSING_OBJECT_PRIVILEGE` lo dirá |

## 5. TEST

- P15 27/27; mutación: sin el `+` en el sanitizador, el caso de ASM falla.

## 6. SECURITY VALIDATION

Todos los nombres salen enmascarados. El `+` no amplía lo que sale: sólo evita que se descarte un nombre ASM antes de enmascararlo. Veredicto: **PASS**.

## 7. REGRESSION VALIDATION

macOS (bash 5.3.20): **968/968**.

## 8. Validación en el lab (pendiente)

Se esperan `OK`/`REAL` sin limitaciones en las 3:
- 2 filas de proxy con `FLAGS` `PROXY MAY ACTIVATE ROLE` y `PROXY MAY ACTIVATE ALL CLIENT ROLES`;
- al menos 1 fila de dispositivo (`DISK`);
- 1 fila de ASM con la instancia enmascarada y el disk group en uso.

Después se registran en el registro de validación en campo.

## 9–10. Registros relacionados

- Abre `CHG-REQ-LAB-REDACTION`.
- Después de la validación, el DBA puede borrar los datos de prueba de proxy (rollback entregado aparte).

## 11. HUMAN REVIEW (pendiente)

## 12. Motor de gobernanza (pendiente, después de §8)

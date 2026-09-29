# CHG-ESTACK-LAB-REVALIDATE-007 — Revalidación en el lab de las queries corregidas en LAB-007

**Tipo:** `/change query|security` (plano B, `ESTACK_DEVELOPMENT`) · **Rama:** `change/lab-revalidate-007` (desde `change/validation-ru`, `1c41e31`)
**Origen:** pendiente de `CHG-ESTACK-ORA19C-LAB-007` (5 queries corregidas, todas `DOCUMENTATION_ONLY`)
**Estado:** propuesto. Validado en el lab (§8). Pendiente: HUMAN REVIEW.

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

## 8. Validación en el lab

2026-09-29T03:38Z, `lab-ol8-19c` (19c RU 19.32, `CDB$ROOT`, ASM, OL 8.10), commit `5ab1e8f`. Las 3 corrieron `OK`/`REAL`, sin limitaciones.

| Query | `REQ` | `EVR` | `query_sha256` | Resultado |
|---|---|---|---|---|
| `Q-RMAN-BACKUP-DEVICE-001` | `REQ-aa3d65b9fc0d` | `EVR-5a9da5b1ac341474c2864d70` | `c761741c…fc9f` | 1 fila `SBT_TAPE`, sin nombre de dispositivo |
| `Q-SEC-PROXY-AUTHENTICATION-001` | `REQ-091f4c1d537f` | `EVR-5f9ca0aba28072d1431371ea` | `164b7604…1b4a` | 2 filas con los datos de prueba: `PROXY MAY ACTIVATE ROLE` y `PROXY MAY ACTIVATE ALL CLIENT ROLES`; usuarios enmascarados; variante V2 (`FLAGS`) |
| `Q-ASM-TOPOLOGY-001` | `REQ-98c25d84c0fd` | `EVR-417325d97b1297203726a9c3` | `1355d8cd…a0eb3` | 2 filas: instancia ASM enmascarada, `CONNECTED`, 19.0.0.0.0, un disk group `EXTERN` (~40 GB, ~35 GB libres); la segunda fila es un cliente sin disk group asociado (el `LEFT JOIN` no encuentra grupo; `GROUP_NUMBER = 0` documentado) |

Las 3 pasan a `FIELD_VALIDATED` en el contexto `LAB-OL8-19C-CDBROOT-ASM` (`config/field-validation-registry.json`). Los datos de prueba de proxy pueden retirarse con el rollback entregado.

**Observación para las skills:** `Q-ASM-TOPOLOGY-001` puede devolver filas de cliente sin disk group. `asm/topology` debe tratarlas como "cliente conectado sin grupo en uso", no como falta de datos (`CHG-REQ-SKILL-ASM-CLIENT-NOGROUP`).

## 9–10. Registros relacionados

- Abre `CHG-REQ-LAB-REDACTION`.
- Después de la validación, el DBA puede borrar los datos de prueba de proxy (rollback entregado aparte).

## 11. HUMAN REVIEW (pendiente)

Revisor distinto del proponente, contra el `content_digest` del motor (§12).

## 12. Motor de gobernanza

Regresión final (macOS, bash 5.3.20): **968/968**. `advise --mode estack` (2026-09-29T03:42:12Z): `governance_state: PENDING_HUMAN_REVIEW`, `blockers: []`, `promote_status: HUMAN_ACTION_REQUIRED`, `content_digest: 7cc271f874b04f818e0922b705ea238d9eaca405bc589fbdead4865441ce37ca`. La salida queda fuera del repo, en `~/.local/share/oracle-diagnostic-estack/change-evidence/CHG-ESTACK-LAB-REVALIDATE-007/`.

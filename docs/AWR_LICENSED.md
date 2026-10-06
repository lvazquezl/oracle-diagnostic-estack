# AWR/ASH con licencia confirmada: gate de licencias y lote B4

`/change query|security|compatibility|documentation` — `CHG-ESTACK-AWR-LICENSED-001`. Rama `change/awr-licensed` sobre `main` (`c8df388`, `v0.25.0-security-assessment`).

## Por qué

AWR y ASH son la fuente principal para analizar el rendimiento histórico, pero requieren **Oracle Diagnostics Pack**. Hasta ahora el e-stack tenía dos huecos:

- **Licencia:** nada impedía pedir una consulta AWR a un target sin licencia confirmada. `CONTROL_MANAGEMENT_PACK_ACCESS = DIAGNOSTIC+TUNING` solo indica que la función está habilitada, no que el contrato la cubra.
- **Consultas AWR existentes:** `Q-PERF-WAIT-AWR-001` y `Q-PERF-DBTIME-001` suman contadores **acumulados** de `DBA_HIST_*` y necesitan binds, así que el gateway no puede recolectarlas. Su corrección queda para un cambio aparte.

La licencia del lab se confirmó por escrito: Diagnostics + Tuning, revisor humano, 2026-10-06 («es del lab, la licencia está confirmada»).

## Gate de licencias

| Ruta | Regla |
|---|---|
| Gateway (`mcp_gateway/catalog.py`) | `license_keys()` traduce `license_requirements` a claves: Diagnostics/AWR/ASH → `diagnostics_pack`; Tuning → `tuning_pack` **y** `diagnostics_pack` (Tuning Pack requiere Diagnostics); Active Data Guard → `active_data_guard`; cualquier otra → `other_option`. Cada clave debe estar `CONFIRMED` en `license_status` del target; si no, `LICENSE_RESTRICTED` y no se ejecuta |
| Ruta humana (`human_evidence request`) | Una consulta licenciada exige `--license-confirmed <clave>` (repetible) y `--confirmed-by REV-…`. Sin esos parámetros se rechaza. La confirmación queda en la solicitud y `ingest` la copia a la procedencia de la evidencia |

`license_requirements` también puede venir como lista en el front matter. Antes eso provocaba un `E_INTERNAL` en el gateway; ahora se normaliza.

## Lote B4 (fábrica de collectors)

Cuatro consultas nuevas en `queries/performance/awr/`, todas sin binds y con ventana fija:

| Query | Qué devuelve | Cómo calcula |
|---|---|---|
| `Q-PERF-AWR-DBTIME-24H-001` | DB time y DB CPU por snapshot, 24 h | Delta con `LAG … PARTITION BY dbid, instance_number, startup_time`; V2 (12.1+) filtra `con_dbid = dbid` |
| `Q-PERF-AWR-TOPSQL-24H-001` | Top 20 `sql_id` por tiempo transcurrido, 24 h | Suma de columnas `*_DELTA` de `DBA_HIST_SQLSTAT`; V2 agrega `con_id`. Sin texto SQL |
| `Q-PERF-AWR-WAITS-24H-001` | Esperas no ociosas, 24 h | `MAX − MIN` por instancia, arranque y evento, sumado después; V2 filtra `con_dbid = dbid` |
| `Q-PERF-ASH-1H-001` | Muestras ASH de los últimos 60 min por clase, evento y `sql_id` | `NVL(wait_class,'CPU')`, `NVL(event,'ON CPU')`; muestras y sesiones distintas |

Licencia `[Diagnostics Pack]`, rol `PRIMARY`, costo `MEDIUM`. El catálogo llega a 65 collectors, 60 habilitados en el lab. El fixture sintético `fixture-licensed-19c` tiene las licencias confirmadas; en `fixture-primary-19c` los mismos collectors responden `LICENSE_RESTRICTED`.

## Validación en el lab (`lab-ol8-19c`, `LAB-OL8-19C-CDBROOT-ASM`, 2026-10-06)

`targets.lab.json` declara `license_status.diagnostics_pack` y `tuning_pack` como `CONFIRMED`, por la confirmación humana. Los 4 collectors corrieron en real; en los 4, el `query_sha256` coincide con el SQL versionado.

| Collector | Request | Evidencia | `query_sha256` | Resultado |
|---|---|---|---|---|
| `Q-PERF-AWR-DBTIME-24H-001` | `REQ-f74e563b2cf8` | `EVR-7b6141c59764900f013d656e` | `e910c75784aa…` | 5 snapshots desde el arranque; el primero sin delta, 4 intervalos con delta |
| `Q-PERF-AWR-TOPSQL-24H-001` | `REQ-51c4d6c069a7` | `EVR-a004957f7334c9a58a32d88c` | `31127f798f95…` | 20 `sql_id` con `con_id`, sin texto SQL |
| `Q-PERF-AWR-WAITS-24H-001` | `REQ-982ea0383458` | `EVR-68753d2ba9fd70b63a15d4e6` | `76768706e391…` | 20 eventos; domina `control file sequential read` con 9.7 s |
| `Q-PERF-ASH-1H-001` | `REQ-53d2f668723e` | `EVR-f444a0c6c73df60b598e2dac` | `55582af77dc4…` | 4 filas; CPU (`ON CPU`) con 32 muestras en 6 sesiones, más System I/O |

### DB CPU mayor que DB time: verificado, viene de AWR

En los 4 intervalos con delta, DB CPU superó a DB time (por ejemplo, 1.25 s contra 0.92 s). Así se investigó:

1. **Hipótesis: mezcla de filas por contenedor. Descartada.** Se agregó `con_dbid = dbid` en V2 (commit `4a99931`) y los resultados fueron idénticos. El filtro se queda: es correcto para un CDB y no cambia nada en un non-CDB.
2. **Valores crudos.** El DBA consultó `DBA_HIST_SYS_TIME_MODEL` ⋈ `DBA_HIST_SNAPSHOT` (snaps 94–98, una fila por estadística y snapshot, sin duplicados). Los deltas calculados a mano coinciden exactamente con los de la query:

   | Intervalo | Δ DB CPU | Δ DB time |
   |---|---|---|
   | 94→95 | 1.251 s | 0.917 s |
   | 95→96 | 0.830 s | 0.528 s |
   | 96→97 | 1.115 s | 0.669 s |
   | 97→98 | 1.056 s | 0.690 s |

3. **Acumulados.** Al snap 98, AWR registra DB time 21.46 s y DB CPU 7.68 s. Cerca de una hora después, `V$SYS_TIME_MODEL` daba 21.99 s y 8.42 s. Ambas fuentes son coherentes. Unos 18.65 s de DB time ocurren entre el arranque (10:12) y el snap 94 (10:23), un intervalo que la query reporta sin delta, igual que el reporte AWR, que no cruza reinicios.

**Conclusión:** la query calcula bien. La relación invertida viene de los valores de AWR con una carga casi nula (menos de 1 s de DB time por hora). La causa interna de esa contabilidad no se determinó con las consultas certificadas y no se afirma ninguna. Quedó documentado en la query como regla de interpretación: con DB time por debajo de ~1 s por hora, la proporción CPU/DB time no es significativa y no debe reportarse como hallazgo.

## Registro del cambio

| Fase | Resultado |
|---|---|
| DETECT GAP | Las consultas AWR existentes suman acumulados y requieren binds, y no había gate de licencia en el gateway ni en la ruta humana |
| PROPOSAL | Gate de licencias en ambas rutas; lote B4 con deltas correctos y ventana fija |
| IMPLEMENT | `catalog.license_keys()` y la normalización de listas en `evaluate_capability`; `human_evidence` (`--license-confirmed`, `--confirmed-by`); 4 queries; matriz de compatibilidad (máximo `23.0`); `lots/B4-awr.json` y 4 definiciones en la base de conocimiento (`wait_class` admite `CPU`); `fixture_target` en la fábrica; fixture `fixture-licensed-19c`; registro de madurez (65 collectors). `Q-PERF-WAIT-ASH-001` 2.2.0: un comentario con `;` salió del bloque SQL |
| TEST | P18 24/24 (licencia restringida y confirmada, Tuning exige ambas claves, deltas por arranque, `con_dbid` en V2 y no en V1); P17 28/28 (gate de licencia en la ruta humana); P14, inventario de 133 queries y 65 collectors |
| SECURITY | 7/7 mutaciones detectadas: gate del gateway eliminado, Tuning sin la clave de Diagnostics, basta una clave confirmada (en vez de todas), ruta humana sin gate, `--confirmed-by` opcional, `license_requirements` en lista ignorado y procedencia sin la confirmación. Las pruebas de P18 cubren deltas por arranque y `con_dbid` |
| REGRESSION | 972/972 en macOS (bash 5.3) |
| LAB | 4/4 en real; `FIELD_VALIDATED` en `LAB-OL8-19C-CDBROOT-ASM` (`config/field-validation-registry.json`) |
| HUMAN REVIEW | Pendiente |

## Pendiente (fuera de este cambio)

- `Q-PERF-WAIT-AWR-001` y `Q-PERF-DBTIME-001` suman contadores acumulados, y `Q-PERF-DBTIME-001` multiplica un `INTERVAL` por 86400. Se corrigen en un `/change query` aparte.

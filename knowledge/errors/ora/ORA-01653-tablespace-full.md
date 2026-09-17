---
id: KC-ORA-01653-001
taxonomy: ora
code: ORA-01653
symptom: "unable to extend table ... in tablespace ..."
confirmed_root_cause: "Tablespace sin autoextend (o con autoextend limitado por MAXSIZE) alcanzó used_pct >= 100% durante una carga de datos sostenida no anticipada por el forecast de capacidad vigente."
resolution_summary: >
  Confirmar espacio disponible en el disk group ASM o filesystem subyacente; si hay espacio disponible,
  la resolución típica es ampliar el datafile o habilitar/ajustar autoextend con un MAXSIZE adecuado
  (ejecución manual del DBA vía el CHG-* generado por change-advisor). Si no hay espacio disponible en
  el storage subyacente, escalar a capacity-analyst para forecast revisado y a change-advisor para
  propuesta de ampliación de storage.
source_analysis_ids: []
applies_to:
  versions: ["10g", "11g", "12c", "18c", "19c", "21c", "23ai"]
  platforms: ["todas"]
  architectures: ["Standalone", "RAC", "NON-CDB", "CDB", "ASM", "Filesystem"]
status: active
---

# Notas

Detectado típicamente por `oracle/tablespaces` (`skills/oracle/tablespaces.md`) antes de que ocurra el `ORA-01653`, cuando `used_pct >= 90%` sin autoextend — el objetivo del healthcheck/assessment es anticipar este error, no sólo diagnosticarlo post-mortem. Si el error ya ocurrió, `incident-root-cause-analyst` lo confirma correlacionando el timestamp del error (evidencia provista por el DBA, ej. alert log) con el `used_pct` histórico vía `capacity/tablespace`/`capacity/trend-analysis` (Fase 10 — Capacity Management & Forecasting).

Este es un ejemplo semilla materializado en Fase 1 para validar el formato de `knowledge/errors/`; casos reales futuros se agregan vía `/change knowledge` con `source_analysis_ids` poblado.

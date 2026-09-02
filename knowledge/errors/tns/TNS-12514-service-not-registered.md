---
id: KC-TNS-12514-001
taxonomy: tns
code: TNS-12514
symptom: "TNS:listener does not currently know of service requested in connect descriptor"
confirmed_root_cause: >
  El listener está activo y aceptando conexiones en el puerto correcto, pero el service_name
  solicitado por el cliente no está registrado (dinámicamente vía PMON, o estáticamente en
  listener.ora) — típicamente porque la instancia está caída, `service_names` no incluye el
  nombre usado por el cliente, o el registro dinámico aún no ocurrió tras un restart reciente.
resolution_summary: >
  Confirmar con get_listener_status si el servicio está registrado; si la instancia está caída,
  la resolución es que el DBA la levante manualmente (fuera del alcance de este e-stack). Si la
  instancia está arriba pero el servicio no aparece, verificar coincidencia entre el service_name
  del connect descriptor del cliente y DBA_SERVICES/service_names del parámetro de instancia
  (hallazgo generado por network/tns + oracle-network-analyst; corrección la ejecuta el DBA).
source_analysis_ids: []
applies_to:
  versions: ["10g", "11g", "12c", "18c", "19c", "21c", "23ai"]
  platforms: ["todas"]
  architectures: ["Standalone", "RAC", "NON-CDB", "CDB"]
status: active
---

# Notas

En RAC, distinguir si el error ocurre contra el listener local de un nodo específico (servicio no placed en ese nodo, comportamiento esperado con `PREFERRED`/`AVAILABLE` instances) vs. contra el SCAN listener (más indicativo de un problema real de registro). Ver `rac/services`/`rac/service-placement` para esa distinción — este skill (`network/tns`) cubre el diagnóstico genérico del error, no la lógica de placement RAC.

Ejemplo semilla materializado en Fase 1.

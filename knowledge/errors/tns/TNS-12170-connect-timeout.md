---
id: KC-TNS-12170-001
taxonomy: tns
code: TNS-12170
symptom: "TNS:Connect timeout occurred"
confirmed_root_cause: >
  El cliente no recibió respuesta dentro de SQLNET.OUTBOUND_CONNECT_TIMEOUT/TCP.CONNECT_TIMEOUT.
  Dos escenarios distintos (# 51 del prompt de Fase 4): (a) SCAN/host resuelve, listener está
  online y el servicio registrado — la causa probable es de path de red/cliente/firewall; (b)
  SCAN/host NO resuelve — la causa probable es de name-resolution, no de red/firewall.
resolution_summary: >
  network/connection-path ejecuta primero network/scan-resolution (o network/name-resolution para
  un target no-RAC); si la resolución falla, clasifica NAME_RESOLUTION sin más pasos. Si resuelve,
  continúa verificando listener/servicio antes de considerar NETWORK_PATH/FIREWALL_SUSPECTED.
  Nunca afirma firewall como causa sin haber descartado name-resolution y listener primero.
source_analysis_ids: []
applies_to:
  versions: ["10g", "11g", "12c", "18c", "19c", "21c", "23ai"]
  platforms: ["todas"]
  architectures: ["Standalone", "RAC", "NON-CDB", "CDB"]
status: active
---

# Notas

Un timeout configurado agresivamente bajo (`network/timeouts`) respecto a la latencia real de la red puede producir este error sin que exista ningún problema de conectividad real — correlacionar antes de escalar al equipo de red.

---
id: KC-TNS-12537-001
taxonomy: tns
code: TNS-12537
symptom: "TNS:connection closed"
confirmed_root_cause: >
  No existe una causa única — es el código más ambiguo de la taxonomía TNS (# 52 del prompt de
  Fase 4). Dominios posibles: listener/red, exhaustion de recursos del server process, límites OS
  (ulimit/processes), path de cliente/aplicación cerrando la conexión, dispositivo intermedio
  (load balancer/firewall con timeout agresivo), o terminación abrupta del proceso Oracle server.
resolution_summary: >
  network/tns-errors NUNCA reduce automáticamente TNS-12537 a "problema de listener" — solicita
  evidencia específica de cada uno de los 6 dominios posibles antes de clasificar, y reporta
  INSUFFICIENT_EVIDENCE explícitamente si no hay suficiente correlación en vez de adivinar.
source_analysis_ids: []
applies_to:
  versions: ["10g", "11g", "12c", "18c", "19c", "21c", "23ai"]
  platforms: ["todas"]
  architectures: ["Standalone", "RAC", "NON-CDB", "CDB"]
status: active
---

# Notas

Correlacionar con `ORA-27300`/`ORA-27301` en el alert log del lado servidor si están disponibles — indican terminación de proceso a nivel OS, un dominio distinto de "problema de red pura".

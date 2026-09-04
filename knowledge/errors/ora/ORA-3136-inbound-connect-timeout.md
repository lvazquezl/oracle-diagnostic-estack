---
id: KC-ORA-3136-001
taxonomy: ora
code: ORA-3136
symptom: "inbound connection timed out (ORA-3136)"
confirmed_root_cause: >
  El servidor cerró una conexión entrante que no completó la autenticación dentro de
  SQLNET.INBOUND_CONNECT_TIMEOUT — puede ser legítimo (cliente lento/latencia real) o síntoma de
  connection storming/scanning contra el listener.
resolution_summary: >
  network/tns-errors correlaciona la frecuencia del error (aislado vs. volumen alto en ventana
  corta) — un volumen alto sugiere connection storming, correlacionar con os-platform-analyst
  para descartar agotamiento de recursos del host. Ajuste de timeout es manual, ejecutado por el
  DBA, nunca automático.
source_analysis_ids: []
applies_to:
  versions: ["11g", "12c", "18c", "19c", "21c", "23ai"]
  platforms: ["todas"]
  architectures: ["Standalone", "RAC", "NON-CDB", "CDB"]
status: active
---

# Notas

Distinto de `TNS-12170` (timeout del lado cliente) — `ORA-3136` se registra en el alert log/listener log del **servidor**, es la contraparte del lado servidor de una conexión entrante lenta.

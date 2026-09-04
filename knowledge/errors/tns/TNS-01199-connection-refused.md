---
id: KC-TNS-01199-001
taxonomy: tns
code: TNS-01199
symptom: "Listener has not recognized the password / connection refused by cross registration"
confirmed_root_cause: >
  Típicamente asociado a fallos de registro dinámico entre instancia y listener cuando la
  seguridad del listener (COST/valid node checking, o registro cruzado entre listeners locales
  en un cluster) rechaza el registro — no es un error de conexión de cliente final, sino de
  registro instancia↔listener.
resolution_summary: >
  network/service-registration verifica si el servicio efectivamente se registró pese al error
  reportado en el log — un TNS-01199 aislado sin impacto en registro real puede no requerir
  acción. Si el registro está genuinamente afectado, la corrección (ajuste de valid node checking,
  reinicio del listener) es manual, ejecutada por el DBA/Grid admin, nunca por este stack.
source_analysis_ids: []
applies_to:
  versions: ["11g", "12c", "18c", "19c", "21c", "23ai"]
  platforms: ["todas"]
  architectures: ["Standalone", "RAC"]
status: active
---

# Notas

Más frecuente en configuraciones con `valid_node_checking_registration_*` restrictivo — visibilidad de esa configuración vía `network/listeners`, nunca modificada por este stack.

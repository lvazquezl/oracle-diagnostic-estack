---
id: KC-TNS-12541-001
taxonomy: tns
code: TNS-12541
symptom: "TNS:no listener"
confirmed_root_cause: >
  Ninguna causa única confirmada — este código sólo indica que no hubo respuesta de ningún
  listener en el host/puerto del connect descriptor. Puede deberse a: listener realmente caído,
  host/puerto incorrecto en el descriptor, o el paquete de red nunca llegó (name resolution
  apuntando al host/IP equivocado, firewall, o SCAN VIP no activo en ningún nodo).
resolution_summary: >
  network/connection-path verifica en orden: resolución de nombre → listener realmente escuchando
  en ese host/puerto (network/listeners) → si ambos son correctos y el error persiste, se
  clasifica NETWORK_PATH/FIREWALL_SUSPECTED (nunca como primera hipótesis, sólo tras descartar
  name resolution y listener). Corrección la ejecuta el DBA/administrador de red correspondiente.
source_analysis_ids: []
applies_to:
  versions: ["10g", "11g", "12c", "18c", "19c", "21c", "23ai"]
  platforms: ["todas"]
  architectures: ["Standalone", "RAC", "NON-CDB", "CDB"]
status: active
---

# Notas

En RAC, `TNS-12541` contra un SCAN endpoint específico puede indicar que el SCAN VIP correspondiente está `OFFLINE` a nivel Clusterware — en ese caso `network/connection-path` remite a `rac/gi-scan` (dominio de `oracle-rac-analyst`) en vez de reconstruir esa verificación.

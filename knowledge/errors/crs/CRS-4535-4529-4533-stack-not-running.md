---
id: KC-CRS-4535-001
taxonomy: crs
code: "CRS-4535 / CRS-4529 / CRS-4533"
symptom: "Cannot communicate with Cluster Ready Services / Event Manager / Cluster Synchronization Services"
confirmed_root_cause: >
  Uno o más daemons del stack Clusterware (CRSD/EVMD/CSSD) no está activo en el nodo consultado —
  `crsctl check crs`/`crsctl check cluster -all` reporta cuál falta. Causas posibles: stack no
  iniciado tras un reboot, stack detenido manualmente por un administrador, o crash reciente de un
  daemon (correlacionar con `rac/instance-eviction` si coincide con pérdida de voting disk/quorum).
resolution_summary: >
  rac/gi-node-status reporta el daemon específico afectado. Si coincide con una instancia
  recientemente reiniciada sin ventana de mantenimiento conocida, correlacionar con
  rac/instance-eviction antes de escalar. El reinicio del stack (`crsctl start crs`) es siempre
  una acción manual del Grid administrator — nunca ejecutada por este e-stack.
source_analysis_ids: []
applies_to:
  versions: ["11gR2", "12c", "18c", "19c", "21c", "23ai"]
  platforms: ["Oracle Linux", "RHEL", "SUSE", "Solaris", "AIX", "Windows Server"]
  architectures: ["RAC", "RAC One Node"]
status: active
---

# Notas

Distinguir un stack detenido deliberadamente (mantenimiento planificado, comunicado por el DBA) de uno caído inesperadamente — `rac/gi-node-status` no asume causa, sólo reporta el estado y remite la clasificación de urgencia a `incident-root-cause-analyst` cuando no hay ventana de mantenimiento conocida.

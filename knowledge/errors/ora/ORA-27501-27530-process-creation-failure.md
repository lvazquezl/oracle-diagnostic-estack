---
id: KC-ORA-27501-001
taxonomy: ora
code: "ORA-27501 / ORA-27530"
symptom: "IPC error creating a port access an IPC port / failed to create a process"
confirmed_root_cause: >
  Fallo al crear un proceso/puerto IPC del lado servidor al aceptar una nueva conexión —
  típicamente agotamiento de `processes`/`sessions` (límite Oracle) o límites OS (`ulimit -u`,
  `kernel.pid_max`), no un problema de red per se.
resolution_summary: >
  network/tns-errors clasifica RESOURCE_EXHAUSTION cuando este código coincide con un TNS-12537 o
  TNS-12500 reportado por el cliente. oracle-dba-analyst (oracle/resource-limits) confirma si
  `processes`/`sessions` está cerca del límite configurado; os-platform-analyst confirma límites
  OS. Ajuste de límites es manual, ejecutado por el DBA, nunca automático.
source_analysis_ids: []
applies_to:
  versions: ["10g", "11g", "12c", "18c", "19c", "21c", "23ai"]
  platforms: ["Oracle Linux", "RHEL", "SUSE", "Solaris", "AIX", "Windows Server"]
  architectures: ["Standalone", "RAC"]
status: active
---

# Notas

Ver `oracle/resource-limits` (Oracle Core, Fase 2) para el análisis de uso pico vs. límite de `processes`/`sessions` — este código de red es la manifestación del lado cliente de ese agotamiento, no un dominio nuevo de análisis.

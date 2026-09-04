---
id: KC-ORA-27300-001
taxonomy: ora
code: "ORA-27300 / ORA-27301"
symptom: "OS system dependent operation failed / failure occurred at (process termination / IPC)"
confirmed_root_cause: >
  Familia de errores OS-dependientes que acompañan la terminación abrupta de un proceso Oracle
  (frecuentemente correlacionados con TNS-12537 del lado cliente) — la causa raíz real está en el
  detalle OS-specific que acompaña el código (OOM killer, límite de recursos, señal recibida), no
  en el código ORA-273xx en sí.
resolution_summary: >
  network/tns-errors correlaciona ORA-27300/27301 en el alert log con el TNS-12537 reportado por
  el cliente en la misma ventana — si coinciden, sube la clasificación de RESOURCE_EXHAUSTION de
  HYPOTHESIS a PROBABLE_CAUSE. Delegar a os-platform-analyst para el detalle OS-dependent
  específico (dmesg/OOM killer/ulimit), nunca interpretado directamente por network/tns-errors.
source_analysis_ids: []
applies_to:
  versions: ["11g", "12c", "18c", "19c", "21c", "23ai"]
  platforms: ["Oracle Linux", "RHEL", "SUSE", "Solaris", "AIX"]
  architectures: ["Standalone", "RAC"]
status: active
---

# Notas

`ORA-27530` (falla de creación de proceso) suele preceder a estos dos cuando la causa es agotamiento de `processes`/límites OS — correlacionar los tres juntos antes de escalar.

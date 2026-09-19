# Change history — incident-root-cause-analyst

v1.0.0 — Foundation, manifest plano (`agents/incident-root-cause-analyst.md`), 8 skills
registered, sólo `incident/root-cause-analysis` materializado. Root Cause Model original:
`FACT → OBSERVATION → HYPOTHESIS → PROBABLE_CAUSE → CONFIRMED_ROOT_CAUSE`, `UNDETERMINED` como
salida legítima.

v2.0.0 — PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: deepening a contrato estructurado
completo (`AGENT.md`, `manifest.yaml`, `routing.yaml`, `context-policy.yaml`,
`collaboration.yaml`, `output-schema.yaml`). Reemplaza el modelo de 8 skill_ids de Foundation por
34 skills nuevos (incident intake/triage, evidence plan, timeline con clock-skew awareness,
symptom clustering, hypothesis generation/testing, contradiction analysis, root cause con causal
chain, contributing factors con rol, impact/blast radius, 10 correlaciones cross-domain,
playbooks, manual remediation plan, post-incident review, lessons learned, incident/RCA reports).
`incident/root-cause-analysis` (Foundation) fusionado como base de `incident/root-cause` v2.0.0 —
su modelo de 6 estados se preserva íntegramente, extendido con hypothesis states y confidence
explícito.

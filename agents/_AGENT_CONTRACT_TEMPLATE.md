---
id: TEMPLATE
role: ""
mission: ""
version: 0.0.0
status: candidate
---

# Responsibilities

-

# Explicit boundaries

-

# Supported versions/platforms/architectures

- Oracle versions:
- OS/platforms:
- Architectures (Standalone/RAC/RAC One Node):
- Tenancy (NON-CDB/CDB/PDB):
- Storage (ASM/Filesystem):
- Role (Primary/Physical Standby/Active Data Guard):

# Allowed skills

-

# Forbidden capabilities

- READ-ONLY ALWAYS. No ejecuta ni recomienda ejecución automática de ninguna operación de escritura.
-

# Required input contract (Task Package)

```yaml
task_id: string
target_summary: string
question: string
relevant_evidence_refs: [EVD-...]
constraints: {}
expected_output: string
```

# Output contract (Result Package)

```yaml
findings: [...]
evidence_refs: [EVD-...]
hypotheses: [...]
confidence: FACT|OBSERVATION|HYPOTHESIS|PROBABLE_CAUSE|CONFIRMED_ROOT_CAUSE|UNDETERMINED
recommendations: [...]
next_skill_or_agent: string|null
capability_status: null   # o el bloque completo (ver docs/CONTRACTS.md#capability-status-model) si algo no se pudo ejecutar
```

# Evidence policy

-

# Collaboration/delegation rules

-

# Context/token policy

- Presupuesto aproximado:
- Evidencia por referencia, no inline.
- No propaga historial completo.

# Confidence rules

-

# Escalation rules

-

# Documentation obligations

-

# Security constraints

- Identidad `ESTACK_DIAG_*`, read-only.
- Nunca solicita ni recibe secretos.

# Tests

-

# Evolution policy

- Cambios vía `/change agent`. Ver [EVOLUTION.md](../EVOLUTION.md).

"""CHG-ESTACK-HUMAN-EVIDENCE-001 — human-reported evidence for certified queries not (yet) exposed as collectors.

Flow (READ-ONLY, HUMAN EXECUTION ONLY):
  1. `request`  — an agent asks for evidence: the CERTIFIED SQL block of a query in queries/ (verbatim, hash-bound,
                  same read-only guard as the gateway) plus SQL*Plus spool instructions. The stack never runs it.
  2. the DBA runs it and saves the CSV in the local inbox.
  3. `ingest`   — local parsing + per-column classification (KEEP/MASK/HASH/TOKENIZE/DROP) + secret detection; the raw
                  CSV stays in evidence/raw (never read by the model); sanitized evidence goes to evidence/sanitized
                  with provenance HUMAN_REPORTED (confidence ceiling PROBABLE_CAUSE, policies/field-validation-policy.md).
Stdlib only.
"""

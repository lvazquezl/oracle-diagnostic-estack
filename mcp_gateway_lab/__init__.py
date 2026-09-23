"""
mcp_gateway_lab — LAB launcher for the read-only `oracle_sql` adapter (CHG-ESTACK-ORA19C-LAB-001).

This package is deliberately SEPARATE from the stdlib-only runtime `mcp_gateway`:
  * `python -m mcp_gateway` is unchanged: fixture mode only, `oracle_sql` stays DISABLED.
  * `python -m mcp_gateway_lab` is the only way to run `oracle_sql`, and only when ALL of these hold:
      - a private lab profile (outside the repository, owner-only permissions, no secrets inside) names exactly
        ONE non-production target with a current human authorization;
      - a lab targets file registers exactly that alias, adapter `oracle_sql`, and only collectors this adapter
        implements (Q-DISC-IDENTITY-001, Q-ORA-RESOURCE-LIMITS-001);
      - the password is read at connect time from an approved secret store (macOS Keychain), never from
        prompts, Git, environment variables or the profile;
      - the connected session proves, before any evidence is returned, that it is the authorized service,
        version, role and container, and that the account is not privileged.
  * SQL text comes only from the certified query file (hash-verified on every call) plus fixed guard
    statements in `oracle_sql.py`. No tool accepts SQL, shell, paths or connection parameters.

READ-ONLY ALWAYS. HUMAN-EXECUTED REMEDIATION ONLY. A successful lab run is not production readiness.
"""

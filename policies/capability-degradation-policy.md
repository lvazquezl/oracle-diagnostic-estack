# Capability Degradation Policy

No se permiten fallos silenciosos. Toda capability (agente, skill o query) que no pueda ejecutarse exactamente como se pidió debe devolver uno de los 8 estados siguientes, con los 5 campos obligatorios. Ver `docs/CONTRACTS.md#capability-status-model`.

## Los 8 estados

### `SUPPORTED`

La capability se ejecutó sin restricciones — comportamiento normal, no requiere el bloque `capability_status` en el Result Package (o se omite/`null`).

### `PARTIALLY_SUPPORTED`

Se ejecutó, pero con alcance reducido respecto a lo solicitado.

```yaml
capability_status: PARTIALLY_SUPPORTED
reason: Diagnostics Pack not confirmed licensed; AWR views may be restricted to a shorter retention window than requested.
impact: Wait event analysis limited to the available AWR retention window, not the full requested time_window.
alternative: Request a shorter window, or confirm licensing to unlock full retention.
required_action: LICENSE_CHECK_REQUIRED
```

### `UNSUPPORTED`

La feature Oracle/OS/arquitectura no existe en este ambiente — no es un problema de evidencia ni de permisos, es que la capability no aplica.

```yaml
capability_status: UNSUPPORTED
reason: Oracle Multitenant is not available on this database/version.
impact: Container-level analysis cannot be performed.
alternative: Use NON-CDB workflow.
required_action: null
```

### `LICENSE_RESTRICTED`

La capability depende de una feature potencialmente no licenciada y no se pudo confirmar que lo esté.

```yaml
capability_status: LICENSE_RESTRICTED
reason: Required feature may depend on Oracle licensing (Diagnostics Pack).
impact: Automated evidence collection via AWR is blocked.
alternative: Use non-licensed evidence path (Statspack or dynamic performance views).
required_action: LICENSE_CHECK_REQUIRED
```

### `INSUFFICIENT_PRIVILEGES`

`ESTACK_DIAGNOSTIC_ROLE` no alcanza para la evidencia requerida.

```yaml
capability_status: INSUFFICIENT_PRIVILEGES
reason: ESTACK_DIAG_* identity lacks SELECT on the required view for this target.
impact: This specific finding cannot be produced.
alternative: DBA can grant the specific missing SELECT via policies/identity-model.md#vistas-diagnósticas-controladas.
required_action: null
```

### `INSUFFICIENT_EVIDENCE`

La evidencia recolectada no permite concluir con la confianza requerida (distinto de `UNDETERMINED` del RCA Model, que es sobre una hipótesis de causa raíz — este estado es sobre la capability en sí, ej. histórico insuficiente para un forecast).

```yaml
capability_status: INSUFFICIENT_EVIDENCE
reason: Only 2 weeks of historical data available for a 6-month capacity forecast.
impact: Forecast confidence capped at HYPOTHESIS; 6-month horizon not reliably supported.
alternative: Offer the maximum horizon actually supported by available history.
required_action: null
```

### `POLICY_BLOCKED`

Una política del e-stack (no una limitación del ambiente) bloquea la operación — ej. `cost_class` excede lo permitido por el workflow actual, o la query tocaría datos de aplicación.

```yaml
capability_status: POLICY_BLOCKED
reason: Query cost_class HIGH not permitted for workflow /diagnose without an explicit time_window.
impact: Wide-window ASH evidence was not collected automatically.
alternative: Narrow the time_window, or re-run under /awr where wider windows are expected.
required_action: null
```

### `ENVIRONMENT_UNKNOWN`

El discovery no pudo determinar lo necesario para evaluar cualquiera de los otros 7 estados.

```yaml
capability_status: ENVIRONMENT_UNKNOWN
reason: core/context-discovery could not confirm database_role for this target.
impact: Cannot evaluate whether Data Guard capabilities apply.
alternative: Re-run discovery with elevated read-only access, or confirm role manually.
required_action: null
```

## Regla de uso

- Un agente/skill que no pudo completar una capability **siempre** produce uno de estos 8 estados — nunca omite el hallazgo sin explicación, y nunca inventa un resultado para evitar reportar la limitación.
- `capability_status` viaja en el Result Package (`docs/CONTRACTS.md#agent-contract`) y se consolida por el orquestador; el análisis final (`analysis/ANA-*/findings.md`) declara explícitamente qué quedó fuera de alcance y por qué.
- Ver `tests/test_capability_supported.sh` … `tests/test_capability_environment_unknown.sh` (uno por estado).

# Oracle Security Licensing Gates — Fase 8

## Principio

"Visible en `V$OPTION` ≠ licenciado." Ninguna capacidad de seguridad premium se reporta como disponible sin confirmación explícita en `Target Profile.security.licensing_profile`.

## Capacidades gateadas

| Capacidad | Licencia | Vista de disponibilidad (no de entitlement) |
|---|---|---|
| TDE (column + tablespace) | Advanced Security Option (donde no incluido en EE base) | `V$OPTION` (`'Advanced Security'`) |
| Data Redaction | Advanced Security Option | `V$OPTION` |
| Database Vault | Database Vault option | `DBA_DV_STATUS` / `V$OPTION` |
| Oracle Label Security (OLS) | OLS option | `V$OPTION` (`'Oracle Label Security'`) |
| Data Masking (Enterprise Manager pack) | Data Masking and Subsetting Pack (EM pack, **distinto bucket** de licencia que ASO) | no hay vista dinámica de servidor — awareness vía EM/documentación del cliente, nunca inferido de `V$OPTION` |

## Distinción explícita ASO vs. EM Pack (`# 33`/`# 34` del prompt)

**Data Redaction** y **TDE** comparten bucket de licencia (Advanced Security Option). **Data Masking** (subsetting/masking en Enterprise Manager) es un bucket de licencia **distinto** (Enterprise Manager Pack) — el e-stack nunca los trata como intercambiables ni asume que uno implica el otro.

## Estados de licensing_status

```text
INCLUDED             — confirmado en Target Profile.security.licensing_profile
NOT_INCLUDED         — confirmado explícitamente no licenciado
UNKNOWN              — sin confirmación explícita (default cuando no hay Target Profile)
NOT_APPLICABLE       — versión no soporta la capacidad
```

`V$OPTION.VALUE = 'TRUE'` únicamente certifica que el binario tiene el componente instalado/activable — nunca certifica derecho de uso. Todo hallazgo relacionado con una capacidad gateada declara `licensing_status` junto al `capability_status` técnico, y nunca colapsa ambos en un solo campo.

## Uso incorrecto explícitamente prohibido

- Nunca inferir `INCLUDED` a partir de que la funcionalidad ya esté en uso en el target (podría ser uso no conforme — el e-stack no audita compliance de licencia, sólo evita asumir cobertura).
- Nunca recomendar activar una capacidad premium sin antes señalar la necesidad de confirmar licensing con el cliente.

## Consumidores

`security/tde-awareness`, `security/keystore-awareness`, `security/tablespace-encryption`, `security/data-redaction-awareness`, `security/database-vault-awareness`, `security/ols-awareness`, `security/data-masking-awareness`, `security/licensing-gates` (skill dedicado que centraliza el modelo para el resto del dominio).

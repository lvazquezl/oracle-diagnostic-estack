# Oracle TDE / Keystore Awareness Model — Fase 8

## Principio

`security/tde-awareness`/`security/keystore-awareness` nunca ejecutan `ADMINISTER KEY MANAGEMENT` en ninguna variante (`OPEN/CLOSE KEYSTORE`, `SET KEY`, `CREATE KEYSTORE`, `ROTATE KEY`) — sólo awareness de estado, nunca exponen wallet password ni key material.

## Version boundaries (verificados)

- `V$ENCRYPTION_WALLET`/`V$ENCRYPTED_TABLESPACES` (TDE tablespace encryption): **11.2+** (WebSearch).
- `DBA_ENCRYPTED_COLUMNS` (TDE column encryption): **10.2+** (WebSearch) — precede a TDE tablespace encryption.

En 10g, sólo column encryption es certificable; en 11.1, ninguna de las dos; desde 11.2, ambas.

## Estados

```yaml
tde:
  wallet_state: OPEN|CLOSED|OPEN_NO_MASTER_KEY|UNKNOWN|NOT_APPLICABLE
keystore:
  type: SOFTWARE|HSM|UNKNOWN|NOT_APPLICABLE
  status: OPEN|CLOSED|UNKNOWN
  secrets_exposed: false   # siempre false por diseño de schema, no por convención
tablespace_encryption:
  classification: ENCRYPTED|UNENCRYPTED|UNKNOWN|NOT_APPLICABLE
```

Un tablespace sin fila en `V$ENCRYPTED_TABLESPACES` es `UNENCRYPTED` (la ausencia es la evidencia) — nunca `UNKNOWN` por ausencia de join.

## Nunca sin policy target

`tablespace_encryption`/`tde` nunca declaran incumplimiento sin `Target Profile.security.encryption_required` explícito.

## Sanitización

`wrl_parameter` (path de wallet) → `MASK` por defecto. `keystore.secrets_exposed` fijo en `false` en el output schema — no existe ningún campo que pudiera exponer contenido de clave, ni siquiera por error de implementación futura.

## Licensing

TDE requiere Advanced Security Option en versiones donde no está incluido en Enterprise Edition base — `security/licensing-gates` reporta el status correspondiente, nunca asumido `INCLUDED`.

## Prohibido

`ADMINISTER KEY MANAGEMENT` (cualquier variante) nunca ejecutado, ni siquiera si aparece en documentación manual generada por `manual_action` — siempre `execution_status: NOT_EXECUTED`.

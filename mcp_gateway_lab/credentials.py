"""
mcp_gateway_lab.credentials — approved secret store lookup.

Two providers (CHG-ESTACK-LAB-PORTABLE-001):

  macos_keychain  `/usr/bin/security find-generic-password -s <service> -a <account> -w` with a FIXED argv (no shell,
                  minimal environment, stdin closed, bounded time). The password is fetched at connect time, for one
                  connection, dropped right after the connect call, never comes from prompts, Git, environment
                  variables, the profile or a tool argument, and never appears in an error. python-oracledb THIN mode.
  oracle_wallet   Oracle Secure External Password Store (SEPS): the e-stack never sees a password at all. It connects
                  with external authentication to a TNS alias whose credential lives in the Oracle wallet named by the
                  operator's sqlnet.ora. Works the same on Windows, Linux and macOS. Requires python-oracledb THICK
                  mode (thin mode cannot use SEPS) — the only case in which thick mode is allowed.

Failures raise CredentialError with fixed text.
"""
from __future__ import annotations

import re
import subprocess

SECURITY_BIN = "/usr/bin/security"
_REF = re.compile(r'^[A-Za-z0-9][A-Za-z0-9_.:/@-]{0,127}$')
_TIMEOUT_SECONDS = 5                    # below the gateway deadline (10 s for the identity collector)
MAX_SECRET_BYTES = 1024


class CredentialError(RuntimeError):
    def __init__(self):
        super().__init__("credential is not available from the approved secret store")


class MacOSKeychain:
    provider = "macos_keychain"

    def __init__(self, runner=subprocess.run):
        self._run = runner                     # injectable for tests; production uses subprocess.run

    def get_password(self, service: str, account: str) -> str:
        if not (isinstance(service, str) and _REF.match(service) and isinstance(account, str) and _REF.match(account)):
            raise CredentialError()
        argv = [SECURITY_BIN, "find-generic-password", "-s", service, "-a", account, "-w"]
        try:
            p = self._run(argv, capture_output=True, stdin=subprocess.DEVNULL, timeout=_TIMEOUT_SECONDS, check=False,
                          shell=False, env={"PATH": "/usr/bin:/bin", "LANG": "C"})
        except Exception:
            raise CredentialError()
        out = p.stdout if isinstance(p.stdout, (bytes, bytearray)) else b""
        if p.returncode != 0 or not out or len(out) > MAX_SECRET_BYTES:
            raise CredentialError()
        secret = out.decode("utf-8", "strict") if out.isascii() else None
        if secret is None:
            raise CredentialError()
        secret = secret[:-1] if secret.endswith("\n") else secret
        if not secret or "\n" in secret or "\r" in secret:
            raise CredentialError()
        return secret


class OracleWallet:
    """External authentication through an Oracle wallet: there is no secret to fetch. `get_password` exists only so
    that a caller which forgets to branch on `external_auth` fails closed instead of connecting without credentials."""
    provider = "oracle_wallet"
    external_auth = True
    thick_mode = True

    def get_password(self, service: str, account: str) -> str:
        raise CredentialError()


MacOSKeychain.external_auth = False
MacOSKeychain.thick_mode = False


def provider_for(name: str, runner=None):
    if name == MacOSKeychain.provider:
        return MacOSKeychain(runner) if runner is not None else MacOSKeychain()
    if name == OracleWallet.provider:
        return OracleWallet()
    raise CredentialError()

"""
mcp_gateway_lab.credentials — approved secret store lookup.

Only macOS Keychain is implemented: `/usr/bin/security find-generic-password -s <service> -a <account> -w` with a
FIXED argv (no shell, minimal environment, stdin closed, bounded time). The password:
  * is fetched at connect time, for one connection, and dropped right after the connect call;
  * never comes from prompts, Git, environment variables, the profile or a tool argument;
  * never appears in an error: failures raise CredentialError with fixed text.
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


def provider_for(name: str, runner=None):
    if name == MacOSKeychain.provider:
        return MacOSKeychain(runner) if runner is not None else MacOSKeychain()
    raise CredentialError()

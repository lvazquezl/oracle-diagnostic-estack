"""
release_readiness.runner — the ONLY module of this package allowed to start processes.

Two kinds of process, both without a shell and with a scrubbed environment:
  * `git` with a fixed, read-only sub-command allowlist (no add/commit/merge/push/tag/checkout/reset...);
  * the repository's own test runner (`bash <repo-relative *.sh>`), or a caller-supplied argv in tests.

A timeout ends the whole process tree and is reported as `timed_out` — never as success.
"""
from __future__ import annotations

import os
import subprocess
import sys
import time

from .common import ReadinessError

GIT_READ_ONLY = frozenset({"rev-parse", "branch", "ls-files", "status", "diff", "describe", "tag", "log", "show", "config"})
_ENV_KEEP = ("PATH", "SYSTEMROOT", "SYSTEMDRIVE", "WINDIR", "COMSPEC", "PATHEXT", "TEMP", "TMP", "TMPDIR", "HOME", "USERPROFILE",
             "LANG", "LC_ALL", "MSYSTEM", "TERM")
GIT_TIMEOUT_SECONDS = 120


def clean_env(extra: dict = None) -> dict:
    env = {k: v for k, v in os.environ.items() if k.upper() in _ENV_KEEP}
    env.update({"GIT_TERMINAL_PROMPT": "0", "GIT_PAGER": "cat", "PYTHONDONTWRITEBYTECODE": "1", "PYTHONUTF8": "1"})
    if extra:
        env.update(extra)
    return env


def git(root: str, *args: str, check: bool = True) -> subprocess.CompletedProcess:
    """Run a read-only git command in `root`. Raises ReadinessError('E_GIT') on failure when check=True."""
    if not args or args[0] not in GIT_READ_ONLY:
        raise ReadinessError("E_COMMAND")
    if args[0] == "config" and (len(args) < 2 or args[1] not in ("--get", "--get-all", "--list")):
        raise ReadinessError("E_COMMAND")
    if args[0] == "tag" and not ({"--list", "-l"} & set(args[1:])):
        raise ReadinessError("E_COMMAND")                     # `git tag <name>` would CREATE a tag; only listing is allowed
    if args[0] == "branch" and args[1:] != ("--show-current",):
        raise ReadinessError("E_COMMAND")                     # `git branch <name>` would create a branch; only --show-current
    try:
        # Neutralize repository-controlled command execution and file output: no fsmonitor hook, no external diff/textconv,
        # and no option that makes git write a file (--output).
        if any(a.startswith(("--output", "--ext-diff", "--textconv", "--exec-path")) for a in args):
            raise ReadinessError("E_COMMAND")
        hardened = list(args)
        if args[0] == "diff":
            hardened[1:1] = ["--no-ext-diff", "--no-textconv"]
        proc = subprocess.run(["git", "-c", "core.fsmonitor=false", "-c", "core.pager=cat", *hardened], cwd=root, capture_output=True,
                              timeout=GIT_TIMEOUT_SECONDS, env=clean_env(), shell=False)
    except (OSError, subprocess.SubprocessError):
        raise ReadinessError("E_GIT")
    if check and proc.returncode != 0:
        raise ReadinessError("E_GIT")
    return proc


def kill_tree(proc: subprocess.Popen) -> None:
    """End the process and its children (Windows: taskkill /T; POSIX: process group)."""
    try:
        if os.name == "nt":
            subprocess.run(["taskkill", "/PID", str(proc.pid), "/T", "/F"], capture_output=True, timeout=30, shell=False)
        else:
            import signal
            os.killpg(os.getpgid(proc.pid), signal.SIGKILL)
    except Exception:
        pass
    try:
        proc.kill()
    except Exception:
        pass


def run_to_file(argv: list, cwd: str, log_path: str, timeout_seconds: float) -> dict:
    """Run `argv` (no shell), stdout+stderr appended to `log_path`. Returns
    {exit_code: int|None, timed_out: bool, started_monotonic, ended_monotonic}. exit_code is None on timeout/failure to start."""
    if not isinstance(argv, list) or not argv or not all(isinstance(a, str) and a for a in argv):
        raise ReadinessError("E_COMMAND")
    started = time.monotonic()
    kwargs = {"creationflags": subprocess.CREATE_NEW_PROCESS_GROUP} if os.name == "nt" else {"start_new_session": True}
    with open(log_path, "wb") as log:
        try:
            # The repository's own test suite runs with the INHERITED environment (a scrubbed one could make legitimate tests
            # fail and so falsify the evidence); only git and the gateway probe use the scrubbed environment.
            proc = subprocess.Popen(argv, cwd=cwd, stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT,
                                    env=dict(os.environ, GIT_TERMINAL_PROMPT="0"), shell=False, **kwargs)
        except OSError:
            return {"exit_code": None, "timed_out": False, "started_monotonic": started, "ended_monotonic": time.monotonic(), "start_failed": True}
        try:
            code = proc.wait(timeout=timeout_seconds)
            timed_out = False
        except subprocess.TimeoutExpired:
            kill_tree(proc)
            code, timed_out = None, True
            try:
                proc.wait(timeout=30)
            except Exception:
                pass
    return {"exit_code": code, "timed_out": timed_out, "started_monotonic": started, "ended_monotonic": time.monotonic(), "start_failed": False}


def probe_gateway(root: str, messages: list, extra_args=(), timeout_seconds: float = 30.0) -> dict:
    """Start the local gateway exactly as documented (`python -m mcp_gateway --audit off`), send the given JSON-RPC
    messages on stdin, close stdin and collect the outputs. The command shape is fixed; only flags from the gateway's
    own bounded set may be added. Returns {returncode, stdout_lines, stderr_text, timed_out}."""
    import json
    allowed = {"--operation-timeout", "--max-session-calls", "--max-rows", "--max-message-bytes"}
    extra = list(extra_args)
    if any(not isinstance(a, str) for a in extra) or any(a.startswith("--") and a not in allowed for a in extra):
        raise ReadinessError("E_COMMAND")
    argv = [sys.executable, "-m", "mcp_gateway", "--audit", "off", *extra]
    newline = bytes([10])
    payload = b"".join(json.dumps(m, separators=(",", ":")).encode("utf-8") + newline for m in messages)
    try:
        proc = subprocess.run(argv, cwd=root, input=payload, capture_output=True, timeout=timeout_seconds, env=clean_env(), shell=False)
    except subprocess.TimeoutExpired:
        return {"returncode": None, "stdout_lines": [], "stderr_text": "", "timed_out": True}
    except OSError:
        raise ReadinessError("E_COMMAND")
    return {"returncode": proc.returncode, "stdout_lines": proc.stdout.decode("utf-8", "replace").splitlines(),
            "stderr_text": proc.stderr.decode("utf-8", "replace"), "timed_out": False}


def version_line(tool: str) -> str:
    """First line of `<tool> --version` for git/bash only; 'UNAVAILABLE' when it cannot be obtained."""
    if tool not in ("git", "bash"):
        raise ReadinessError("E_COMMAND")
    try:
        out = subprocess.run([tool, "--version"], capture_output=True, timeout=30, env=clean_env(), shell=False).stdout
        return (out.decode("utf-8", "replace").splitlines() or ["UNAVAILABLE"])[0][:120]
    except (OSError, subprocess.SubprocessError):
        return "UNAVAILABLE"


def python_executable() -> str:
    return sys.executable
